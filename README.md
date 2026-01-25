# NixOS Configuration

Personal NixOS configuration with Hyprland, dotfiles, and Rust security tooling for multi-device deployment.

**Current Focus:** Single device (laptop-intel) with full secrets management, VPN, malware protection, and storage systems.

## Quick Links

- **Getting Started:** [Installation Guide](INSTALL.md) | [Quick Start](QUICK-START.md)
- **Architecture:** [System Architecture](ARCHITECTURE.md)
- **Secrets:** [Secrets Setup](PHASE-2-SECRETS-SETUP.md) | [Per-Device Model](secrets/PER-DEVICE-SECRETS.md)
- **VPN:** [VPN Quick Start](QUICK-START-VPN.md) | [Full VPN Guide](PHASE-6-WIREGUARD-MULLVAD.md)
- **Storage:** [Storage Quick Start](STORAGE-QUICKSTART.md) | [Storage Guide](docs/STORAGE-MANAGEMENT.md)
- **Security:** [Malware Scanner Quick Start](MALWARE-SCANNER-QUICKSTART.md) | [Full Scanner Guide](MALWARE-SCANNER.md)

## Current Status

### Implemented (Laptop-Intel Ready)

| Feature | Status | Documentation |
|---------|--------|---------------|
| **Base System** | ✅ Complete | [Phase 1](PHASE-1-COMPLETE.md) |
| **Secrets Management** | ✅ Complete | [Phase 2 Setup](PHASE-2-SECRETS-SETUP.md), [Implementation](PHASE-2-IMPLEMENTATION-SUMMARY.md) |
| **Hyprland Desktop** | ✅ Complete | [Phase 4](PHASE-4-COMPLETE.md), [Hyprland Configs](HYPRLAND-CONFIGS-SUMMARY.md) |
| **Wireguard VPN** | ✅ Complete | [Phase 6](PHASE-6-WIREGUARD-MULLVAD.md), [Quick Start](QUICK-START-VPN.md) |
| **Malware Scanner** | ✅ Complete | [Phase 7](PHASE-7-MALWARE-SCANNER-SUMMARY.md), [Quick Start](MALWARE-SCANNER-QUICKSTART.md) |
| **Storage Management** | ✅ Complete | [Phase 8](PHASE-8-STORAGE-SUMMARY.md), [Quick Start](STORAGE-QUICKSTART.md) |
| **Rust Tooling** | ✅ Complete | [Rust Tools Overview](rust/README.md) |

All features ready for testing after NixOS installation on laptop-intel.

### Current Device

| Host | User | Hardware | Status |
|------|------|----------|--------|
| laptop-intel | sam-laptop | Intel i5-10210U, 32GB RAM, Intel UHD Graphics | ✅ Ready for install |

### Future Devices (Not Yet Configured)

- **framework** - AMD Ryzen, 64GB RAM, AMD Radeon (Phase 3)
- **devtower** - AMD desktop, 64GB RAM, AMD Radeon + Go XLR (Phase 3)

## Features

### Security
- **Per-device secrets** with agenix encryption
- **Zero-trust model** - Each device has unique SSH keys for GitHub
- **Malware scanner** with real-time protection and ClamAV integration
- **VPN kill switch** - Blocks traffic if VPN drops
- **Multi-hop routing** - 5+ hop chains through Mullvad

### Networking
- **Mullvad VPN** with automatic rotation and split tunneling
- **Per-app VPN routing** via cgroups
- **LAN bypass** for local network access
- **Production server bypass** for audit trail

### Storage
- **Restic backups** - Runtime-configurable encrypted backups
- **ZFS support** - Advanced filesystem with snapshots
- **RAID management** - Linux software RAID with monitoring
- **No Nix editing** - Configure via CLI and JSON files

### Desktop
- **Hyprland** Wayland compositor with modular configs
- **Per-device customization** - Base config + device-specific overlays
- **Multi-account Git** - Directory-based account switching
- **Development tools** - Python, TypeScript, Rust, PHP, GraphQL

### Development
- **Rust workspace** with 6 CLI tools
- **Just commands** for automation
- **Fuzzing infrastructure** for security testing
- **Linting and formatting** for all languages

## Quick Start

### Prerequisites

