use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

/// Create a directory with secure permissions (0700 - owner only)
#[cfg(unix)]
fn create_secure_dir(path: &Path) -> Result<()> {
    use std::os::unix::fs::DirBuilderExt;
    use std::fs::DirBuilder;

    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(path)
        .context("Failed to create directory with secure permissions")?;
    Ok(())
}

#[cfg(not(unix))]
fn create_secure_dir(path: &Path) -> Result<()> {
    fs::create_dir_all(path)
        .context("Failed to create directory")?;
    Ok(())
}

pub fn run(location: &str) -> Result<()> {
    // Validate location
    let valid_locations = ["uk", "us", "eu"];
    if !valid_locations.contains(&location) {
        anyhow::bail!(
            "Invalid exit location: {}. Must be one of: {}",
            location,
            valid_locations.join(", ")
        );
    }

    println!("Setting exit location to: {}", location);

    // Get config directory
    let config_dir = crate::paths::get_config_dir()?;

    // Save exit location to config file
    create_secure_dir(&config_dir)?;

    let config_path = config_dir.join("exit-location.txt");
    fs::write(&config_path, location)
        .context("Failed to write exit location config")?;

    println!("✅ Exit location updated to: {}", location);
    println!("\n🎯 The next server rotation will use {} exit nodes", location);
    println!("   Run 'just vpn-rotate' to apply immediately");

    Ok(())
}
