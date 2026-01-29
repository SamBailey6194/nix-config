# CLAUDE.md

**Last Updated**: 29/01/2026
**Version**: 0.8.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Personal NixOS configuration with Hyprland, dotfiles, and Rust tooling for multi-device deployment. This repository manages:
- NixOS system configurations (declarative OS setup)
- Hyprland Wayland compositor configuration
- Development environment dotfiles (Zed, git, zsh, etc.)
- Per-device secrets management with agenix (Phase 2 ✅)
- Rust CLI tools for secrets verification and management (Phase 2 ✅)
- Wireguard VPN with Mullvad integration (Phase 6 ✅)
- Malware scanner with real-time protection (Phase 7 ✅)
- Runtime-configurable storage management (Phase 8 ✅)
- Future: Rust-based security wrapper with OpenBao integration (Phase 10)

## Current Phase: Phase 2 - Secrets Management ✅ COMPLETE

**Status**: Per-device secrets with Rust tooling implemented, ready for NixOS installation

**Phase 1 Goals** ✅:
- ✅ Set up flake.nix with basic inputs (nixpkgs, home-manager, agenix, hyprland)
- ✅ Create core modules (common.nix, users.nix, nix-settings.nix)
- ✅ Create base Hyprland desktop module
- ✅ Create laptop-intel host configuration
- 🔲 Boot NixOS installer, partition, install
- 🔲 Clone repo and rebuild with configuration
- 🔲 Get Hyprland working with basic keybinds

**Phase 2 Goals** ✅:
- ✅ Enhanced secrets.nix for per-device granularity (zero-trust model)
- ✅ Created Rust workspace (secrets-verify, agenix-helper)
- ✅ Auto-generated SSH config per device (modules/core/ssh-config.nix)
- ✅ Comprehensive documentation (PER-DEVICE-SECRETS.md)
- ✅ Task automation (justfile)
- ✅ Two-tier security (GitHub: no passphrase, Servers: with passphrase)

**Next Steps**: Complete Phase 1 (NixOS installation) → Phase 3 (Multi-device sync)

## Architecture

**Modular Design**: Shared base configuration + device-specific additions

```
nix-config/
├── flake.nix               # Flake inputs + Rust tooling dev shell
├── flake.lock              # Locked dependencies
├── justfile                # Task automation (secrets, rebuild, lint, etc.)
│
├── hosts/                  # Per-device configs (minimal - just imports modules)
│   ├── laptop-intel/       # Intel i5-10210U, 32GB, Intel UHD Graphics
│   ├── framework/          # AMD Ryzen + Radeon, 64GB (future)
│   └── devtower/           # AMD CPU + GPU, 64GB, Go XLR (future)
│
├── modules/                # Reusable modules (composable)
│   ├── core/
│   │   ├── base-configuration.nix  # Shared settings for ALL devices
│   │   ├── common.nix              # Base packages
│   │   ├── nix-settings.nix        # Nix daemon settings
│   │   ├── ssh-config.nix          # Auto-generated SSH config (per-device keys)
│   │   ├── secrets-laptop.nix      # Laptop secrets declarations
│   │   └── secrets-desktop.nix     # Desktop secrets declarations
│   │
│   ├── hardware/           # Hardware-specific modules
│   │   ├── intel-laptop.nix   # Intel CPU + integrated GPU
│   │   ├── amd-laptop.nix     # AMD CPU + dedicated GPU
│   │   ├── amd-desktop.nix    # AMD desktop (full performance)
│   │   └── go-xlr.nix         # Go XLR audio interface (devtower only)
│   │
│   ├── network/            # Network and VPN modules
│   │   ├── wireguard-mullvad.nix   # Mullvad VPN integration
│   │   ├── wireguard-firewall.nix  # VPN firewall rules
│   │   └── wireguard-routes.nix    # Split tunneling
│   │
│   ├── security/           # Security modules
│   │   └── malware-scanner.nix     # Real-time malware protection
│   │
│   ├── storage/            # Storage management (Phase 8)
│   │   ├── restic.nix         # Runtime-configurable backups
│   │   ├── zfs.nix            # ZFS management framework
│   │   └── raid.nix           # RAID management framework
│   │
│   ├── software/           # Software suites
│   │   └── creative.nix       # DaVinci Resolve Studio
│   │
│   ├── desktop/
│   │   └── hyprland/          # Hyprland Wayland compositor
│   │
│   └── users/              # Device-specific user accounts
│       ├── laptop.nix         # sam-laptop
│       ├── framework.nix      # sam-framework
│       └── devtower.nix       # sam-desktop
│
├── secrets/                # Agenix encrypted secrets (Phase 2)
│   ├── secrets.nix            # Defines which keys decrypt which secrets
│   ├── PER-DEVICE-SECRETS.md  # Per-device secrets architecture guide
│   └── *.age                  # Encrypted secrets (safe to commit)
│
├── rust/                   # Rust tooling workspace
│   ├── Cargo.toml             # Workspace root
│   ├── README.md              # Rust tooling guide
│   ├── secrets-verify/        # Verify secrets deployed correctly
│   ├── agenix-helper/         # Helper CLI for managing secrets
│   ├── wireguard-helper/      # Mullvad VPN management (Phase 6)
│   ├── malware-scanner/       # Malware scanning engine (Phase 7)
│   └── storage-manager/       # Storage CLI tools (Phase 8)
│       ├── restic-manage      # Restic backup configuration
│       ├── zfs-manage         # ZFS management helper
│       └── raid-manage        # RAID management helper
│
├── home/                   # Home Manager (user environment)
│   ├── common.nix             # Shared dotfiles, packages, programs
│   ├── laptop.nix             # Device-specific additions
│   ├── framework.nix
│   └── devtower.nix
│
├── config/                 # Dotfiles (Phase 4: integrated with home-manager)
│   ├── git/, zed/
│   └── hypr/                  # Modular Hyprland configs (base + per-device)
│
└── linters/                # Shared linter configs
```

