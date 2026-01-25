# Quick Installation Reference

## TL;DR - Installation Command

**Use this during nixos-install to avoid tmpfs space issues:**

```bash
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel-minimal --root /mnt
```

**After successful boot, rebuild with full config:**

```bash
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel
```

---

## Complete Installation (Copy-Paste)

```bash
# 1. Partition (adjust /dev/nvme0n1 for your disk)
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 1GiB -8GiB
parted /dev/nvme0n1 -- mkpart primary linux-swap -8GiB 100%

# 2. Format
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2
mkswap -L swap /dev/nvme0n1p3

# 3. Mount
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/nvme0n1p3

# 4. Generate hardware config
nixos-generate-config --root /mnt

# 5. Clone repo
nix-shell -p git
git clone https://github.com/SamBailey6194/nix-config /mnt/etc/nixos/nix-config
cd /mnt/etc/nixos/nix-config

# 6. Copy hardware config
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/etc/nixos/nix-config/hosts/laptop-intel/hardware-configuration.nix

# 7. Install with MINIMAL config (important!)
nixos-install --flake /mnt/etc/nixos/nix-config#laptop-intel-minimal --root /mnt

# 8. Set root password when prompted

# 9. Reboot
reboot
```

---

## After First Boot

```bash
# Rebuild with FULL configuration
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel
```

This installs all packages, home-manager, Hyprland, browsers, dev tools, etc.

---

## Why Two Steps?

- **Minimal**: Only essential packages (~2GB)
- **Full**: Everything (~15GB+ with caches)

NixOS installer runs in tmpfs (RAM), which gets full. After boot, system uses disk storage, so no space issues.

---

## Disk Size Reference

| Configuration | Download | Built | Total |
|---------------|----------|-------|-------|
| Minimal       | ~500MB   | ~2GB  | ~2.5GB |
| Full          | ~5GB     | ~15GB | ~20GB |

Your 32GB RAM should handle minimal install. Full install needs to happen after boot when using disk storage.
