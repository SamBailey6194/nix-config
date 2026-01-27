# NixOS Installation Guide

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

## Table of Contents

- [Quick Start](#quick-start)
- [Why Staged Installation?](#why-staged-installation)
- [Installation Stages](#installation-stages)
- [Pre-Installation](#pre-installation)
- [Stage-by-Stage Workflow](#stage-by-stage-workflow)
- [Device-Specific Targets](#device-specific-targets)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)
- [Quick Reference](#quick-reference)

---

## Quick Start

**TL;DR - Get NixOS running in 30 minutes:**

```bash
# 1. Boot NixOS Minimal ISO
# 2. Partition disk (see Pre-Installation)
# 3. Install with minimal configuration
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel-minimal

# 4. Reboot and rebuild with desktop
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel-desktop

# 5. Log into Hyprland and continue with remaining stages
```

---

## Why Staged Installation?

Installing everything at once can:
- Consume excessive tmpfs space during installation
- Make troubleshooting difficult if something fails
- Download/build hundreds of packages before verifying hardware works
- Create long feedback loops when debugging issues

Staged installation lets you:
- ✅ Verify each layer works before adding the next
- ✅ Isolate problems to specific software groups
- ✅ Avoid tmpfs space issues during installation
- ✅ Get a bootable system quickly to test hardware
- ✅ Build confidence that everything is working

---

## Installation Stages

Each device has 6 configuration stages:

| Stage | Target | Purpose | Add | Typical Build Time |
|-------|--------|---------|-----|-------------------|
| 1 | `{device}-minimal` | Boot test | Base system, network, shell | 10-20 min |
| 2 | `{device}-desktop` | Desktop environment | Hyprland, terminal, launcher | 15-30 min |
| 3 | `{device}-dev` | Development tools | Browsers, dev tools, language servers | 20-40 min |
| 4 | `{device}-productivity` | Office & communication | LibreOffice, Discord, Zoom, VLC | 15-25 min |
| 5 | `{device}-creative` | Creative software | Blender, GIMP, DaVinci (GPU-dependent) | 30-60 min |
| 6 | `{device}` | **Daily use** | ALL stages combined | First time: 60-120 min, updates: 5-30 min |

**Replace `{device}` with your device**: `laptop-intel`, `framework`, or `devtower`

---

## Pre-Installation

### Prerequisites

- NixOS Minimal ISO (24.11 or later)
- USB flash drive (4GB+ for bootable image)
- Target disk (backup any data first!)
- Laptop with internet connection
- 30GB free space minimum on target disk

### Hardware-Specific Notes

| Device | CPU | GPU | RAM | Storage | Disk Path |
|--------|-----|-----|-----|---------|-----------|
| `laptop-intel` | i5-10210U | Intel UHD | 32GB | 1TB | `/dev/nvme0n1` |
| `framework` | AMD Ryzen | Radeon | 64GB | 1TB | `/dev/nvme0n1` |
| `devtower` | AMD | Radeon | 64GB | 1TB | `/dev/nvme0n1` |

### Step 1: Create Bootable USB

On your current Ubuntu system:

```bash
# Identify USB device (be VERY careful!)
lsblk

# Create bootable USB (replace sdX with your USB device)
sudo dd if=nixos-minimal-24.11.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Verify write completed
sync
```

### Step 2: Boot NixOS Installer

1. Insert USB drive into laptop
2. Reboot and enter BIOS/UEFI (usually F2, F12, or Del key)
3. Disable Secure Boot (required for NixOS)
4. Set USB as first boot device
5. Save and exit
6. Select "NixOS Installer" from boot menu

### Step 3: Partition Disk

Once booted into the installer, become root:

```bash
sudo -i
```

**Partitioning Scheme (example for 1TB disk)**:

```bash
# Check disk name (likely /dev/nvme0n1 or /dev/sda)
lsblk

# DANGER: This erases all data! Replace nvme0n1 with your disk
parted /dev/nvme0n1 -- mklabel gpt

# EFI boot partition (1GB)
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on

# Root partition (remaining space - 8GB for swap)
parted /dev/nvme0n1 -- mkpart primary 1GiB -8GiB

# Swap partition (8GB - adjust based on your RAM)
parted /dev/nvme0n1 -- mkpart primary linux-swap -8GiB 100%
```

### Step 4: Format Partitions

```bash
# Format EFI partition
mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# Format root partition
mkfs.ext4 -L nixos /dev/nvme0n1p2

# Create swap
mkswap -L swap /dev/nvme0n1p3
```

### Step 5: Mount Filesystems

```bash
# Mount root
mount /dev/disk/by-label/nixos /mnt

# Mount boot
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# Enable swap
swapon /dev/nvme0n1p3
```

### Step 6: Clone Repository

```bash
# Enter nix shell with git
nix-shell -p git

# Clone repo
git clone https://github.com/SamBailey6194/nix-config /mnt/etc/nixos/nix-config
cd /mnt/etc/nixos/nix-config
```

### Step 7: Generate Hardware Configuration

```bash
# Generate hardware-specific config
nixos-generate-config --root /mnt

# Copy to host directory
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix
```

**Verify the hardware config looks correct**:

```bash
cat /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix
```

Look for:
- UUIDs present (not "REPLACE-WITH-ACTUAL-UUID")
- Correct partitions and filesystems
- Correct disk device path

---

## Stage-by-Stage Workflow

### Stage 1: Minimal Installation

**Purpose**: Get a bootable system to verify hardware works

**What's Included**:
- Base NixOS system
- Hardware configuration
- Network Manager
- Essential packages (vim, git, wget, htop, zsh)
- User account setup

**Installation**:

```bash
# Install with minimal configuration
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel-minimal

# When prompted, set a secure root password
# Reboot when installation completes
reboot
```

**First Boot**:

1. At login screen, log in as your user (default: `sam-dev`)
2. Set user password:
   ```bash
   passwd
   ```

**Verification**:

```bash
# Check system info
uname -a
uname -m  # Should be x86_64

# Check network
nmcli device status

# Verify hostname
hostname
```

**After Stage 1 Success**:
- System boots without errors
- Network is connected (or can be configured via `nmtui`)
- You can log in and run commands

---

### Stage 2: Desktop Environment

**Purpose**: Add graphical desktop (Hyprland) and basic tools

**What's Added**:
- Hyprland Wayland compositor
- Terminal (kitty)
- Application launcher (wofi)
- Status bar (waybar)
- File manager (thunar)
- Web browser (Firefox)
- SSH configuration

**Rebuild**:

```bash
# On the newly booted system
cd /etc/nixos/nix-config

# Rebuild with desktop
sudo nixos-rebuild switch --flake .#laptop-intel-desktop

# Wait for build to complete (~15-30 minutes first time)
```

**First Hyprland Login**:

1. Log out (Alt+F4 or system menu)
2. At login screen, click the gear icon and select "Hyprland"
3. Log in with your user credentials

**Verification**:

```bash
# In Hyprland terminal (Super+Return):
echo $XDG_SESSION_TYPE  # Should output "wayland"
pgrep Hyprland         # Should show a process ID
```

**Basic Keybinds**:
- `Super + Return` - Open terminal (kitty)
- `Super + D` - Open app launcher (wofi)
- `Super + Q` - Close window
- `Super + Shift + E` - Exit Hyprland

**After Stage 2 Success**:
- Hyprland starts without errors
- Desktop is responsive
- Terminal and app launcher work
- Firefox can access the internet

---

### Stage 3: Development Tools

**Purpose**: Add development environment and tools

**What's Added**:
- Browsers (LibreWolf, Chrome, Firefox)
- Development tools (Docker, git, GitHub CLI)
- Language servers (TypeScript, Python, Rust, Nix, LSP)
- Build tools (make, cmake, ninja, gcc)
- Database tools (PostgreSQL, SQLite, Redis)
- API testing (Postman, Insomnia)
- Container tools (Docker, container CLI)

**Rebuild**:

```bash
sudo nixos-rebuild switch --flake .#laptop-intel-dev
```

**Verification**:

```bash
# Check Docker
docker --version

# Check language servers available
which typescript-language-server
which pyright
which rust-analyzer

# Check git
git --version
gh --version
```

**After Stage 3 Success**:
- Multiple browsers launch without errors
- Docker engine is running
- Language servers are available
- Git and GitHub CLI work

---

### Stage 4: Productivity Software

**Purpose**: Add office and communication tools

**What's Added**:
- LibreOffice (Writer, Calc, Impress)
- Communication (Discord, Teams, Zoom, Slack)
- Media players (VLC, Spotify)
- PDF tools
- Obsidian (notes/knowledge management)
- Email client (Thunderbird)

**Rebuild**:

```bash
sudo nixos-rebuild switch --flake .#laptop-intel-productivity
```

**Verification**:

```bash
# Check office tools
which libreoffice

# Check communication apps
which discord
which zoomus
```

**After Stage 4 Success**:
- LibreOffice launches and can open documents
- Communication apps install and launch
- Media players work (test with a video file)
- Notes app works

---

### Stage 5: Creative Software

**Purpose**: Add creative and media tools (GPU-dependent)

**What's Added Varies by Device**:

**For laptop-intel (Intel UHD Graphics)**:
- ✅ Blender (3D creation)
- ✅ GIMP (image editing)
- ✅ Inkscape (vector graphics)
- ✅ Krita (digital painting)
- ❌ No DaVinci Resolve (Intel GPU not supported)

**For framework/devtower (AMD Radeon)**:
- ✅ Blender (3D creation)
- ✅ GIMP, Inkscape, Krita
- ✅ DaVinci Resolve Studio (professional video editing)
- ✅ Reaper (digital audio workstation)

**For devtower only**:
- ✅ Go XLR audio interface support

**Rebuild**:

```bash
sudo nixos-rebuild switch --flake .#laptop-intel-creative
```

**Verification**:

```bash
# Check installed apps
which blender
which gimp

# Test DaVinci (AMD only)
which davinci-resolve-studio
```

**After Stage 5 Success**:
- Creative apps launch without errors
- 3D graphics rendering works (test with Blender)
- Image/vector editing tools work

**Note**: See `DAVINCI-RESOLVE-AMD.md` for AMD-specific video editing setup.

---

### Stage 6: Full Configuration (Daily Use)

**Purpose**: Complete installation with all features for daily use

**What's Included**:
- ALL previous stages combined
- Home Manager integration for dotfiles
- Secrets management framework (agenix)
- All software modules
- Per-device configuration

**Switch to Full Config**:

```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

**This becomes your permanent configuration**:
- Use this target for all future updates
- All staged targets are for installation only
- Rebuild with: `sudo nixos-rebuild switch --flake .#laptop-intel`
- Update inputs with: `nix flake update` (in repo directory)

**Next Steps After Stage 6**:

1. **Set Up Secrets** (Phase 2):
   - Follow `SECRETS.md`
   - Generate per-device SSH keys for GitHub
   - Activate secrets module

2. **Configure Dotfiles**:
   - Edit Home Manager configuration
   - Set up Zed or Neovim
   - Configure git for multi-account usage

3. **Set Up VPN** (optional):
   - Follow `VPN.md` for Mullvad + WireGuard setup
   - Configure per-app VPN routing

4. **Enable Malware Scanner** (optional):
   - Follow `MALWARE-SCANNER.md`
   - Set up boot-time and real-time protection

5. **Configure Storage** (optional):
   - Follow `STORAGE.md` for backups and storage systems
   - Set up Restic for encrypted backups

---

## Device-Specific Targets

### laptop-intel (Intel i5-10210U, 32GB, Intel UHD Graphics)

```bash
# Stage 1: Minimal (during nixos-install)
nixos-install --flake .#laptop-intel-minimal

# Stage 2: Desktop
sudo nixos-rebuild switch --flake .#laptop-intel-desktop

# Stage 3: Development
sudo nixos-rebuild switch --flake .#laptop-intel-dev

# Stage 4: Productivity
sudo nixos-rebuild switch --flake .#laptop-intel-productivity

# Stage 5: Creative
sudo nixos-rebuild switch --flake .#laptop-intel-creative

# Stage 6: Full (daily use)
sudo nixos-rebuild switch --flake .#laptop-intel
```

### framework (AMD Ryzen + Radeon, 64GB)

```bash
# Stage 1: Minimal (during nixos-install)
nixos-install --flake .#framework-minimal

# Stage 2: Desktop
sudo nixos-rebuild switch --flake .#framework-desktop

# Stage 3: Development
sudo nixos-rebuild switch --flake .#framework-dev

# Stage 4: Productivity
sudo nixos-rebuild switch --flake .#framework-productivity

# Stage 5: Creative (+ DaVinci Resolve)
sudo nixos-rebuild switch --flake .#framework-creative

# Stage 6: Full (daily use)
sudo nixos-rebuild switch --flake .#framework
```

### devtower (AMD CPU + GPU, 64GB, Go XLR)

```bash
# Stage 1: Minimal (during nixos-install)
nixos-install --flake .#devtower-minimal

# Stage 2: Desktop
sudo nixos-rebuild switch --flake .#devtower-desktop

# Stage 3: Development
sudo nixos-rebuild switch --flake .#devtower-dev

# Stage 4: Productivity
sudo nixos-rebuild switch --flake .#devtower-productivity

# Stage 5: Creative (+ DaVinci + Go XLR)
sudo nixos-rebuild switch --flake .#devtower-creative

# Stage 6: Full (daily use)
sudo nixos-rebuild switch --flake .#devtower
```

---

## Post-Installation

### First System Rebuild

After Stage 1 installation, test the full rebuild workflow:

```bash
cd /etc/nixos/nix-config

# Verify configuration syntax
nix flake check

# Test build without activating
sudo nixos-rebuild test --flake .#laptop-intel-desktop

# Apply changes
sudo nixos-rebuild switch --flake .#laptop-intel-desktop
```

### Garbage Collection

Clean up old generations to free disk space:

```bash
# Remove old generations
sudo nix-collect-garbage -d

# Optimize nix store
nix-store --optimise
```

### System Rollback

If something breaks, rollback to previous generation:

```bash
# See all generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Future Updates

```bash
# Update flake inputs (nixpkgs, home-manager, etc.)
cd /etc/nixos/nix-config
nix flake update

# Review what will change
git diff flake.lock

# Rebuild with new versions
sudo nixos-rebuild switch --flake .#laptop-intel
```

---

## Troubleshooting

### Build Fails at a Specific Stage

**Problem**: Stage 3 builds successfully but Stage 4 fails

**Solution**:
1. Stay on Stage 3 (it still works)
2. Check the error message: `sudo nixos-rebuild build --flake .#laptop-intel-productivity --show-trace`
3. Fix the problematic module
4. Try Stage 4 again
5. You haven't lost your working system!

### Running Out of tmpfs Space During Installation

**Problem**: `nixos-install` fails with "No space left on device"

**Solution**:
- You should be using `*-minimal` for installation
- If minimal is still too large, reduce packages in `configuration-minimal.nix`
- Or, bind-mount disk storage during install:
  ```bash
  mkdir -p /mnt/nix
  mount --bind /mnt/nix /nix
  nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel-minimal
  ```

### Desktop Environment Won't Start

**Problem**: After Stage 2, can't log into Hyprland

**Solution**:
1. Switch to TTY (Ctrl+Alt+F2)
2. Check logs:
   ```bash
   journalctl -xeu display-manager
   journalctl -xeu hyprland
   ```
3. Verify Hyprland is installed:
   ```bash
   which Hyprland
   ```
4. Rollback to Stage 1 and try again:
   ```bash
   sudo nixos-rebuild switch --rollback
   ```

### Can't Login to Hyprland

**Problem**: Stuck at login screen, password not accepted

**Solution**:
```bash
# Switch to TTY (Ctrl+Alt+F2)
# Login as root
# Set user password
sudo passwd sam-dev
# Try login again
```

### Creative Software Won't Launch (DaVinci Resolve)

**Problem**: DaVinci Resolve crashes on startup (AMD only)

**Solution**:
```bash
# Verify GPU is detected
lspci | grep VGA

# Check OpenCL/ROCm support
rocminfo

# Launch with debug environment variables
ROC_ENABLE_PRE_VEGA=1 RUSTICL_ENABLE=radeonsi \
QT_QPA_PLATFORM=xcb davinci-resolve-studio
```

See `DAVINCI-RESOLVE-AMD.md` for detailed troubleshooting.

### Configuration Doesn't Build

**Problem**: Build fails with cryptic error

**Solution**:
```bash
# Check syntax
nix flake check

# See detailed error with trace
sudo nixos-rebuild build --flake .#laptop-intel --show-trace

# Check for Nix syntax errors
nix-instantiate --parse < hosts/laptop-intel/configuration.nix
```

### Out of Disk Space

**Problem**: `/nix/store` is full

**Solution**:
```bash
# Check disk usage
du -sh /nix/store

# Clean old generations
sudo nix-collect-garbage -d

# Optimize store links
nix-store --optimise
```

---

## Quick Reference

### Common Commands

```bash
# System rebuild
sudo nixos-rebuild switch --flake .#laptop-intel

# Test before applying
sudo nixos-rebuild test --flake .#laptop-intel

# Check configuration syntax
nix flake check

# See what will change
sudo nixos-rebuild dry-run --flake .#laptop-intel

# Update flake inputs
nix flake update

# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Clean garbage
sudo nix-collect-garbage -d
```

### Hyprland Keybinds

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal (kitty) |
| `Super + D` | App launcher (wofi) |
| `Super + Q` | Close window |
| `Super + H/J/K/L` | Focus window (vim-style) |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + F` | Toggle floating |
| `Super + M` | Fullscreen |
| `Super + 1-5` | Switch workspace |
| `Super + Shift + 1-5` | Move window to workspace |
| `Super + Shift + E` | Exit Hyprland |
| `Print` | Screenshot (select area) |

### Stage Installation Summary

| Stage | Install Command | Purpose | Time |
|-------|-----------------|---------|------|
| 1 | `nixos-install --flake .#laptop-intel-minimal` | Boot test | 10-20 min |
| 2 | `sudo nixos-rebuild switch --flake .#laptop-intel-desktop` | Desktop | 15-30 min |
| 3 | `sudo nixos-rebuild switch --flake .#laptop-intel-dev` | Dev tools | 20-40 min |
| 4 | `sudo nixos-rebuild switch --flake .#laptop-intel-productivity` | Office tools | 15-25 min |
| 5 | `sudo nixos-rebuild switch --flake .#laptop-intel-creative` | Creative apps | 30-60 min |
| 6 | `sudo nixos-rebuild switch --flake .#laptop-intel` | **Daily use** | 5-30 min |

---

## Next Steps

After successful installation:

1. **Set Up Secrets** (Phase 2): Read `SECRETS.md`
2. **Add Another Device** (Phase 3): Copy host configuration
3. **Integrate Dotfiles** (Phase 4): Configure Home Manager
4. **Set Up VPN** (Phase 6): Read `VPN.md`
5. **Enable Malware Scanner** (Phase 7): Read `MALWARE-SCANNER.md`
6. **Configure Storage** (Phase 8): Read `STORAGE.md`

See `../CLAUDE.md` for the full 12-phase roadmap.
