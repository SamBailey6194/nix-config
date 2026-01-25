# Minimal NixOS Installation Guide

## Problem
The full configuration is too large for the NixOS installer's tmpfs (RAM-based filesystem). During `nixos-install`, the `/nix/store` and `/nix/.rw-store` fill up to 95%+ causing installation to fail.

## Solution: Two-Stage Installation

### Stage 1: Minimal Installation (Get System Bootable)

Use the minimal configuration that only includes:
- Essential system settings
- Basic hardware support
- NetworkManager
- Minimal packages (vim, wget, git, htop)
- **NO** home-manager, browsers, development tools, or heavy software

### Stage 2: Full Configuration (After First Boot)

Once the system is bootable, add all the features back and rebuild.

---

## Installation Steps

### 1. Boot NixOS Installer

1. Create bootable USB with NixOS ISO
2. Boot laptop from USB
3. Connect to WiFi: `sudo systemctl start wpa_supplicant`

### 2. Partition Disk

```bash
# Example for 1TB disk (/dev/nvme0n1)
# Adjust partition sizes for your disk

# Create GPT partition table
parted /dev/nvme0n1 -- mklabel gpt

# EFI boot partition (1GB)
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on

# Root partition (remaining space - 8GB for swap)
parted /dev/nvme0n1 -- mkpart primary 1GiB -8GiB

# Swap partition (8GB - adjust based on RAM)
parted /dev/nvme0n1 -- mkpart primary linux-swap -8GiB 100%
```

### 3. Format Partitions

```bash
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2
mkswap -L swap /dev/nvme0n1p3
```

### 4. Mount Filesystems

```bash
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/nvme0n1p3
```

### 5. Generate Hardware Config

```bash
nixos-generate-config --root /mnt
```

### 6. Clone Repository

```bash
# Enter nix shell with git
nix-shell -p git

# Clone repo
git clone https://github.com/SamBailey6194/nix-config /mnt/etc/nixos/nix-config
cd /mnt/etc/nixos/nix-config
```

### 7. Copy Hardware Config

```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix
```

### 8. Install with MINIMAL Configuration

**CRITICAL**: Use the minimal configuration for installation:

```bash
# Option A: Use the minimal config directly
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel-minimal --root /mnt

# Option B: Temporarily symlink (if flake doesn't have minimal target)
cd /mnt/etc/nixos/nix-config/hosts/laptop-intel
mv configuration.nix configuration-full.nix
cp configuration-minimal.nix configuration.nix
cd /mnt
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel --root /mnt
```

### 9. Set Root Password

When prompted, set the root password.

### 10. Reboot

```bash
reboot
```

---

## After First Boot

### 1. Log in as root (or your user if created)

### 2. Restore Full Configuration

```bash
cd /etc/nixos/nix-config/hosts/laptop-intel
# If you renamed it:
mv configuration.nix configuration-minimal.nix
mv configuration-full.nix configuration.nix

# Or just edit configuration.nix and uncomment all the imports
```

### 3. Add Flake Minimal Target (Optional)

To make future installations easier, add this to `flake.nix`:

```nix
# Minimal installation configuration (for tmpfs-constrained installs)
laptop-intel-minimal = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; };
  modules = [
    ./hosts/laptop-intel/configuration-minimal.nix
    agenix.nixosModules.default
  ];
};
```

### 4. Rebuild with Full Configuration

```bash
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel
```

This will now install all the packages, home-manager, browsers, dev tools, etc. Because the system is already installed and has a persistent `/nix/store` on disk (not tmpfs), this won't run out of space.

---

## What's Different Between Minimal and Full?

### Minimal Configuration Includes:
- Hardware configuration
- Nix settings
- Intel laptop hardware support
- User accounts
- Basic packages (vim, wget, git, htop)

### Minimal Configuration EXCLUDES:
- ❌ Home Manager (biggest space saver)
- ❌ All software modules (browsers, development, communication, media, office, creative)
- ❌ Hyprland and desktop environment
- ❌ Secrets management (agenix)
- ❌ SSH configuration
- ❌ Wireguard VPN
- ❌ Docker, PostgreSQL, development tools
- ❌ Language servers, linters, formatters

### Full Configuration (After Boot) Adds:
- ✅ Home Manager with dotfiles
- ✅ Hyprland desktop environment
- ✅ All software suites
- ✅ Per-device secrets
- ✅ Development tools
- ✅ Everything else

---

## Troubleshooting

### Still Running Out of Space?

If even the minimal config fails:

1. **Increase installer RAM** (if in VM)
2. **Mount disk's /nix/store during install**:
   ```bash
   # After mounting /mnt
   mkdir -p /mnt/nix
   mount --bind /mnt/nix /nix
   # Then run nixos-install
   ```

3. **Install without flakes**:
   ```bash
   # Copy config to /mnt/etc/nixos
   cp hosts/laptop-intel/configuration-minimal.nix /mnt/etc/nixos/configuration.nix
   cp hosts/laptop-intel/hardware-configuration.nix /mnt/etc/nixos/
   nixos-install --root /mnt
   ```

### After Successful Boot

Once booted into the minimal system:
1. The system is now using the disk's persistent `/nix/store`
2. You can rebuild with the full configuration without space issues
3. Run `sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel`
4. This will download and build everything, but won't run out of space

---

## Summary

**Installation Process**:
1. Boot installer → Partition → Mount
2. Clone repo
3. **Install with MINIMAL config** (avoid tmpfs overflow)
4. Reboot into working system
5. **Rebuild with FULL config** (now using disk storage)

This two-stage approach ensures successful installation even with large configurations.
