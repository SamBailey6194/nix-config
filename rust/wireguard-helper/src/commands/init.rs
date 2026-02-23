use crate::wg_config;
use anyhow::{Context, Result};
use std::process::Command;

pub fn run(device: &str) -> Result<()> {
    // Validate device name to prevent injection attacks
    let device = crate::validation::validate_device_name(device)?;

    println!("Initializing WireGuard for device: {}", device);

    // Generate WireGuard keypair
    println!("Generating WireGuard keypair...");
    let (private_key, public_key) =
        wg_config::generate_keypair().context("Failed to generate WireGuard keypair")?;

    // Validate the generated keys
    crate::validation::validate_wg_key(&private_key)
        .context("Generated private key has invalid format")?;
    crate::validation::validate_wg_key(&public_key)
        .context("Generated public key has invalid format")?;

    println!("✅ Generated keypair");
    println!("   Public key: {}", public_key);
    println!("   Private key: <hidden>");

    // Get secrets directory
    let secrets_dir = crate::paths::get_secrets_dir()?;

    // Encrypt private key to agenix
    let secret_name = format!("wireguard-{}-private.age", device);
    let secret_path = secrets_dir.join(&secret_name);

    println!("\nEncrypting private key to agenix...");

    // Create secure temporary file with private key
    use std::io::Write;
    use tempfile::NamedTempFile;

    let mut temp_file = NamedTempFile::new().context("Failed to create temporary file")?;
    temp_file
        .write_all(private_key.as_bytes())
        .context("Failed to write to temporary file")?;

    let _temp_path = temp_file.path();

    // Encrypt with agenix
    let secret_path_str = secret_path
        .to_str()
        .context("Secret path contains invalid UTF-8")?;

    // When running as root (via sudo), agenix can't find user SSH keys.
    // Use the host SSH key which root can read and is authorised in secrets.nix.
    let host_key_path = "/etc/ssh/ssh_host_ed25519_key";
    let mut agenix_args = vec!["-e", secret_path_str];
    if std::path::Path::new(host_key_path).exists() {
        agenix_args.extend(["-i", host_key_path]);
    }

    let output = Command::new("agenix")
        .args(&agenix_args)
        .stdin(std::process::Stdio::piped())
        .output()
        .context("Failed to run agenix")?;

    // Temp file automatically cleaned up when temp_file is dropped

    if !output.status.success() {
        // Log full error to stderr for debugging, but don't expose to user
        eprintln!(
            "DEBUG: agenix stderr: {}",
            String::from_utf8_lossy(&output.stderr)
        );
        anyhow::bail!("Failed to encrypt private key. Check that agenix is installed and secrets.nix is configured correctly");
    }

    println!("✅ Private key encrypted to: {}", secret_path.display());

    println!("\n🎯 Next steps:");
    println!("1. Add this public key to your Mullvad account:");
    println!("   {}", public_key);
    println!("2. Save your Mullvad account number:");
    println!("   agenix -e secrets/mullvad-account-{}.age", device);
    println!("3. Generate initial VPN configuration:");
    println!("   just vpn-rotate {}", device);

    Ok(())
}
