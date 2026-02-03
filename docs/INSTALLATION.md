# NixOS Installation Guide

**Last Updated**: 03/02/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## Quick Start

**TL;DR - Get NixOS running in 30 minutes:**

```bash
# 1. Boot NixOS Minimal ISO
# 2. Choose: Standard or LUKS+BTRFS (see below)
# 3. Partition disk (see Pre-Installation)
# 4. Install with minimal configuration
nixos-install --flake /mnt/etc/nixos/nix-config#{device}-minimal

# 5. Reboot and rebuild with desktop
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#{device}-desktop

# 6. Log into Hyprland and continue with remaining stages
```

**Replace `{device}` with**: `laptop-intel`, `framework`, or `devtower`

---

## Installation Method: Choose Your Approach

### Option 1: Standard (Simple)

**Best for**: First-time NixOS users, testing hardware, simple setups

**Partitioning**:
```
/dev/nvme0n1p1  1GB   FAT32   /boot (EFI)
/dev/nvme0n1p2  ~984GB ext4   /
/dev/nvme0n1p3  8GB   swap    swap
```

**Features**:
- ✅ Simple 3-partition layout
- ✅ Fast installation
- ✅ Easy to understand
- ❌ No encryption
- ❌ No snapshots
- ❌ No compression

### Option 2: LUKS + BTRFS (Recommended)

**Best for**: Production use, laptops, security-conscious users

**Partitioning**:
```
/dev/nvme0n1p1  1GB   FAT32   /boot (unencrypted)
/dev/nvme0n1p2  ~992GB LUKS   cryptroot (encrypted)
  └─ BTRFS filesystem with subvolumes:
     ├─ @root      -> /
     ├─ @home      -> /home
     ├─ @nix       -> /nix
     ├─ @snapshots -> /.snapshots
     └─ @log       -> /var/log
```

**Features**:
- ✅ Full disk encryption (except /boot)
- ✅ Automatic snapshots (rollback updates)
- ✅ Transparent compression (save 30-50% space)
- ✅ TPM2 auto-unlock (optional)
- ✅ zram swap (no swap partition needed)
- ⚠️  Slightly more complex setup

**Choose your method before continuing!**

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
- Device with internet connection
- 30GB free space minimum on target disk

### Hardware-Specific Notes

| Device | CPU | GPU | RAM | Storage | Primary Disk |
|--------|-----|-----|-----|---------|--------------|
| `laptop-intel` | i5-10210U | Intel UHD | 32GB | 1TB SSD | `/dev/nvme0n1` |
| `framework` | AMD Ryzen | AMD Radeon | 64GB | 1TB SSD | `/dev/nvme0n1` |
| `devtower` | AMD CPU | AMD Radeon | 64GB | 1TB OS + 1TB Home + 3.6TB Media | `/dev/nvme0n1` (OS) |

**devtower multi-drive setup**:
- `/dev/nvme0n1` - OS drive (1TB)
- `/dev/nvme1n1` - Home drive (1TB)
- `/dev/sda` - Media drive (3.6TB HDD)

### Step 1: Create Bootable USB

On your current system:

```bash
# Identify USB device (be VERY careful!)
lsblk

# Create bootable USB (replace sdX with your USB device)
sudo dd if=nixos-minimal-24.11.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Verify write completed
sync
```

### Step 2: Boot NixOS Installer

1. Insert USB drive into target device
2. Reboot and enter BIOS/UEFI (usually F2, F12, or Del key)
3. Disable Secure Boot (required for NixOS)
4. Set USB as first boot device
5. Save and exit
6. Select "NixOS Installer" from boot menu

### Step 3: Become Root

```bash
sudo -i
```

---

## Partitioning and Formatting

**CRITICAL**: The following steps ERASE ALL DATA on your disk. Back up first!

### Choose Your Installation Method

