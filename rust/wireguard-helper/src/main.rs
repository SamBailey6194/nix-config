use anyhow::Result;
use clap::{Parser, Subcommand};

mod cache;
mod commands;
mod metrics_logger;
mod mullvad_api;
mod paths;
mod route_history;
mod validation;
mod wg_config;

use commands::{cgroup_launch, init, metrics, rotate, set_exit, status, verify};

#[derive(Parser)]
#[command(name = "wireguard-helper")]
#[command(about = "Mullvad WireGuard VPN management tool with multi-hop routing", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate WireGuard keypair and encrypt to agenix
    Init {
        /// Device hostname (e.g., laptop-intel)
        device: String,
    },

    /// Rotate Mullvad servers (2-hop: entry → exit)
    Rotate {
        /// Device hostname
        device: String,

        /// Exit location (uk, us, or eu)
        #[arg(long, default_value = "uk")]
        exit: String,

        /// Mullvad-assigned IPv4 address (e.g., 10.74.122.237/32)
        #[arg(long)]
        address: String,

        /// Mullvad-assigned IPv6 address (e.g., fc00:bbbb:bbbb:bb01::b:7aec/128)
        #[arg(long)]
        address6: String,
    },

    /// Verify VPN connection and exit location
    Verify,

    /// Show VPN status (interface, endpoint, handshake, IP/country)
    Status,

    /// Switch exit location and trigger rotation
    SetExit {
        /// Exit location (uk, us, or eu)
        location: String,
    },

    /// Display VPN metrics from log file
    Metrics {
        /// Show tail of metrics log
        #[arg(long)]
        tail: bool,

        /// Number of lines to show
        #[arg(long, default_value = "20")]
        lines: usize,
    },

    /// Launch app with cgroup-based VPN routing
    VpnApp {
        /// Command to run through VPN
        command: Vec<String>,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Init { device } => {
            init::run(&device)?;
        }
        Commands::Rotate {
            device,
            exit,
            address,
            address6,
        } => {
            rotate::run(&device, &exit, &address, &address6)?;
        }
        Commands::Verify => {
            verify::run()?;
        }
        Commands::Status => {
            status::run()?;
        }
        Commands::SetExit { location } => {
            set_exit::run(&location)?;
        }
        Commands::Metrics { tail, lines } => {
            metrics::run(tail, lines)?;
        }
        Commands::VpnApp { command } => {
            cgroup_launch::run(&command)?;
        }
    }

    Ok(())
}
