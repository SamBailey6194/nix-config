use anyhow::{Context, Result};
use serde::Deserialize;
use std::process::Command;

#[derive(Debug, Deserialize)]
struct MullvadCheckResponse {
    ip: String,
    country: String,
    city: String,
    mullvad_exit_ip: bool,
}

pub fn run() -> Result<()> {
    println!("Verifying VPN connection...");

    // Check if VPN interface is up
    let output = Command::new("ip")
        .args(["link", "show", "mullvad0"])
        .output()
        .context("Failed to check VPN interface")?;

    if !output.status.success() {
        anyhow::bail!("❌ VPN interface mullvad0 is not up. Run 'just vpn-up' to start VPN.");
    }

    println!("✅ VPN interface is up");

    // Check current IP and location
    println!("\nChecking exit location...");

    let output = Command::new("curl")
        .args(["-s", "--max-time", "10", "https://am.i.mullvad.net/json"])
        .output()
        .context("Failed to run curl (is curl installed?)")?;

    let response_text = String::from_utf8_lossy(&output.stdout);

    if !output.status.success() || response_text.trim().is_empty() {
        println!("❌ Could not reach Mullvad API (https://am.i.mullvad.net/json)");
        println!("   This means traffic is not flowing through the VPN tunnel.");
        println!("   The WireGuard handshake may succeed but Mullvad is dropping packets.");
        println!("\n   Common causes:");
        println!("   - Interface Address doesn't match the public key registered in Mullvad");
        println!("   - Multi-hop relay configuration issue");
        println!("   - DNS not resolving through the tunnel");
        println!("\n   Debug steps:");
        println!("   1. Check your Mullvad address: https://mullvad.net/account → WireGuard");
        println!("   2. Verify it matches the --address flag in 'just vpn-rotate'");
        println!("   3. Try: curl -v https://am.i.mullvad.net/json");
        anyhow::bail!("VPN tunnel is up but traffic is not flowing");
    }

    let response: MullvadCheckResponse =
        serde_json::from_str(&response_text).context("Failed to parse Mullvad API response")?;

    if response.mullvad_exit_ip {
        println!("✅ Connected via Mullvad");
    } else {
        println!("⚠️  Warning: Not using Mullvad exit IP");
        println!("   Traffic may not be routed through the VPN tunnel");
    }
    println!("   Exit IP: {}", response.ip);
    println!("   Location: {}, {}", response.city, response.country);

    // Check WireGuard handshake (needs root to see peer details)
    let output = Command::new("sudo")
        .args(["wg", "show", "mullvad0"])
        .output()
        .context("Failed to check WireGuard status (sudo required)")?;

    let wg_output = String::from_utf8_lossy(&output.stdout);

    if wg_output.contains("latest handshake") {
        println!("✅ WireGuard handshake successful");
    } else {
        println!("⚠️  Warning: No recent handshake detected");
    }

    println!("\n🎉 VPN verification complete!");

    Ok(())
}
