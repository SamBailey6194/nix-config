use anyhow::Result;
use colored::*;
use std::fs;
use std::path::Path;
use std::process::Command;

pub fn run(_repo_root: &Path) -> Result<()> {
    println!("{}", "🔍 Checking Host Keys".bold().cyan());
    println!();

    // Check if we're on a NixOS system
    let hostname_output = Command::new("hostname").output()?;
    let hostname = String::from_utf8_lossy(&hostname_output.stdout)
        .trim()
        .to_string();

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
