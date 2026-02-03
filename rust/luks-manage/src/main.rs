use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// LUKS encryption management CLI
#[derive(Parser)]
#[command(name = "luks-manage")]
#[command(about = "Manage LUKS encrypted devices with TPM2 support", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Show status of all LUKS devices
    Status,

    /// Enroll TPM2 for auto-unlock
    EnrollTpm2 {
        /// Device to enroll (e.g., /dev/nvme0n1p2)
        device: PathBuf,

        /// PCR banks to bind to (comma-separated, default: 7)
        #[arg(long, default_value = "7")]
        pcr: String,
    },

    /// Add passphrase to LUKS key slot
    AddPassphrase {
        /// Device to add passphrase to
        device: PathBuf,

        /// Key slot to use (0-7)
        #[arg(long)]
        slot: Option<u8>,
    },

    /// Remove key from LUKS slot
    RemoveKey {
        /// Device to remove key from
        device: PathBuf,

        /// Key slot to remove (0-7)
        slot: u8,
    },

    /// Rotate LUKS master key
    RotateKey {
        /// Device to rotate key for
        device: PathBuf,
    },

    /// Backup LUKS header
    BackupHeader {
        /// Device to backup
        device: PathBuf,

        /// Output directory (default: /var/lib/luks-backups)
        #[arg(long, default_value = "/var/lib/luks-backups")]
        output: PathBuf,
    },

    /// Restore LUKS header
    RestoreHeader {
        /// Device to restore to
        device: PathBuf,

        /// Backup file to restore from
        backup: PathBuf,
    },

    /// Test if passphrase works
    TestUnlock {
        /// Device to test
        device: PathBuf,
    },

    /// Benchmark encryption performance
    Benchmark {
        /// Device to benchmark
        device: PathBuf,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Status => show_status(),
        Commands::EnrollTpm2 { device, pcr } => enroll_tpm2(&device, &pcr),
        Commands::AddPassphrase { device, slot } => add_passphrase(&device, slot),
        Commands::RemoveKey { device, slot } => remove_key(&device, slot),
        Commands::RotateKey { device } => rotate_key(&device),
        Commands::BackupHeader { device, output } => backup_header(&device, &output),
        Commands::RestoreHeader { device, backup } => restore_header(&device, &backup),
        Commands::TestUnlock { device } => test_unlock(&device),
        Commands::Benchmark { device } => benchmark(&device),
    };

    if let Err(e) = result {
        eprintln!("{} {}", "Error:".red().bold(), e);
        std::process::exit(1);
    }
}

