# Changelog

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 27/01/2026

### Added
- Documentation consolidation: Created central hub (`docs/README.md`) with 9 active documentation files
- Staged installation system: 6 progressive stages to avoid tmpfs issues during installation
- Multi-device support: Configurations for laptop-intel, framework, and devtower (18 total configurations)
- Affinity Apps integration: Designer, Photo, and Publisher via affinity-nix flake
- Storage modules in Stage 1 (Minimal): Restic, ZFS, and RAID management available from first boot
- VPN and malware scanner in Stage 6 (Full): Mullvad WireGuard and ClamAV protection

### Changed
- Moved 20 legacy documentation files to `docs/archive/` for historical reference
- Enabled Hyprland and Affinity Apps inputs in `flake.nix`
- Updated `README.md` to focus on staged installation approach
- Enhanced `modules/software/creative.nix` with Affinity Apps package

### Deprecated
- Direct full configuration installation (still available but not recommended due to tmpfs limits)

---

## Release Notes

### Version 0.1.0 - Documentation Consolidation and Module Distribution

**Focus**: Improved documentation structure and progressive installation system

**Key Improvements**:
- 68% reduction in active documentation files (29 → 9)
- 6-stage installation system for reliable deployment
- Multi-device support with 18 pre-configured installation stages
- Affinity Apps for creative workflows
- Storage management available from minimal installation

**Installation**: Use staged installation starting with `nixos-install --flake .#{device}-minimal`

**Documentation**: All guides available in `docs/` directory with central navigation hub
