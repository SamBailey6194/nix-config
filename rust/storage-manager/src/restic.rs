use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const CONFIG_DIR: &str = "/var/lib/restic";
const CONFIG_FILE: &str = "config.json";

#[derive(Parser)]
#[command(name = "restic-manage")]
#[command(about = "Runtime Restic backup configuration manager", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Add a new backup repository
    AddRepo {
        /// Repository name
        name: String,

        /// Repository type (local, b2, s3, sftp, rest)
        #[arg(short, long, default_value = "local")]
        repo_type: String,

        /// Repository path or URL
        path: String,
    },

    /// Remove a backup repository
    RemoveRepo {
        /// Repository name
        name: String,
    },

    /// List all configured repositories
    ListRepos {
        /// Show detailed information
        #[arg(short, long)]
        verbose: bool,
    },

    /// Add a new backup job
    AddBackup {
        /// Backup job name
        name: String,

        /// Paths to backup (comma-separated)
        #[arg(short, long)]
        paths: String,

        /// Repository name to backup to
        #[arg(short, long)]
        repository: String,

        /// Backup schedule (systemd timer format)
        #[arg(short, long, default_value = "daily")]
        schedule: String,

        /// Retention policy (e.g., "7d,4w,6m,2y")
        #[arg(long, default_value = "7d,4w,6m,2y")]
        retention: String,
    },

    /// Remove a backup job
    RemoveBackup {
        /// Backup job name
        name: String,
    },

    /// List all configured backups
    ListBackups {
        /// Show detailed information
        #[arg(short, long)]
        verbose: bool,
    },

    /// Initialize repository (create if doesn't exist)
    InitRepo {
        /// Repository name
        name: String,
    },

    /// Test repository connection
    TestRepo {
        /// Repository name
        name: String,
    },

    /// Generate systemd service files for all backups
    GenerateServices {
        /// Force regeneration even if files exist
        #[arg(short, long)]
        force: bool,
    },

    /// Show configuration file location
    ConfigPath,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct Repository {
    #[serde(rename = "type")]
    repo_type: String,
    path: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct Backup {
    paths: Vec<String>,
    repository: String,
    schedule: String,
    retention: String,
    #[serde(default)]
    exclude: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct Config {
    repositories: HashMap<String, Repository>,
    backups: HashMap<String, Backup>,
}

fn get_hostname() -> Result<String> {
    let output = Command::new("hostname")
        .output()
        .context("Failed to get hostname")?;

    Ok(String::from_utf8(output.stdout)?.trim().to_string())
}

fn get_config_path() -> Result<PathBuf> {
    let hostname = get_hostname()?;
    let config_dir = Path::new(CONFIG_DIR).join(&hostname);

    // Ensure directory exists
    if !config_dir.exists() {
        fs::create_dir_all(&config_dir).context(format!(
            "Failed to create config directory: {:?}",
            config_dir
        ))?;
    }

    Ok(config_dir.join(CONFIG_FILE))
}

fn load_config() -> Result<Config> {
    let config_path = get_config_path()?;

    if !config_path.exists() {
        // Create default config
        let config = Config::default();
        save_config(&config)?;
        return Ok(config);
    }

    let contents = fs::read_to_string(&config_path).context("Failed to read config file")?;

    serde_json::from_str(&contents).context("Failed to parse config file")
}

fn save_config(config: &Config) -> Result<()> {
    let config_path = get_config_path()?;

    let contents = serde_json::to_string_pretty(config).context("Failed to serialize config")?;

    fs::write(&config_path, contents).context("Failed to write config file")?;

    println!(
        "{} Configuration saved to: {}",
        "✓".green(),
        config_path.display()
    );

    Ok(())
}

fn add_repo(name: String, repo_type: String, path: String) -> Result<()> {
    let mut config = load_config()?;

    if config.repositories.contains_key(&name) {
        anyhow::bail!("Repository '{}' already exists", name);
    }

    config.repositories.insert(
        name.clone(),
        Repository {
            repo_type: repo_type.clone(),
            path: path.clone(),
        },
    );

    save_config(&config)?;

    println!(
        "{} Added repository: {} ({} -> {})",
        "✓".green(),
        name.bold(),
        repo_type,
        path
    );

    Ok(())
}

fn remove_repo(name: String) -> Result<()> {
    let mut config = load_config()?;

    if !config.repositories.contains_key(&name) {
        anyhow::bail!("Repository '{}' not found", name);
    }

    // Check if any backups use this repository
    let dependent_backups: Vec<_> = config
        .backups
        .iter()
        .filter(|(_, backup)| backup.repository == name)
        .map(|(name, _)| name.clone())
        .collect();

    if !dependent_backups.is_empty() {
        anyhow::bail!(
            "Cannot remove repository '{}': used by backups: {}",
            name,
            dependent_backups.join(", ")
        );
    }

    config.repositories.remove(&name);
    save_config(&config)?;

    println!("{} Removed repository: {}", "✓".green(), name.bold());

    Ok(())
}

fn list_repos(verbose: bool) -> Result<()> {
    let config = load_config()?;

    if config.repositories.is_empty() {
        println!("{}", "No repositories configured".yellow());
        println!("\nAdd one with: restic-manage add-repo <name> <path>");
        return Ok(());
    }

    println!("{}", "Configured Repositories:".bold());
    println!();

    for (name, repo) in &config.repositories {
        println!(
            "  {} {} ({})",
            "•".blue(),
            name.bold(),
            repo.repo_type.cyan()
        );
        if verbose {
            println!("    Path: {}", repo.path);
        }
    }

    Ok(())
}

fn add_backup(
    name: String,
    paths: String,
    repository: String,
    schedule: String,
    retention: String,
) -> Result<()> {
    let mut config = load_config()?;

    if config.backups.contains_key(&name) {
        anyhow::bail!("Backup '{}' already exists", name);
    }

    if !config.repositories.contains_key(&repository) {
        anyhow::bail!(
            "Repository '{}' not found. Add it first with add-repo",
            repository
        );
    }

    let paths_vec: Vec<String> = paths.split(',').map(|s| s.trim().to_string()).collect();

    config.backups.insert(
        name.clone(),
        Backup {
            paths: paths_vec.clone(),
            repository: repository.clone(),
            schedule: schedule.clone(),
            retention: retention.clone(),
            exclude: Vec::new(),
        },
    );

    save_config(&config)?;

    println!("{} Added backup: {}", "✓".green(), name.bold());
    println!("  Paths: {}", paths_vec.join(", "));
    println!("  Repository: {}", repository);
    println!("  Schedule: {}", schedule);
    println!(
        "\n{} Run 'restic-manage generate-services' to create systemd services",
        "→".blue()
    );

    Ok(())
}

fn remove_backup(name: String) -> Result<()> {
    let mut config = load_config()?;

    if !config.backups.contains_key(&name) {
        anyhow::bail!("Backup '{}' not found", name);
    }

    config.backups.remove(&name);
    save_config(&config)?;

    println!("{} Removed backup: {}", "✓".green(), name.bold());
    println!(
        "\n{} Remember to remove systemd service: sudo systemctl disable restic-backup@{}.timer",
        "→".yellow(),
        name
    );

    Ok(())
}

fn list_backups(verbose: bool) -> Result<()> {
    let config = load_config()?;

    if config.backups.is_empty() {
        println!("{}", "No backups configured".yellow());
        println!(
            "\nAdd one with: restic-manage add-backup <name> --paths <paths> --repository <repo>"
        );
        return Ok(());
    }

    println!("{}", "Configured Backups:".bold());
    println!();

    for (name, backup) in &config.backups {
        println!(
            "  {} {} -> {} ({})",
            "•".blue(),
            name.bold(),
            backup.repository.cyan(),
            backup.schedule.yellow()
        );

        if verbose {
            println!("    Paths: {}", backup.paths.join(", "));
            println!("    Retention: {}", backup.retention);
        }
    }

    Ok(())
}

fn generate_services(_force: bool) -> Result<()> {
    let config = load_config()?;
    let _hostname = get_hostname()?;

    if config.backups.is_empty() {
        println!("{}", "No backups configured. Nothing to generate.".yellow());
        return Ok(());
    }

    println!("{}", "Generating systemd service files...".bold());
    println!();

    for (name, backup) in &config.backups {
        let service_name = format!("restic-backup@{}.service", name);
        let _timer_name = format!("restic-backup@{}.timer", name);

        println!("  {} {}", "→".blue(), service_name);

        // Service files are generated by the NixOS module
        // This command just validates the configuration

        let repo = config
            .repositories
            .get(&backup.repository)
            .context(format!("Repository '{}' not found", backup.repository))?;

        println!("    Repository: {} ({})", repo.path, repo.repo_type);
        println!("    Schedule: {}", backup.schedule);
    }

    println!();
    println!("{} Configuration validated", "✓".green());
    println!("\n{} Enable backups with:", "→".blue());
    println!("  sudo systemctl daemon-reload");

    for (name, _) in &config.backups {
        println!("  sudo systemctl enable --now restic-backup@{}.timer", name);
    }

    Ok(())
}

fn init_repo(name: String) -> Result<()> {
    let config = load_config()?;
    let hostname = get_hostname()?;

    let repo = config
        .repositories
        .get(&name)
        .context(format!("Repository '{}' not found", name))?;

    println!("{} Initializing repository: {}", "→".blue(), name.bold());
    println!("  Type: {}", repo.repo_type);
    println!("  Path: {}", repo.path);
    println!();

    let password_file = format!("/run/agenix/restic-password-{}", hostname);

    if !Path::new(&password_file).exists() {
        anyhow::bail!(
            "Password file not found: {}\nCreate it with: agenix -e restic-password-{}.age",
            password_file,
            hostname
        );
    }

    // Initialize repository
    let status = Command::new("restic")
        .arg("-r")
        .arg(&repo.path)
        .arg("--password-file")
        .arg(&password_file)
        .arg("init")
        .status()
        .context("Failed to run restic init")?;

    if status.success() {
        println!("{} Repository initialized successfully", "✓".green());
    } else {
        anyhow::bail!("Failed to initialize repository");
    }

    Ok(())
}

fn test_repo(name: String) -> Result<()> {
    let config = load_config()?;
    let hostname = get_hostname()?;

    let repo = config
        .repositories
        .get(&name)
        .context(format!("Repository '{}' not found", name))?;

    println!("{} Testing repository: {}", "→".blue(), name.bold());

    let password_file = format!("/run/agenix/restic-password-{}", hostname);

    if !Path::new(&password_file).exists() {
        anyhow::bail!("Password file not found: {}", password_file);
    }

    // Test repository with snapshots command
    let status = Command::new("restic")
        .arg("-r")
        .arg(&repo.path)
        .arg("--password-file")
        .arg(&password_file)
        .arg("snapshots")
        .status()
        .context("Failed to run restic snapshots")?;

    if status.success() {
        println!("{} Repository is accessible", "✓".green());
    } else {
        anyhow::bail!("Failed to access repository");
    }

    Ok(())
}

fn config_path() -> Result<()> {
    let path = get_config_path()?;
    println!("{}", path.display());
    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::AddRepo {
            name,
            repo_type,
            path,
        } => add_repo(name, repo_type, path),
        Commands::RemoveRepo { name } => remove_repo(name),
        Commands::ListRepos { verbose } => list_repos(verbose),
        Commands::AddBackup {
            name,
            paths,
            repository,
            schedule,
            retention,
        } => add_backup(name, paths, repository, schedule, retention),
        Commands::RemoveBackup { name } => remove_backup(name),
        Commands::ListBackups { verbose } => list_backups(verbose),
        Commands::InitRepo { name } => init_repo(name),
        Commands::TestRepo { name } => test_repo(name),
        Commands::GenerateServices { force } => generate_services(force),
        Commands::ConfigPath => config_path(),
    }
}
