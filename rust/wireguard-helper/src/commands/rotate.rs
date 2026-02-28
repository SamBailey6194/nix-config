use crate::mullvad_api::MullvadApi;
use crate::route_history::RouteHistory;
use crate::wg_config;
use anyhow::{Context, Result};
use std::path::Path;

/// Create a directory with secure permissions (0700 - owner only)
#[cfg(unix)]
fn create_secure_dir(path: &Path) -> Result<()> {
    use std::fs::DirBuilder;
    use std::os::unix::fs::DirBuilderExt;

    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(path)
        .context("Failed to create directory with secure permissions")?;
    Ok(())
}

#[cfg(not(unix))]
fn create_secure_dir(path: &Path) -> Result<()> {
    fs::create_dir_all(path).context("Failed to create directory")?;
    Ok(())
}

pub fn run(device: &str, ipv4_address: &str, ipv6_address: &str) -> Result<()> {
    // Validate inputs to prevent injection attacks
    let device = crate::validation::validate_device_name(device)?;

    // Exit is permanently fixed to UK — this is enforced here, not via a CLI flag,
    // so it cannot be accidentally overridden.
    let exit = "uk";

    println!("Rotating Mullvad servers for device: {}", device);
    println!("Exit location: UK (fixed)");
    println!("Client address: {}, {}", ipv4_address, ipv6_address);

    // Get directories
    let cache_dir = crate::paths::get_cache_dir()?;
    let secrets_dir = crate::paths::get_secrets_dir()?;

    // Ensure cache directory exists with secure permissions
    create_secure_dir(&cache_dir)?;

    // Load route history
    let history_path = cache_dir.join(format!("route-history-{}.json", device));
    let history_path_str = history_path
        .to_str()
        .context("History path contains invalid UTF-8")?;
    let mut history =
        RouteHistory::load(history_path_str).context("Failed to load route history")?;

    let used_servers = history.get_used_servers();
    println!("Avoiding {} previously used servers", used_servers.len());

    // Fetch relays and select hops
    let cache_path = cache_dir.join("relay-cache.json");
    let cache_path_str = cache_path
        .to_str()
        .context("Cache path contains invalid UTF-8")?;
    let mut api =
        MullvadApi::new(cache_path_str).context("Failed to initialize Mullvad API client")?;

    // Mullvad supports 2-hop multi-hop: entry → exit
    let selected_hops = api
        .select_hops(exit, 2, &used_servers)
        .context("Failed to select relay hops")?;

    let entry_relay = &selected_hops[0];
    let exit_relay = &selected_hops[1];

    // Read decrypted private key from agenix runtime location
    // Agenix deploys decrypted secrets to /run/agenix/ at boot time
    let runtime_key_path =
        std::path::PathBuf::from("/run/agenix").join(format!("wireguard-{}-private", device));

    // Check if the encrypted secret exists in the repo
    let encrypted_key_path = secrets_dir.join(format!("wireguard-{}-private.age", device));
    if !encrypted_key_path.exists() {
        anyhow::bail!(
            "Encrypted private key not found at {}. Run 'wireguard-helper init {}' first",
            encrypted_key_path.display(),
            device
        );
    }

    // Read the decrypted key from runtime location
    if !runtime_key_path.exists() {
        anyhow::bail!(
            "WireGuard private key not deployed by agenix. \
             Expected at: {}\n\
             Ensure the secret is configured in secrets.nix and rebuild your system with:\n  \
             sudo nixos-rebuild switch --flake .#{}\n\
             If you just created the secret, you need to rebuild first.",
            runtime_key_path.display(),
            device
        );
    }

    let private_key = std::fs::read_to_string(&runtime_key_path)
        .context("Failed to read WireGuard private key from agenix runtime location")?
        .trim()
        .to_string();

    // Validate key format before using it
    crate::validation::validate_wg_key(&private_key)
        .context("Invalid WireGuard private key format")?;

    // Generate WireGuard config (2-hop: connect to entry on exit's multihop_port)
    let config = wg_config::generate_config(
        &private_key,
        entry_relay,
        exit_relay,
        ipv4_address,
        ipv6_address,
    )
    .context("Failed to generate WireGuard config")?;

    // SECURITY: Encrypt configuration directly to agenix without writing cleartext to disk
    // This prevents the private key from being exposed in /tmp
    let config_secret_name = format!("mullvad-wg-config-{}.age", device);
    let config_secret_path = secrets_dir.join(&config_secret_name);

    println!("\n✅ Generated configuration");
    println!("📝 Encrypting to agenix secret: {}", config_secret_name);

    // Use agenix to encrypt the config directly via stdin
    use std::process::{Command, Stdio};

    // When running as root (via sudo), agenix can't find user SSH keys.
    // Use the host SSH key which root can read and is authorised in secrets.nix.
    let host_key_path = "/etc/ssh/ssh_host_ed25519_key";
    let mut agenix_args = vec!["-e", &config_secret_name];
    if std::path::Path::new(host_key_path).exists() {
        agenix_args.extend(["-i", host_key_path]);
    }

    let mut agenix = Command::new("agenix")
        .args(&agenix_args)
        .current_dir(&secrets_dir)
        .stdin(Stdio::piped())
        .spawn()
        .context("Failed to start agenix for encryption. Is agenix installed?")?;

    if let Some(mut stdin) = agenix.stdin.take() {
        use std::io::Write;
        stdin
            .write_all(config.as_bytes())
            .context("Failed to write config to agenix stdin")?;
    }

    let status = agenix.wait().context("Failed to wait for agenix process")?;

    if !status.success() {
        anyhow::bail!(
            "Failed to encrypt configuration with agenix (exit code: {:?})",
            status.code()
        );
    }

    println!(
        "✅ Configuration encrypted to: {}",
        config_secret_path.display()
    );

    // Update route history
    let server_names: Vec<String> = selected_hops.iter().map(|r| r.hostname.clone()).collect();
    history.add(server_names, exit.to_string());
    history
        .save(history_path_str)
        .context("Failed to save route history")?;

    println!("\n🎯 Next steps:");
    println!("1. Commit the encrypted config:");
    println!("   git add {}", config_secret_path.display());
    println!(
        "   git commit -m 'feat(wireguard): Update Mullvad config for {}'",
        device
    );
    println!("2. Rebuild NixOS:");
    println!("   sudo nixos-rebuild switch --flake .#{}", device);
    println!("3. Start VPN:");
    println!("   just vpn-up");

    Ok(())
}
