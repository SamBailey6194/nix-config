use anyhow::{Context, Result};
use std::fs::OpenOptions;
use std::io::Write;
use chrono::Utc;

pub struct MetricsLogger {
    log_file: String,
}

impl MetricsLogger {
    pub fn new(log_file: &str) -> Self {
        Self {
            log_file: log_file.to_string(),
        }
    }

    /// Log VPN metrics
    #[allow(dead_code)]
    pub fn log_metrics(
        &self,
        rx_mb: u64,
        tx_mb: u64,
        latency: &str,
        exit_location: &str,
        uptime_min: u64,
        handshake: &str,
    ) -> Result<()> {
        let timestamp = Utc::now().to_rfc3339();

        let line = format!(
            "[{}] rx_mb={} tx_mb={} latency={} exit={} uptime_min={} handshake={}\n",
            timestamp, rx_mb, tx_mb, latency, exit_location, uptime_min, handshake
        );

        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.log_file)
            .context("Failed to open metrics log file")?;

        file.write_all(line.as_bytes())
            .context("Failed to write metrics")?;

        Ok(())
    }

    /// Read last N lines from metrics log
    pub fn read_tail(&self, lines: usize) -> Result<Vec<String>> {
        use std::fs;

        if !std::path::Path::new(&self.log_file).exists() {
            return Ok(Vec::new());
        }

        let contents = fs::read_to_string(&self.log_file)
            .context("Failed to read metrics log")?;

        let all_lines: Vec<String> = contents.lines().map(|s| s.to_string()).collect();

        let tail = if all_lines.len() > lines {
            all_lines[all_lines.len() - lines..].to_vec()
        } else {
            all_lines
        };

        Ok(tail)
    }
}
