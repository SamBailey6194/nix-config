use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::fs;
use std::process::Command;

const MDADM_CONF: &str = "/etc/mdadm.conf";

#[derive(Parser)]
#[command(name = "raid-manage")]
#[command(about = "RAID (mdadm) storage management helper", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new RAID array
    Create {
        /// RAID level (0, 1, 5, 6, 10)
        level: String,

        /// MD device path (e.g., /dev/md0)
        device: String,

        /// Component devices
        devices: Vec<String>,
    },

    /// Stop a RAID array
    Stop {
        /// MD device path
        device: String,
    },

    /// Assemble (start) a RAID array
    Assemble {
        /// MD device path
        device: String,
    },

    /// Show detailed array status
    Status {
        /// MD device (optional, shows all if not specified)
        device: Option<String>,
    },

    /// Show /proc/mdstat
    Mdstat,

    /// Add a device to an array
    Add {
        /// MD device path
        array: String,

        /// Device to add
        device: String,
    },

    /// Mark a device as failed
    Fail {
        /// MD device path
        array: String,

        /// Device to fail
        device: String,
    },

    /// Remove a device from an array
    Remove {
        /// MD device path
        array: String,

        /// Device to remove
        device: String,
    },

    /// Show rebuild progress
    Progress,

    /// Check array health
    Health,

    /// Update mdadm.conf with current arrays
    UpdateConfig,

    /// Monitor arrays (start monitoring daemon)
    Monitor {
        /// Enable monitoring
        #[arg(short, long)]
        enable: bool,

        /// Disable monitoring
        #[arg(short, long)]
        disable: bool,
    },
}

fn run_command(program: &str, args: &[&str]) -> Result<bool> {
    let status = Command::new(program).args(args).status().context(format!(
        "Failed to run: {} {}",
        program,
        args.join(" ")
    ))?;

    Ok(status.success())
}

fn run_command_output(program: &str, args: &[&str]) -> Result<String> {
    let output = Command::new(program).args(args).output().context(format!(
        "Failed to run: {} {}",
        program,
        args.join(" ")
    ))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Command failed: {} {}\n{}", program, args.join(" "), stderr);
    }

    Ok(String::from_utf8(output.stdout)?)
}

fn create(level: String, device: String, devices: Vec<String>) -> Result<()> {
    if devices.is_empty() {
        anyhow::bail!("No devices specified");
    }

    // Validate RAID level
    if !["0", "1", "5", "6", "10"].contains(&level.as_str()) {
        anyhow::bail!("Invalid RAID level. Must be: 0, 1, 5, 6, or 10");
    }

    println!("{} Creating RAID array:", "→".blue());
    println!("  Level: RAID{}", level.bold());
    println!("  Device: {}", device);
    println!("  Devices: {}", devices.join(" "));
    println!("  Count: {}", devices.len());
    println!();

    // Confirm
    print!(
        "{}  This will DESTROY all data on these devices. Continue? (yes/no): ",
        "⚠️".yellow()
    );
    std::io::Write::flush(&mut std::io::stdout())?;

    let mut input = String::new();
    std::io::stdin().read_line(&mut input)?;

    if input.trim() != "yes" {
        println!("Aborted");
        return Ok(());
    }

    // Build mdadm create command
    let device_count = devices.len().to_string();
    let mut args = vec![
        "--create",
        &device,
        "--level",
        &level,
        "--raid-devices",
        &device_count,
    ];

    for dev in &devices {
        args.push(dev);
    }

    if run_command("mdadm", &args)? {
        println!("{} Array created successfully", "✓".green());
        println!();

        // Update mdadm.conf
        update_config()?;

        // Show status
        run_command("mdadm", &["--detail", &device])?;

        println!();
        println!(
            "{} Monitor build progress with: raid-manage progress",
            "→".blue()
        );
    } else {
        anyhow::bail!("Failed to create array");
    }

    Ok(())
}

fn stop(device: String) -> Result<()> {
    println!("{} Stopping array: {}", "→".blue(), device.bold());

    if run_command("mdadm", &["--stop", &device])? {
        println!("{} Array stopped", "✓".green());
    } else {
        anyhow::bail!("Failed to stop array");
    }

    Ok(())
}

fn assemble(device: String) -> Result<()> {
    println!("{} Assembling array: {}", "→".blue(), device.bold());

    if run_command("mdadm", &["--assemble", &device])? {
        println!("{} Array assembled", "✓".green());
    } else {
        anyhow::bail!("Failed to assemble array");
    }

    Ok(())
}

fn status(device: Option<String>) -> Result<()> {
    if let Some(dev) = device {
        run_command("mdadm", &["--detail", &dev])?;
    } else {
        // Show all arrays
        let mdstat = fs::read_to_string("/proc/mdstat").context("Failed to read /proc/mdstat")?;

        let arrays: Vec<_> = mdstat
            .lines()
            .filter(|line| line.starts_with("md"))
            .map(|line| {
                let parts: Vec<_> = line.split_whitespace().collect();
                format!("/dev/{}", parts[0])
            })
            .collect();

        if arrays.is_empty() {
            println!("{}", "No RAID arrays found".yellow());
            return Ok(());
        }

        for array in arrays {
            println!();
            run_command("mdadm", &["--detail", &array])?;
        }
    }

    Ok(())
}

