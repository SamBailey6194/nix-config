use anyhow::Result;
use colored::*;
use std::fs;
use std::path::Path;

pub fn run(repo_root: &Path, verbose: bool) -> Result<()> {
    let secrets_dir = repo_root.join("secrets");
    let secrets_nix = secrets_dir.join("secrets.nix");

    println!("{}", "📋 Agenix Secrets Overview".bold().cyan());
    println!();

    // Read secrets.nix
    let content = fs::read_to_string(&secrets_nix)?;

    // Parse secrets (simple regex-based approach)
    println!("{}", "Encrypted Secrets:".bold());

    for entry in walkdir::WalkDir::new(&secrets_dir)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        if entry.file_type().is_file() {
            let path = entry.path();
            if let Some(ext) = path.extension() {
                if ext == "age" {
                    if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                        print!("  {} {}", "🔒".cyan(), name.bold());

                        // Try to find which keys can decrypt this
                        if let Some(keys_line) = find_keys_for_secret(&content, name) {
                            println!(" -> {}", keys_line.dimmed());
                        } else {
                            println!();
                        }
                    }
                }
            }
        }
    }

    println!();

    if verbose {
        println!("{}", "Host Public Keys:".bold());
        print_host_keys(&content);
        println!();
    }

    Ok(())
}

fn find_keys_for_secret(content: &str, secret_name: &str) -> Option<String> {
    for line in content.lines() {
        if line.contains(&format!("\"{}\"", secret_name)) {
            // Extract publicKeys = [...];
            if let Some(start) = line.find("publicKeys = ") {
                let rest = &line[start + 13..];
                if let Some(end) = rest.find(';') {
                    return Some(rest[..end].trim().to_string());
                }
            }
        }
    }
    None
}

fn print_host_keys(content: &str) {
    let hosts = ["laptop-intel", "framework", "devtower"];

    for host in &hosts {
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with(&format!("{} = ", host)) {
                println!("  {} {}", "🖥️".blue(), trimmed);
                break;
            }
        }
    }
}
