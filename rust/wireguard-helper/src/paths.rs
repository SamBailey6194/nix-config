use anyhow::{Context, Result};
use std::env;
use std::path::PathBuf;

/// Get the secrets directory path
///
/// Priority:
/// 1. NIX_CONFIG_SECRETS_DIR environment variable
/// 2. Find nix-config repo from current directory
/// 3. Error
pub fn get_secrets_dir() -> Result<PathBuf> {
    // Try environment variable first
    if let Ok(dir) = env::var("NIX_CONFIG_SECRETS_DIR") {
        let path = PathBuf::from(dir);
        if path.exists() {
            return Ok(path);
        }
        eprintln!("Warning: NIX_CONFIG_SECRETS_DIR is set but directory doesn't exist: {}", path.display());
    }

    // Find repo root from current directory
    let current = env::current_dir().context("Cannot determine current directory")?;
    for ancestor in current.ancestors() {
        let secrets = ancestor.join("secrets");
        if secrets.exists() && ancestor.join("flake.nix").exists() {
            return Ok(secrets);
        }
    }

    // Check common locations as fallback
    if let Ok(home) = env::var("HOME") {
        let common_paths = [
            PathBuf::from(&home).join("Repos/personal/nix-config/secrets"),
            PathBuf::from(&home).join("nix-config/secrets"),
            PathBuf::from(&home).join(".config/nix-config/secrets"),
        ];

        for path in &common_paths {
            if path.exists() {
                return Ok(path.clone());
            }
        }
    }

    anyhow::bail!(
        "Cannot find secrets directory. Either:\n\
         1. Set NIX_CONFIG_SECRETS_DIR environment variable, or\n\
         2. Run from within nix-config repository, or\n\
         3. Ensure ~/Repos/personal/nix-config/secrets exists"
    )
}

/// Get the cache directory path
///
/// Uses XDG Base Directory specification with fallback to ~/.cache
pub fn get_cache_dir() -> Result<PathBuf> {
    // Try environment variable first
    if let Ok(dir) = env::var("WIREGUARD_HELPER_CACHE_DIR") {
        let path = PathBuf::from(dir);
        return Ok(path);
    }

    // Use XDG_CACHE_HOME if set
    if let Ok(cache_home) = env::var("XDG_CACHE_HOME") {
        let path = PathBuf::from(cache_home).join("wireguard-helper");
        return Ok(path);
    }

    // Fallback to ~/.cache/wireguard-helper
    if let Ok(home) = env::var("HOME") {
        let path = PathBuf::from(home).join(".cache/wireguard-helper");
        return Ok(path);
    }

    // Last resort: /tmp/wireguard-helper-{uid}
    #[cfg(unix)]
    {
        use nix::unistd::Uid;
        let uid = Uid::current();
        let path = PathBuf::from(format!("/tmp/wireguard-helper-{}", uid));
        Ok(path)
    }

    #[cfg(not(unix))]
    anyhow::bail!("Cannot determine cache directory")
}

/// Get the config directory path
///
/// Uses XDG Base Directory specification with fallback to ~/.config
pub fn get_config_dir() -> Result<PathBuf> {
    // Try environment variable first
    if let Ok(dir) = env::var("WIREGUARD_HELPER_CONFIG_DIR") {
        let path = PathBuf::from(dir);
        return Ok(path);
    }

    // Use XDG_CONFIG_HOME if set
    if let Ok(config_home) = env::var("XDG_CONFIG_HOME") {
        let path = PathBuf::from(config_home).join("wireguard-helper");
        return Ok(path);
    }

    // Fallback to ~/.config/wireguard-helper
    if let Ok(home) = env::var("HOME") {
        let path = PathBuf::from(home).join(".config/wireguard-helper");
        return Ok(path);
    }

    anyhow::bail!("Cannot determine config directory")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_cache_dir_respects_env() {
        env::set_var("WIREGUARD_HELPER_CACHE_DIR", "/tmp/test-cache");
        let dir = get_cache_dir().unwrap();
        assert_eq!(dir, PathBuf::from("/tmp/test-cache"));
        env::remove_var("WIREGUARD_HELPER_CACHE_DIR");
    }

    #[test]
    fn test_get_config_dir_respects_env() {
        env::set_var("WIREGUARD_HELPER_CONFIG_DIR", "/tmp/test-config");
        let dir = get_config_dir().unwrap();
        assert_eq!(dir, PathBuf::from("/tmp/test-config"));
        env::remove_var("WIREGUARD_HELPER_CONFIG_DIR");
    }
}