fn mdstat() -> Result<()> {
    let content = fs::read_to_string("/proc/mdstat").context("Failed to read /proc/mdstat")?;

    println!("{}", content);
    Ok(())
}

fn add(array: String, device: String) -> Result<()> {
    println!("{} Adding {} to {}", "→".blue(), device.bold(), array);

    if run_command("mdadm", &["--manage", &array, "--add", &device])? {
        println!("{} Device added successfully", "✓".green());
        println!(
            "{} Monitor rebuild progress with: raid-manage progress",
            "→".blue()
        );
    } else {
        anyhow::bail!("Failed to add device");
    }

    Ok(())
}

fn fail(array: String, device: String) -> Result<()> {
    println!(
        "{} Marking {} as failed in {}",
        "→".blue(),
        device.bold(),
        array
    );

    if run_command("mdadm", &["--manage", &array, "--fail", &device])? {
        println!("{} Device marked as failed", "✓".green());
    } else {
        anyhow::bail!("Failed to mark device as failed");
    }

    Ok(())
}

fn remove(array: String, device: String) -> Result<()> {
    println!("{} Removing {} from {}", "→".blue(), device.bold(), array);

    if run_command("mdadm", &["--manage", &array, "--remove", &device])? {
        println!("{} Device removed successfully", "✓".green());
    } else {
        anyhow::bail!("Failed to remove device");
    }

    Ok(())
}

fn progress() -> Result<()> {
    println!("{}", "RAID Rebuild/Resync Progress:".bold());
    println!();

    // Use watch-like behavior
    println!("Press Ctrl+C to exit");
    println!();

    loop {
        // Clear screen
        print!("\x1B[2J\x1B[1;1H");

        let content = fs::read_to_string("/proc/mdstat").context("Failed to read /proc/mdstat")?;

        println!("{}", content);

        // Sleep for 1 second
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}

fn health() -> Result<()> {
    println!("{}", "RAID Array Health:".bold());
    println!();

    let mdstat = fs::read_to_string("/proc/mdstat").context("Failed to read /proc/mdstat")?;

    let arrays: Vec<_> = mdstat
        .lines()
        .filter(|line| line.starts_with("md"))
        .map(|line| {
            let parts: Vec<_> = line.split_whitespace().collect();
            parts[0].to_string()
        })
        .collect();

    if arrays.is_empty() {
        println!("{}", "No RAID arrays found".yellow());
        return Ok(());
    }

    for array in arrays {
        let device = format!("/dev/{}", array);
        let output = run_command_output("mdadm", &["--detail", &device])?;

        // Parse state
        let state = output
            .lines()
            .find(|line| line.contains("State :"))
            .and_then(|line| line.split(':').nth(1))
            .map(|s| s.trim())
            .unwrap_or("UNKNOWN");

        let symbol = match state {
            s if s.contains("active") && s.contains("clean") => "✓".green(),
            s if s.contains("degraded") => "⚠".yellow(),
            _ => "✗".red(),
        };

        println!("  {} {} - {}", symbol, device.bold(), state);
    }

    Ok(())
}

fn update_config() -> Result<()> {
    println!("{} Updating mdadm.conf...", "→".blue());

    let output = run_command_output("mdadm", &["--detail", "--scan"])?;

    // Read current config
    let current = if std::path::Path::new(MDADM_CONF).exists() {
        fs::read_to_string(MDADM_CONF)?
    } else {
        String::new()
    };

    // Remove old ARRAY lines
    let non_array_lines: Vec<_> = current
        .lines()
        .filter(|line| !line.trim().starts_with("ARRAY"))
        .collect();

    // Combine with new ARRAY lines
    let mut new_content = non_array_lines.join("\n");
    if !new_content.is_empty() {
        new_content.push('\n');
    }
    new_content.push_str(&output);

    fs::write(MDADM_CONF, new_content).context("Failed to write mdadm.conf")?;

    println!("{} Updated {}", "✓".green(), MDADM_CONF);

    Ok(())
}

fn monitor(enable: bool, disable: bool) -> Result<()> {
    if enable {
        println!("{} Enabling RAID monitoring...", "→".blue());
        run_command("systemctl", &["enable", "--now", "mdmonitor.service"])?;
        println!("{} Monitoring enabled", "✓".green());
    } else if disable {
        println!("{} Disabling RAID monitoring...", "→".blue());
        run_command("systemctl", &["disable", "--now", "mdmonitor.service"])?;
        println!("{} Monitoring disabled", "✓".green());
    } else {
        // Show status
        run_command("systemctl", &["status", "mdmonitor.service"])?;
    }

    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Create {
            level,
            device,
            devices,
        } => create(level, device, devices),
        Commands::Stop { device } => stop(device),
        Commands::Assemble { device } => assemble(device),
        Commands::Status { device } => status(device),
        Commands::Mdstat => mdstat(),
        Commands::Add { array, device } => add(array, device),
        Commands::Fail { array, device } => fail(array, device),
        Commands::Remove { array, device } => remove(array, device),
        Commands::Progress => progress(),
        Commands::Health => health(),
        Commands::UpdateConfig => update_config(),
        Commands::Monitor { enable, disable } => monitor(enable, disable),
    }
}
