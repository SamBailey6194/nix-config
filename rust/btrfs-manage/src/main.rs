use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

/// BTRFS filesystem management CLI
#[derive(Parser)]
#[command(name = "btrfs-manage")]
#[command(about = "Manage BTRFS filesystems and snapshots", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a snapshot of a subvolume
    Snapshot {
        /// Subvolume to snapshot (e.g., / or /home)
        subvolume: PathBuf,

        /// Snapshot name (default: auto-generated with timestamp)
        #[arg(long)]
        name: Option<String>,

        /// Make snapshot read-only
        #[arg(long, short = 'r')]
        readonly: bool,
    },

    /// List all snapshots
    ListSnapshots {
        /// Snapshot directory (default: /.snapshots)
        #[arg(long, default_value = "/.snapshots")]
        dir: PathBuf,
    },

    /// Rollback to a snapshot
    Rollback {
        /// Snapshot to rollback to
        snapshot: PathBuf,

        /// Target mount point (default: /)
        #[arg(long, default_value = "/")]
        target: PathBuf,
    },

    /// Delete old snapshots based on retention policy
    Cleanup {
        /// Snapshot directory (default: /.snapshots)
        #[arg(long, default_value = "/.snapshots")]
        dir: PathBuf,

        /// Keep last N snapshots
        #[arg(long, default_value = "7")]
        keep: usize,

        /// Dry run (don't actually delete)
        #[arg(long)]
        dry_run: bool,
    },

    /// Balance filesystem (redistribute data across devices)
    Balance {
        /// Path to BTRFS filesystem
        #[arg(default_value = "/")]
        path: PathBuf,

        /// Balance data only
        #[arg(long)]
        data: bool,

        /// Balance metadata only
        #[arg(long)]
        metadata: bool,

        /// Balance usage threshold (0-100)
        #[arg(long)]
        usage: Option<u8>,
    },

    /// Run filesystem scrub (data integrity check)
    Scrub {
        /// Path to BTRFS filesystem
        #[arg(default_value = "/")]
        path: PathBuf,

        /// Show scrub status instead of starting
        #[arg(long)]
        status: bool,
    },

    /// Defragment files
    Defrag {
        /// Path to defragment
        path: PathBuf,

        /// Recursive defragmentation
        #[arg(long, short = 'r')]
        recursive: bool,

        /// Compress after defrag (zstd, lzo, zlib)
        #[arg(long, short = 'c')]
        compress: Option<String>,
    },

    /// Show filesystem usage statistics
    Usage {
        /// Path to BTRFS filesystem
        #[arg(default_value = "/")]
        path: PathBuf,
    },

    /// Show subvolume list
    Subvolumes {
        /// Path to BTRFS filesystem
        #[arg(default_value = "/")]
        path: PathBuf,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Snapshot {
            subvolume,
            name,
            readonly,
        } => create_snapshot(&subvolume, name.as_deref(), readonly),
        Commands::ListSnapshots { dir } => list_snapshots(&dir),
        Commands::Rollback { snapshot, target } => rollback(&snapshot, &target),
        Commands::Cleanup { dir, keep, dry_run } => cleanup_snapshots(&dir, keep, dry_run),
        Commands::Balance {
            path,
            data,
            metadata,
            usage,
        } => balance(&path, data, metadata, usage),
        Commands::Scrub { path, status } => scrub(&path, status),
        Commands::Defrag {
            path,
            recursive,
            compress,
        } => defrag(&path, recursive, compress),
        Commands::Usage { path } => show_usage(&path),
        Commands::Subvolumes { path } => list_subvolumes(&path),
    };

    if let Err(e) = result {
        eprintln!("{} {}", "Error:".red().bold(), e);
        std::process::exit(1);
    }
}

fn create_snapshot(subvolume: &Path, name: Option<&str>, readonly: bool) -> Result<()> {
    check_root()?;
    check_btrfs_filesystem(subvolume)?;

    let snapshot_dir = Path::new("/.snapshots");
    std::fs::create_dir_all(snapshot_dir)?;

    let snapshot_name = match name {
        Some(n) => n.to_string(),
        None => {
            let timestamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
            let subvol_name = subvolume
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("root");
            format!("{}-{}", subvol_name, timestamp)
        }
    };

    let snapshot_path = snapshot_dir.join(&snapshot_name);

    println!(
        "{}",
        format!("Creating snapshot of: {}", subvolume.display())
            .cyan()
            .bold()
    );
    println!("Snapshot: {}", snapshot_path.display().to_string().green());
    if readonly {
        println!("{}", "Mode: read-only".yellow());
    }

    let mut cmd = Command::new("btrfs");
    cmd.args(&["subvolume", "snapshot"]);

    if readonly {
        cmd.arg("-r");
    }

    cmd.arg(subvolume).arg(&snapshot_path);

    let status = cmd
        .status()
        .context("Failed to create snapshot")?;

    if !status.success() {
        return Err(anyhow!("Snapshot creation failed"));
    }

    println!();
    println!("{}", "✓ Snapshot created successfully".green().bold());

    Ok(())
}

