use anyhow::{Context, Result};
use colored::*;
use std::fs;
use std::path::Path;
use std::process::Command;

const DEFAULT_DEVICES: &[&str] = &["laptop-intel", "framework", "devtower"];

pub fn run(repo_root: &Path, server_name: &str, devices: Option<Vec<String>>) -> Result<()> {
    // Validate server name to prevent injection attacks
    let server_name = crate::validation::validate_name(server_name, "Server")?;

    let devices =
        devices.unwrap_or_else(|| DEFAULT_DEVICES.iter().map(|s| s.to_string()).collect());

    // Validate all device names
    for device in &devices {
        crate::validation::validate_name(device, "Device")?;
    }

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

    // SECURITY: Create a secure temporary directory with 0700 permissions
    // This prevents other users from reading the SSH keys in transit
    let temp_dir = tempfile::Builder::new()
        .prefix("agenix-keys-")
        .tempdir()
        .context("Failed to create secure temporary directory")?;

    // Set secure permissions (owner-only)
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(temp_dir.path(), fs::Permissions::from_mode(0o700))
            .context("Failed to set secure permissions on temp directory")?;
    }

    let mut public_keys = Vec::new();

    // Generate SSH keys for each device
    for device in &devices {
        println!("  {} Generating key for {}...", "⚙️".blue(), device.bold());

        let key_name = format!("server-{}-{}-key", server_name, device);
        let temp_key = temp_dir.path().join(&key_name);

        // Generate SSH key WITH passphrase
        let passphrase = generate_random_passphrase()?;

        // Convert path to string with proper error handling
        let temp_key_str = temp_key
            .to_str()
            .context("Temporary key path contains invalid UTF-8")?;

        // SECURITY: Use stdin to pass passphrase instead of command-line args
        // to prevent exposure in process listings (ps aux)
        use std::io::Write;
        use std::process::Stdio;

        let mut child = Command::new("ssh-keygen")
            .args([
                "-t",
                "ed25519",
                "-C",
                &format!("{}@{}", device, server_name),
                "-f",
                temp_key_str,
            ])
            .stdin(Stdio::piped())
            .spawn()
            .context("Failed to spawn ssh-keygen")?;

        // Write passphrase to stdin (ssh-keygen will prompt twice)
        if let Some(mut stdin) = child.stdin.take() {
            writeln!(stdin, "{}", passphrase)
                .context("Failed to write passphrase to ssh-keygen stdin")?;
            writeln!(stdin, "{}", passphrase)
                .context("Failed to write passphrase confirmation to ssh-keygen stdin")?;
        }

        let status = child.wait().context("Failed to wait for ssh-keygen")?;

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
        let _key_secret_path = secrets_dir.join(&key_age);

        crate::print_info(&format!("  Encrypting {}", key_age));

        // Read private key
        let _private_key = fs::read_to_string(&temp_key)?;

        // SECURITY: Instead of writing to another temp file, encrypt directly via stdin
        // This prevents the private key from being written to disk unencrypted
        // TODO: Implement actual agenix encryption via stdin
        // For now, we'll just show what would happen
        println!("    {} Would encrypt: {}", "ℹ️".blue(), key_age.dimmed());

        // Encrypt passphrase
        let passphrase_age = format!("server-{}-{}-passphrase.age", server_name, device);
        println!(
            "    {} Would encrypt: {}",
            "ℹ️".blue(),
            passphrase_age.dimmed()
        );

        // Clean up temp files - no need to manually remove, tempdir cleanup handles it
        // But we'll do it anyway for extra security (defense in depth)
        let _ = fs::remove_file(&temp_key);
        let _ = fs::remove_file(&pub_key_path);
    }

    // Temp directory will be automatically cleaned up when temp_dir goes out of scope
    // This ensures cleanup even if an error occurs

    println!();
    crate::print_success(&format!("Generated SSH keys for {} devices", devices.len()));
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
    println!(
        "  1. Add the above public keys to {}:/root/.ssh/authorized_keys",
        server_name
    );
    println!("  2. Uncomment the server entries in secrets/secrets.nix");
    println!("  3. Run: agenix-helper rekey");
    println!("  4. Update modules/core/secrets-*.nix to deploy the keys");
    println!("  5. Run: sudo nixos-rebuild switch");

    Ok(())
}

/// Generate a cryptographically secure random passphrase
///
/// Uses rand::thread_rng() which provides a cryptographically secure PRNG
/// Returns a base64-encoded passphrase with 192 bits of entropy (24 bytes)
fn generate_random_passphrase() -> Result<String> {
    use base64::{engine::general_purpose::STANDARD, Engine};
    use rand::RngCore;

    // Generate 24 bytes of cryptographically secure random data (192 bits of entropy)
    let mut rng = rand::thread_rng();
    let mut bytes = [0u8; 24];
    rng.fill_bytes(&mut bytes);

    // Encode as base64 for a readable passphrase
    Ok(STANDARD.encode(bytes))
}
