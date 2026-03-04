use crate::cache::Cache;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

const MULLVAD_API_URL: &str = "https://api.mullvad.net/www/relays/wireguard/";
const CACHE_TTL_HOURS: u64 = 6;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Relay {
    pub hostname: String,
    pub ipv4_addr_in: String,
    #[serde(default)]
    pub ipv6_addr_in: Option<String>,
    #[serde(alias = "public_key")]
    pub pubkey: String,
    pub multihop_port: u16,
    pub country_code: String,
    #[serde(default)]
    pub city_name: Option<String>,
    pub active: bool,
}

pub struct MullvadApi {
    cache: Cache<Vec<Relay>>,
}

/// Validate a relay entry from the API
fn validate_relay(relay: &Relay) -> Result<()> {
    // Validate hostname format
    crate::validation::validate_hostname(&relay.hostname)
        .with_context(|| format!("Invalid hostname: {}", relay.hostname))?;

    // Validate IPv4 address
    crate::validation::validate_ipv4(&relay.ipv4_addr_in)
        .with_context(|| format!("Invalid IPv4 address: {}", relay.ipv4_addr_in))?;

    // Validate public key format (WireGuard keys are 44 chars base64)
    crate::validation::validate_wg_key(&relay.pubkey)
        .with_context(|| format!("Invalid public key for {}", relay.hostname))?;

    // Validate port number
    crate::validation::validate_port(relay.multihop_port)
        .with_context(|| format!("Invalid port for {}", relay.hostname))?;

    // Validate country code (ISO 3166-1 alpha-2: 2 lowercase letters)
    crate::validation::validate_country_code(&relay.country_code)
        .with_context(|| format!("Invalid country code: {}", relay.country_code))?;

    Ok(())
}

impl MullvadApi {
    pub fn new(cache_path: &str) -> Result<Self> {
        // Clear old cache on format change (app/v1 -> www API)
        let path = std::path::Path::new(cache_path);
        if path.exists() {
            if let Ok(contents) = std::fs::read_to_string(path) {
                if contents.contains("\"wireguard\"") {
                    let _ = std::fs::remove_file(path);
                }
            }
        }

        // Validate cache path
        let _validated = crate::validation::validate_simple_filename(
            std::path::Path::new(cache_path)
                .file_name()
                .and_then(|n| n.to_str())
                .context("Invalid cache path")?,
        )?;

        Ok(Self {
            cache: Cache::new(cache_path, CACHE_TTL_HOURS)?,
        })
    }

    /// Fetch relay list from Mullvad API (with caching)
    pub fn fetch_relays(&mut self) -> Result<Vec<Relay>> {
        // Try to load from cache first
        if let Some(relays) = self.cache.load()? {
            println!("Using cached relay list ({} relays)", relays.len());

            // Validate cached relays
            let validation_failed = relays.iter().any(|relay| validate_relay(relay).is_err());

            if validation_failed {
                eprintln!("WARNING: Cached relays failed validation, fetching fresh data");
                self.cache.clear()?;
                // Don't recurse - fall through to API fetch
            } else {
                return Ok(relays);
            }
        }

        // Fetch from API (non-recursive - only called if cache miss or invalid)
        self.fetch_relays_from_api()
    }

