# Documentation Index

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

Complete documentation for the nix-config NixOS configuration.

## Getting Started

Start here if you're new to this project:

1. **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design overview
2. **[INSTALLATION.md](INSTALLATION.md)** - Complete NixOS installation guide (6 stages)
3. **[SECRETS.md](SECRETS.md)** - Per-device secrets setup with Agenix

## Feature Guides

Detailed guides for specific features:

### Core Features

| Feature | Guide | Purpose |
|---------|-------|---------|
| Installation | [INSTALLATION.md](INSTALLATION.md) | NixOS setup from bootable USB |
| Secrets Management | [SECRETS.md](SECRETS.md) | GitHub SSH keys and server credentials |
| VPN (Mullvad) | [VPN.md](VPN.md) | WireGuard multi-hop VPN setup |
| Storage | [STORAGE.md](STORAGE.md) | Restic backups, ZFS, and RAID |
| Malware Scanner | [MALWARE-SCANNER.md](MALWARE-SCANNER.md) | Boot-time and real-time threat protection |

### Software-Specific

| Software | Guide | Purpose |
|----------|-------|---------|
| DaVinci Resolve (AMD) | [DAVINCI-RESOLVE-AMD.md](DAVINCI-RESOLVE-AMD.md) | Video editing on AMD GPU |
| Neovim | [NEOVIM-SETUP.md](NEOVIM-SETUP.md) | Editor configuration |

## Quick Reference

### 5-Minute Quickstart

```bash
# Installation
nixos-install --flake .#laptop-intel-minimal
sudo nixos-rebuild switch --flake .#laptop-intel-desktop

# Secrets
agenix-helper edit github-ssh-personal-laptop-intel
sudo nixos-rebuild switch

# VPN
just vpn-rotate laptop-intel
just vpn-up
just vpn-verify

# Backups
restic-manage add-backup home --paths /home --repository local
restic-backup-now home
```

### Common Commands

```bash
# System management
sudo nixos-rebuild switch --flake .#laptop-intel    # Apply changes
nix flake update                                      # Update inputs
sudo nix-collect-garbage -d                           # Clean old stuff

# VPN
just vpn-up       # Start VPN
just vpn-status   # Check status
just vpn-verify   # Test connection

# Backups
restic-backup-now home                                # Run backup
restic-repo local snapshots                           # List backups

# Malware
malware-scanner scan ~/Downloads --quarantine        # Scan directory
malware-scanner test                                 # Test detection
```

### Device Configuration

Replace `laptop-intel` with your device name:
- `laptop-intel` - Intel i5-10210U, 32GB, Intel UHD Graphics
- `framework` - AMD Ryzen, 64GB, AMD Radeon
- `devtower` - AMD CPU + GPU, 64GB, Go XLR audio

## Documentation Structure

```
docs/
├── README.md                    # This file
├── ARCHITECTURE.md              # System architecture
├── INSTALLATION.md              # NixOS installation (merged from 5 files)
├── SECRETS.md                   # Secrets setup (merged from 2 files)
├── VPN.md                       # VPN setup (merged from 2 files)
├── STORAGE.md                   # Storage systems (merged from 2 files)
├── MALWARE-SCANNER.md           # Threat protection
├── DAVINCI-RESOLVE-AMD.md       # Video editing
├── NEOVIM-SETUP.md              # Editor setup
└── archive/                     # Historical/obsolete documentation
    ├── PHASE-*-COMPLETE.md      # Phase summaries
    ├── *-IMPLEMENTATION.md      # Implementation notes
    ├── *-SUMMARY.md             # Feature summaries
    └── MINIMAL-CONFIG-TEMPLATE.md
```

## Installation

### Choose Your Path

#### Fresh NixOS Installation

1. Read: [INSTALLATION.md](INSTALLATION.md)
2. Follow: 10-step pre-installation
3. Install: Stage 1 (minimal)
4. Build up: Stages 2-6 as needed

#### Add Secrets to Existing System

1. Read: [SECRETS.md](SECRETS.md)
2. Generate: Per-device GitHub SSH keys
3. Encrypt: With Agenix
4. Deploy: Via system rebuild

#### Enable VPN on Existing System

1. Read: [VPN.md](VPN.md)
2. Setup: Mullvad account
3. Initialize: WireGuard keys
4. Deploy: Via system rebuild

#### Setup Backups on Existing System

1. Read: [STORAGE.md](STORAGE.md)
2. Choose: Restic, ZFS, or RAID
3. Configure: Backup destinations
4. Enable: Systemd timers

## Installation Stages

The staged installation approach builds up your system progressively:

| Stage | Target | What's Included | Purpose | Time |
|-------|--------|-----------------|---------|------|
| 1 | `{device}-minimal` | Base OS, network, shell | Boot test | 10-20 min |
| 2 | `{device}-desktop` | Hyprland, terminal, launcher | Desktop environment | 15-30 min |
| 3 | `{device}-dev` | Browsers, dev tools, language servers | Development | 20-40 min |
| 4 | `{device}-productivity` | LibreOffice, Discord, Zoom, VLC | Office & communication | 15-25 min |
| 5 | `{device}-creative` | Blender, GIMP, DaVinci (GPU-dependent) | Creative software | 30-60 min |
| 6 | `{device}` | ALL stages combined | **Daily use** | 5-30 min updates |

