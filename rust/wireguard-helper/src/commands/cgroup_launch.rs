use anyhow::{Context, Result};
use std::process::Command;

pub fn run(command: &[String]) -> Result<()> {
    if command.is_empty() {
        anyhow::bail!("No command provided. Usage: wireguard-helper vpn-app <command>");
    }

    // Validate command doesn't start with systemd-run options to prevent option injection
    if command[0].starts_with('-') {
        anyhow::bail!(
            "Command cannot start with '-' (potential option injection). \
             If you need to pass options to the command, use: wireguard-helper vpn-app -- {}",
            command.join(" ")
        );
    }

    // Sanitize description to prevent injection
    let safe_description = command
        .iter()
        .map(|s| s.replace("--", "").replace("'", "").replace("\"", ""))
        .collect::<Vec<_>>()
        .join(" ");

    println!("Launching via VPN cgroup: {}", command.join(" "));

    // Use systemd-run to launch in VPN slice
    // CRITICAL: Use -- separator to prevent option injection
    let mut cmd = Command::new("systemd-run");
    cmd.args([
        "--user",
        "--scope",
        "--slice=vpn-apps",
        &format!("--description=VPN-routed application: {}", safe_description),
        "--",  // CRITICAL: Separator prevents option injection
    ]);

    cmd.args(command);

    let output = cmd.output()
        .context("Failed to launch command via systemd-run")?;

    if !output.status.success() {
        // Log full error to stderr for debugging, don't expose to user
        eprintln!("DEBUG: systemd-run stderr: {}", String::from_utf8_lossy(&output.stderr));
        anyhow::bail!("Failed to launch command via systemd-run. Check that systemd is available and configured correctly");
    }

    println!("✅ Launched: {}", command.join(" "));

    Ok(())
}
