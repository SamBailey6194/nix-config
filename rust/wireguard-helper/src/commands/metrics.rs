use anyhow::{Context, Result};
use crate::metrics_logger::MetricsLogger;

const DEFAULT_LOG_FILE: &str = "/var/log/vpn-logs.txt";

pub fn run(tail: bool, lines: usize) -> Result<()> {
    let logger = MetricsLogger::new(DEFAULT_LOG_FILE);

    if !std::path::Path::new(DEFAULT_LOG_FILE).exists() {
        println!("No metrics logged yet. VPN may not be running.");
        return Ok(());
    }

    if tail {
        println!("VPN Metrics (last {} lines):\n", lines);
        let tail_lines = logger.read_tail(lines)
            .context("Failed to read metrics log")?;

        for line in tail_lines {
            println!("{}", line);
        }
    } else {
        // Show full file
        let contents = std::fs::read_to_string(DEFAULT_LOG_FILE)
            .context("Failed to read metrics log")?;
        println!("{}", contents);
    }

    Ok(())
}
