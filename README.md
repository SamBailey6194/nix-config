# NixOS Configuration

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

Personal NixOS configuration with Hyprland, dotfiles, and Rust security tooling for multi-device deployment.

**Current Focus:** Single device (laptop-intel) with full secrets management, VPN, malware protection, and storage systems.

## Quick Links

- **Getting Started:** [Installation Guide](docs/INSTALLATION.md) | [Architecture](docs/ARCHITECTURE.md)
- **Core Features:** [Secrets](docs/SECRETS.md) | [VPN](docs/VPN.md) | [Storage](docs/STORAGE.md) | [Security](docs/MALWARE-SCANNER.md)
- **Complete Index:** [Documentation Hub](docs/README.md)

## Overview

A complete NixOS configuration featuring a **6-stage progressive installation system** that builds your system incrementally, from minimal base to full desktop environment. Designed for single-device deployment first (laptop-intel), with plans to expand to framework laptop and devtower desktop.

### Key Features

- **Staged Installation** - 6 progressive stages avoid tmpfs issues during installation
- **Hyprland Desktop** - Modern Wayland compositor with modular configuration
- **Per-Device Secrets** - Zero-trust model with unique SSH keys per device (Agenix)
- **Mullvad VPN** - Multi-hop WireGuard with kill switch and split tunneling
- **Malware Protection** - Real-time scanning with ClamAV, YARA, and custom detection
- **Storage Management** - Runtime-configurable Restic backups, ZFS, and RAID
- **Development Environment** - Language servers, Docker, and tooling for Python, TypeScript, Rust, PHP
- **Rust Tooling** - 6 CLI tools for secrets, VPN, malware scanning, and storage management

### Current Device

| Host | User | Hardware | Status |
|------|------|----------|--------|
| laptop-intel | sam-laptop | Intel i5-10210U, 32GB RAM, Intel UHD Graphics | ✅ Ready for install |

### Future Devices

- **framework** - AMD Ryzen, 64GB RAM, AMD Radeon (future)
- **devtower** - AMD desktop, 64GB RAM, AMD Radeon + Go XLR audio (future)

## Installation Stages

The staged installation system builds your system progressively, avoiding tmpfs issues:

| Stage | Target | What's Included | Purpose | Time |
|-------|--------|-----------------|---------|------|
| 1 | `{device}-minimal` | Base OS, network, shell | Boot test | 10-20 min |
| 2 | `{device}-desktop` | Hyprland, terminal, launcher | Desktop environment | 15-30 min |
| 3 | `{device}-dev` | Browsers, dev tools, language servers | Development | 20-40 min |
| 4 | `{device}-productivity` | LibreOffice, Discord, Zoom, VLC | Office & communication | 15-25 min |
| 5 | `{device}-creative` | Blender, GIMP, DaVinci (GPU-dependent) | Creative software | 30-60 min |
| 6 | `{device}` | ALL stages combined | **Daily use** | 5-30 min updates |

**Example flow:**
```bash
# Stage 1: Minimal installation
nixos-install --flake .#laptop-intel-minimal

# Stage 2: Add desktop environment
sudo nixos-rebuild switch --flake .#laptop-intel-desktop

# Stage 6: Full configuration for daily use
sudo nixos-rebuild switch --flake .#laptop-intel
```

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for complete walkthrough.

## Quick Start

### 1. Install NixOS

```bash
# Download NixOS ISO from nixos.org
# Create bootable USB: dd if=nixos.iso of=/dev/sdX bs=4M status=progress
# Boot from USB

# Stage 1: Minimal installation (10-20 min)
nixos-install --flake .#laptop-intel-minimal
reboot

# Stage 2: Desktop environment (15-30 min)
sudo nixos-rebuild switch --flake .#laptop-intel-desktop

# Stage 6: Full configuration (5-30 min)
sudo nixos-rebuild switch --flake .#laptop-intel
```

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for complete guide with disk partitioning and setup.

### 2. Setup Secrets

```bash
# Generate per-device GitHub SSH keys
agenix-helper add-device laptop-intel

# Encrypt secrets
agenix-helper edit github-ssh-personal-laptop-intel

# Deploy
sudo nixos-rebuild switch --flake .#laptop-intel
```

See [docs/SECRETS.md](docs/SECRETS.md) for complete guide.

### 3. Optional: Enable VPN

```bash
# Generate 5-hop VPN configuration
just vpn-rotate laptop-intel

# Start VPN
just vpn-up

# Verify connection
just vpn-verify
```

See [docs/VPN.md](docs/VPN.md) for complete guide.

### 4. Optional: Configure Backups

```bash
# Add backup job
restic-manage add-backup home --paths /home --repository local

# Run backup
restic-backup-now home
```