fn list_snapshots(dir: &Path) -> Result<()> {
    if !dir.exists() {
        println!("{}", "No snapshots directory found".yellow());
        return Ok(());
    }

    println!("{}", "=== BTRFS Snapshots ===".cyan().bold());
    println!();

    let mut snapshots: Vec<_> = std::fs::read_dir(dir)?
        .filter_map(|e| e.ok())
        .collect();

    if snapshots.is_empty() {
        println!("{}", "No snapshots found".yellow());
        return Ok(());
    }

    snapshots.sort_by_key(|e| e.file_name());

    for entry in snapshots {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();

        // Get creation time
        let metadata = entry.metadata()?;
        let created = metadata.created().or_else(|_| metadata.modified())?;
        let datetime: chrono::DateTime<chrono::Local> = created.into();

        println!(
            "{} ({})",
            name_str.green(),
            datetime.format("%Y-%m-%d %H:%M:%S").to_string().dimmed()
        );
    }

    Ok(())
}

fn rollback(snapshot: &Path, target: &Path) -> Result<()> {
    check_root()?;

    if !snapshot.exists() {
        return Err(anyhow!("Snapshot not found: {}", snapshot.display()));
    }

    println!(
        "{}",
        format!("Rolling back to snapshot: {}", snapshot.display())
            .yellow()
            .bold()
    );
    println!("Target: {}", target.display().to_string().green());
    println!();
    println!("{}", "WARNING: This will replace the current subvolume!".red().bold());
    println!("{}", "Make sure you have a backup if needed.".red());
    println!();

    print!("Continue with rollback? [y/N]: ");
    io::stdout().flush()?;
    let mut response = String::new();
    io::stdin().read_line(&mut response)?;

    if !response.trim().eq_ignore_ascii_case("y") {
        println!("{}", "Rollback cancelled".yellow());
        return Ok(());
    }

    println!();
    println!("{}", "Instructions for manual rollback:".cyan().bold());
    println!("1. Boot into a live system or single-user mode");
    println!("2. Mount the BTRFS filesystem");
    println!(
        "3. Delete or rename the current @root subvolume: btrfs subvolume delete /mnt/@root"
    );
    println!(
        "4. Create a new writable snapshot: btrfs subvolume snapshot {} /mnt/@root",
        snapshot.display()
    );
    println!("5. Reboot");

    Ok(())
}

fn cleanup_snapshots(dir: &Path, keep: usize, dry_run: bool) -> Result<()> {
    check_root()?;

    if !dir.exists() {
        println!("{}", "No snapshots directory found".yellow());
        return Ok(());
    }

    let mut snapshots: Vec<_> = std::fs::read_dir(dir)?
        .filter_map(|e| e.ok())
        .collect();

    if snapshots.is_empty() {
        println!("{}", "No snapshots found".yellow());
        return Ok(());
    }

    // Sort by creation time (newest first)
    snapshots.sort_by_key(|e| {
        e.metadata()
            .ok()
            .and_then(|m| m.created().or_else(|_| m.modified()).ok())
    });
    snapshots.reverse();

    if snapshots.len() <= keep {
        println!(
            "{}",
            format!(
                "Only {} snapshots found, keeping all (retention: {})",
                snapshots.len(),
                keep
            )
            .green()
        );
        return Ok(());
    }

    let to_delete = &snapshots[keep..];

    println!(
        "{}",
        format!(
            "Will delete {} old snapshots (keeping {} newest)",
            to_delete.len(),
            keep
        )
        .yellow()
        .bold()
    );
    println!();

    for entry in to_delete {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        let path = entry.path();

        if dry_run {
            println!("{} {}", "[DRY RUN]".cyan(), name_str.dimmed());
        } else {
            println!("Deleting: {}", name_str.dimmed());

            let status = Command::new("btrfs")
                .args(&["subvolume", "delete", path.to_str().unwrap()])
                .status()
                .context(format!("Failed to delete snapshot: {}", name_str))?;

            if !status.success() {
                eprintln!("{} Failed to delete: {}", "Warning:".yellow(), name_str);
            }
        }
    }

    if dry_run {
        println!();
        println!("{}", "Dry run completed. No snapshots deleted.".cyan());
    } else {
        println!();
        println!("{}", "✓ Cleanup completed".green().bold());
    }

    Ok(())
}