- **[Standard Installation](#standard-installation-simple)** - Simple ext4 setup
- **[LUKS + BTRFS Installation](#luks--btrfs-installation-recommended)** - Encrypted with snapshots

---

## Standard Installation (Simple)

### 1. Partition the Disk

```bash
# Verify disk name
lsblk

# DANGER: This erases ALL data!
# For laptop-intel and framework:
parted /dev/nvme0n1 -- mklabel gpt

# For devtower (OS drive):
parted /dev/nvme0n1 -- mklabel gpt

# EFI boot partition (1GB)
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on

# Root partition (remaining space minus 8GB for swap)
parted /dev/nvme0n1 -- mkpart primary 1GiB -8GiB

# Swap partition (8GB)
parted /dev/nvme0n1 -- mkpart primary linux-swap -8GiB 100%

# Verify partitions
lsblk
```

**Device-specific notes**:
- **laptop-intel**: 32GB RAM → 8GB swap is sufficient
- **framework**: 64GB RAM → Can use 4GB swap or enable zram instead
- **devtower**: 64GB RAM → Recommend zram instead of swap partition (see LUKS+BTRFS method)

### 2. Format Partitions

```bash
# Format EFI partition
mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# Format root partition
mkfs.ext4 -L nixos /dev/nvme0n1p2

# Create swap
mkswap -L swap /dev/nvme0n1p3
```

### 3. Mount Filesystems

```bash
# Mount root
mount /dev/disk/by-label/nixos /mnt

# Mount boot
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# Enable swap
swapon /dev/nvme0n1p3

# Verify mounts
df -h
lsblk
```

**Skip to [Clone Repository](#clone-repository) section below**

---

## LUKS + BTRFS Installation (Recommended)

### 1. Partition the Disk

```bash
# Verify disk name
lsblk

# DANGER: This erases ALL data!
# For laptop-intel and framework:
parted /dev/nvme0n1 -- mklabel gpt

# For devtower (OS drive):
parted /dev/nvme0n1 -- mklabel gpt

# EFI boot partition (1GB, unencrypted)
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on

# LUKS encrypted partition (remaining space)
parted /dev/nvme0n1 -- mkpart primary 1GiB 100%

# Verify partitions
lsblk
```

**Device-specific notes**:
- **laptop-intel**: Single drive setup
- **framework**: Single drive setup
- **devtower**: Repeat for `/dev/nvme1n1` (home) and `/dev/sda` (media) if encrypting all drives

### 2. Create LUKS Encryption

```bash
# Create LUKS container
# You'll be prompted for a password - USE A STRONG PASSWORD!
cryptsetup luksFormat /dev/nvme0n1p2

# Type "YES" (uppercase) to confirm
# Enter your encryption password (remember this!)

# Open the LUKS container
cryptsetup open /dev/nvme0n1p2 cryptroot

# Verify it's open
ls -l /dev/mapper/cryptroot
```

**Device-specific LUKS setup**:

**laptop-intel** / **framework** (single drive):
```bash
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
```

**devtower** (multiple drives - optional):
```bash
# OS drive
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot

# Home drive (optional)
cryptsetup luksFormat /dev/nvme1n1p1
cryptsetup open /dev/nvme1n1p1 crypthome

# Media drive (optional)
cryptsetup luksFormat /dev/sda1
cryptsetup open /dev/sda1 cryptmedia
```

**IMPORTANT**: Remember your LUKS password! You'll need it on every boot. Without it, your data is permanently inaccessible.

### 3. Create BTRFS Filesystem

```bash
# Format the encrypted container as BTRFS
# For laptop-intel and framework:
mkfs.btrfs -L nixos /dev/mapper/cryptroot

# For devtower (OS drive):
mkfs.btrfs -L nixos-os /dev/mapper/cryptroot

# Mount the BTRFS volume
mount /dev/mapper/cryptroot /mnt
```

**devtower multi-drive setup**:
```bash
# OS drive
mkfs.btrfs -L nixos-os /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

# Home drive (if encrypted)
mkfs.btrfs -L nixos-home /dev/mapper/crypthome

# Media drive (if encrypted)
mkfs.btrfs -L nixos-media /dev/mapper/cryptmedia
```

### 4. Create BTRFS Subvolumes

**For laptop-intel and framework** (single drive layout):
```bash
# Create subvolumes
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log

# List subvolumes to verify
btrfs subvolume list /mnt

# Unmount to remount with proper options
umount /mnt
```

**For devtower** (OS drive only - no @home):
```bash
# Create OS subvolumes (no @home on OS drive)
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log

# List subvolumes to verify
btrfs subvolume list /mnt

# Unmount to remount with proper options
umount /mnt

# If using separate home drive:
mount /dev/mapper/crypthome /mnt
btrfs subvolume create /mnt/@home
umount /mnt

# If using media drive:
mount /dev/mapper/cryptmedia /mnt
btrfs subvolume create /mnt/@media
btrfs subvolume create /mnt/@archive
btrfs subvolume create /mnt/@projects
umount /mnt
```

### 5. Mount Subvolumes with Options

**For laptop-intel and framework**:
```bash
# Mount options (compression + SSD optimizations)
OPTS="compress=zstd:1,noatime,ssd,discard=async"

# Mount root subvolume
mount -o $OPTS,subvol=@root /dev/mapper/cryptroot /mnt

# Create mount points
mkdir -p /mnt/{boot,home,nix,.snapshots,var/log}

# Mount remaining subvolumes
mount -o $OPTS,subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o $OPTS,subvol=@nix /dev/mapper/cryptroot /mnt/nix
mount -o $OPTS,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o $OPTS,subvol=@log,nodatacow /dev/mapper/cryptroot /mnt/var/log

# Format and mount EFI boot partition
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mount /dev/nvme0n1p1 /mnt/boot
```

**For devtower** (multi-drive):
```bash
# Mount options
OPTS="compress=zstd:1,noatime,ssd,discard=async"

# Mount OS drive subvolumes
mount -o $OPTS,subvol=@root /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,home,nix,.snapshots,var/log}
mount -o $OPTS,subvol=@nix /dev/mapper/cryptroot /mnt/nix
mount -o $OPTS,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o $OPTS,subvol=@log,nodatacow /dev/mapper/cryptroot /mnt/var/log

# Mount home drive (if separate)
mount -o $OPTS,subvol=@home /dev/mapper/crypthome /mnt/home

# Mount media drive (if using)
mkdir -p /mnt/mnt/{media,archive,projects}
mount -o $OPTS,subvol=@media /dev/mapper/cryptmedia /mnt/mnt/media
mount -o $OPTS,subvol=@archive /dev/mapper/cryptmedia /mnt/mnt/archive
mount -o $OPTS,subvol=@projects /dev/mapper/cryptmedia /mnt/mnt/projects

# Format and mount EFI boot partition
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mount /dev/nvme0n1p1 /mnt/boot
```

### 6. Verify All Mounts

```bash
# Check all mounts are correct
df -h
lsblk
mount | grep /mnt
```

---

## Clone Repository

**This step is the same for ALL devices and installation methods:**

```bash
# Enter nix shell with git
nix-shell -p git

# Clone your nix-config repo
git clone https://github.com/SamBailey6194/nix-config /mnt/etc/nixos/nix-config
cd /mnt/etc/nixos/nix-config
```

---

## Generate Hardware Configuration

```bash
# Generate hardware-specific config
nixos-generate-config --root /mnt

# Copy to the appropriate host directory
```

**Device-specific copy commands**:

**laptop-intel**:
```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix
```

**framework**:
```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/nix-config/hosts/framework/hardware-configuration.nix
```

**devtower**:
```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/nix-config/hosts/devtower/hardware-configuration.nix
```

### Verify Hardware Configuration

**For Standard (ext4) installations**:
```bash
cat /mnt/etc/nixos/nix-config/hosts/{device}/hardware-configuration.nix
```

Look for:
- ✅ UUIDs present (not "REPLACE-WITH-ACTUAL-UUID")
- ✅ Correct partitions: `/boot`, `/`, `swap`
- ✅ Filesystems: `vfat`, `ext4`, `swap`

**For LUKS + BTRFS installations**:
```bash
cat /mnt/etc/nixos/nix-config/hosts/{device}/hardware-configuration.nix
```

Look for:
- ✅ LUKS device configuration:
  ```nix
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/SOME-UUID";
    allowDiscards = true;  # TRIM support
  };
  ```
- ✅ BTRFS mount options:
  ```nix
  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd:1" "noatime" ];
  };
  ```
- ✅ All subvolumes listed (/, /home, /nix, /.snapshots, /var/log)

---

## Enable Encryption Modules (LUKS + BTRFS only)

**If you used LUKS + BTRFS**, you need to enable the encryption modules before installation.

Edit your host configuration file:

**laptop-intel**: `/mnt/etc/nixos/nix-config/hosts/laptop-intel/configuration-full.nix`
**framework**: `/mnt/etc/nixos/nix-config/hosts/framework/configuration-full.nix`
**devtower**: `/mnt/etc/nixos/nix-config/hosts/devtower/configuration-full.nix`

```bash
# Use nano or vim to edit
nano /mnt/etc/nixos/nix-config/hosts/{device}/configuration-full.nix
```

**Uncomment these lines**:
```nix
# Security tools (uncomment for LUKS encryption)
../../modules/security/luks-encryption.nix

# Filesystem (uncomment for BTRFS)
../../modules/filesystem/btrfs.nix
../../modules/filesystem/btrfs-layouts.nix
../../modules/filesystem/zram.nix  # Compressed swap in RAM
```

**Add this configuration at the bottom of the file** (before the closing `}`):

**For laptop-intel**:
```nix
  # LUKS encryption configuration
  security.luksEncryption = {
    enable = true;
    devices.cryptroot = {
      device = "/dev/nvme0n1p2";
      name = "cryptroot";
      allowDiscards = true;  # TRIM support for SSD
      fallbackToPassword = true;  # Allow password if TPM2 fails
    };
  };

  # BTRFS configuration with laptop layout
  filesystem.btrfsLayouts = {
    layout = "laptop";
    rootDevice = "/dev/mapper/cryptroot";
  };

  # Enable zram for swap (no swap partition needed)
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;  # 32GB RAM → ~16GB compressed swap
```

**For framework**:
```nix
  # LUKS encryption configuration
  security.luksEncryption = {
    enable = true;
    devices.cryptroot = {
      device = "/dev/nvme0n1p2";
      name = "cryptroot";
      allowDiscards = true;  # TRIM support for SSD
      fallbackToPassword = true;  # Allow password if TPM2 fails
    };
  };

  # BTRFS configuration with laptop layout
  filesystem.btrfsLayouts = {
    layout = "laptop";
    rootDevice = "/dev/mapper/cryptroot";
  };

  # Enable zram for swap (no swap partition needed)
  zramSwap.enable = true;
  zramSwap.memoryPercent = 25;  # 64GB RAM → ~16GB compressed swap
```

**For devtower** (multi-drive):
```nix
  # LUKS encryption configuration
  security.luksEncryption = {
    enable = true;
    devices = {
      cryptroot = {
        device = "/dev/nvme0n1p2";
        name = "cryptroot";
        allowDiscards = true;
        fallbackToPassword = true;
      };
      # If encrypting home drive:
      crypthome = {
        device = "/dev/nvme1n1p1";
        name = "crypthome";
        allowDiscards = true;
        fallbackToPassword = true;
      };
      # If encrypting media drive:
      cryptmedia = {
        device = "/dev/sda1";
        name = "cryptmedia";
        allowDiscards = false;  # HDD, no TRIM
        fallbackToPassword = true;
      };
    };
  };

  # BTRFS configuration with devtower OS layout
  filesystem.btrfsLayouts = {
    layout = "devtower-os";
    rootDevice = "/dev/mapper/cryptroot";
  };

  # Enable zram for swap (no swap partition needed)
  zramSwap.enable = true;
  zramSwap.memoryPercent = 25;  # 64GB RAM → ~16GB compressed swap
```

**Standard (ext4) users**: Skip this step - no additional configuration needed.

---

## Install NixOS (Stage 1: Minimal)

**Device-specific installation commands**:

**laptop-intel**:
```bash
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel-minimal
```

**framework**:
```bash
nixos-install --flake /mnt/etc/nixos/nix-config#framework-minimal
```

**devtower**:
```bash
nixos-install --flake /mnt/etc/nixos/nix-config#devtower-minimal
```

**During installation**:
1. Enter a **strong root password** when prompted
2. Wait for installation to complete (10-20 minutes)
3. Don't remove the USB yet

**After installation completes**:
```bash
reboot
```

---

## First Boot

### For Standard (ext4) Installation

1. **Login**: At the console, log in as `root`
2. **Set User Password**:
   ```bash
   # For laptop-intel:
   passwd sam-laptop

   # For framework:
   passwd sam-framework

   # For devtower:
   passwd sam-desktop
   ```
3. **Log Out**: Type `exit`
4. **Log In** as your user account

### For LUKS + BTRFS Installation

1. **LUKS Password Prompt**:
   - Enter your LUKS encryption password
   - This happens BEFORE the login prompt
   - Boot will pause here waiting for password

2. **Login**: After LUKS unlocks, log in as `root`

3. **Set User Password**:
   ```bash
   # For laptop-intel:
   passwd sam-laptop

   # For framework:
   passwd sam-framework

   # For devtower:
   passwd sam-desktop
   ```

4. **Log Out**: Type `exit`

5. **Log In** as your user account

---

## Staged Installation Workflow

After first boot, progressively add features through staged rebuilds:

### Stage 2: Desktop Environment

**laptop-intel**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#laptop-intel-desktop
```

**framework**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#framework-desktop
```

**devtower**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#devtower-desktop
```

**After rebuild**:
1. Log out (system menu or `Alt+F4`)
2. At login screen, click gear icon → Select "Hyprland"
3. Log in with your user credentials

**Test Hyprland**:
- `Super + Return` - Open terminal (kitty)
- `Super + D` - Open app launcher (wofi)
- `Super + Q` - Close window

### Stage 3: Development Tools

**laptop-intel**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#laptop-intel-dev
```

**framework**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#framework-dev
```

**devtower**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#devtower-dev
```

**What's Added**: Browsers, Docker, git, GitHub CLI, language servers, build tools

**Verify**:
```bash
docker --version
gh --version
which typescript-language-server
```

### Stage 4: Productivity Software

**laptop-intel**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#laptop-intel-productivity
```

**framework**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#framework-productivity
```

**devtower**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#devtower-productivity
```

**What's Added**: LibreOffice, Discord, Teams, Zoom, Slack, VLC, Spotify, Thunderbird

### Stage 5: Creative Software

**laptop-intel** (Intel UHD GPU - limited):
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#laptop-intel-creative
```
**What's Added**: Blender, GIMP, Inkscape, Krita (no DaVinci - Intel GPU not supported)

**framework** (AMD Radeon - full support):
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#framework-creative
```
**What's Added**: Blender, GIMP, Inkscape, Krita, DaVinci Resolve Studio, Reaper

**devtower** (AMD Radeon + Go XLR - full support):
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#devtower-creative
```
**What's Added**: Blender, GIMP, Inkscape, Krita, DaVinci Resolve Studio, Reaper, Go XLR audio interface

### Stage 6: Full Configuration (Daily Use)

**This becomes your permanent configuration for all future updates**:

**laptop-intel**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#laptop-intel
```

**framework**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#framework
```

**devtower**:
```bash
cd /etc/nixos/nix-config
sudo nixos-rebuild switch --flake .#devtower
```

**From now on, use this command for all system updates!**

---

## Post-Installation

### Verify System

```bash
# Check system info
uname -a
uname -m  # Should be x86_64

# Check network
nmcli device status

# Verify hostname
hostname
```

**Expected hostnames**:
- **laptop-intel**: `laptop-intel`
- **framework**: `framework`
- **devtower**: `devtower`

### For LUKS + BTRFS: Verify Encryption

```bash
# Check LUKS status
sudo cryptsetup status cryptroot

# Check BTRFS subvolumes
sudo btrfs subvolume list /

# Check compression is working
sudo compsize /
```

**Expected output**:
- LUKS: `cryptroot is active`
- BTRFS: Shows @root, @home, @nix, @snapshots, @log
- Compression: ~30-50% compression ratio

### TPM2 Auto-Unlock (LUKS Only - Optional)

After your encrypted system is working, you can enable TPM2 for automatic unlocking:

```bash
# Enroll TPM2 key (all devices)
sudo systemd-cryptenroll /dev/nvme0n1p2 --tpm2-device=auto

# For devtower with multiple encrypted drives:
sudo systemd-cryptenroll /dev/nvme1n1p1 --tpm2-device=auto
sudo systemd-cryptenroll /dev/sda1 --tpm2-device=auto

# Verify enrollment
sudo systemd-cryptenroll /dev/nvme0n1p2
```

The TPM2 configuration in your NixOS config already has `fallbackToPassword = true`, so if TPM2 fails, you'll be prompted for your password.

**Test**: Reboot and verify the system unlocks automatically.

---

## Next Steps

After successful installation:

1. **Set Up Secrets** (Phase 2):
   - Follow `PHASE-2-SECRETS-SETUP.md`
   - Generate per-device SSH keys for GitHub
   - Activate secrets modules

2. **Configure Dotfiles** (Phase 4):
   - Edit Home Manager configuration
   - Set up Zed or Neovim
   - Configure git for multi-account usage

3. **Set Up VPN** (Phase 6 - optional):
   - Follow `VPN.md` for Mullvad + Wireguard setup
   - Configure per-app VPN routing

4. **Enable Malware Scanner** (Phase 7 - optional):
   - Follow `MALWARE-SCANNER.md`
   - Set up boot-time and real-time protection

5. **Configure Storage** (Phase 8 - optional):
   - Follow `STORAGE.md` for backups
   - Set up Restic for encrypted backups

---

## Troubleshooting

### Build Fails During Installation

**Problem**: `nixos-install` fails with error

**Solution**:
```bash
# Check for syntax errors
cd /mnt/etc/nixos/nix-config
nix flake check

# See detailed error
nixos-install --flake /mnt/etc/nixos/nix-config#{device}-minimal --show-trace
```

### Out of tmpfs Space During Installation

**Problem**: `nixos-install` fails with "No space left on device"

**Solution**:
```bash
# Bind-mount disk storage during install
mkdir -p /mnt/nix
mount --bind /mnt/nix /nix
nixos-install --flake /mnt/etc/nixos/nix-config#{device}-minimal
```

### LUKS Password Not Working (LUKS only)

**Problem**: Can't unlock disk at boot

**Solution**:
1. Boot from USB installer
2. Try opening LUKS manually:
   ```bash
   sudo cryptsetup open /dev/nvme0n1p2 cryptroot
   ```
3. If password works → Issue with initrd configuration
4. If password fails → Password was mistyped during setup (data is lost)

### BTRFS Mount Fails (LUKS + BTRFS only)

**Problem**: Boot fails with "cannot mount /dev/mapper/cryptroot"

**Solution**:
1. Boot from USB
2. Open LUKS and check BTRFS:
   ```bash
   sudo cryptsetup open /dev/nvme0n1p2 cryptroot
   mount /dev/mapper/cryptroot /mnt
   btrfs subvolume list /mnt
   ```
3. Verify subvolumes exist: @root, @home, @nix, @snapshots, @log
4. Check `hardware-configuration.nix` has correct subvolume names

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
# Reset user password
sudo passwd sam-laptop   # Or sam-framework / sam-desktop
# Try login again
```

### Creative Software Won't Launch (DaVinci Resolve)

**Problem**: DaVinci Resolve crashes on startup (framework/devtower only)

**Solution**:
```bash
# Verify GPU is detected
lspci | grep VGA

# Check OpenCL/ROCm support
rocminfo

# Launch with debug variables
ROC_ENABLE_PRE_VEGA=1 RUSTICL_ENABLE=radeonsi \
QT_QPA_PLATFORM=xcb davinci-resolve-studio
```

See `DAVINCI-RESOLVE-AMD.md` for detailed AMD GPU troubleshooting.

---

## Quick Reference

### Common Commands

```bash
# System rebuild (all devices - use your device name)
sudo nixos-rebuild switch --flake .#{device}

# Test before applying
sudo nixos-rebuild test --flake .#{device}

# Check configuration syntax
nix flake check

# See what will change
sudo nixos-rebuild dry-run --flake .#{device}

# Update flake inputs
nix flake update

# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Clean garbage
sudo nix-collect-garbage -d
```

### BTRFS Snapshot Commands (LUKS + BTRFS only)

```bash
# List snapshots
sudo btrfs subvolume list /.snapshots

# Create manual snapshot
sudo btrfs subvolume snapshot / /.snapshots/@root-$(date +%Y%m%d)

# Rollback to snapshot (from live USB or recovery)
mount /dev/mapper/cryptroot /mnt
cd /mnt
mv @root @root.broken
btrfs subvolume snapshot .snapshots/@root-20260203 @root
reboot
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

| Device | Minimal | Desktop | Dev | Productivity | Creative | Full |
|--------|---------|---------|-----|--------------|----------|------|
| **laptop-intel** | `#laptop-intel-minimal` | `#laptop-intel-desktop` | `#laptop-intel-dev` | `#laptop-intel-productivity` | `#laptop-intel-creative` | `#laptop-intel` |
| **framework** | `#framework-minimal` | `#framework-desktop` | `#framework-dev` | `#framework-productivity` | `#framework-creative` | `#framework` |
| **devtower** | `#devtower-minimal` | `#devtower-desktop` | `#devtower-dev` | `#devtower-productivity` | `#devtower-creative` | `#devtower` |

---

## Comparison: Installation Methods

| Feature | Standard (ext4) | LUKS + BTRFS |
|---------|----------------|--------------|
| **Encryption** | ❌ None | ✅ Full disk (except /boot) |
| **Snapshots** | ❌ None | ✅ Automatic + manual rollback |
| **Compression** | ❌ None | ✅ Transparent (save 30-50% space) |
| **Rollback** | ❌ Reinstall required | ✅ Instant (from snapshot) |
| **Swap** | Dedicated partition | zram (compressed in RAM) |
| **Complexity** | Simple | Moderate |
| **Performance** | Baseline | +10-20% (from compression) |
| **Security** | Basic | High (encrypted at rest) |
| **Boot Process** | Direct boot | Password prompt at boot |
| **TPM2 Support** | N/A | ✅ Auto-unlock (optional) |
| **Best For** | Testing, simple setups | Production, laptops, security |

---

## Installation Checklist

Use this checklist to track your progress:

- [ ] Created bootable USB with NixOS ISO
- [ ] Disabled Secure Boot in BIOS
- [ ] Booted from USB installer
- [ ] Chose installation method (Standard or LUKS+BTRFS)
- [ ] Partitioned disk(s)
- [ ] Formatted partitions (and encrypted if using LUKS)
- [ ] Created BTRFS subvolumes (if using BTRFS)
- [ ] Mounted all filesystems
- [ ] Cloned nix-config repository
- [ ] Generated hardware configuration
- [ ] Enabled encryption modules (if using LUKS+BTRFS)
- [ ] Installed Stage 1 (minimal)
- [ ] Rebooted successfully
- [ ] Set user password
- [ ] Logged in as user
- [ ] Rebuilt Stage 2 (desktop)
- [ ] Logged into Hyprland
- [ ] Rebuilt Stage 3 (development)
- [ ] Rebuilt Stage 4 (productivity)
- [ ] Rebuilt Stage 5 (creative)
- [ ] Rebuilt Stage 6 (full configuration)
- [ ] Configured TPM2 auto-unlock (optional, LUKS only)
- [ ] Set up secrets (Phase 2)
- [ ] Configured VPN (Phase 6, optional)

---

See `CLAUDE.md` for the full 12-phase roadmap and next steps.