See [docs/STORAGE.md](docs/STORAGE.md) for complete guide.

## Documentation

Comprehensive documentation organized by topic:

### Core Guides

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture and design principles
- **[docs/INSTALLATION.md](docs/INSTALLATION.md)** - Complete NixOS installation with 6 stages
- **[docs/SECRETS.md](docs/SECRETS.md)** - Per-device secrets management with Agenix
- **[docs/VPN.md](docs/VPN.md)** - Mullvad WireGuard multi-hop VPN setup
- **[docs/STORAGE.md](docs/STORAGE.md)** - Restic backups, ZFS, and RAID management
- **[docs/MALWARE-SCANNER.md](docs/MALWARE-SCANNER.md)** - Real-time malware protection

### Software-Specific

- **[docs/DAVINCI-RESOLVE-AMD.md](docs/DAVINCI-RESOLVE-AMD.md)** - DaVinci Resolve Studio on AMD GPUs
- **[docs/NEOVIM-SETUP.md](docs/NEOVIM-SETUP.md)** - Neovim editor configuration

### Development

- **[rust/README.md](rust/README.md)** - Rust tooling overview
- **[rust/secrets-verify/README.md](rust/secrets-verify/README.md)** - Secrets verification tool
- **[rust/agenix-helper/README.md](rust/agenix-helper/README.md)** - Agenix helper CLI
- **[rust/wireguard-helper/README.md](rust/wireguard-helper/README.md)** - VPN management CLI
- **[rust/malware-scanner/README.md](rust/malware-scanner/README.md)** - Malware scanner CLI
- **[rust/storage-manager/README.md](rust/storage-manager/README.md)** - Storage management tools

### Complete Index

**[docs/README.md](docs/README.md)** - Full documentation index with quick reference

Historical phase documentation and implementation notes are archived in [docs/archive/](docs/archive/).

## Repository Structure

```
nix-config/
├── flake.nix               # Entry point - defines hosts and dev shell
├── flake.lock              # Locked dependencies
├── justfile                # Task automation (just --list)
│
├── docs/                   # Documentation
│   ├── INSTALLATION.md     # 6-stage installation guide
│   ├── ARCHITECTURE.md     # System architecture
│   ├── SECRETS.md          # Per-device secrets setup
│   ├── VPN.md              # Mullvad VPN configuration
│   ├── STORAGE.md          # Backup and storage systems
│   ├── MALWARE-SCANNER.md  # Malware protection
│   └── archive/            # Historical phase documentation
│
├── hosts/                  # Per-device configurations
│   ├── laptop-intel/       # Intel i5-10210U, 32GB, Intel UHD
│   │   ├── configuration.nix           # Stage 6 (full)
│   │   ├── configuration-minimal.nix   # Stage 1 (minimal)
│   │   └── hardware-configuration.nix  # Generated by NixOS
│   ├── framework/          # AMD Ryzen, 64GB (future)
│   └── devtower/           # AMD desktop, 64GB (future)
│
├── modules/                # Reusable modules
│   ├── core/               # Base configuration (nix settings, SSH)
│   ├── hardware/           # Intel/AMD, laptop/desktop
│   ├── desktop/hyprland/   # Hyprland Wayland compositor
│   ├── network/            # VPN, firewall, routing
│   ├── security/           # Malware scanner
│   ├── storage/            # Restic, ZFS, RAID
│   ├── software/           # Creative suite (DaVinci, etc.)
│   └── users/              # Per-device user accounts
│
├── home/                   # Home Manager (user environment)
│   ├── common.nix          # Shared dotfiles and packages
│   └── laptop.nix          # Device-specific additions
│
├── config/                 # Dotfiles
│   ├── git/                # Multi-account Git configs
│   ├── hypr/               # Modular Hyprland configs
│   ├── zed/, kitty/, etc.  # Application configs
│
├── secrets/                # Agenix encrypted secrets
│   ├── secrets.nix         # Secret definitions and keys
│   └── *.age               # Encrypted files (safe to commit)
│
└── rust/                   # Rust CLI tools
    ├── secrets-verify/     # Verify secrets deployed
    ├── agenix-helper/      # Manage agenix secrets
    ├── wireguard-helper/   # VPN management
    ├── malware-scanner/    # Malware detection
    └── storage-manager/    # Storage CLI tools
```

**Design Principles:**
- **Modular** - Shared base + device-specific overrides
- **Composable** - Each host imports only needed modules
- **Staged** - 6 progressive installation targets
- **Secure** - Per-device secrets with zero-trust model

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed explanation.

## Common Commands

All commands available via `just`. Run `just --list` to see all commands.

