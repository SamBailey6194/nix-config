use anyhow::{Context, Result};
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Serialize, Deserialize)]
struct CacheEntry<T> {
    data: T,
    timestamp: DateTime<Utc>,
}

pub struct Cache<T> {
    path: String,
    ttl_hours: u64,
    _phantom: std::marker::PhantomData<T>,
}

/// Create a directory with secure permissions (0700 - owner only)
#[cfg(unix)]
fn create_secure_dir(path: &Path) -> Result<()> {
    use std::fs::DirBuilder;
    use std::os::unix::fs::DirBuilderExt;

    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(path)
        .context("Failed to create directory with secure permissions")?;
    Ok(())
}

#[cfg(not(unix))]
fn create_secure_dir(path: &Path) -> Result<()> {
    fs::create_dir_all(path).context("Failed to create directory")?;
    Ok(())
}

impl<T> Cache<T>
where
    T: Serialize + for<'de> Deserialize<'de>,
{
    pub fn new(path: &str, ttl_hours: u64) -> Result<Self> {
        let path_buf = PathBuf::from(path);

        // Validate path is safe
        // 1. Must be absolute or in a safe relative location
        // 2. Must not escape to system directories

        if path_buf.is_absolute() {
            // For absolute paths, ensure they're in allowed directories
            let allowed_prefixes = ["/tmp/wireguard-helper", "/var/cache/wireguard-helper"];

            // Also check XDG cache home if available
            let mut allowed_dirs: Vec<PathBuf> =
                allowed_prefixes.iter().map(PathBuf::from).collect();

            if let Ok(home) = std::env::var("HOME") {
                allowed_dirs.push(PathBuf::from(home).join(".cache/wireguard-helper"));
            }

            if let Ok(xdg_cache) = std::env::var("XDG_CACHE_HOME") {
                allowed_dirs.push(PathBuf::from(xdg_cache).join("wireguard-helper"));
            }

            // Check if path starts with any allowed directory
            let is_allowed = allowed_dirs.iter().any(|allowed| {
                path_buf.starts_with(allowed)
                    || path_buf
                        .canonicalize()
                        .ok()
                        .map(|p| p.starts_with(allowed))
                        .unwrap_or(false)
            });

            if !is_allowed {
                anyhow::bail!(
                    "Cache path must be in an allowed directory. \
                     Use XDG_CACHE_HOME or WIREGUARD_HELPER_CACHE_DIR to configure."
                );
            }
        }

        // Validate filename component
        if let Some(filename) = path_buf.file_name().and_then(|n| n.to_str()) {
            crate::validation::validate_simple_filename(filename)
                .context("Invalid cache filename")?;
        }

        Ok(Self {
            path: path.to_string(),
            ttl_hours,
            _phantom: std::marker::PhantomData,
        })
    }

    /// Load data from cache if not expired
    pub fn load(&self) -> Result<Option<T>> {
        let path = Path::new(&self.path);

        if !path.exists() {
            return Ok(None);
        }

        let contents = fs::read_to_string(path).context("Failed to read cache file")?;

        let entry: CacheEntry<T> =
            serde_json::from_str(&contents).context("Failed to parse cache file")?;

        // Check if cache is still valid
        let now = Utc::now();
        let age = now.signed_duration_since(entry.timestamp);

        if age > Duration::hours(self.ttl_hours as i64) {
            println!("Cache expired (age: {} hours)", age.num_hours());
            return Ok(None);
        }

        Ok(Some(entry.data))
    }

    /// Save data to cache
    pub fn save(&self, data: &T) -> Result<()> {
        let entry = CacheEntry {
            data,
            timestamp: Utc::now(),
        };

        let json =
            serde_json::to_string_pretty(&entry).context("Failed to serialize cache data")?;

        // Ensure parent directory exists with secure permissions
        if let Some(parent) = Path::new(&self.path).parent() {
            create_secure_dir(parent)?;
        }

        fs::write(&self.path, json).context("Failed to write cache file")?;

        Ok(())
    }

    /// Clear cache
    pub fn clear(&self) -> Result<()> {
        if Path::new(&self.path).exists() {
            fs::remove_file(&self.path).context("Failed to remove cache file")?;
        }
        Ok(())
    }
}
