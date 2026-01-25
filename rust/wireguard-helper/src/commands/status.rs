use anyhow::{Context, Result};
use std::process::Command;

pub fn run() -> Result<()> {
    println!("VPN Status Report\n");

    // Check interface status
    let output = Command::new("ip")
        .args(["link", "show", "mullvad0"])
        .output()
        .context("Failed to check interface")?;

    if !output.status.success() {
        println!("❌ Interface: DOWN");
        println!("\nRun 'just vpn-up' to start the VPN");
        return Ok(());
    }

    println!("✅ Interface: UP");

    // Get WireGuard details
    let output = Command::new("wg")
        .args(["show", "mullvad0"])
        .output()
        .context("Failed to get WireGuard details")?;

    let wg_output = String::from_utf8_lossy(&output.stdout);
    println!("\nWireGuard Details:");
    println!("{}", wg_output);

    // Get current IP and location
    let output = Command::new("curl")
        .args(["-s", "https://am.i.mullvad.net/json"])
        .output();

    if let Ok(output) = output {
        let response = String::from_utf8_lossy(&output.stdout);
        if let Ok(data) = serde_json::from_str::<serde_json::Value>(&response) {
            println!("\nExit Information:");
            println!("  IP: {}", data["ip"].as_str().unwrap_or("unknown"));
            println!(
                "  Country: {}",
                data["country"].as_str().unwrap_or("unknown")
            );
            println!("  City: {}", data["city"].as_str().unwrap_or("unknown"));
            println!(
                "  Mullvad Exit: {}",
                data["mullvad_exit_ip"].as_bool().unwrap_or(false)
            );
        }
    }

    // Get interface statistics
    let rx_bytes = std::fs::read_to_string("/sys/class/net/mullvad0/statistics/rx_bytes")
        .unwrap_or_else(|_| "0".to_string());
    let tx_bytes = std::fs::read_to_string("/sys/class/net/mullvad0/statistics/tx_bytes")
        .unwrap_or_else(|_| "0".to_string());

    let rx_mb: u64 = rx_bytes.trim().parse().unwrap_or(0) / 1024 / 1024;
    let tx_mb: u64 = tx_bytes.trim().parse().unwrap_or(0) / 1024 / 1024;

    println!("\nTraffic Statistics:");
    println!("  Downloaded: {} MB", rx_mb);
    println!("  Uploaded: {} MB", tx_mb);

    Ok(())
}
