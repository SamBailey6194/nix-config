use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

/// TPM2 management CLI
#[derive(Parser)]
#[command(name = "tpm-manage")]
#[command(about = "Manage TPM2 devices and LUKS enrollments", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Show TPM2 status
    Status,

    /// List TPM2-enrolled LUKS devices
    EnrolledDevices,

    /// Remove TPM2 enrollment from device
    ClearDevice {
        /// Device to clear TPM2 enrollment from
        device: PathBuf,
    },

    /// Re-enroll device with TPM2
    ReEnroll {
        /// Device to re-enroll
        device: PathBuf,

        /// PCR banks to bind to (comma-separated, default: 7)
        #[arg(long, default_value = "7")]
        pcr: String,
    },

    /// Verify TPM2 is working
    Verify,
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Status => show_status(),
        Commands::EnrolledDevices => list_enrolled_devices(),
        Commands::ClearDevice { device } => clear_device(&device),
        Commands::ReEnroll { device, pcr } => re_enroll_device(&device, &pcr),
        Commands::Verify => verify_tpm(),
    };

    if let Err(e) = result {
        eprintln!("{} {}", "Error:".red().bold(), e);
        std::process::exit(1);
    }
}

fn show_status() -> Result<()> {
    println!("{}", "=== TPM2 Status ===".cyan().bold());
    println!();

    // Check if TPM2 device exists
    let tpm_devices = ["/dev/tpm0", "/dev/tpmrm0"];
    let mut found = false;

    for dev in &tpm_devices {
        if Path::new(dev).exists() {
            println!("{} {}", "✓".green(), format!("TPM device found: {}", dev).green());
            found = true;
        }
    }

    if !found {
        println!("{} {}", "✗".red(), "No TPM device found".red());
        return Ok(());
    }

    println!();

    // Get TPM2 capabilities
    println!("{}", "TPM2 Capabilities:".cyan());
    let output = Command::new("systemd-cryptenroll")
        .args(&["--tpm2-device=list"])
        .output()
        .context("Failed to list TPM2 devices")?;

    if output.status.success() {
        println!("{}", String::from_utf8_lossy(&output.stdout));
    } else {
        println!("{}", "Could not retrieve TPM2 capabilities".yellow());
    }

    // Check TPM2 PCR values
    println!();
    println!("{}", "TPM2 PCR Banks:".cyan());
    let pcr_output = Command::new("tpm2_pcrread")
        .output();

    if let Ok(output) = pcr_output {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            // Only show first few lines to avoid clutter
            for line in stdout.lines().take(10) {
                println!("{}", line);
            }
            if stdout.lines().count() > 10 {
                println!("{}", "... (truncated)".dimmed());
            }
        }
    } else {
        println!("{}", "tpm2_pcrread not available (install tpm2-tools)".yellow());
    }

    Ok(())
}

