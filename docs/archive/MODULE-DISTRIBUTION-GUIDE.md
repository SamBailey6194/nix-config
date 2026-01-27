# Module Distribution Guide

This document shows which modules are included at each installation stage for all devices.

## Module Distribution by Stage

### Stage 1: Minimal (Installation Only)

All devices get:
- `modules/core/nix-settings.nix` - Nix daemon settings
- `modules/hardware/{device}.nix` - Device-specific hardware config
- `modules/users/{device}.nix` - Device-specific user account
- **`modules/storage/restic.nix`** - Runtime-configurable backups
- **`modules/storage/zfs.nix`** - Runtime-configurable ZFS
- **`modules/storage/raid.nix`** - Runtime-configurable RAID

**Why storage in minimal?** Storage management tools are lightweight and enable you to configure backups/RAID after installation without rebuilding.

### Stage 2: Desktop (Hyprland + SSH)

Adds:
- `modules/desktop/hyprland/` - Hyprland compositor + ecosystem
- `modules/core/ssh-config.nix` - Per-device SSH keys for GitHub

### Stage 3: Development (Dev Tools)

Adds:
- `modules/software/browsers.nix` - LibreWolf, Firefox, Chrome
- `modules/software/development.nix` - Docker, language servers, build tools

### Stage 4: Productivity (Office + Communication)

Adds:
- `modules/software/office.nix` - LibreOffice, PDF tools
- `modules/software/communication.nix` - Discord, Slack, Teams, Zoom, Obsidian
- `modules/software/media.nix` - VLC, Spotify, GIMP, Audacity

### Stage 5: Creative (GPU-Dependent Software)

**laptop-intel** (Intel UHD Graphics):
- Blender, GIMP, Inkscape, Krita (added directly in config)
- ❌ No `modules/software/creative.nix` (requires AMD/NVIDIA GPU)
- **Affinity Apps** (Designer, Photo, Publisher) via flake

**framework** (AMD Radeon):
- `modules/software/creative.nix` - DaVinci Resolve Studio, Blender, Reaper
- **Affinity Apps** (Designer, Photo, Publisher) via flake

**devtower** (AMD Radeon + Go XLR):
- `modules/software/creative.nix` - DaVinci Resolve Studio, Blender, Reaper
- `modules/hardware/go-xlr.nix` - Go XLR audio interface
- **Affinity Apps** (Designer, Photo, Publisher) via flake

### Stage 6: Full (Daily Use - Everything)

All devices get everything from stages 1-5 PLUS:
- **`modules/network/wireguard-mullvad.nix`** - Mullvad VPN with multi-hop
  - Auto-imports: `wireguard-firewall.nix`, `wireguard-routes.nix`, `wireguard-cgroups.nix`
- **`modules/security/malware-scanner.nix`** - Real-time malware protection
- **Affinity Apps** (Designer, Photo, Publisher) via flake
- Home Manager integration
- Secrets management (when Phase 2 activated)

**devtower only**:
- `modules/hardware/openrgb.nix` - RGB keyboard/peripheral control

## Module Summary Table

| Module | Minimal | Desktop | Dev | Productivity | Creative | Full |
|--------|---------|---------|-----|--------------|----------|------|
| **Core** | | | | | | |
| nix-settings.nix | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ssh-config.nix | | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Hardware** | | | | | | |
| {device}-specific.nix | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| go-xlr.nix (devtower) | | | | | ✅ | ✅ |
| openrgb.nix (devtower) | | | | | | ✅ |
| **Storage** | | | | | | |
| restic.nix | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| zfs.nix | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| raid.nix | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Desktop** | | | | | | |
| hyprland/ | | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Software** | | | | | | |
| browsers.nix | | | ✅ | ✅ | ✅ | ✅ |
| development.nix | | | ✅ | ✅ | ✅ | ✅ |
| office.nix | | | | ✅ | ✅ | ✅ |
| communication.nix | | | | ✅ | ✅ | ✅ |
| media.nix | | | | ✅ | ✅ | ✅ |
| creative.nix (AMD GPU) | | | | | ✅ | ✅ |
| **Security & Network** | | | | | | |
| wireguard-mullvad.nix | | | | | | ✅ |
| malware-scanner.nix | | | | | | ✅ |
| **External Packages** | | | | | | |
| Affinity Apps (flake) | | | | | ✅ | ✅ |
| **Integration** | | | | | | |
| Home Manager | | | | | | ✅ |
| Secrets (Phase 2) | | | | | | ✅ |

## Device-Specific Differences

