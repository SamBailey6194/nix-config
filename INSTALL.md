# NixOS Installation Guide - Phase 1

This guide walks through installing NixOS on your Intel i5-10210U laptop using this configuration.

## Prerequisites

- Intel i5-10210U laptop with 1TB disk and 32GB RAM
- USB flash drive (4GB+ for NixOS installer)
- Backup of any important data (this will wipe the disk)
- This repository cloned or available

## Step 1: Download NixOS

1. Visit: https://nixos.org/download.html
2. Download: **NixOS 24.11 Minimal ISO (x86_64)**
3. Verify checksum (optional but recommended)

## Step 2: Create Bootable USB

On your current Ubuntu system:

```bash
# Find your USB device (be VERY careful here!)
lsblk

# Create bootable USB (replace sdX with your USB device)
sudo dd if=nixos-minimal-24.11.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Step 3: Boot NixOS Installer

1. Insert USB drive into laptop
2. Reboot and enter BIOS/UEFI (usually F2, F12, or Del key)
3. Disable Secure Boot (required for NixOS)
4. Set USB as first boot device
5. Save and exit
6. Select "NixOS Installer" from boot menu

## Step 4: Partition Disk

Once booted into the installer, become root:

```bash
sudo -i
```

### Partitioning Scheme (for 1TB disk)

We'll create:
- 1GB EFI boot partition
- ~984GB root partition
- 8GB swap partition

```bash
# Check disk name (likely /dev/nvme0n1 or /dev/sda)
lsblk

# DANGER: This erases all data! Replace nvme0n1 with your disk
parted /dev/nvme0n1 -- mklabel gpt

# EFI boot partition
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on

# Root partition (1GB to -8GB from end)
parted /dev/nvme0n1 -- mkpart primary 1GiB -8GiB

# Swap partition (last 8GB)
parted /dev/nvme0n1 -- mkpart primary linux-swap -8GiB 100%
```

### Format Partitions

```bash
# Format EFI partition
mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# Format root partition
mkfs.ext4 -L nixos /dev/nvme0n1p2

# Create swap
mkswap -L swap /dev/nvme0n1p3
```

### Mount Filesystems

```bash
# Mount root
mount /dev/disk/by-label/nixos /mnt

# Mount boot
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# Enable swap
swapon /dev/nvme0n1p3
```

## Step 5: Generate Hardware Configuration

```bash
nixos-generate-config --root /mnt
```

This creates `/mnt/etc/nixos/configuration.nix` and `/mnt/etc/nixos/hardware-configuration.nix`.

## Step 6: Get This Configuration

### Option A: Clone from GitHub (requires internet)

```bash
# Enter a Nix shell with git
nix-shell -p git

# Clone this repo
cd /mnt/etc/nixos
git clone https://github.com/SamBailey6194/nix-config
```

### Option B: Copy from USB/External Drive

If you have this repo on a USB drive:

```bash
# Mount USB drive
mkdir -p /mnt/usb
mount /dev/sdX1 /mnt/usb  # Replace sdX1 with USB partition

# Copy to system
cp -r /mnt/usb/nix-config /mnt/etc/nixos/
```

## Step 7: Replace Hardware Configuration

```bash
# Copy the generated hardware config to our host directory
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix
```

## Step 8: Review Configuration

Optional but recommended - check the hardware config looks correct:

```bash
cat /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix
```

Verify:
- UUIDs are present (not "REPLACE-WITH-ACTUAL-UUID")
- Partitions match what you created
- File systems are correct

## Step 9: Install NixOS

```bash
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel
```

This will:
- Download all required packages
- Build the system
- Install to /mnt
- Ask you to set a root password

**Set a secure root password when prompted.**

Installation takes 10-30 minutes depending on internet speed.

## Step 10: Reboot

```bash
reboot
```

Remove the USB drive when prompted.

## Step 11: First Boot

1. At login screen, select **Hyprland** session (gear icon)
2. Log in as: **sam-dev** (you'll need to set password)
3. Open terminal: `Super + Return`
4. Set your user password:
   ```bash
   passwd
   ```

## Step 12: Test Basic Functionality

### Test Hyprland Keybinds

- `Super + Return` - Open Kitty terminal
- `Super + D` - Open Wofi app launcher
- `Super + Q` - Close window
- `Super + 1-5` - Switch workspaces
- `Print` - Screenshot (select area with mouse)

### Test Network

```bash
# Check network status
nmcli device status

# Connect to WiFi
nmtui
```

### Test System Rebuild

```bash
# Rebuild system (test that flake works)
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel
```

If this works without errors, your NixOS installation is successful!

## Step 13: Set Up Git (Optional)

If you want to make changes to the config:

```bash
cd /etc/nixos/nix-config

# Configure git
git config user.name "Sam Bailey"
git config user.email "sambailey6194@gmail.com"
```

## Troubleshooting

### Screen is Black After Hyprland Login

Press `Super + Return` to open a terminal, then check:

```bash
echo $XDG_SESSION_TYPE  # Should be "wayland"
pgrep Hyprland          # Should show a process ID
```

If Hyprland isn't running:
```bash
# Check logs
journalctl -b -u display-manager
```

### WiFi Doesn't Work

```bash
# Check if NetworkManager is running
systemctl status NetworkManager

# Try restarting NetworkManager
sudo systemctl restart NetworkManager
```

### Can't Login as sam-dev

Boot into recovery mode, mount root, chroot, and set password:

```bash
# From installer USB
mount /dev/disk/by-label/nixos /mnt
nixos-enter --root /mnt
passwd sam-dev
exit
reboot
```

## Next Steps

After successful installation:
- **Phase 2**: Set up agenix for secrets management
- **Phase 3**: Add second device (Framework or DevTower)
- **Phase 4**: Integrate existing dotfiles with Home Manager

See `README.md` for the full roadmap.
