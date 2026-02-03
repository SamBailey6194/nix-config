use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// Per-folder encryption management with gocryptfs
#[derive(Parser)]
#[command(name = "vault-manage")]
#[command(about = "Manage encrypted vaults with gocryptfs", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new encrypted vault
    Create {
        /// Vault name
        name: String,

        /// Vaults storage directory (default: ~/vaults)
        #[arg(long)]
        vaults_dir: Option<PathBuf>,

        /// Mount points directory (default: ~/mnt)
        #[arg(long)]
        mount_dir: Option<PathBuf>,
    },

    /// Mount an encrypted vault
    Mount {
        /// Vault name
        name: String,

        /// Vaults storage directory (default: ~/vaults)
        #[arg(long)]
        vaults_dir: Option<PathBuf>,

        /// Mount points directory (default: ~/mnt)
        #[arg(long)]
        mount_dir: Option<PathBuf>,
    },

    /// Unmount a vault
    Unmount {
        /// Vault name
        name: String,

        /// Mount points directory (default: ~/mnt)
        #[arg(long)]
        mount_dir: Option<PathBuf>,
    },

    /// Unmount all vaults
    UnmountAll {
        /// Mount points directory (default: ~/mnt)
        #[arg(long)]
        mount_dir: Option<PathBuf>,
    },

    /// List all vaults
    List {
        /// Vaults storage directory (default: ~/vaults)
        #[arg(long)]
        vaults_dir: Option<PathBuf>,
    },

    /// Show mounted vaults
    Status {
        /// Mount points directory (default: ~/mnt)
        #[arg(long)]
        mount_dir: Option<PathBuf>,
    },

    /// Change vault password
    ChangePassword {
        /// Vault name
        name: String,

        /// Vaults storage directory (default: ~/vaults)
        #[arg(long)]
        vaults_dir: Option<PathBuf>,
    },

    /// Remove vault (with confirmation)
    Remove {
        /// Vault name
        name: String,

        /// Vaults storage directory (default: ~/vaults)
        #[arg(long)]
        vaults_dir: Option<PathBuf>,

        /// Mount points directory (default: ~/mnt)
        #[arg(long)]
        mount_dir: Option<PathBuf>,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Create {
            name,
            vaults_dir,
            mount_dir,
        } => create_vault(&name, vaults_dir, mount_dir),
        Commands::Mount {
            name,
            vaults_dir,
            mount_dir,
        } => mount_vault(&name, vaults_dir, mount_dir),
        Commands::Unmount { name, mount_dir } => unmount_vault(&name, mount_dir),
        Commands::UnmountAll { mount_dir } => unmount_all(mount_dir),
        Commands::List { vaults_dir } => list_vaults(vaults_dir),
        Commands::Status { mount_dir } => show_status(mount_dir),
        Commands::ChangePassword { name, vaults_dir } => change_password(&name, vaults_dir),
        Commands::Remove {
            name,
            vaults_dir,
            mount_dir,
        } => remove_vault(&name, vaults_dir, mount_dir),
    };

    if let Err(e) = result {
        eprintln!("{} {}", "Error:".red().bold(), e);
        std::process::exit(1);
    }
}

fn get_vaults_dir(custom: Option<PathBuf>) -> Result<PathBuf> {
    match custom {
        Some(dir) => Ok(dir),
        None => {
            let home = dirs::home_dir().ok_or_else(|| anyhow!("Could not determine home directory"))?;
            Ok(home.join("vaults"))
        }
    }
}

fn get_mount_dir(custom: Option<PathBuf>) -> Result<PathBuf> {
    match custom {
        Some(dir) => Ok(dir),
        None => {
            let home = dirs::home_dir().ok_or_else(|| anyhow!("Could not determine home directory"))?;
            Ok(home.join("mnt"))
        }
    }
}

fn create_vault(name: &str, vaults_dir: Option<PathBuf>, mount_dir: Option<PathBuf>) -> Result<()> {
    let vaults_dir = get_vaults_dir(vaults_dir)?;
    let mount_dir = get_mount_dir(mount_dir)?;

    let vault_path = vaults_dir.join(name);
    let mount_path = mount_dir.join(name);

    if vault_path.exists() {
        return Err(anyhow!("Vault '{}' already exists", name));
    }

    println!("{}", format!("Creating encrypted vault: {}", name).cyan().bold());
    println!("Vault storage: {}", vault_path.display().to_string().green());
    println!("Mount point: {}", mount_path.display().to_string().green());
    println!();

    std::fs::create_dir_all(&vault_path)?;
    std::fs::create_dir_all(&mount_path)?;

    println!("{}", "Enter password for new vault:".yellow());
    let status = Command::new("gocryptfs")
        .args(&["-init", vault_path.to_str().unwrap()])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("Failed to initialize vault")?;

    if !status.success() {
        std::fs::remove_dir(&vault_path)?;
        return Err(anyhow!("Vault creation failed"));
    }

    println!();
    println!("{}", "✓ Vault created successfully".green().bold());
    println!("Mount with: vault-manage mount {}", name);

    Ok(())
}