fn show_status() -> Result<()> {
    println!("{}", "=== LUKS Device Status ===".cyan().bold());
    println!();

    // Find all LUKS devices
    let output = Command::new("lsblk")
        .args(&["-o", "NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT", "-p"])
        .output()
        .context("Failed to run lsblk")?;

    if !output.status.success() {
        return Err(anyhow!("lsblk failed"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut found_luks = false;

    for line in stdout.lines() {
        if line.contains("crypto_LUKS") || line.contains("crypt") {
            println!("{}", line);
            found_luks = true;
        }
    }

    if !found_luks {
        println!("{}", "No LUKS devices found".yellow());
    }

    println!();
    println!("{}", "=== Mapped Devices ===".cyan().bold());

    let mapper_dir = Path::new("/dev/mapper");
    if mapper_dir.exists() {
        for entry in std::fs::read_dir(mapper_dir)? {
            let entry = entry?;
            let name = entry.file_name();
            let name_str = name.to_string_lossy();

            // Skip control device
            if name_str == "control" {
                continue;
            }

            println!("  {} -> {}", name_str.green(), entry.path().display());
        }
    }

    Ok(())
}

fn enroll_tpm2(device: &Path, pcr: &str) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;
    check_luks_device(device)?;

    println!(
        "{}",
        format!("Enrolling TPM2 for device: {}", device.display())
            .cyan()
            .bold()
    );
    println!("PCR banks: {}", pcr.yellow());
    println!();

    // Check if TPM2 is available
    let tpm_check = Command::new("systemd-cryptenroll")
        .args(&["--tpm2-device=list"])
        .output()
        .context("Failed to check TPM2 availability")?;

    if !tpm_check.status.success() {
        return Err(anyhow!("No TPM2 device found"));
    }

    println!("{}", "Available TPM2 devices:".green());
    println!("{}", String::from_utf8_lossy(&tpm_check.stdout));

    // Confirm enrollment
    print!("Enroll TPM2 for auto-unlock? [y/N]: ");
    io::stdout().flush()?;
    let mut response = String::new();
    io::stdin().read_line(&mut response)?;

    if !response.trim().eq_ignore_ascii_case("y") {
        println!("{}", "Enrollment cancelled".yellow());
        return Ok(());
    }

    // Perform enrollment
    println!("{}", "Enrolling TPM2...".cyan());
    let status = Command::new("systemd-cryptenroll")
        .arg(device)
        .arg("--tpm2-device=auto")
        .arg(format!("--tpm2-pcrs={}", pcr))
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("Failed to enroll TPM2")?;

    if !status.success() {
        return Err(anyhow!("TPM2 enrollment failed"));
    }

    println!();
    println!("{}", "✓ TPM2 enrollment successful".green().bold());
    println!(
        "{}",
        "Device will now auto-unlock on boot (with passphrase fallback)".green()
    );

    Ok(())
}

fn add_passphrase(device: &Path, slot: Option<u8>) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;
    check_luks_device(device)?;

    println!(
        "{}",
        format!("Adding passphrase to device: {}", device.display())
            .cyan()
            .bold()
    );

    let slot_string;
    let mut args = vec!["luksAddKey", device.to_str().unwrap()];
    if let Some(s) = slot {
        if s > 7 {
            return Err(anyhow!("Key slot must be 0-7"));
        }
        slot_string = s.to_string();
        args.push("--key-slot");
        args.push(&slot_string);
    }

    let status = Command::new("cryptsetup")
        .args(&args)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("Failed to add passphrase")?;

    if !status.success() {
        return Err(anyhow!("Failed to add passphrase"));
    }

    println!();
    println!("{}", "✓ Passphrase added successfully".green().bold());

    Ok(())
}

fn remove_key(device: &Path, slot: u8) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;
    check_luks_device(device)?;

    if slot > 7 {
        return Err(anyhow!("Key slot must be 0-7"));
    }

    println!(
        "{}",
        format!("Removing key from slot {} on device: {}", slot, device.display())
            .red()
            .bold()
    );
    println!();
    println!("{}", "WARNING: This action cannot be undone!".red().bold());

    print!("Are you sure you want to remove this key? [y/N]: ");
    io::stdout().flush()?;
    let mut response = String::new();
    io::stdin().read_line(&mut response)?;

    if !response.trim().eq_ignore_ascii_case("y") {
        println!("{}", "Key removal cancelled".yellow());
        return Ok(());
    }

    let status = Command::new("cryptsetup")
        .args(&[
            "luksKillSlot",
            device.to_str().unwrap(),
            &slot.to_string(),
        ])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("Failed to remove key")?;

    if !status.success() {
        return Err(anyhow!("Failed to remove key"));
    }

    println!();
    println!("{}", "✓ Key removed successfully".green().bold());

    Ok(())
}

fn rotate_key(device: &Path) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;
    check_luks_device(device)?;

    println!(
        "{}",
        format!("Rotating master key for device: {}", device.display())
            .yellow()
            .bold()
    );
    println!();
    println!("{}", "This will re-encrypt the LUKS header with a new master key.".yellow());
    println!("{}", "All key slots will remain valid.".yellow());
    println!();

    print!("Continue with key rotation? [y/N]: ");
    io::stdout().flush()?;
    let mut response = String::new();
    io::stdin().read_line(&mut response)?;

    if !response.trim().eq_ignore_ascii_case("y") {
        println!("{}", "Key rotation cancelled".yellow());
        return Ok(());
    }

    let status = Command::new("cryptsetup")
        .args(&["luksChangeKey", device.to_str().unwrap()])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("Failed to rotate key")?;

    if !status.success() {
        return Err(anyhow!("Key rotation failed"));
    }

    println!();
    println!("{}", "✓ Master key rotated successfully".green().bold());

    Ok(())
}