See `ARCHITECTURE.md` for detailed explanation of the modular design.

## Commands

### Secrets Management (Phase 2)
```bash
just verify-secrets           # Verify all secrets deployed correctly
just edit-secret <name>       # Edit an encrypted secret
just list-secrets             # List all secrets and authorized keys
just rekey-secrets            # Rekey all secrets (after adding hosts)
just add-server <name>        # Generate per-device SSH keys for server
```

### NixOS System Management
```bash
just rebuild                  # Rebuild current system
just rebuild-host <host>      # Rebuild specific host
just check                    # Test configuration syntax
just update                   # Update flake inputs
just diff                     # Show configuration changes
```

### Development
```bash
just dev                      # Enter nix dev shell with Rust tools
just build-rust               # Build Rust tools
just test-rust                # Test Rust tools
just lint                     # Run all linters
just format                   # Format all code
```

### Rust Tools (Auto-available in `nix develop`)
```bash
secrets-verify                # Verify secrets deployed correctly
secrets-verify --test-github  # Test GitHub SSH connections

agenix-helper edit <secret>   # Edit encrypted secret
agenix-helper list            # List all secrets
agenix-helper rekey           # Rekey all secrets
agenix-helper add-server <name>  # Generate per-device server keys
agenix-helper check-keys      # Verify host keys

wireguard-helper init         # Initialize VPN configuration
wireguard-helper rotate       # Rotate VPN servers
wireguard-helper status       # Show VPN status

malware-scanner scan <path>   # Scan for malware
malware-scanner quarantine list  # List quarantined files

restic-manage add-repo        # Add backup repository
restic-manage add-backup      # Configure backup job
zfs-manage create-pool        # Create ZFS pool
raid-manage create            # Create RAID array
```

## Multi-Account Git

Directory-based conditional includes auto-switch GitHub accounts:

| Directory | Account | SSH Host |
|-----------|---------|----------|
| `~/Repos/personal/` | SamBailey6194 | github-personal |
| `~/Repos/syntek/` | syntek-studio | github-syntek |
| `~/Repos/missional-gen/` | sam-missionalgen | github-missionalgen |

Verify with: `git config user.email` in each directory.

## Stack Support

- **Python**: Ruff, Pyright, python-lsp-server, Django stubs
- **TypeScript/JavaScript**: Prettier, ESLint, tsc
- **Rust**: rustfmt, Clippy, rust-analyzer (configs stay per-project)
- **Markdown**: Prettier, markdownlint-cli2, markdown-toc
- **PHP**: php-cs-fixer, Intelephense
- **GraphQL, Tailwind CSS**: Language servers included

