use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::fs;
use std::path::Path;
use std::process::Command;

const SCHEDULE_FILE: &str = "/etc/zfs/snapshot-schedule.conf";

#[derive(Parser)]
#[command(name = "zfs-manage")]
#[command(about = "ZFS storage management helper", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new ZFS pool (wrapper for zpool create)
    CreatePool {
        /// Pool name
        name: String,

        /// VDEV type (single, mirror, raidz, raidz2, raidz3)
        #[arg(short, long, default_value = "single")]
        vdev_type: String,

        /// Devices (space-separated)
        devices: Vec<String>,
    },

    /// Create a new dataset
    CreateDataset {
        /// Dataset path (pool/dataset)
        path: String,

        /// Mount point
        #[arg(short, long)]
        mountpoint: Option<String>,

        /// Compression (on, off, lz4, zstd)
        #[arg(short, long)]
        compression: Option<String>,
    },

    /// Setup automatic snapshots for a dataset
    SetupSnapshots {
        /// Dataset path
        dataset: String,

        /// Snapshot frequency (hourly, daily, weekly, monthly)
        #[arg(short, long, default_value = "daily")]
        frequency: String,

        /// Number of snapshots to retain
        #[arg(short, long, default_value = "7")]
        retention: u32,
    },

    /// Remove automatic snapshots for a dataset
    RemoveSnapshots {
        /// Dataset path
        dataset: String,

        /// Snapshot frequency
        #[arg(short, long)]
        frequency: Option<String>,
    },

    /// List all snapshot schedules
    ListSchedules,

    /// Show pool status (wrapper for zpool status)
    Status {
        /// Pool name (optional, shows all if not specified)
        pool: Option<String>,
    },

    /// Show all datasets (wrapper for zfs list)
    List {
        /// Show snapshots
        #[arg(short, long)]
        snapshots: bool,
    },

    /// Take manual snapshot
    Snapshot {
        /// Dataset path
        dataset: String,

        /// Snapshot name (auto-generated if not provided)
        #[arg(short, long)]
        name: Option<String>,
    },

    /// Check pool health
    Health,

    /// Show ARC statistics
    ArcStats,
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
        anyhow::bail!("Command failed: {} {}", program, args.join(" "));
    }

    Ok(String::from_utf8(output.stdout)?)
}

fn create_pool(name: String, vdev_type: String, devices: Vec<String>) -> Result<()> {
    if devices.is_empty() {
        anyhow::bail!("No devices specified");
    }

    println!("{} Creating ZFS pool:", "→".blue());
    println!("  Pool: {}", name.bold());
    println!("  Type: {}", vdev_type);
    println!("  Devices: {}", devices.join(" "));
    println!();

    // Confirm
    print!(
        "{}  This will destroy all data on these devices. Continue? (yes/no): ",
        "⚠️".yellow()
    );
    std::io::Write::flush(&mut std::io::stdout())?;

    let mut input = String::new();
    std::io::stdin().read_line(&mut input)?;

    if input.trim() != "yes" {
        println!("Aborted");
        return Ok(());
    }

    // Build zpool create command
    let mut args = vec!["create", &name];

    if vdev_type != "single" {
        args.push(&vdev_type);
    }

    for device in &devices {
        args.push(device);
    }

    if run_command("zpool", &args)? {
        println!("{} Pool created successfully", "✓".green());
        run_command("zpool", &["status", &name])?;
    } else {
        anyhow::bail!("Failed to create pool");
    }

    Ok(())
}

fn create_dataset(
    path: String,
    mountpoint: Option<String>,
    compression: Option<String>,
) -> Result<()> {
    println!("{} Creating dataset: {}", "→".blue(), path.bold());

    // Pre-allocate strings to ensure they live long enough
    let mount_opt = mountpoint.as_ref().map(|mp| format!("mountpoint={}", mp));
    let comp_opt = compression
        .as_ref()
        .map(|comp| format!("compression={}", comp));

    let mut args = vec!["create"];

    if let Some(opt) = &mount_opt {
        args.push("-o");
        args.push(opt.as_str());
    }

    if let Some(opt) = &comp_opt {
        args.push("-o");
        args.push(opt.as_str());
    }

    args.push(&path);

    if run_command("zfs", &args)? {
        println!("{} Dataset created successfully", "✓".green());

        // Show details
        run_command("zfs", &["list", &path])?;
    } else {
        anyhow::bail!("Failed to create dataset");
    }

    Ok(())
}

fn setup_snapshots(dataset: String, frequency: String, retention: u32) -> Result<()> {
    // Validate frequency
    if !["hourly", "daily", "weekly", "monthly"].contains(&frequency.as_str()) {
        anyhow::bail!("Invalid frequency. Must be: hourly, daily, weekly, or monthly");
    }

    // Verify dataset exists
    let output = run_command_output("zfs", &["list", "-H", "-o", "name", &dataset]);
    if output.is_err() {
        anyhow::bail!("Dataset '{}' not found", dataset);
    }

    // Read current schedules
    let schedules = if Path::new(SCHEDULE_FILE).exists() {
        fs::read_to_string(SCHEDULE_FILE)?
    } else {
        String::new()
    };

    // Check if schedule already exists
    let schedule_line = format!("{}:{}:{}", dataset, frequency, retention);
    if schedules
        .lines()
        .any(|line| line.starts_with(&format!("{}:", dataset)))
    {
        println!("{} Updating existing snapshot schedule", "→".yellow());

        // Remove old schedule for this dataset
        let new_schedules: Vec<_> = schedules
            .lines()
            .filter(|line| !line.starts_with(&format!("{}:", dataset)))
            .collect();

        let mut new_content = new_schedules.join("\n");
        if !new_content.is_empty() {
            new_content.push('\n');
        }
        new_content.push_str(&schedule_line);
        new_content.push('\n');

        fs::write(SCHEDULE_FILE, new_content)?;
    } else {
        // Append new schedule
        let mut content = schedules;
        if !content.is_empty() && !content.ends_with('\n') {
            content.push('\n');
        }
        content.push_str(&schedule_line);
        content.push('\n');

        fs::write(SCHEDULE_FILE, content)?;
    }

    println!("{} Snapshot schedule configured:", "✓".green());
    println!("  Dataset: {}", dataset.bold());
    println!("  Frequency: {}", frequency.yellow());
    println!("  Retention: {} snapshots", retention);
    println!();
    println!(
        "{} Snapshots will be created automatically based on the schedule",
        "→".blue()
    );

    Ok(())
}