    /// Fetch relay list directly from Mullvad API
    fn fetch_relays_from_api(&mut self) -> Result<Vec<Relay>> {
        println!("Fetching relay list from Mullvad API...");

        // Build secure HTTPS client with modern TLS and security headers
        let client = reqwest::blocking::ClientBuilder::new()
            .https_only(true)
            .timeout(std::time::Duration::from_secs(30))
            .min_tls_version(reqwest::tls::Version::TLS_1_2)
            .user_agent("wireguard-helper/0.1.0")
            .build()
            .context("Failed to create HTTP client")?;

        let response = client
            .get(MULLVAD_API_URL)
            .header("Accept", "application/json")
            .send()
            .context("Failed to fetch Mullvad relay list")?;

        // SECURITY: Validate we actually connected to Mullvad (prevent redirects)
        if let Some(url) = response.url().domain() {
            if url != "api.mullvad.net" {
                anyhow::bail!("Unexpected redirect to domain: {}", url);
            }
        }

        let relays = response
            .json::<Vec<Relay>>()
            .context("Failed to parse Mullvad API response")?;

        // Validate all relays before caching
        println!("Validating {} relays from API...", relays.len());
        let mut valid_hostnames = Vec::new();
        let mut invalid_count = 0;

        for relay in &relays {
            match validate_relay(relay) {
                Ok(_) => valid_hostnames.push(relay.hostname.clone()),
                Err(e) => {
                    eprintln!("WARNING: Skipping invalid relay: {}", e);
                    invalid_count += 1;
                }
            }
        }

        if invalid_count > 0 {
            eprintln!(
                "WARNING: {} relays failed validation and were skipped",
                invalid_count
            );
        }

        if valid_hostnames.is_empty() {
            anyhow::bail!("No valid relays received from API");
        }

        println!("Validated {} relays successfully", valid_hostnames.len());

        // Save to cache
        self.cache.save(&relays)?;

        Ok(relays)
    }

    /// Select relays for the VPN route, avoiding previously used servers.
    ///
    /// - `num_hops == 1`: single-hop direct to an exit relay
    /// - `num_hops == 2`: multi-hop with entry relay (different country) → exit relay
    ///
    /// Returns `[exit]` for single-hop or `[entry, exit]` for multi-hop.
    pub fn select_hops(
        &mut self,
        exit_location: &str,
        num_hops: usize,
        used_servers: &HashSet<String>,
    ) -> Result<Vec<Relay>> {
        let relays = self.fetch_relays()?;

        // Filter active relays
        let active: Vec<_> = relays.into_iter().filter(|r| r.active).collect();

        // Define exit countries based on location preference
        let exit_countries = match exit_location {
            "uk" => vec!["gb"],
            "us" => vec!["us"],
            "eu" => vec!["nl", "de", "fr", "se"],
            _ => vec!["gb"],
        };

        // Filter relays by exit location
        let exit_relays: Vec<_> = active
            .iter()
            .filter(|r| exit_countries.contains(&r.country_code.as_str()))
            .filter(|r| !used_servers.contains(&r.hostname))
            .cloned()
            .collect();

        if exit_relays.is_empty() {
            anyhow::bail!("No available exit relays for location: {}", exit_location);
        }

        use rand::seq::SliceRandom;
        let mut rng = rand::thread_rng();

        // Pick an exit relay
        let exit = exit_relays
            .choose(&mut rng)
            .context("Failed to select exit relay")?
            .clone();

        if num_hops >= 2 {
            // Multi-hop: pick an entry relay from a DIFFERENT country than the exit
            let entry_relays: Vec<_> = active
                .iter()
                .filter(|r| !exit_countries.contains(&r.country_code.as_str()))
                .filter(|r| !used_servers.contains(&r.hostname))
                .filter(|r| r.hostname != exit.hostname)
                .cloned()
                .collect();

            if entry_relays.is_empty() {
                anyhow::bail!("No available entry relays for multi-hop (need a relay outside {:?})", exit_countries);
            }

            let entry = entry_relays
                .choose(&mut rng)
                .context("Failed to select entry relay")?
                .clone();

            println!("Selected multi-hop route:");
            println!("  Entry: {} ({}, {})",
                entry.hostname,
                entry.city_name.as_deref().unwrap_or("Unknown"),
                entry.country_code
            );
            println!("  Exit:  {} ({}, {})",
                exit.hostname,
                exit.city_name.as_deref().unwrap_or("Unknown"),
                exit.country_code
            );

            Ok(vec![entry, exit])
        } else {
            // Single-hop: direct to exit
            println!("Selected relay: {} ({}, {})",
                exit.hostname,
                exit.city_name.as_deref().unwrap_or("Unknown"),
                exit.country_code
            );

            Ok(vec![exit])
        }
    }
}
