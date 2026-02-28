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

use commands::{cgroup_launch, init, metrics, rotate, status, verify};

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

    /// Rotate Mullvad multi-hop servers (entry → UK exit). Keys are never changed.
    Rotate {
        /// Device hostname
        device: String,

        /// Mullvad-assigned IPv4 address (from account portal, tied to public key)
        #[arg(long)]
        address: String,

        /// Mullvad-assigned IPv6 address (from account portal, tied to public key)
        #[arg(long)]
        address6: String,
    },

    /// Verify VPN connection and exit location
    Verify,

    /// Show VPN status (interface, endpoint, handshake, IP/country)
    Status,

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
            address,
            address6,
        } => {
            rotate::run(&device, &address, &address6)?;
        }
        Commands::Verify => {
            verify::run()?;
        }
        Commands::Status => {
            status::run()?;
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
