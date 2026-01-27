# Version History

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

Technical change log with implementation details for developers.

---

## [0.1.0] - 27/01/2026

### Type: MINOR (New Features)

### Summary
Documentation consolidation and module distribution implementation for NixOS configuration. Reduced documentation files from 29 to 9 active files (68% reduction), implemented 6-stage progressive installation system, and added Affinity Apps integration.

### Changes Added

#### Documentation Consolidation
- Created `docs/README.md` - Central documentation hub with navigation
- Created `docs/INSTALLATION.md` - Comprehensive staged installation guide
- Created `docs/SECRETS.md` - Per-device secrets architecture and setup
- Created `docs/VPN.md` - Mullvad WireGuard VPN configuration guide
- Created `docs/STORAGE.md` - Storage management (Restic, ZFS, RAID)
- Created `docs/MALWARE-SCANNER.md` - Malware protection documentation
- Created `docs/UPDATES.md` - System update procedures
- Created `docs/ARCHITECTURE.md` - System architecture documentation
- Created `docs/DAVINCI-RESOLVE-AMD.md` - DaVinci Resolve setup guide
- Created `docs/NEOVIM-SETUP.md` - Neovim configuration guide
- Moved 20 legacy documentation files to `docs/archive/` for historical reference

#### Module Distribution Implementation
- **Stage 1 (Minimal)**: Added storage modules (Restic, ZFS, RAID) to all minimal configurations
  - Updated `hosts/laptop-intel/configuration-minimal.nix`
  - Created `hosts/framework/configuration-minimal.nix`
  - Created `hosts/devtower/configuration-minimal.nix`
- **Stage 2-4**: Created intermediate stage configurations for all devices
  - Desktop, Development, and Productivity stages for laptop-intel, framework, devtower
- **Stage 5 (Creative)**: Added Affinity Apps to creative stage configurations
  - Updated `hosts/laptop-intel/configuration-creative.nix`
  - Created `hosts/framework/configuration-creative.nix`
  - Created `hosts/devtower/configuration-creative.nix`
- **Stage 6 (Full)**: Added VPN and malware scanner to full configurations
  - Updated `hosts/laptop-intel/configuration-full.nix`
  - Created `hosts/framework/configuration-full.nix`
  - Created `hosts/devtower/configuration-full.nix`

#### Flake Integration
- Enabled Hyprland input in `flake.nix` (uncommented)
- Enabled Affinity Apps input in `flake.nix` (uncommented)
- Configured all 6 installation stages for 3 devices (18 total configurations)

#### Module Updates
- Updated `modules/software/creative.nix` - Added Affinity Apps package
- Updated `modules/core/nix-settings.nix` - Enhanced Nix daemon settings
- Updated `.claude/CLAUDE.md` - Reflected new documentation structure and staged installation approach

#### Root Documentation
- Updated `README.md` - Simplified with links to new docs structure, highlighted staged installation system

### Files Changed
- `.claude/CLAUDE.md` - Updated installation instructions and documentation references
- `README.md` - Restructured with staged installation focus
- `flake.nix` - Enabled Hyprland and Affinity inputs, configured 18 host configurations
- `modules/core/nix-settings.nix` - Enhanced Nix settings
- `modules/software/creative.nix` - Added Affinity Apps integration
- `hosts/laptop-intel/configuration-minimal.nix` - Added storage modules
- `hosts/laptop-intel/configuration-creative.nix` - Added Affinity Apps
- `hosts/laptop-intel/configuration-full.nix` - Added VPN and malware scanner
- `hosts/framework/configuration-*.nix` - Created all 6 stages (new files)
- `hosts/devtower/configuration-*.nix` - Created all 6 stages (new files)
- `docs/README.md` - Created documentation hub (new file)
- `docs/INSTALLATION.md` - Created comprehensive installation guide (new file)
- `docs/SECRETS.md` - Created secrets management guide (new file)
- `docs/VPN.md` - Created VPN configuration guide (new file)
- `docs/STORAGE.md` - Created storage management guide (new file)
- `docs/MALWARE-SCANNER.md` - Moved from root (existing file)
- `docs/UPDATES.md` - Created update procedures guide (new file)
- `docs/ARCHITECTURE.md` - Moved from root (existing file)
- `docs/DAVINCI-RESOLVE-AMD.md` - Moved from root (existing file)
- `docs/NEOVIM-SETUP.md` - Moved from root (existing file)
- `docs/archive/*` - Archived 20 legacy documentation files

### Technical Details

**Documentation Reduction**: 68% reduction (29 → 9 active files)
- Eliminates documentation sprawl
- Provides clear navigation via central hub
- Preserves historical documentation in archive

**Staged Installation System**: 6 progressive stages
- Stage 1 (Minimal): Base OS + storage management
- Stage 2 (Desktop): Hyprland desktop environment
- Stage 3 (Development): Dev tools and language servers
- Stage 4 (Productivity): Office and communication software
- Stage 5 (Creative): Affinity Apps, Blender, GIMP, DaVinci Resolve
- Stage 6 (Full): All stages + VPN + malware scanner

**Multi-Device Support**: 3 devices × 6 stages = 18 configurations
- laptop-intel: Intel i5-10210U, 32GB RAM, Intel UHD Graphics
- framework: AMD Ryzen, 64GB RAM, AMD Radeon
- devtower: AMD desktop, 64GB RAM, AMD Radeon + Go XLR

**Affinity Apps Integration**: Via affinity-nix flake
- Affinity Designer (vector graphics)
- Affinity Photo (photo editing)
- Affinity Publisher (desktop publishing)

### Testing Required
- [ ] Verify all 18 flake configurations build successfully
- [ ] Test staged installation on laptop-intel (primary device)
- [ ] Verify storage modules work in minimal configuration
- [ ] Test Affinity Apps in creative stage
- [ ] Verify VPN and malware scanner in full configuration
- [ ] Validate documentation links and navigation

### Migration Notes
- Legacy documentation files moved to `docs/archive/` (not deleted)
- All documentation links updated to new structure
- Staged installation is now the recommended installation method
- Full configuration remains available for direct installation (not recommended due to tmpfs limits)

---

## Version Format

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes (incompatible API changes)
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)

## Previous Versions

No previous tagged versions. This is the initial version file creation.