1. Download NixOS ISO from [nixos.org](https://nixos.org/download.html)
2. Create bootable USB: `dd if=nixos.iso of=/dev/sdX bs=4M status=progress`
3. Boot from USB

### Installation (10 Steps)

See [INSTALL.md](INSTALL.md) for detailed step-by-step instructions.

**TL;DR:**
1. Partition disk (EFI + root + swap)
2. Format and mount filesystems
3. Generate hardware config
4. Clone this repo
5. Install with flake: `nixos-install --flake .#laptop-intel`
6. Set root password and reboot
7. Log in and rebuild: `sudo nixos-rebuild switch --flake .#laptop-intel`

### Post-Installation

After NixOS is running:

1. **Setup secrets:** Follow [PHASE-2-SECRETS-SETUP.md](PHASE-2-SECRETS-SETUP.md)
2. **Setup VPN:** Follow [QUICK-START-VPN.md](QUICK-START-VPN.md)
3. **Setup storage:** Follow [STORAGE-QUICKSTART.md](STORAGE-QUICKSTART.md)
4. **Verify installation:** [QUICK-START.md](QUICK-START.md)

## Documentation Index

### Getting Started
- [INSTALL.md](INSTALL.md) - Full installation guide
- [QUICK-START.md](QUICK-START.md) - Post-install verification
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview

### Secrets Management
- [PHASE-2-SECRETS-SETUP.md](PHASE-2-SECRETS-SETUP.md) - Step-by-step secrets setup
- [secrets/PER-DEVICE-SECRETS.md](secrets/PER-DEVICE-SECRETS.md) - Zero-trust secrets model
- [secrets/README.md](secrets/README.md) - Quick reference
- [PHASE-2-IMPLEMENTATION-SUMMARY.md](PHASE-2-IMPLEMENTATION-SUMMARY.md) - What was implemented

### VPN
- [QUICK-START-VPN.md](QUICK-START-VPN.md) - 5-minute VPN setup
- [PHASE-6-WIREGUARD-MULLVAD.md](PHASE-6-WIREGUARD-MULLVAD.md) - Complete VPN guide
- [rust/wireguard-helper/README.md](rust/wireguard-helper/README.md) - VPN CLI tool

### Storage
- [STORAGE-QUICKSTART.md](STORAGE-QUICKSTART.md) - Quick start guide
- [docs/STORAGE-MANAGEMENT.md](docs/STORAGE-MANAGEMENT.md) - Complete storage guide

### Security
- [MALWARE-SCANNER-QUICKSTART.md](MALWARE-SCANNER-QUICKSTART.md) - Quick start guide
- [MALWARE-SCANNER.md](MALWARE-SCANNER.md) - Complete malware scanner guide
- [PHASE-7-MALWARE-SCANNER-SUMMARY.md](PHASE-7-MALWARE-SCANNER-SUMMARY.md) - Implementation summary

### Desktop Environment
- [HYPRLAND-CONFIGS-SUMMARY.md](HYPRLAND-CONFIGS-SUMMARY.md) - Hyprland configuration
- [PHASE-4-COMPLETE.md](PHASE-4-COMPLETE.md) - Home Manager integration
- [NEOVIM-SETUP.md](NEOVIM-SETUP.md) - Neovim configuration

### Development
- [rust/README.md](rust/README.md) - Rust tooling overview
- [rust/secrets-verify/README.md](rust/secrets-verify/README.md) - Secrets verification tool
- [rust/agenix-helper/README.md](rust/agenix-helper/README.md) - Agenix helper CLI
- [rust/wireguard-helper/README.md](rust/wireguard-helper/README.md) - Wireguard CLI
- [rust/malware-scanner/README.md](rust/malware-scanner/README.md) - Malware scanner
- [rust/fuzz/README.md](rust/fuzz/README.md) - Fuzzing infrastructure
- [rust/fuzz/FUZZING-GUIDE.md](rust/fuzz/FUZZING-GUIDE.md) - Fuzzing guide

### Additional Topics
- [DAVINCI-RESOLVE-AMD.md](DAVINCI-RESOLVE-AMD.md) - DaVinci Resolve setup for AMD GPUs
- [FUZZING-INFRASTRUCTURE-SUMMARY.md](FUZZING-INFRASTRUCTURE-SUMMARY.md) - Fuzzing infrastructure
- [modules/software/README.md](modules/software/README.md) - Software modules

### Phase Summaries
- [PHASE-1-COMPLETE.md](PHASE-1-COMPLETE.md) - Base system
- [PHASE-2-IMPLEMENTATION-SUMMARY.md](PHASE-2-IMPLEMENTATION-SUMMARY.md) - Secrets
- [PHASE-4-COMPLETE.md](PHASE-4-COMPLETE.md) - Home Manager
- [PHASE-6-WIREGUARD-MULLVAD.md](PHASE-6-WIREGUARD-MULLVAD.md) - VPN
- [PHASE-7-MALWARE-SCANNER-SUMMARY.md](PHASE-7-MALWARE-SCANNER-SUMMARY.md) - Security
- [PHASE-8-STORAGE-SUMMARY.md](PHASE-8-STORAGE-SUMMARY.md) - Storage
- [IMPLEMENTATION-COMPLETE.md](IMPLEMENTATION-COMPLETE.md) - Overall summary

## Architecture

This configuration uses a **modular design** with shared base configuration and device-specific additions.

```
nix-config/
├── flake.nix               # Entry point - defines hosts and dev shell
├── justfile                # Task automation commands
│
├── hosts/                  # Per-device configs (minimal imports)
│   └── laptop-intel/       # Intel i5-10210U, 32GB, Intel UHD
│
├── modules/                # Reusable modules
│   ├── core/               # Shared base configuration
│   ├── hardware/           # Hardware-specific (Intel/AMD, laptop/desktop)
│   ├── desktop/hyprland/   # Hyprland compositor
│   ├── network/            # VPN, firewall, routing
│   ├── security/           # Malware scanner
│   ├── storage/            # Restic, ZFS, RAID
│   ├── software/           # Software suites (creative, etc.)
│   └── users/              # Device-specific user accounts
│
├── home/                   # Home Manager (user environment)
│   ├── common.nix          # Shared dotfiles and packages
│   └── laptop.nix          # Device-specific additions
│
├── config/                 # Dotfiles
│   ├── git/                # Multi-account Git configs
│   ├── hypr/               # Modular Hyprland configs
│   ├── zed/                # Zed editor
│   └── ...                 # Other dotfiles
│
├── secrets/                # Agenix encrypted secrets
│   ├── secrets.nix         # Secret definitions
│   └── *.age               # Encrypted files (safe to commit)
│
└── rust/                   # Rust CLI tools
    ├── secrets-verify/     # Verify secrets deployed
    ├── agenix-helper/      # Manage agenix secrets
    ├── wireguard-helper/   # VPN management
    ├── malware-scanner/    # Malware detection
    └── storage-manager/    # Storage CLI tools
```

**Key Principles:**
- **DRY** - Shared config defined once in base modules
- **Composability** - Each host imports only needed modules
- **Separation** - Hardware, software, users kept separate
- **Per-device isolation** - Each device has unique secrets and user

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed explanation.

## Commands

All commands available via `just`. Run `just --list` to see all commands.

### System Management
```bash
just rebuild                  # Rebuild current system
just rebuild-host <host>      # Rebuild specific host
just check                    # Test configuration syntax
just update                   # Update flake inputs
just diff                     # Show configuration changes
```

### Secrets Management
```bash
just verify-secrets           # Verify all secrets deployed
just edit-secret <name>       # Edit an encrypted secret
just list-secrets             # List all secrets
just rekey-secrets            # Rekey after adding hosts
```

### VPN Management
```bash
just vpn-up                   # Start VPN
just vpn-down                 # Stop VPN
just vpn-status               # Show VPN status
just vpn-verify               # Verify VPN connection
just vpn-set-exit uk          # Switch exit location (uk/us/eu)
just vpn-rotate laptop-intel  # Generate new 5-hop config
just vpn-app firefox          # Launch app through VPN
```

### Storage Management
```bash
just backup-now <name>        # Run backup immediately
just restic-snapshots <repo>  # List snapshots
just zfs-status               # ZFS pool status
just raid-status              # RAID array status
```

### Security
```bash
just malware-scan <path>      # Scan for malware
just malware-status           # Show scanner status
```

### Development
```bash
just dev                      # Enter nix dev shell with Rust tools
just build-rust               # Build Rust tools
just test-rust                # Test Rust tools
just lint                     # Run all linters
just format                   # Format all code
```

## Rust Tools

All Rust tools are automatically available in `nix develop`:

```bash
secrets-verify                # Verify secrets deployed correctly
agenix-helper edit <secret>   # Edit encrypted secret
wireguard-helper rotate       # Rotate VPN servers
malware-scanner scan <path>   # Scan for malware
restic-manage add-repo        # Add backup repository
zfs-manage create-pool        # Create ZFS pool
raid-manage create            # Create RAID array
```

See [rust/README.md](rust/README.md) for complete documentation.

## Multi-Account Git

Directory-based conditional includes automatically switch GitHub accounts:

| Directory | Account | SSH Host |
|-----------|---------|----------|
| `~/Repos/personal/` | SamBailey6194 | github-personal |
| `~/Repos/syntek/` | syntek-studio | github-syntek |
| `~/Repos/missional-gen/` | sam-missionalgen | github-missionalgen |

Verify with: `git config user.email` in each directory.

## Development Stack Support

- **Python:** Ruff, Pyright, python-lsp-server, Django stubs
- **TypeScript/JavaScript:** Prettier, ESLint, tsc
- **Rust:** rustfmt, Clippy, rust-analyzer
- **PHP:** php-cs-fixer, Intelephense
- **Markdown:** Prettier, markdownlint, markdown-toc
- **GraphQL, Tailwind CSS:** Language servers included

## Completed Phases

### Phase 1: Base System ✅
- NixOS with Hyprland running on laptop-intel
- Flake-based configuration
- Core modules (common.nix, nix-settings.nix)
- Base Hyprland desktop module

**Documentation:** [PHASE-1-COMPLETE.md](PHASE-1-COMPLETE.md)

### Phase 2: Secrets Management ✅
- Per-device secrets with agenix
- Zero-trust model (unique keys per device)
- Rust tooling (secrets-verify, agenix-helper)
- Auto-generated SSH config per device
- Two-tier security (GitHub vs Servers)

**Documentation:** [PHASE-2-SECRETS-SETUP.md](PHASE-2-SECRETS-SETUP.md), [PHASE-2-IMPLEMENTATION-SUMMARY.md](PHASE-2-IMPLEMENTATION-SUMMARY.md)

### Phase 4: Home Manager ✅
- User environment management
- Dotfiles integration
- Git, Zsh, Starship, Kitty, Zed
- Modular Hyprland configs (base + device-specific)

**Documentation:** [PHASE-4-COMPLETE.md](PHASE-4-COMPLETE.md), [HYPRLAND-CONFIGS-SUMMARY.md](HYPRLAND-CONFIGS-SUMMARY.md)

### Phase 6: Wireguard VPN (Partial) ✅
- Mullvad VPN with multi-hop routing (5+ hops)
- Split tunneling (LAN bypass)
- Kill switch (prevent IP leaks)
- Automatic rotation (weekly)
- Per-app VPN routing via cgroups
- Rust CLI tool (wireguard-helper)

**Documentation:** [PHASE-6-WIREGUARD-MULLVAD.md](PHASE-6-WIREGUARD-MULLVAD.md), [QUICK-START-VPN.md](QUICK-START-VPN.md)

**Note:** Full Wireguard mesh network between devices pending Phase 3 (multi-device).

### Phase 7: Malware Scanner ✅
- Real-time malware protection
- ClamAV integration with custom signatures
- Quarantine system
- Automatic updates
- Rust CLI tool

**Documentation:** [MALWARE-SCANNER.md](MALWARE-SCANNER.md), [MALWARE-SCANNER-QUICKSTART.md](MALWARE-SCANNER-QUICKSTART.md)

### Phase 8: Storage Management ✅
- Runtime-configurable Restic backups
- ZFS pool and dataset management
- RAID management with monitoring
- No Nix editing after initial setup
- Rust CLI tools

**Documentation:** [STORAGE-QUICKSTART.md](STORAGE-QUICKSTART.md), [docs/STORAGE-MANAGEMENT.md](docs/STORAGE-MANAGEMENT.md)

### Phase 10: Rust Tooling (Partial) ✅
- secrets-verify - Secrets verification
- agenix-helper - Agenix management
- wireguard-helper - VPN management
- malware-scanner - Malware detection
- storage-manager - Storage tools (restic-manage, zfs-manage, raid-manage)
- Fuzzing infrastructure

**Documentation:** [rust/README.md](rust/README.md)

**Note:** Full secrets wrapper with OpenBao integration pending Phase 9.

## Future Phases (Not Yet Implemented)

### Phase 3: Multi-Device
- Add framework (AMD laptop) configuration
- Add devtower (AMD desktop) configuration
- Device-specific modules (hardware, software)
- Shared secrets between devices
- Test multi-device deployment

### Phase 5: Local VM Testing
- VM configurations for testing
- QEMU virtualization
- Test workflow before hardware deployment

### Phase 6: Wireguard Network (Complete)
- Full Wireguard mesh between all devices
- Hub topology (one device as central hub)
- Peer-to-peer connectivity

### Phase 7: Server Modules
- nginx module
- Cloudflare Tunnel (cloudflared)
- gunicorn + uvicorn
- Test server stack locally

### Phase 8: Hetzner Staging
- Cloud server deployment
- Production-ready server config
- Cloudflare integration
- Full stack testing

### Phase 9: OpenBao Setup
- OpenBao deployment on Hetzner
- Migrate from agenix to OpenBao for runtime secrets
- Keep agenix for bootstrap token only
- Rust wrapper integration

### Phase 10: Rust Wrapper (Complete)
- Full secrets management via Rust
- Django-compatible encryption
- TOTP and IP-based encryption
- API clients (Cloudflare, GitHub)
- Rotation scheduler
- Unix socket server

### Phase 11: Production Workflow
- CI/CD pipeline with GitHub Actions
- Branch strategy (feature → dev → staging → main)
- Automatic staging deploys
- Manual production approval

### Phase 12: Additional Infrastructure (Partial)
- NAS configuration
- Router configuration (NixOS on router)
- Raspberry Pi configuration
- Full Tailscale or Wireguard mesh
- Vaultwarden password management

## Support

- **Issues:** File issues in this repository
- **Documentation:** See links above for detailed guides
- **Commands:** Run `just --list` for all available commands

## License

Personal configuration - use at your own risk.