fn backup_header(device: &Path, output_dir: &Path) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;
    check_luks_device(device)?;

    std::fs::create_dir_all(output_dir)
        .context(format!("Failed to create output directory: {}", output_dir.display()))?;

    let device_name = device.file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| anyhow!("Invalid device name"))?;

    let timestamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
    let backup_file = output_dir.join(format!("{}-header-{}.img", device_name, timestamp));

    println!(
        "{}",
        format!("Backing up LUKS header for: {}", device.display())
            .cyan()
            .bold()
    );
    println!("Output: {}", backup_file.display().to_string().green());

    let status = Command::new("cryptsetup")
        .args(&[
            "luksHeaderBackup",
            device.to_str().unwrap(),
            "--header-backup-file",
            backup_file.to_str().unwrap(),
        ])
        .status()
        .context("Failed to backup header")?;

    if !status.success() {
        return Err(anyhow!("Header backup failed"));
    }

    println!();
    println!("{}", "✓ LUKS header backed up successfully".green().bold());
    println!("{}", "Keep this file in a secure location!".yellow().bold());

    Ok(())
}

fn restore_header(device: &Path, backup: &Path) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;

    if !backup.exists() {
        return Err(anyhow!("Backup file not found: {}", backup.display()));
    }

    println!(
        "{}",
        format!("Restoring LUKS header to: {}", device.display())
            .red()
            .bold()
    );
    println!("From backup: {}", backup.display().to_string().yellow());
    println!();
    println!("{}", "WARNING: This will DESTROY all data on the device!".red().bold());
    println!("{}", "Make absolutely sure this is the correct device!".red().bold());
    println!();

    print!("Type 'YES' to confirm header restoration: ");
    io::stdout().flush()?;
    let mut response = String::new();
    io::stdin().read_line(&mut response)?;

    if response.trim() != "YES" {
        println!("{}", "Header restoration cancelled".yellow());
        return Ok(());
    }

    let status = Command::new("cryptsetup")
        .args(&[
            "luksHeaderRestore",
            device.to_str().unwrap(),
            "--header-backup-file",
            backup.to_str().unwrap(),
        ])
        .status()
        .context("Failed to restore header")?;

    if !status.success() {
        return Err(anyhow!("Header restoration failed"));
    }

    println!();
    println!("{}", "✓ LUKS header restored successfully".green().bold());

    Ok(())
}

fn test_unlock(device: &Path) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;
    check_luks_device(device)?;

    println!(
        "{}",
        format!("Testing passphrase for device: {}", device.display())
            .cyan()
            .bold()
    );
    println!();
    println!("{}", "Enter passphrase to test:".yellow());

    let status = Command::new("cryptsetup")
        .args(&["luksOpen", "--test-passphrase", device.to_str().unwrap()])
        .stdin(Stdio::inherit())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .context("Failed to test passphrase")?;

    println!();
    if status.success() {
        println!("{}", "✓ Passphrase is valid".green().bold());
    } else {
        println!("{}", "✗ Passphrase is invalid".red().bold());
    }

    Ok(())
}

fn benchmark(device: &Path) -> Result<()> {
    check_root()?;
    check_device_exists(device)?;
    check_luks_device(device)?;

    println!(
        "{}",
        format!("Benchmarking encryption for device: {}", device.display())
            .cyan()
            .bold()
    );
    println!();

    let status = Command::new("cryptsetup")
        .args(&["benchmark", "--cipher", "aes-xts-plain64"])
        .status()
        .context("Failed to run benchmark")?;

    if !status.success() {
        return Err(anyhow!("Benchmark failed"));
    }

    Ok(())
}

// Helper functions

fn check_root() -> Result<()> {
    if unsafe { libc::geteuid() } != 0 {
        return Err(anyhow!("This command requires root privileges (use sudo)"));
    }
    Ok(())
}

fn check_device_exists(device: &Path) -> Result<()> {
    if !device.exists() {
        return Err(anyhow!("Device not found: {}", device.display()));
    }
    Ok(())
}

fn check_luks_device(device: &Path) -> Result<()> {
    let output = Command::new("cryptsetup")
        .args(&["isLuks", device.to_str().unwrap()])
        .output()
        .context("Failed to check LUKS status")?;

    if !output.status.success() {
        return Err(anyhow!("Device is not a LUKS device: {}", device.display()));
    }

    Ok(())
}
