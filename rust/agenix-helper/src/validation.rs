use anyhow::{Context, Result};
use std::path::{Component, Path, PathBuf};

/// Validates a secret name to prevent path traversal attacks
///
/// # Security
///
/// This function prevents path traversal by:
/// - Rejecting any path components other than normal filenames
/// - Rejecting paths containing directory separators
/// - Ensuring the canonicalized path stays within the secrets directory
///
/// # Arguments
///
/// * `name` - The secret name to validate (e.g., "github-key")
///
/// # Returns
///
/// Returns the validated secret name with `.age` extension if not present
///
/// # Errors
///
/// Returns an error if:
/// - Name contains path traversal components (`..`, `/`, `\`)
/// - Name is empty
/// - Name contains invalid characters
pub fn validate_secret_name(name: &str) -> Result<String> {
    // Check for empty name
    if name.is_empty() {
        anyhow::bail!("Secret name cannot be empty");
    }

    // Remove .age extension for validation
    let base_name = name.strip_suffix(".age").unwrap_or(name);

    // Check for path separators
    if base_name.contains('/') || base_name.contains('\\') {
        anyhow::bail!("Secret name cannot contain path separators");
    }

    // Ensure no path traversal components
    let path = Path::new(base_name);
    for component in path.components() {
        match component {
            Component::Normal(_) => continue,
            _ => anyhow::bail!("Invalid secret name: contains path traversal components"),
        }
    }

    // Ensure reasonable length
    if base_name.len() > 255 {
        anyhow::bail!("Secret name too long (max 255 characters)");
    }

    // Return with .age extension
    Ok(format!("{}.age", base_name))
}

/// Validates a server/device name to prevent injection attacks
///
/// # Security
///
/// Only allows alphanumeric characters and hyphens to prevent:
/// - Path traversal
/// - Shell injection
/// - Command injection
pub fn validate_name(name: &str, type_name: &str) -> Result<String> {
    if name.is_empty() {
        anyhow::bail!("{} name cannot be empty", type_name);
    }

    // Only allow alphanumeric and hyphens
    if !name.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_') {
        anyhow::bail!(
            "{} name must contain only alphanumeric characters, hyphens, and underscores",
            type_name
        );
    }

    // Reasonable length limit
    if name.len() > 64 {
        anyhow::bail!("{} name too long (max 64 characters)", type_name);
    }

    Ok(name.to_string())
}

/// Validates and secures a path is within a base directory
///
/// # Security
///
/// Ensures the resolved path:
/// - Exists
/// - Is within the specified base directory
/// - Does not escape via symlinks or .. components
pub fn validate_path_in_directory(path: &Path, base_dir: &Path) -> Result<PathBuf> {
    let canonical = path
        .canonicalize()
        .context("Path does not exist or cannot be resolved")?;

    let canonical_base = base_dir
        .canonicalize()
        .context("Base directory does not exist")?;

    if !canonical.starts_with(&canonical_base) {
        anyhow::bail!("Path traversal detected: path is outside allowed directory");
    }

    Ok(canonical)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_secret_name_accepts_valid() {
        assert_eq!(validate_secret_name("github-key").unwrap(), "github-key.age");
        assert_eq!(validate_secret_name("github-key.age").unwrap(), "github-key.age");
        assert_eq!(validate_secret_name("server_key").unwrap(), "server_key.age");
    }

    #[test]
    fn test_validate_secret_name_rejects_traversal() {
        assert!(validate_secret_name("../etc/passwd").is_err());
        assert!(validate_secret_name("../../secret").is_err());
        assert!(validate_secret_name("/etc/passwd").is_err());
        assert!(validate_secret_name("dir/secret").is_err());
    }

    #[test]
    fn test_validate_secret_name_rejects_empty() {
        assert!(validate_secret_name("").is_err());
    }

    #[test]
    fn test_validate_name_accepts_valid() {
        assert!(validate_name("laptop-intel", "device").is_ok());
        assert!(validate_name("server_01", "server").is_ok());
        assert!(validate_name("test123", "device").is_ok());
    }

    #[test]
    fn test_validate_name_rejects_invalid() {
        assert!(validate_name("server; rm -rf /", "server").is_err());
        assert!(validate_name("../etc/passwd", "device").is_err());
        assert!(validate_name("test/dir", "device").is_err());
        assert!(validate_name("", "device").is_err());
    }
}
