use anyhow::{Context, Result};
use colored::*;
use std::fs;
use std::path::Path;
use std::process::Command;

const DEFAULT_DEVICES: &[&str] = &["laptop-intel", "framework", "devtower"];

pub fn run(repo_root: &Path, server_name: &str, devices: Option<Vec<String>>) -> Result<()> {
    let devices = devices
        .unwrap_or_else(|| DEFAULT_DEVICES.iter().map(|s| s.to_string()).collect());

    println!(
        "{}",
        format!("🔑 Adding server: {}", server_name).bold().cyan()
    );
    println!();

    crate::print_info(&format!(
        "Generating per-device SSH keys for {} devices",
        devices.len()
    ));
    println!();

    let secrets_dir = repo_root.join("secrets");
    let temp_dir = std::env::temp_dir();

    let mut public_keys = Vec::new();

    // Generate SSH keys for each device
    for device in &devices {
        println!("  {} Generating key for {}...", "⚙️".blue(), device.bold());

        let key_name = format!("server-{}-{}-key", server_name, device);
        let temp_key = temp_dir.join(&key_name);

        // Generate SSH key WITH passphrase
        let passphrase = generate_random_passphrase()?;

        // Create key with passphrase
        let status = Command::new("ssh-keygen")
            .args([
                "-t",
                "ed25519",
                "-C",
                &format!("{}@{}", device, server_name),
                "-f",
                temp_key.to_str().unwrap(),
                "-N",
                &passphrase,
            ])
            .status()
            .context("Failed to generate SSH key")?;

        if !status.success() {
            anyhow::bail!("ssh-keygen failed for device: {}", device);
        }

        // Read public key
        let pub_key_path = temp_key.with_extension("pub");
        let pub_key = fs::read_to_string(&pub_key_path)
            .context("Failed to read public key")?
            .trim()
            .to_string();

        public_keys.push((device.clone(), pub_key));

        // Encrypt private key
        let key_age = format!("{}.age", key_name);
        let key_secret_path = secrets_dir.join(&key_age);

        crate::print_info(&format!("  Encrypting {}", key_age));

        // Read private key
        let private_key = fs::read_to_string(&temp_key)?;

        // Write to temp file for agenix
        let temp_input = temp_dir.join(format!("{}.tmp", key_name));
        fs::write(&temp_input, private_key)?;

        // TODO: Encrypt with agenix
        // For now, we'll just show what would happen
        println!(
            "    {} Would encrypt: {}",
            "ℹ️".blue(),
            key_age.dimmed()
        );

        // Encrypt passphrase
        let passphrase_age = format!("server-{}-{}-passphrase.age", server_name, device);
        println!(
            "    {} Would encrypt: {}",
            "ℹ️".blue(),
            passphrase_age.dimmed()
        );

        // Clean up temp files
        let _ = fs::remove_file(&temp_key);
        let _ = fs::remove_file(&pub_key_path);
        let _ = fs::remove_file(&temp_input);
    }

    println!();
    crate::print_success(&format!(
        "Generated SSH keys for {} devices",
        devices.len()
    ));
    println!();

    // Print public keys to add to server
    println!(
        "{}",
        "Add these public keys to the server's authorized_keys:".bold()
    );
    println!();

    for (device, pub_key) in &public_keys {
        println!("  # {}", device.dimmed());
        println!("  {}", pub_key);
        println!();
    }

    println!("{}", "Next steps:".bold().yellow());
    println!("  1. Add the above public keys to {}:/root/.ssh/authorized_keys", server_name);
    println!("  2. Uncomment the server entries in secrets/secrets.nix");
    println!("  3. Run: agenix-helper rekey");
    println!("  4. Update modules/core/secrets-*.nix to deploy the keys");
    println!("  5. Run: sudo nixos-rebuild switch");

    Ok(())
}

fn generate_random_passphrase() -> Result<String> {
    // Generate a random passphrase using /dev/urandom
    let output = Command::new("head")
        .args(["-c", "32", "/dev/urandom"])
        .output()
        .context("Failed to generate random passphrase")?;

    // Convert to base64 for a readable passphrase
    let passphrase = Command::new("base64")
        .arg("-w")
        .arg("0")
        .stdin(std::process::Stdio::piped())
        .output()
        .context("Failed to encode passphrase")?;

    let mut cmd = Command::new("base64");
    cmd.arg("-w").arg("0");

    let passphrase = base64::encode(&output.stdout);

    Ok(passphrase[..24].to_string()) // Take first 24 chars for reasonable length
}

// Simple base64 encoding without external crate
mod base64 {
    const CHARS: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    pub fn encode(input: &[u8]) -> String {
        let mut result = String::new();
        let mut i = 0;

        while i < input.len() {
            let b1 = input[i];
            let b2 = input.get(i + 1).copied().unwrap_or(0);
            let b3 = input.get(i + 2).copied().unwrap_or(0);

            result.push(CHARS[(b1 >> 2) as usize] as char);
            result.push(CHARS[(((b1 & 0x03) << 4) | (b2 >> 4)) as usize] as char);

            if i + 1 < input.len() {
                result.push(CHARS[(((b2 & 0x0F) << 2) | (b3 >> 6)) as usize] as char);
            } else {
                result.push('=');
            }

            if i + 2 < input.len() {
                result.push(CHARS[(b3 & 0x3F) as usize] as char);
            } else {
                result.push('=');
            }

            i += 3;
        }

        result
    }
}