fn balance(path: &Path, data_only: bool, metadata_only: bool, usage: Option<u8>) -> Result<()> {
    check_root()?;
    check_btrfs_filesystem(path)?;

    println!(
        "{}",
        format!("Starting balance on: {}", path.display())
            .yellow()
            .bold()
    );

    if let Some(u) = usage {
        println!("Usage threshold: {}%", u.to_string().cyan());
    }

    println!();
    println!(
        "{}",
        "Note: Balance can take a long time and is I/O intensive.".yellow()
    );

    let mut cmd = Command::new("btrfs");
    cmd.args(&["balance", "start"]);

    if let Some(u) = usage {
        if data_only {
            cmd.arg(format!("-dusage={}", u));
        } else if metadata_only {
            cmd.arg(format!("-musage={}", u));
        } else {
            cmd.arg(format!("-dusage={}", u));
            cmd.arg(format!("-musage={}", u));
        }
    } else {
        if data_only {
            cmd.arg("-d");
        } else if metadata_only {
            cmd.arg("-m");
        }
    }

    cmd.arg(path);

    let status = cmd.status().context("Failed to start balance")?;

    if !status.success() {
        return Err(anyhow!("Balance failed"));
    }

    Ok(())
}

fn scrub(path: &Path, status_only: bool) -> Result<()> {
    check_root()?;
    check_btrfs_filesystem(path)?;

    if status_only {
        println!(
            "{}",
            format!("Scrub status for: {}", path.display())
                .cyan()
                .bold()
        );

        let status = Command::new("btrfs")
            .args(&["scrub", "status", path.to_str().unwrap()])
            .status()
            .context("Failed to get scrub status")?;

        if !status.success() {
            return Err(anyhow!("Failed to get scrub status"));
        }
    } else {
        println!(
            "{}",
            format!("Starting scrub on: {}", path.display())
                .cyan()
                .bold()
        );
        println!();

        let status = Command::new("btrfs")
            .args(&["scrub", "start", "-B", path.to_str().unwrap()])
            .status()
            .context("Failed to start scrub")?;

        if !status.success() {
            return Err(anyhow!("Scrub failed"));
        }

        println!();
        println!("{}", "✓ Scrub completed successfully".green().bold());
    }

    Ok(())
}

fn defrag(path: &Path, recursive: bool, compress: Option<String>) -> Result<()> {
    check_root()?;

    println!(
        "{}",
        format!("Defragmenting: {}", path.display())
            .cyan()
            .bold()
    );

    let mut cmd = Command::new("btrfs");
    cmd.args(&["filesystem", "defragment"]);

    if recursive {
        cmd.arg("-r");
    }

    if let Some(algo) = compress {
        cmd.arg(format!("-c{}", algo));
    }

    cmd.arg(path);

    let status = cmd.status().context("Failed to defragment")?;

    if !status.success() {
        return Err(anyhow!("Defragmentation failed"));
    }

    println!();
    println!("{}", "✓ Defragmentation completed".green().bold());

    Ok(())
}

fn show_usage(path: &Path) -> Result<()> {
    check_btrfs_filesystem(path)?;

    println!(
        "{}",
        format!("=== BTRFS Usage for: {} ===", path.display())
            .cyan()
            .bold()
    );
    println!();

    let status = Command::new("btrfs")
        .args(&["filesystem", "usage", path.to_str().unwrap()])
        .status()
        .context("Failed to get filesystem usage")?;

    if !status.success() {
        return Err(anyhow!("Failed to get usage statistics"));
    }

    Ok(())
}

fn list_subvolumes(path: &Path) -> Result<()> {
    check_btrfs_filesystem(path)?;

    println!(
        "{}",
        format!("=== BTRFS Subvolumes on: {} ===", path.display())
            .cyan()
            .bold()
    );
    println!();

    let status = Command::new("btrfs")
        .args(&["subvolume", "list", path.to_str().unwrap()])
        .status()
        .context("Failed to list subvolumes")?;

    if !status.success() {
        return Err(anyhow!("Failed to list subvolumes"));
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

fn check_btrfs_filesystem(path: &Path) -> Result<()> {
    let output = Command::new("stat")
        .args(&["-f", "-c", "%T", path.to_str().unwrap()])
        .output()
        .context("Failed to check filesystem type")?;

    if !output.status.success() {
        return Err(anyhow!("Failed to check filesystem type"));
    }

    let fstype = String::from_utf8_lossy(&output.stdout);
    if !fstype.contains("btrfs") {
        return Err(anyhow!("Path is not on a BTRFS filesystem: {}", path.display()));
    }

    Ok(())
}