### System Management
```bash
# Daily use
sudo nixos-rebuild switch --flake .#laptop-intel   # Apply changes
nix flake update                                    # Update inputs
sudo nix-collect-garbage -d                         # Clean old generations

# With just automation
just rebuild                  # Rebuild current system
just update                   # Update flake inputs
just check                    # Test configuration syntax
```

### Secrets Management
```bash
agenix-helper edit <secret>   # Edit encrypted secret
agenix-helper list            # List all secrets
agenix-helper rekey           # Rekey after adding hosts
secrets-verify                # Verify secrets deployed
```

### VPN Management
```bash
just vpn-up                   # Start VPN
just vpn-status               # Show VPN status
just vpn-verify               # Verify connection
just vpn-rotate laptop-intel  # Generate new 5-hop config
just vpn-app firefox          # Launch app through VPN
```

### Storage Management
```bash
restic-manage add-backup home --paths /home --repository local  # Add backup
restic-backup-now home        # Run backup immediately
restic-repo local snapshots   # List backups
zfs-manage pool-status        # ZFS status (if enabled)
```

### Security
```bash
malware-scanner scan ~/Downloads --quarantine  # Scan directory
malware-scanner status                          # Show scanner status
malware-scanner test                            # Test detection
```

### Development
```bash
nix develop                   # Enter dev shell with Rust tools
just build-rust               # Build Rust tools
just test-rust                # Test Rust tools
just lint                     # Run all linters
```

See [docs/README.md](docs/README.md) for complete command reference.

## Features in Detail

### Per-Device Secrets (Agenix)
Each device has **unique** SSH keys for GitHub and servers:
- Device compromise only exposes that device's keys
- Independent key rotation per device
- Full audit trail of which device accessed what
- Two-tier security: GitHub (no passphrase), servers (with passphrase)

### Multi-Hop VPN (Mullvad WireGuard)
5-hop chain provides strong anonymity:
- Entry → Relay1 → Relay2 → Relay3 → Exit
- VPN provider can't correlate your origin and destination
- Kill switch blocks traffic if VPN drops
- Split tunneling keeps LAN functional
- Per-app routing via cgroups

### Malware Protection
Multi-engine threat detection:
- ClamAV signatures (8+ million)
- YARA pattern matching
- Behavioral heuristics
- Hash-based detection
- Real-time monitoring

### Storage Management
Runtime-configurable without editing Nix:
- **Restic** - Encrypted backups to local/cloud
- **ZFS** - Advanced filesystem with snapshots
- **RAID** - Linux software RAID with monitoring
- Configure via CLI and JSON files

### Development Stack
Comprehensive language support:
- **Python** - Ruff, Pyright, python-lsp-server, Django stubs
- **TypeScript/JavaScript** - Prettier, ESLint, tsc
- **Rust** - rustfmt, Clippy, rust-analyzer
- **PHP** - php-cs-fixer, Intelephense
- **Markdown, GraphQL, Tailwind CSS** - Language servers included

### Multi-Account Git
Directory-based account switching:

| Directory | Account | SSH Host |
|-----------|---------|----------|
| `~/Repos/personal/` | SamBailey6194 | github-personal |
| `~/Repos/syntek/` | syntek-studio | github-syntek |
| `~/Repos/missional-gen/` | sam-missionalgen | github-missionalgen |

Verify with: `git config user.email` in each directory.

## Troubleshooting

### Installation Issues
See [docs/INSTALLATION.md](docs/INSTALLATION.md) troubleshooting section for:
- tmpfs space issues during installation
- Hardware detection problems
- Boot loader configuration

### Secrets Not Working
See [docs/SECRETS.md](docs/SECRETS.md) troubleshooting section for:
- Permission denied errors
- SSH key deployment issues
- Agenix decryption problems

### VPN Connection Problems
See [docs/VPN.md](docs/VPN.md) troubleshooting section for:
- Connection failures
- Kill switch issues
- Split tunneling problems

### Backup Failures
See [docs/STORAGE.md](docs/STORAGE.md) troubleshooting section for:
- Repository initialization
- Permission issues
- Systemd timer problems

## Support and Resources

- **Project Repository** - https://github.com/SamBailey6194/nix-config
- **Documentation Hub** - [docs/README.md](docs/README.md)
- **NixOS Manual** - https://nixos.org/manual/nixos/stable/
- **Home Manager** - https://nix-community.github.io/home-manager/
- **Hyprland Wiki** - https://wiki.hyprland.org/
- **Mullvad Support** - https://mullvad.net/support

## License

Personal configuration provided as-is. Use at your own risk.

---

**Last Updated**: 2026-01-27
**Maintained By**: Sam Bailey
**Current Status**: Single-device deployment ready (laptop-intel)