## Current Hosts

| Host | User | Device | CPU | GPU | RAM | Software | Status |
|------|------|--------|-----|-----|-----|----------|--------|
| `laptop-intel` | sam-laptop | Intel laptop | i5-10210U | Intel UHD | 32GB | Affinity Apps | ✅ Ready for install |
| `framework` | sam-framework | Framework AMD | AMD Ryzen | AMD Radeon | 64GB | Affinity + DaVinci | ✅ Configured (future) |
| `devtower` | sam-desktop | AMD desktop | AMD | AMD Radeon | 64GB | Affinity + DaVinci + Go XLR | ✅ Configured (future) |
| `nas` | TBD | NAS server | TBD | TBD | TBD | - | Future - Phase 12 |
| `cloud-staging` | TBD | Hetzner VM | TBD | TBD | TBD | Server stack | Future - Phase 8 |
| `router` | TBD | DIY router | TBD | TBD | TBD | Wireguard, firewall | Future - Phase 12 |

**Note**: Each device has a separate user account with separate password and home directory.

## Installation

### Staged Installation Approach

We use a **6-stage progressive installation** to:
- Avoid tmpfs space issues during installation
- Verify each layer works before adding the next
- Isolate problems to specific software groups
- Get a bootable system quickly to test hardware

**Complete guide**: See `docs/STAGED-INSTALLATION-GUIDE.md`

**Quick reference**:
```bash
# Stage 1: Minimal (installation only)
nixos-install --flake .#laptop-intel-minimal

# After reboot, progressively add features:
sudo nixos-rebuild switch --flake .#laptop-intel-desktop       # Stage 2
sudo nixos-rebuild switch --flake .#laptop-intel-dev           # Stage 3
sudo nixos-rebuild switch --flake .#laptop-intel-productivity  # Stage 4
sudo nixos-rebuild switch --flake .#laptop-intel-creative      # Stage 5

# Stage 6: Switch to full config (for all future updates)
sudo nixos-rebuild switch --flake .#laptop-intel
```

**Disk setup**: See `MINIMAL-INSTALL-GUIDE.md` for partitioning and formatting

### Legacy Dotfiles Installation (Pre-NixOS)

If still on Ubuntu and want to use Zed/git configs:
```bash
cd ~/Repos/personal/nix-config
chmod +x install.sh && ./install.sh
```

## Post-Installation

After NixOS is running:

### Phase 1 Verification
- Test Hyprland: Log out, select "Hyprland" session, log in
- Test keybinds: `Super+Return` (kitty), `Super+D` (wofi), `Super+Q` (close window)
- Verify network: `nmtui` or NetworkManager applet in systray
- Check system: `just rebuild`

### Phase 2 Secrets Setup
1. **Enter dev shell:**
   ```bash
   cd /etc/nixos/nix-config  # or ~/.config/nix-config
   nix develop
   # Rust tools auto-build: secrets-verify, agenix-helper
   ```

2. **Get host SSH key:**
   ```bash
   agenix-helper check-keys
   # Copy the ssh-ed25519 key
   ```

3. **Update secrets/secrets.nix** with actual host key

4. **Generate per-device GitHub keys:**
   ```bash
   # Follow PHASE-2-SECRETS-SETUP.md Step 3
   # Generate keys for THIS specific device (not shared!)
   ```

5. **Encrypt secrets:**
   ```bash
   agenix-helper edit github-ssh-personal-laptop-intel
   # Paste private key, save
   ```

6. **Rebuild and verify:**
   ```bash
   just rebuild
   secrets-verify --test-github
   ```

See `PHASE-2-SECRETS-SETUP.md` for complete guide.

## Key Documentation

- **Installation**: `CLAUDE.md` (this file) - Quick start guide
- **Secrets Setup**: `PHASE-2-SECRETS-SETUP.md` - Step-by-step secrets configuration
- **Per-Device Architecture**: `secrets/PER-DEVICE-SECRETS.md` - Zero-trust secrets model
- **Rust Tools**: `rust/README.md` - Rust tooling overview
- **Phase 2 Summary**: `PHASE-2-IMPLEMENTATION-SUMMARY.md` - What was implemented
- **Task Automation**: `justfile` - All available commands (`just --list`)