### laptop-intel
- **Hardware**: `modules/hardware/intel-laptop.nix`
- **Creative**: Basic tools only (no DaVinci - Intel GPU not supported)
- **No OpenRGB**: No RGB peripherals

### framework
- **Hardware**: `modules/hardware/amd-laptop.nix`
- **Creative**: Full suite (DaVinci Resolve Studio + Affinity)
- **No OpenRGB**: No RGB peripherals
- **No Go XLR**: Standard audio only

### devtower
- **Hardware**: `modules/hardware/amd-desktop.nix`
- **Creative**: Full suite (DaVinci Resolve Studio + Affinity)
- **Go XLR**: `modules/hardware/go-xlr.nix` (Stage 5+)
- **OpenRGB**: `modules/hardware/openrgb.nix` (Stage 6 only)

## Flake Integration

### Affinity Apps

Added via `affinity-nix.nixosModules.default` in flake.nix for:
- `{device}-creative` (Stage 5)
- `{device}` (Stage 6 - full)

**Usage**: Affinity Designer, Photo, and Publisher are automatically available after Stage 5.

### Hyprland

Added via `hyprland` flake input, enabled in `modules/desktop/hyprland/`.

**Note**: Hyprland is NOT enabled in Stage 1 (minimal). It's first enabled in Stage 2 (desktop).

## Runtime Configuration

These modules provide FRAMEWORKS only - actual configuration happens at runtime:

### Storage Modules
- **restic.nix**: Use `restic-manage` CLI to configure backups
- **zfs.nix**: Use `zfs-manage` CLI to create pools/datasets
- **raid.nix**: Use `raid-manage` CLI to create arrays

**Example**:
```bash
# After Stage 1 (minimal), storage tools are available:
restic-manage add-repo local /mnt/backups
zfs-manage create-pool tank mirror /dev/sda /dev/sdb
raid-manage create raid1 /dev/md0 /dev/sdc /dev/sdd
```

### VPN Module
- **wireguard-mullvad.nix**: Use `wireguard-helper` CLI to configure VPN

**Example**:
```bash
# After Stage 6 (full), VPN tools are available:
wireguard-helper init
wireguard-helper rotate
```

### Security Module
- **malware-scanner.nix**: Use `malware-scanner` CLI to manage scanning

**Example**:
```bash
# After Stage 6 (full), malware scanner is available:
malware-scanner scan /home
malware-scanner quarantine list
```

## Why This Distribution?

### Early Stages (1-2)
- **Lightweight**: Get bootable system quickly
- **Essential**: Only what's needed to verify hardware works
- **Storage ready**: Tools available for backup/RAID setup after install

### Middle Stages (3-4)
- **Progressive testing**: Add software groups incrementally
- **Isolate issues**: Easy to identify which software group causes problems

### Late Stages (5-6)
- **GPU-dependent**: Creative software requires proper GPU
- **Security last**: VPN and malware scanner added after everything else works
- **Final integration**: Home Manager and secrets in Stage 6

## Enabling/Disabling Modules

All storage, VPN, and malware modules are **enabled by default** in their respective stages.

To **disable** a module at runtime:

```nix
# In configuration-full.nix, set:
services.restic-runtime.enable = false;
services.zfs-runtime.enable = false;
services.raid-runtime.enable = false;
networking.wireguard-mullvad.enable = false;
security.malwareScanner.enable = false;
```

## Next Steps After Stage 6

1. **Configure VPN**:
   ```bash
   wireguard-helper init
   ```

2. **Set up backups**:
   ```bash
   restic-manage add-repo b2 b2:my-bucket
   restic-manage add-backup home /home b2 daily
   ```

3. **Enable malware scanner**:
   ```bash
   # Already enabled by default
   # Check status:
   systemctl status malware-monitor
   ```

4. **Activate secrets** (Phase 2):
   - Uncomment secrets module in `configuration-full.nix`
   - Follow `PHASE-2-SECRETS-SETUP.md`

5. **Daily updates**:
   ```bash
   cd /etc/nixos/nix-config
   nix flake update
   sudo nixos-rebuild switch --flake .#{device}
   ```

## Documentation Cross-References

- **Staged Installation**: `docs/STAGED-INSTALLATION-GUIDE.md`
- **Quick Reference**: `docs/STAGED-INSTALL-QUICK-REF.md`
- **Storage Management**: `docs/STORAGE-MANAGEMENT.md` (if exists)
- **VPN Setup**: `docs/WIREGUARD-MULLVAD-SETUP.md` (if exists)
- **Malware Scanner**: `rust/malware-scanner/README.md`
- **Secrets Setup**: `PHASE-2-SECRETS-SETUP.md`