fn remove_snapshots(dataset: String, frequency: Option<String>) -> Result<()> {
    if !Path::new(SCHEDULE_FILE).exists() {
        println!("{}", "No snapshot schedules configured".yellow());
        return Ok(());
    }

    let schedules = fs::read_to_string(SCHEDULE_FILE)?;

    let new_schedules: Vec<_> = schedules
        .lines()
        .filter(|line| {
            if let Some(freq) = &frequency {
                // Remove specific frequency
                !line.starts_with(&format!("{}:{}:", dataset, freq))
            } else {
                // Remove all frequencies for this dataset
                !line.starts_with(&format!("{}:", dataset))
            }
        })
        .collect();

    fs::write(SCHEDULE_FILE, new_schedules.join("\n") + "\n")?;

    if let Some(freq) = frequency {
        println!(
            "{} Removed {} snapshots for {}",
            "✓".green(),
            freq,
            dataset.bold()
        );
    } else {
        println!(
            "{} Removed all snapshot schedules for {}",
            "✓".green(),
            dataset.bold()
        );
    }

    Ok(())
}

fn list_schedules() -> Result<()> {
    if !Path::new(SCHEDULE_FILE).exists() {
        println!("{}", "No snapshot schedules configured".yellow());
        println!("\nAdd one with: zfs-manage setup-snapshots <dataset> --frequency <freq>");
        return Ok(());
    }

    let schedules = fs::read_to_string(SCHEDULE_FILE)?;

    if schedules.trim().is_empty() {
        println!("{}", "No snapshot schedules configured".yellow());
        return Ok(());
    }

    println!("{}", "Configured Snapshot Schedules:".bold());
    println!();

    for line in schedules.lines() {
        if line.trim().is_empty() || line.starts_with('#') {
            continue;
        }

        let parts: Vec<_> = line.split(':').collect();
        if parts.len() == 3 {
            println!(
                "  {} {} ({}, keep {})",
                "•".blue(),
                parts[0].bold(),
                parts[1].yellow(),
                parts[2].cyan()
            );
        }
    }

    Ok(())
}

fn status(pool: Option<String>) -> Result<()> {
    if let Some(p) = pool {
        run_command("zpool", &["status", &p])?;
    } else {
        run_command("zpool", &["status"])?;
    }
    Ok(())
}

fn list(snapshots: bool) -> Result<()> {
    let args = if snapshots {
        vec!["list", "-t", "all"]
    } else {
        vec!["list"]
    };

    run_command("zfs", &args)?;
    Ok(())
}

fn snapshot(dataset: String, name: Option<String>) -> Result<()> {
    let snapshot_name = if let Some(n) = name {
        n
    } else {
        // Auto-generate name with timestamp
        let now = chrono::Local::now();
        format!("manual-{}", now.format("%Y%m%d-%H%M%S"))
    };

    let full_name = format!("{}@{}", dataset, snapshot_name);

    println!("{} Creating snapshot: {}", "→".blue(), full_name.bold());

    if run_command("zfs", &["snapshot", &full_name])? {
        println!("{} Snapshot created successfully", "✓".green());
    } else {
        anyhow::bail!("Failed to create snapshot");
    }

    Ok(())
}

fn health() -> Result<()> {
    println!("{}", "ZFS Pool Health:".bold());
    println!();

    let output = run_command_output("zpool", &["list", "-H", "-o", "name"])?;

    for pool in output.lines() {
        let pool = pool.trim();
        if pool.is_empty() {
            continue;
        }

        let status_output = run_command_output("zpool", &["status", pool])?;

        // Parse state
        let state = status_output
            .lines()
            .find(|line| line.contains("state:"))
            .and_then(|line| line.split_whitespace().nth(1))
            .unwrap_or("UNKNOWN");

        let symbol = match state {
            "ONLINE" => "✓".green(),
            "DEGRADED" => "⚠".yellow(),
            _ => "✗".red(),
        };

        println!("  {} {} - {}", symbol, pool.bold(), state);
    }

    Ok(())
}

fn arc_stats() -> Result<()> {
    run_command("arc_summary", &[])?;
    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::CreatePool {
            name,
            vdev_type,
            devices,
        } => create_pool(name, vdev_type, devices),
        Commands::CreateDataset {
            path,
            mountpoint,
            compression,
        } => create_dataset(path, mountpoint, compression),
        Commands::SetupSnapshots {
            dataset,
            frequency,
            retention,
        } => setup_snapshots(dataset, frequency, retention),
        Commands::RemoveSnapshots { dataset, frequency } => remove_snapshots(dataset, frequency),
        Commands::ListSchedules => list_schedules(),
        Commands::Status { pool } => status(pool),
        Commands::List { snapshots } => list(snapshots),
        Commands::Snapshot { dataset, name } => snapshot(dataset, name),
        Commands::Health => health(),
        Commands::ArcStats => arc_stats(),
    }
}