fn list_enrolled_devices() -> Result<()> {
    println!("{}", "=== TPM2-Enrolled LUKS Devices ===".cyan().bold());
    println!();

    // Find all LUKS devices
    let output = Command::new("lsblk")
        .args(&["-o", "NAME,TYPE,FSTYPE", "-p", "-n"])
        .output()
        .context("Failed to list block devices")?;

    if !output.status.success() {
        return Err(anyhow!("Failed to list block devices"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut found_any = false;

    for line in stdout.lines() {
        if !line.contains("crypto_LUKS") {
            continue;
        }

        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }

        let device = parts[0];
        found_any = true;

        // Check if device has TPM2 enrollment
        let luksmeta_output = Command::new("systemd-cryptenroll")
            .args(&[device])
            .output();

        match luksmeta_output {
            Ok(output) => {
                let info = String::from_utf8_lossy(&output.stdout);
                if info.contains("tpm2") {
                    println!("{} {}", "✓".green(), device.green());
                    println!("  {}", "TPM2 enrolled".dimmed());
                } else {
                    println!("{} {}", "✗".yellow(), device);
                    println!("  {}", "No TPM2 enrollment".dimmed());
                }
            }
            Err(_) => {
                println!("{} {}", "?".yellow(), device);
                println!("  {}", "Could not check enrollment status".dimmed());
            }
        }
        println!();
    }

    if !found_any {
        println!("{}", "No LUKS devices found".yellow());
    }

    Ok(())
}

fn clear_device(device: &Path) -> Result<()> {
    check_root()?;

    if !device.exists() {
        return Err(anyhow!("Device not found: {}", device.display()));
    }

    println!(
        "{}",
        format!("Clearing TPM2 enrollment from: {}", device.display())
            .yellow()
            .bold()
    );
    println!();
    println!("{}", "This will remove TPM2 auto-unlock (passphrase will still work)".yellow());

    print!("Continue? [y/N]: ");
    io::stdout().flush()?;
    let mut response = String::new();
    io::stdin().read_line(&mut response)?;

    if !response.trim().eq_ignore_ascii_case("y") {
        println!("{}", "Operation cancelled".yellow());
        return Ok(());
    }

    let status = Command::new("systemd-cryptenroll")
        .args(&[device.to_str().unwrap(), "--wipe-slot=tpm2"])
        .status()
        .context("Failed to clear TPM2 enrollment")?;

    if !status.success() {
        return Err(anyhow!("Failed to clear TPM2 enrollment"));
    }

    println!();
    println!("{}", "✓ TPM2 enrollment cleared".green().bold());

    Ok(())
}

fn re_enroll_device(device: &Path, pcr: &str) -> Result<()> {
    check_root()?;

    if !device.exists() {
        return Err(anyhow!("Device not found: {}", device.display()));
    }

    println!(
        "{}",
        format!("Re-enrolling TPM2 for device: {}", device.display())
            .cyan()
            .bold()
    );
    println!("PCR banks: {}", pcr.yellow());
    println!();

    // Clear existing TPM2 enrollment first
    println!("{}", "Clearing existing TPM2 enrollment...".dimmed());
    let _ = Command::new("systemd-cryptenroll")
        .args(&[device.to_str().unwrap(), "--wipe-slot=tpm2"])
        .output();

    // Enroll TPM2
    println!("{}", "Enrolling TPM2...".cyan());
    let status = Command::new("systemd-cryptenroll")
        .arg(device)
        .arg("--tpm2-device=auto")
        .arg(format!("--tpm2-pcrs={}", pcr))
        .status()
        .context("Failed to enroll TPM2")?;

    if !status.success() {
        return Err(anyhow!("TPM2 enrollment failed"));
    }

    println!();
    println!("{}", "✓ TPM2 re-enrolled successfully".green().bold());

    Ok(())
}

fn verify_tpm() -> Result<()> {
    println!("{}", "=== Verifying TPM2 ===".cyan().bold());
    println!();

    // Check TPM device exists
    let tpm_exists = Path::new("/dev/tpm0").exists() || Path::new("/dev/tpmrm0").exists();
    print_check("TPM device exists", tpm_exists);

    // Check systemd-cryptenroll is available
    let cryptenroll_available = Command::new("which")
        .arg("systemd-cryptenroll")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    print_check("systemd-cryptenroll available", cryptenroll_available);

    // Check tpm2-tools is available
    let tpm2_tools_available = Command::new("which")
        .arg("tpm2_pcrread")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    print_check("tpm2-tools available", tpm2_tools_available);

    // Try to list TPM2 devices
    if cryptenroll_available {
        let tpm_list = Command::new("systemd-cryptenroll")
            .args(&["--tpm2-device=list"])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);
        print_check("TPM2 device accessible", tpm_list);
    }

    println!();
    if tpm_exists && cryptenroll_available {
        println!("{}", "✓ TPM2 is working correctly".green().bold());
    } else {
        println!("{}", "✗ TPM2 is not fully functional".red().bold());
        if !tpm_exists {
            println!("  - No TPM device found");
        }
        if !cryptenroll_available {
            println!("  - systemd-cryptenroll not found");
        }
    }

    Ok(())
}

fn print_check(label: &str, success: bool) {
    if success {
        println!("{} {}", "✓".green(), label);
    } else {
        println!("{} {}", "✗".red(), label);
    }
}

fn check_root() -> Result<()> {
    if unsafe { libc::geteuid() } != 0 {
        return Err(anyhow!("This command requires root privileges (use sudo)"));
    }
    Ok(())
}