fn mount_vault(name: &str, vaults_dir: Option<PathBuf>, mount_dir: Option<PathBuf>) -> Result<()> {
    let vaults_dir = get_vaults_dir(vaults_dir)?;
    let mount_dir = get_mount_dir(mount_dir)?;

    let vault_path = vaults_dir.join(name);
    let mount_path = mount_dir.join(name);

    if !vault_path.exists() {
        return Err(anyhow!("Vault '{}' not found", name));
    }

    // Check if already mounted
    if is_mounted(&mount_path)? {
        println!("{}", format!("Vault '{}' is already mounted", name).yellow());
        return Ok(());
    }

    std::fs::create_dir_all(&mount_path)?;

    println!("{}", format!("Mounting vault: {}", name).cyan().bold());
    println!("Enter password:");

    let status = Command::new("gocryptfs")
        .args(&[vault_path.to_str().unwrap(), mount_path.to_str().unwrap()])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("Failed to mount vault")?;

    if !status.success() {
        return Err(anyhow!("Vault mount failed"));
    }

    println!();
    println!("{}", "✓ Vault mounted successfully".green().bold());
    println!("Access at: {}", mount_path.display().to_string().green());

    Ok(())
}

fn unmount_vault(name: &str, mount_dir: Option<PathBuf>) -> Result<()> {
    let mount_dir = get_mount_dir(mount_dir)?;
    let mount_path = mount_dir.join(name);

    if !is_mounted(&mount_path)? {
        println!("{}", format!("Vault '{}' is not mounted", name).yellow());
        return Ok(());
    }

    println!("{}", format!("Unmounting vault: {}", name).cyan().bold());

    let status = Command::new("fusermount")
        .args(&["-u", mount_path.to_str().unwrap()])
        .status()
        .context("Failed to unmount vault")?;

    if !status.success() {
        return Err(anyhow!("Vault unmount failed"));
    }

    println!("{}", "✓ Vault unmounted successfully".green().bold());

    Ok(())
}

fn unmount_all(mount_dir: Option<PathBuf>) -> Result<()> {
    let _mount_dir = get_mount_dir(mount_dir)?;

    println!("{}", "Unmounting all vaults...".cyan().bold());

    // Kill all gocryptfs processes for current user
    let _ = Command::new("pkill")
        .args(&["-u", &whoami::username(), "gocryptfs"])
        .status();

    println!("{}", "✓ All vaults unmounted".green().bold());

    Ok(())
}

fn list_vaults(vaults_dir: Option<PathBuf>) -> Result<()> {
    let vaults_dir = get_vaults_dir(vaults_dir)?;

    if !vaults_dir.exists() {
        println!("{}", "No vaults directory found".yellow());
        return Ok(());
    }

    println!("{}", "=== Available Vaults ===".cyan().bold());
    println!();

    let entries = std::fs::read_dir(&vaults_dir)?;
    let mut found = false;

    for entry in entries {
        let entry = entry?;
        if entry.path().is_dir() {
            let name = entry.file_name();
            println!("  - {}", name.to_string_lossy().green());
            found = true;
        }
    }

    if !found {
        println!("{}", "No vaults found".yellow());
    }

    Ok(())
}

fn show_status(_mount_dir: Option<PathBuf>) -> Result<()> {
    println!("{}", "=== Mounted Vaults ===".cyan().bold());
    println!();

    let output = Command::new("findmnt")
        .args(&["-t", "fuse.gocryptfs", "-o", "TARGET,SOURCE"])
        .output()
        .context("Failed to check mounted vaults")?;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        if stdout.lines().count() <= 1 {
            println!("{}", "(none)".dimmed());
        } else {
            println!("{}", stdout);
        }
    } else {
        println!("{}", "(none)".dimmed());
    }

    Ok(())
}

fn change_password(name: &str, vaults_dir: Option<PathBuf>) -> Result<()> {
    let vaults_dir = get_vaults_dir(vaults_dir)?;
    let vault_path = vaults_dir.join(name);

    if !vault_path.exists() {
        return Err(anyhow!("Vault '{}' not found", name));
    }

    println!("{}", format!("Changing password for vault: {}", name).yellow().bold());
    println!();

    let status = Command::new("gocryptfs")
        .args(&["-passwd", vault_path.to_str().unwrap()])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("Failed to change password")?;

    if !status.success() {
        return Err(anyhow!("Password change failed"));
    }

    println!();
    println!("{}", "✓ Password changed successfully".green().bold());

    Ok(())
}

fn remove_vault(name: &str, vaults_dir: Option<PathBuf>, mount_dir: Option<PathBuf>) -> Result<()> {
    let vaults_dir = get_vaults_dir(vaults_dir)?;
    let mount_dir = get_mount_dir(mount_dir)?;

    let vault_path = vaults_dir.join(name);
    let mount_path = mount_dir.join(name);

    if !vault_path.exists() {
        return Err(anyhow!("Vault '{}' not found", name));
    }

    println!("{}", format!("Removing vault: {}", name).red().bold());
    println!("{}", "WARNING: This will DELETE all encrypted data!".red().bold());
    println!();

    print!("Type 'DELETE {}' to confirm: ", name);
    io::stdout().flush()?;
    let mut response = String::new();
    io::stdin().read_line(&mut response)?;

    if response.trim() != format!("DELETE {}", name) {
        println!("{}", "Vault removal cancelled".yellow());
        return Ok(());
    }

    // Unmount if mounted
    if is_mounted(&mount_path)? {
        let _ = Command::new("fusermount")
            .args(&["-u", mount_path.to_str().unwrap()])
            .status();
    }

    // Remove vault directory
    std::fs::remove_dir_all(&vault_path)
        .context("Failed to remove vault directory")?;

    println!();
    println!("{}", "✓ Vault removed successfully".green().bold());

    Ok(())
}

fn is_mounted(path: &Path) -> Result<bool> {
    let output = Command::new("mountpoint")
        .args(&["-q", path.to_str().unwrap()])
        .output()
        .context("Failed to check mount status")?;

    Ok(output.status.success())
}
