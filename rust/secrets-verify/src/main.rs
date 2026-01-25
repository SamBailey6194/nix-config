use anyhow::{Context, Result};
use clap::Parser;
use colored::*;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Parser)]
#[command(author, version, about = "Verify agenix secrets are deployed correctly", long_about = None)]
struct Cli {
    /// Test GitHub SSH connections
    #[arg(long)]
    test_github: bool,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,

    /// Custom secrets directory (defaults to ~/.ssh)
    #[arg(long)]
    secrets_dir: Option<PathBuf>,
}

struct SecretCheck {
    name: String,
    exists: bool,
    permissions: Option<u32>,
    is_valid: bool,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    println!("{}", "🔒 Agenix Secrets Verification".bold().cyan());
    println!();

    let secrets_dir = cli.secrets_dir.unwrap_or_else(|| {
        dirs::home_dir()
            .expect("Could not find home directory")
            .join(".ssh")
    });

    if cli.verbose {
        println!("Checking secrets in: {}", secrets_dir.display());
        println!();
    }

    // Check GitHub SSH keys
    let github_accounts = vec!["personal", "syntek", "missionalgen"];
    let mut all_valid = true;

    println!("{}", "GitHub SSH Keys:".bold());
    for account in &github_accounts {
        let check = verify_secret(&secrets_dir, &format!("github-{}", account))?;
        print_check_result(&check);
        all_valid = all_valid && check.is_valid;
    }
    println!();

    // Test GitHub SSH connections if requested
    if cli.test_github {
        println!("{}", "Testing GitHub SSH Connections:".bold());
        for account in &github_accounts {
            test_github_ssh(account)?;
        }
        println!();
    }

    // Check for any other secrets in the directory
    if cli.verbose {
        println!("{}", "Other secrets in directory:".bold());
        for entry in walkdir::WalkDir::new(&secrets_dir)
            .max_depth(1)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.file_type().is_file() {
                let path = entry.path();
                if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                    if !name.starts_with("github-")
                        && !name.ends_with(".pub")
                        && name != "known_hosts"
                        && name != "config"
                    {
                        let check = verify_secret_path(path)?;
                        print_check_result(&check);
                    }
                }
            }
        }
        println!();
    }

    // Final summary
    if all_valid {
        println!(
            "{}",
            "✅ All critical secrets verified successfully!".green().bold()
        );
        Ok(())
    } else {
        println!(
            "{}",
            "❌ Some secrets are missing or have incorrect permissions!".red().bold()
        );
        std::process::exit(1);
    }
}

fn verify_secret(secrets_dir: &Path, name: &str) -> Result<SecretCheck> {
    let path = secrets_dir.join(name);
    verify_secret_path(&path)
}

fn verify_secret_path(path: &Path) -> Result<SecretCheck> {
    use std::os::unix::fs::MetadataExt;

    let name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    let exists = path.exists();
    let mut permissions = None;
    let mut is_valid = false;

    if exists {
        let metadata = fs::metadata(path)?;
        let perms = metadata.permissions().mode();
        permissions = Some(perms & 0o777);

        // Security checks
        let mut security_checks_passed = true;

        // 1. Check file permissions (must be 0600)
        if permissions != Some(0o600) {
            security_checks_passed = false;
            eprintln!(
                "  WARNING: {} has incorrect permissions: {:o} (expected 0600)",
                name,
                permissions.unwrap_or(0)
            );
        }

        // 2. Check file ownership (must be owned by current user)
        let file_uid = metadata.uid();
        let current_uid = unsafe { libc::getuid() };
        if file_uid != current_uid {
            security_checks_passed = false;
            eprintln!(
                "  WARNING: {} not owned by current user (file uid: {}, current uid: {})",
                name, file_uid, current_uid
            );
        }

        // 3. Check parent directory permissions (should not have group/other access)
        if let Some(parent) = path.parent() {
            if let Ok(parent_meta) = fs::metadata(parent) {
                let parent_perms = parent_meta.permissions().mode() & 0o777;
                if parent_perms & 0o077 != 0 {
                    eprintln!(
                        "  WARNING: Parent directory {} has group/other permissions: {:o}",
                        parent.display(),
                        parent_perms
                    );
                }

                // Check parent ownership
                let parent_uid = parent_meta.uid();
                if parent_uid != current_uid {
                    eprintln!(
                        "  WARNING: Parent directory {} not owned by current user",
                        parent.display()
                    );
                }
            }
        }

        // 4. Check if it's a valid SSH private key
        let is_valid_format = check_ssh_key_format(path)?;
        if !is_valid_format {
            security_checks_passed = false;
        }

        is_valid = is_valid_format && security_checks_passed;
    }

    Ok(SecretCheck {
        name,
        exists,
        permissions,
        is_valid,
    })
}

fn check_ssh_key_format(path: &Path) -> Result<bool> {
    let content = fs::read_to_string(path)?;
    Ok(content.contains("BEGIN OPENSSH PRIVATE KEY")
        || content.contains("BEGIN RSA PRIVATE KEY")
        || content.contains("BEGIN EC PRIVATE KEY")
        || content.contains("BEGIN PRIVATE KEY"))
}

fn print_check_result(check: &SecretCheck) {
    let status = if check.is_valid {
        "✅".green()
    } else if check.exists {
        "⚠️".yellow()
    } else {
        "❌".red()
    };

    print!("  {} {}", status, check.name);

    if check.exists {
        if let Some(perms) = check.permissions {
            let perm_str = format!("{:o}", perms);
            if perms == 0o600 {
                print!(" ({})", perm_str.green());
            } else {
                print!(" ({} - should be 600)", perm_str.red());
            }
        }
    } else {
        print!(" {}", "(not found)".red());
    }

    println!();
}

fn test_github_ssh(account: &str) -> Result<()> {
    let host = format!("github-{}", account);

    print!("  Testing {}... ", host);

    let output = Command::new("ssh")
        .args(["-T", "-o", "StrictHostKeyChecking=accept-new", &format!("git@{}", host)])
        .output()
        .context("Failed to execute ssh command")?;

    // GitHub SSH test returns exit code 1 with success message
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let combined = format!("{}{}", stdout, stderr);

    if combined.contains("successfully authenticated") {
        println!("{}", "✅ Success".green());
    } else {
        println!("{}", "❌ Failed".red());

        // SECURITY: Only show debug output if VERBOSE environment variable is set
        // This prevents information leakage in logs and terminal output
        if std::env::var("VERBOSE").is_ok() {
            // Sanitize output - remove potentially sensitive information
            let sanitized = combined
                .lines()
                .filter(|line| {
                    // Filter out lines that may contain sensitive key data
                    !line.to_lowercase().contains("key")
                        && !line.to_lowercase().contains("fingerprint")
                        && !line.to_lowercase().contains("signature")
                })
                .collect::<Vec<_>>()
                .join("\n");

            eprintln!("DEBUG: SSH connection failed for {}", host);
            eprintln!("DEBUG: Sanitized output: {}", sanitized.trim());
            eprintln!("    (Set VERBOSE=1 to see this debug output)");
        } else {
            // Show generic message without leaking details
            eprintln!("    SSH connection failed (set VERBOSE=1 for details)");
        }

        // Show sanitized message to user
        println!("    Check SSH configuration and key permissions");
    }

    Ok(())
}
