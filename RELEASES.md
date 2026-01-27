# Release Notes

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

User-facing release notes and feature highlights.

---

## Version 0.1.0 - Documentation Consolidation and Module Distribution

**Released**: 27/01/2026

### What's New

#### Streamlined Documentation
Your documentation is now organised in a single `docs/` directory with a central navigation hub. We've reduced active documentation from 29 files to just 9, making it much easier to find what you need.

**Quick Access**:
- Installation Guide - Step-by-step installation with 6 progressive stages
- Secrets Management - Per-device SSH key management and encryption
- VPN Setup - Mullvad WireGuard configuration with kill switch
- Storage Management - Backup, ZFS, and RAID configuration
- Security - Malware scanning and protection

#### Progressive Installation System
Install your NixOS system in 6 stages to avoid installation failures:

1. **Minimal** (10-20 min) - Base OS with storage management
2. **Desktop** (15-30 min) - Hyprland Wayland compositor
3. **Development** (20-40 min) - Browsers and dev tools
4. **Productivity** (15-25 min) - Office and communication
5. **Creative** (30-60 min) - Affinity Apps, Blender, GIMP, DaVinci Resolve
6. **Full** (5-30 min) - Everything together with VPN and malware protection

Each stage verifies the previous one works before adding more software.

#### Affinity Apps Integration
Professional creative software is now available in Stage 5:
- **Affinity Designer** - Vector graphics and illustration
- **Affinity Photo** - Professional photo editing
- **Affinity Publisher** - Desktop publishing and layout

Perfect for design work, photo editing, and document creation.

#### Multi-Device Ready
Pre-configured installations for three devices:
- **laptop-intel** - Intel laptop with integrated graphics (ready for installation)
- **framework** - AMD Framework laptop with dedicated GPU (future)
- **devtower** - AMD desktop with Go XLR audio interface (future)

### Improvements

- **Storage from Day 1**: Backup tools (Restic), ZFS, and RAID management available immediately in minimal installation
- **Better Organisation**: All core modules properly distributed across installation stages
- **Clearer Navigation**: Documentation hub provides easy access to all guides
- **Historical Archive**: Legacy documentation preserved in `docs/archive/` for reference

### Installation

If you're installing for the first time:

```bash
# Stage 1: Minimal installation
nixos-install --flake .#laptop-intel-minimal

# After reboot, progressively add features:
sudo nixos-rebuild switch --flake .#laptop-intel-desktop       # Stage 2
sudo nixos-rebuild switch --flake .#laptop-intel-dev           # Stage 3
sudo nixos-rebuild switch --flake .#laptop-intel-productivity  # Stage 4
sudo nixos-rebuild switch --flake .#laptop-intel-creative      # Stage 5
sudo nixos-rebuild switch --flake .#laptop-intel               # Stage 6 (full)
```

See `docs/INSTALLATION.md` for complete installation guide.

### Documentation

- **Getting Started**: [docs/INSTALLATION.md](docs/INSTALLATION.md)
- **Documentation Hub**: [docs/README.md](docs/README.md)
- **Architecture**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

### Coming Next

- Complete NixOS installation on laptop-intel (Phase 1)
- Multi-device synchronisation with Syncthing (Phase 3)
- Enhanced Hyprland configuration with device-specific keybinds (Phase 4)

---

## About Releases

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 0.1.0)
- **MAJOR**: Breaking changes
- **MINOR**: New features
- **PATCH**: Bug fixes

Pre-1.0 versions (0.x.x) indicate development phase.