See [INSTALLATION.md](INSTALLATION.md) for complete walkthrough.

## Key Features

### Per-Device Secrets

Each device has **unique** SSH keys for GitHub and servers:
- Device loss only exposes that device's keys
- Independent key rotation per device
- Audit trail of which device accessed what
- Two-tier security (GitHub keys without passphrase, server keys with passphrase)

**Setup**: [SECRETS.md](SECRETS.md)

### Multi-Hop VPN

Mullvad WireGuard with 5+ server hops:
- Entry → Relay1 → Relay2 → Relay3 → Exit
- VPN provider can't see your origin or destination
- Kill switch blocks traffic if VPN drops
- Split tunneling keeps LAN functional

**Setup**: [VPN.md](VPN.md)

### Staged Installation

Avoid tmpfs issues and verify each layer:
- Stage 1: Minimal base system (installation only)
- Stages 2-5: Add features progressively
- Stage 6: Full config for daily use

**Details**: [INSTALLATION.md](INSTALLATION.md)

### Encrypted Backups

Restic provides client-side encrypted backups to:
- Local filesystem
- Backblaze B2 (cloud)
- Amazon S3
- SFTP servers

**Setup**: [STORAGE.md](STORAGE.md)

### Malware Protection

Multi-engine threat detection:
- ClamAV signatures (8+ million)
- YARA pattern matching
- Behavioral heuristics
- Hash-based detection
- Entropy analysis

**Setup**: [MALWARE-SCANNER.md](MALWARE-SCANNER.md)

## Configuration Examples

### Enable All Core Features

Edit `hosts/laptop-intel/configuration.nix`:

```nix
{
  imports = [
    # Secrets
    ../../modules/core/secrets-laptop.nix

    # VPN
    ../../modules/network/wireguard-mullvad.nix

    # Storage
    ../../modules/storage/restic.nix

    # Security
    ../../modules/security/malware-scanner.nix
  ];

  # Secrets configuration
  # (Host key and agenix setup required first)

  # VPN configuration
  networking.wireguard-mullvad = {
    enable = true;
    device = "laptop-intel";
    enableKillSwitch = true;
    autoRotate.enable = true;
  };

  # Storage configuration
  services.restic-runtime.enable = true;

  # Malware scanner configuration
  security.malwareScanner = {
    enable = true;
    bootScan.enable = true;
    realTimeMonitoring.enable = true;
  };
}
```

Rebuild: `sudo nixos-rebuild switch --flake .#laptop-intel`

## Troubleshooting

### "Permission denied" errors

Check permissions on SSH keys:
```bash
ls -la ~/.ssh/
# Should be: -rw------- (0600)
chmod 0600 ~/.ssh/github-*
```

### VPN won't connect

Check connection and configuration:
```bash
just vpn-status
journalctl -u wg-quick-mullvad0 -n 50
```

### Backups not running

Verify timer is active:
```bash
systemctl list-timers restic-backup@home.timer
journalctl -u restic-backup@home.service
```

### See [INSTALLATION.md](INSTALLATION.md), [SECRETS.md](SECRETS.md), [VPN.md](VPN.md), [STORAGE.md](STORAGE.md), and [MALWARE-SCANNER.md](MALWARE-SCANNER.md) for detailed troubleshooting sections.

## Next Steps

1. **Read ARCHITECTURE.md** - Understand the system design
2. **Follow INSTALLATION.md** - Get NixOS running
3. **Complete SECRETS.md** - Set up per-device SSH keys
4. **Optional: VPN.md** - Add Mullvad VPN
5. **Optional: STORAGE.md** - Configure backups or storage
6. **Optional: MALWARE-SCANNER.md** - Enable threat protection

## Support and Resources

- **Project**: [nix-config](https://github.com/SamBailey6194/nix-config)
- **Main Guide**: [../CLAUDE.md](../CLAUDE.md)
- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **Home Manager**: https://nix-community.github.io/home-manager/
- **Hyprland Wiki**: https://wiki.hyprland.org/
- **Mullvad**: https://mullvad.net/support

## Documentation History

This documentation was consolidated from multiple sources:

### Merged Files
- QUICK-START.md
- QUICK-START-VPN.md
- STAGED-INSTALLATION-GUIDE.md
- MINIMAL-INSTALL-GUIDE.md
- INSTALL.md
- INSTALL-QUICK-REF.md
- PHASE-2-SECRETS-SETUP.md
- PER-DEVICE-SECRETS.md
- PHASE-6-WIREGUARD-MULLVAD.md
- STORAGE-MANAGEMENT.md
- STORAGE-QUICKSTART.md
- MALWARE-SCANNER-QUICKSTART.md

### Archived Files
Historical phase documentation and implementation notes are in `archive/`:
- PHASE-*-COMPLETE.md
- *-IMPLEMENTATION.md
- *-SUMMARY.md
- Other obsolete guides

**Why consolidate?**
- Single source of truth for each feature
- Reduced duplication
- Easier maintenance
- Clear entry points for users
- Phase notes preserved for reference

## License

This documentation and configuration are provided as-is. See the main repository for license details.

---

**Last Updated**: 2026-01-27
**Maintained By**: Sam Bailey
**Version**: Phase 2 Complete ✅
