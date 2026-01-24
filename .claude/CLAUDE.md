# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Personal NixOS configuration with Hyprland, dotfiles, and Rust security wrapper for multi-device deployment. This repository manages:
- NixOS system configurations (declarative OS setup)
- Hyprland Wayland compositor configuration
- Development environment dotfiles (Zed, git, zsh, etc.)
- Future: Rust-based secrets management wrapper (OpenBao integration)

## Current Phase: Phase 1 - Foundation

**Status**: NixOS configuration initialized, ready for installation on laptop-intel

**Phase 1 Goals**:
- ✅ Set up flake.nix with basic inputs (nixpkgs, home-manager, agenix, hyprland)
- ✅ Create core modules (common.nix, users.nix, nix-settings.nix)
- ✅ Create base Hyprland desktop module
- ✅ Create laptop-intel host configuration
- 🔲 Boot NixOS installer, partition, install
- 🔲 Clone repo and rebuild with configuration
- 🔲 Get Hyprland working with basic keybinds

**Next Phase**: Phase 2 - Secrets with agenix (after successful NixOS installation)

## Architecture

**Modular Design**: Shared base configuration + device-specific additions

```
nix-config/
├── flake.nix               # Flake inputs: nixpkgs, home-manager, affinity-nix
├── flake.lock              # Locked dependencies
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
│   │   └── nix-settings.nix        # Nix daemon settings
│   │
│   ├── hardware/           # Hardware-specific modules
│   │   ├── intel-laptop.nix   # Intel CPU + integrated GPU
│   │   ├── amd-laptop.nix     # AMD CPU + dedicated GPU
│   │   ├── amd-desktop.nix    # AMD desktop (full performance)
│   │   └── go-xlr.nix         # Go XLR audio interface (devtower only)
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
├── linters/                # Shared linter configs
└── justfile                # Task runner
```

See `ARCHITECTURE.md` for detailed explanation of the modular design.

## Commands

```bash
just lint       # Run all linters
just format     # Run all formatters
just audit      # Full security audit
just watch-md   # Watch markdown files
just watch-py   # Watch Python files
just watch-ts   # Watch TypeScript files
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

### Phase 1: Install NixOS on laptop-intel

1. **Download NixOS ISO**: Get minimal ISO from nixos.org
2. **Create bootable USB**: `dd if=nixos.iso of=/dev/sdX bs=4M status=progress`
3. **Boot from USB**: Boot laptop from USB, select "NixOS Installer"
4. **Partition disk** (example for 1TB disk):
   ```bash
   # Create GPT partition table
   parted /dev/nvme0n1 -- mklabel gpt

   # EFI boot partition (1GB)
   parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
   parted /dev/nvme0n1 -- set 1 esp on

   # Root partition (remaining space - 8GB for swap)
   parted /dev/nvme0n1 -- mkpart primary 1GiB -8GiB

   # Swap partition (8GB)
   parted /dev/nvme0n1 -- mkpart primary linux-swap -8GiB 100%
   ```

5. **Format partitions**:
   ```bash
   mkfs.fat -F 32 -n boot /dev/nvme0n1p1
   mkfs.ext4 -L nixos /dev/nvme0n1p2
   mkswap -L swap /dev/nvme0n1p3
   ```

6. **Mount filesystems**:
   ```bash
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount /dev/disk/by-label/boot /mnt/boot
   swapon /dev/nvme0n1p3
   ```

7. **Generate hardware config**:
   ```bash
   nixos-generate-config --root /mnt
   ```

8. **Clone this repo**:
   ```bash
   nix-shell -p git
   git clone https://github.com/SamBailey6194/nix-config /mnt/etc/nixos/nix-config
   ```

9. **Copy generated hardware config**:
   ```bash
   cp /mnt/etc/nixos/hardware-configuration.nix \
      /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix
   ```

10. **Install NixOS**:
    ```bash
    nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel
    ```

11. **Set root password when prompted**, then **reboot**

12. **After reboot, rebuild from flake**:
    ```bash
    sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel
    ```

### Legacy Dotfiles Installation (Pre-NixOS)

If still on Ubuntu and want to use Zed/git configs:
```bash
cd ~/Repos/personal/nix-config
chmod +x install.sh && ./install.sh
```

## Post-Installation

After NixOS is running:
- Test Hyprland: Log out, select "Hyprland" session, log in
- Test keybinds: `Super+Return` (kitty), `Super+D` (wofi), `Super+Q` (close window)
- Verify network: `nmtui` or NetworkManager applet in systray
- Check system: `nixos-rebuild switch --flake ~/.config/nix-config#laptop-intel`
