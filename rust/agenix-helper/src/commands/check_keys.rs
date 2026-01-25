use anyhow::{Context, Result};
use colored::*;
use std::fs;
use std::path::Path;
use std::process::Command;

/// SECURITY: Validate hostname to prevent path traversal and injection attacks
fn validate_hostname(hostname: &str) -> Result<String> {
    // Reject empty or overly long hostnames
    if hostname.is_empty() {
        anyhow::bail!("Hostname is empty");
    }

    if hostname.len() > 253 {
        anyhow::bail!("Hostname too long (max 253 characters)");
    }

    // Only allow alphanumeric, hyphens, and dots (RFC 1123)
    if !hostname
        .chars()
        .all(|c| c.is_alphanumeric() || c == '-' || c == '.')
    {
        anyhow::bail!("Hostname contains invalid characters (only alphanumeric, '-', '.' allowed)");
    }

    // Reject path traversal attempts
    if hostname.contains("..") || hostname.contains('/') || hostname.contains('\\') {
        anyhow::bail!("Hostname contains path traversal characters");
    }

    // Reject hostnames that start or end with hyphen or dot
    if hostname.starts_with('-')
        || hostname.ends_with('-')
        || hostname.starts_with('.')
        || hostname.ends_with('.')
    {
        anyhow::bail!("Hostname has invalid format (cannot start/end with '-' or '.')");
    }

    Ok(hostname.to_string())
}

pub fn run(_repo_root: &Path) -> Result<()> {
    println!("{}", "🔍 Checking Host Keys".bold().cyan());
    println!();

    // Check if we're on a NixOS system
    let hostname_output = Command::new("hostname").output()?;
    let raw_hostname = String::from_utf8_lossy(&hostname_output.stdout)
        .trim()
        .to_string();

    // SECURITY: Validate hostname before using it
    let hostname = validate_hostname(&raw_hostname).context("Invalid hostname detected")?;

    crate::print_info(&format!("Current hostname: {}", hostname));

    // Try to read the host SSH key
    let host_key_path = "/etc/ssh/ssh_host_ed25519_key.pub";

    if Path::new(host_key_path).exists() {
        let host_key = fs::read_to_string(host_key_path)?;
        println!();
        println!("{}", "Current host SSH key:".bold());
        println!("  {}", host_key.trim());
        println!();
        println!(
            "{}",
            "Make sure this matches the key in secrets/secrets.nix".yellow()
        );
    } else {
        crate::print_warning("Host SSH key not found (not on NixOS or key not generated)");
        println!("  Expected location: {}", host_key_path);
    }

    Ok(())
}
