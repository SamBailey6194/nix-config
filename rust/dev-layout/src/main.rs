use std::process::Command;
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use colored::Colorize;

/// Launch a dev layout: Zed (left 75%) + two Kitty terminals (stacked right 25%).
fn main() -> Result<()> {
    println!("{}", "Launching dev layout...".green());

    // Spawn Zed editor
    Command::new("zeditor")
        .arg("-n")
        .spawn()
        .context("Failed to launch zeditor")?;
    thread::sleep(Duration::from_secs(1));

    // Spawn first terminal
    Command::new("kitty")
        .spawn()
        .context("Failed to launch kitty")?;
    thread::sleep(Duration::from_millis(500));

    // Spawn second terminal
    Command::new("kitty")
        .spawn()
        .context("Failed to launch kitty")?;
    thread::sleep(Duration::from_millis(500));

    // Focus left (Zed) and set split ratio
    hyprctl(&["dispatch", "movefocus", "l"])?;
    hyprctl(&["dispatch", "movefocus", "l"])?;
    hyprctl(&["dispatch", "splitratio", "exact", "0.75"])?;

    println!("{}", "Dev layout ready.".green());
    Ok(())
}

/// Run a hyprctl command and check for errors.
fn hyprctl(args: &[&str]) -> Result<()> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .context("Failed to run hyprctl")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("hyprctl {} failed: {}", args.join(" "), stderr);
    }

    Ok(())
}
