use anyhow::Result;
use std::path::Path;

pub fn run(_repo_root: &Path, device: &str) -> Result<()> {
    // Validate device name to prevent injection attacks
    let device = crate::validation::validate_name(device, "Device")?;

    crate::print_info(&format!("Initializing secrets for device: {}", device));

    println!();
    println!("Steps to initialize secrets for {}:", device);
    println!();
    println!("1. Install NixOS on the device");
    println!("2. Get the host SSH key:");
    println!("   sudo cat /etc/ssh/ssh_host_ed25519_key.pub");
    println!();
    println!("3. Add the key to secrets/secrets.nix:");
    println!(
        "   {} = \"ssh-ed25519 AAAA... root@{}\";",
        device, device
    );
    println!();
    println!("4. Rekey all secrets to include the new device:");
    println!("   agenix-helper rekey");
    println!();
    println!("5. Rebuild on the device:");
    println!("   sudo nixos-rebuild switch --flake .#{}", device);

    Ok(())
}
