use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::path::PathBuf;
use std::process::Command;

mod commands;

#[derive(Parser)]
#[command(author, version, about = "Helper CLI for managing agenix secrets", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Edit an encrypted secret
    Edit {
        /// Secret name (e.g., github-ssh-personal.age)
        secret: String,
    },

    /// Rekey all secrets (after adding new host keys)
    Rekey,

    /// List all secrets and which devices can decrypt them
    List {
        /// Show full public keys
        #[arg(long)]
        verbose: bool,
    },

    /// Add a new server with per-device SSH keys (WITH passphrases)
    AddServer {
        /// Server name (e.g., client-acme)
        name: String,

        /// Devices to generate keys for (defaults to all: laptop-intel, framework, devtower)
        #[arg(long, value_delimiter = ',')]
        devices: Option<Vec<String>>,
    },

    /// Initialize secrets for a new device
    Init {
        /// Device name (e.g., laptop-intel)
        device: String,
    },

    /// Check that host keys in secrets.nix match actual system keys
    CheckKeys,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Verify we're in a nix-config directory
    let repo_root = find_repo_root()?;

    match cli.command {
        Commands::Edit { secret } => commands::edit::run(&repo_root, &secret),
        Commands::Rekey => commands::rekey::run(&repo_root),
        Commands::List { verbose } => commands::list::run(&repo_root, verbose),
        Commands::AddServer { name, devices } => {
            commands::add_server::run(&repo_root, &name, devices)
        }
        Commands::Init { device } => commands::init::run(&repo_root, &device),
        Commands::CheckKeys => commands::check_keys::run(&repo_root),
    }
}

fn find_repo_root() -> Result<PathBuf> {
    let current_dir = std::env::current_dir()?;

    // Look for flake.nix to identify repo root
    for ancestor in current_dir.ancestors() {
        if ancestor.join("flake.nix").exists() && ancestor.join("secrets").exists() {
            return Ok(ancestor.to_path_buf());
        }
    }

    anyhow::bail!(
        "Could not find nix-config repository root. \
         Make sure you're inside the nix-config directory."
    );
}

/// Check if agenix CLI is available
pub fn check_agenix_available() -> Result<PathBuf> {
    which::which("agenix").context(
        "agenix CLI not found. Run 'nix develop' first to enter the dev shell with agenix.",
    )
}

/// Run agenix command
pub fn run_agenix(args: &[&str]) -> Result<()> {
    let agenix = check_agenix_available()?;

    let status = Command::new(agenix)
        .args(args)
        .status()
        .context("Failed to execute agenix")?;

    if !status.success() {
        anyhow::bail!("agenix command failed");
    }

    Ok(())
}

/// Print success message
pub fn print_success(msg: &str) {
    println!("{} {}", "✅".green(), msg);
}

/// Print error message
pub fn print_error(msg: &str) {
    eprintln!("{} {}", "❌".red(), msg);
}

/// Print warning message
pub fn print_warning(msg: &str) {
    println!("{} {}", "⚠️".yellow(), msg);
}

/// Print info message
pub fn print_info(msg: &str) {
    println!("{} {}", "ℹ️".blue(), msg);
}
