# Changelog

**Last Updated**: 03/02/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## Table of Contents

- [Unreleased](#unreleased)
- [1.0.0 - 03/02/2026](#100---03022026) 🎉
- [0.12.0 - 30/01/2026](#0120---30012026)
- [0.10.0 - 30/01/2026](#0100---30012026)
- [0.9.2 - 30/01/2026](#092---30012026)
- [0.9.1 - 30/01/2026](#091---30012026)
- [0.8.0 - 29/01/2026](#080---29012026)
- [0.7.1 - 29/01/2026](#071---29012026)
- [0.7.0 - 29/01/2026](#070---29012026)
- [0.6.7 - 28/01/2026](#067---28012026)
- [0.6.6 - 28/01/2026](#066---28012026)
- [0.6.5 - 28/01/2026](#065---28012026)
- [0.6.4 - 27/01/2026](#064---27012026)
- [0.6.3 - 27/01/2026](#063---27012026)
- [0.6.2 - 27/01/2026](#062---27012026)
- [0.6.1 - 27/01/2026](#061---27012026)
- [0.6.0 - 27/01/2026](#060---27012026)
- [0.5.10 - 25/01/2026](#0510---25012026)
- [0.5.0 - 25/01/2026](#050---25012026)
- [0.4.0 - 24/01/2026](#040---24012026)
- [0.3.0 - 24/01/2026](#030---24012026)
- [0.2.0 - 24/01/2026](#020---24012026)
- [0.1.0 - 14-20/01/2026](#010---14-20012026)
- [0.0.1 - 14/01/2026](#001---14012026)

---

## [Unreleased]

### Added
- Nothing yet

---

## [1.0.0] - 03/02/2026 🎉

**PRODUCTION READY MILESTONE** - First stable release with comprehensive encryption, multi-device support, and production-grade security.

### Added
- **LUKS + BTRFS Encryption Support**: Full disk encryption with TPM2 auto-unlock and password fallback
  - LUKS encryption modules with TPM2 integration (`modules/security/luks-encryption.nix`)
  - BTRFS filesystem with subvolumes, compression, and snapshots (`modules/filesystem/btrfs.nix`)
  - BTRFS layout presets for laptop and devtower configurations (`modules/filesystem/btrfs-layouts.nix`)
  - zram compressed swap support (no swap partition needed) (`modules/filesystem/zram.nix`)
  - Automatic LUKS header backups for disaster recovery
  - TRIM support for SSD performance with encryption

- **Comprehensive Installation Guide**: Production-ready installation documentation
  - Device-specific instructions for laptop-intel, framework, and devtower (`docs/INSTALLATION.md`)
  - Side-by-side comparison: Standard (ext4) vs LUKS+BTRFS installation methods
  - Multi-drive setup guide for devtower (OS, home, and media drives)
  - TPM2 auto-unlock configuration guide
  - BTRFS snapshot management and rollback procedures
  - Staged installation workflow (6 stages from minimal to full)
  - Comprehensive troubleshooting section
  - Installation checklist for tracking progress

- **Security Modules**: Production-grade security tooling
  - Encryption tools suite with GPG, VeraCrypt, 7-Zip, gocryptfs (`modules/security/encryption-tools.nix`)
  - Folder-based encryption with EncFS and CryFS (`modules/security/folder-encryption.nix`)
  - Hardened SSH daemon configuration (`modules/security/ssh-daemon.nix`)
  - Security implementation documentation (`SECURITY-IMPLEMENTATION-SUMMARY.md`)
  - Encryption guide for end-users (`docs/ENCRYPTION-GUIDE.md`)

- **Rust Storage Management Tools**: CLI utilities for managing encrypted storage
  - `btrfs-manage`: BTRFS pool creation, snapshot management, and scrubbing
  - `luks-manage`: LUKS container management and key rotation
  - `tpm-manage`: TPM2 enrollment and key management
  - `vault-manage`: HashiCorp Vault integration for secrets storage

- **Remote Desktop Infrastructure** (ready to enable):
  - Wireguard + Defguard + RustDesk remote desktop setup (`modules/network/remote-desktop.nix`)
  - 2FA authentication gateway via Defguard
  - Zero-trust remote access over Wireguard VPN
  - Firewall rules scoped to Wireguard interface only
  - Documentation for enabling remote desktop features

- **Multi-Device Support**: Enhanced device-specific configurations
  - Device-specific BTRFS layouts (single-drive laptop vs multi-drive devtower)
  - Per-device encryption settings with hardware-appropriate defaults
  - GPU-specific creative software configurations
  - RAM-appropriate zram swap sizing

### Changed
- **Updated INSTALLATION.md**: Integrated encryption options throughout installation workflow
- **Enhanced configuration-full.nix**: Added commented imports for all new security and filesystem modules
- **Improved remote-desktop.nix**: Added future Wireguard/Defguard/RustDesk setup alongside existing Tailscale
- **Updated flake inputs**: Added dependencies for new Rust storage management tools

### Removed
- **Deleted fuzzing workflow**: Removed `.github/workflows/fuzzing.yml` (not applicable to NixOS configs)

### Security
- ✅ Full disk encryption with LUKS2
- ✅ TPM2 integration for auto-unlock with password fallback
- ✅ BTRFS with transparent compression (zstd)
- ✅ Automatic snapshots for system rollback
- ✅ Hardware-appropriate security defaults per device
- ✅ Zero-trust remote desktop architecture (Wireguard + 2FA)

### Breaking Changes
- None - all encryption and security features are opt-in
- Existing configurations continue to work without modification
- New installations can choose Standard or LUKS+BTRFS at install time

### Migration Notes
- **New installations**: Choose LUKS+BTRFS during initial setup for full encryption
- **Existing systems**: Can migrate to encryption by backing up, repartitioning, and restoring
- **Standard installations**: Continue to work as-is with no changes required

### Version Significance
This 1.0.0 release marks the configuration as **production-ready** with:
- ✅ Comprehensive security features (encryption, TPM2, hardening)
- ✅ Multi-device support (laptop-intel, framework, devtower)
- ✅ Complete installation documentation
- ✅ Disaster recovery capabilities (snapshots, LUKS header backups)
- ✅ Professional remote desktop infrastructure (ready to enable)

---

## [0.12.0] - 30/01/2026

### Added
- Native Nix package for Claude Code via `claude-code-nix` flake input
- Automatic hourly updates for Claude Code through Nix package management
- Nixpkgs overlay to provide `pkgs.claude-code` across all modules

### Changed
- Replaced curl-based Claude Code installation with native Nix package
- Removed `.local/bin` PATH addition from shell configuration (no longer needed)
- Updated documentation in `nix-settings.nix` to reflect native package installation

### Removed
- Manual PATH configuration for Claude Code installation directory

---

## [0.10.0] - 30/01/2026

### Added
- Python 3.14 as default Python version for new development projects
- Python 3.13 maintained for legacy project support
- Complete package management tooling (pip, virtualenv) for both Python versions
- Seamless integration with UV package manager for fast dependency installation

### Changed
- Updated development environment to support latest Python 3.14 features
- Dual Python version support enables smooth migration path from legacy to modern Python

---

## [0.9.2] - 30/01/2026

### Fixed
- Hyprland configuration syntax errors across all device configs (laptop-intel, framework, devtower)
- Converted deprecated colon syntax to new nested block syntax for decoration settings
- Fixed animation bezier definitions using correct top-level `bezier` keyword
- Prevents Hyprland boot errors due to deprecated syntax

### Changed
- Added explicit monitor configuration for laptop-intel (1920x1080@60 on eDP-1)
- Migrated `decoration:blur:size` syntax to nested `decoration { blur { size } }` blocks
- Migrated `animations:bezier` to top-level `bezier` declarations

---

## [0.9.1] - 30/01/2026

### Fixed
- Home Manager file collision errors during `nixos-rebuild switch`
- Comprehensive legacy dotfile cleanup system backs up 40+ conflicting files before Home Manager activation
- Automatic one-time cleanup prevents mimeapps.list and other file conflicts

### Added
- `home/modules/legacy-cleanup.nix` - Modular legacy file backup and removal system
- `docs/LEGACY-FILE-CLEANUP.md` - User guide for backup and restoration
- `docs/LEGACY-CLEANUP-IMPLEMENTATION.md` - Technical implementation details

### Changed
- Refactored `home/stages/base.nix` - Replaced inline backup script with modular legacy-cleanup import
- Removed inline mimeapps.list cleanup from `home/stages/desktop.nix` (now handled by module)

---

## [0.9.0] - 29/01/2026

### Added
- Tailscale VPN service for secure mesh networking across devices
- Remmina remote desktop client for VNC/RDP connections to client computers
- Firewall rules for Tailscale traffic (trusted interface)
- Optional x11vnc server configuration for incoming remote connections
- Comprehensive setup guide: `docs/TAILSCALE-REMMINA-SETUP.md`

### Technical Details
- Tailscale service enabled with automatic network-online dependency
- Firewall configured with `checkReversePath = "loose"` for Tailscale
- Remmina installed with VNC, RDP, and SSH protocol support
- x11vnc server configuration provided (commented out by default for security)
- VNC firewall rules configured to only allow Tailscale interface connections
- Deployed across all hosts: laptop-intel, framework, devtower

---

## [0.8.0] - 29/01/2026

### Added
- NVM (Node Version Manager) integration in zsh shell configuration
- Auto-initialisation of NVM in shell sessions via `home/modules/shell.nix`
- Support for XDG-compliant NVM directory configuration

### Technical Details
- NVM_DIR automatically set to `~/.nvm` or `$XDG_CONFIG_HOME/nvm`
- NVM script sourced on shell initialisation if present
- Proper Nix escaping for shell variables in Home Manager configuration

---

## [0.7.1] - 29/01/2026

### Fixed
- Fixed duplicate `decoration` blocks in Hyprland device-specific configurations causing boot errors
- Converted nested decoration/animation blocks to direct property overrides using colon syntax
- Applied fix to laptop-intel.conf, framework.conf, and devtower.conf

### Changed
- Replaced `decoration { blur { ... } }` syntax with `decoration:blur:property = value` syntax
- Replaced `animations { ... }` block in devtower.conf with individual animation property overrides

---

## [0.7.0] - 29/01/2026

### Added
- Progressive staged installation with Home Manager integration across all 6 stages
- Greetd display manager for lightweight Wayland-native session management
- UEFI boot order management with efibootmgr package
- Modular Hyprland configuration split into separate .conf files

### Changed
- Switched Hyprland configuration from Nix expressions to native .conf format
- Replaced LightDM display manager with greetd for better Wayland support
- Integrated Home Manager into desktop stage configuration

### Fixed
- Improved Hyprland startup performance by eliminating Nix evaluation overhead

---

## [0.6.7] - 28/01/2026

### Fixed
- Removed duplicate xdg-desktop-portal-hyprland declaration

---

## [0.6.6] - 28/01/2026

### Fixed
- Resolved systemd service symlink collision in Hyprland module

---

## [0.6.5] - 28/01/2026

### Changed
- Updated deprecated nix.gc options to new syntax

### Fixed
- Resolved dependency errors in Nix configuration
- Fixed package dependency resolution issues

---

## [0.6.4] - 27/01/2026

### Fixed
- Corrected noto-fonts-cjk package name in Hyprland module
- Replaced invalid programs.ssh options with system-level SSH configuration
- Blacklisted rtsx_pci kernel modules to prevent 90-second boot hang on laptop-intel
- Updated hardware configuration for better hardware compatibility

---

## [0.6.3] - 27/01/2026

### Added
- Flake.lock file for reproducible builds (then removed from version control)

### Changed
- Added flake.lock to .gitignore for user-specific lock files

---

## [0.6.2] - 27/01/2026

### Fixed
- Resolved duplicate environment.systemPackages declarations in storage modules
- Updated ZFS module configuration for NixOS compatibility
- Fixed syntax errors in storage module declarations

---

## [0.6.1] - 27/01/2026

### Added
- Minimal installation configuration for bare-bones NixOS deployment
- Minimal installation documentation guide
- Zsh shell enabled in minimal installation
- Device-specific SSH keys added to configuration

### Changed
- Removed problematic packages from base configuration for installation compatibility
- Commented out unused SSH keys until installation completion

---

## [0.6.0] - 27/01/2026

### Added
- Documentation consolidation: Created central hub with 9 active documentation files
- Staged installation system: 6 progressive stages to avoid tmpfs issues
- Multi-device support: Configurations for laptop-intel, framework, and devtower (18 total)
- Affinity Apps integration: Designer, Photo, and Publisher via affinity-nix flake
- Storage modules in Stage 1 (Minimal): Restic, ZFS, and RAID management
- VPN and malware scanner in Stage 6 (Full): Mullvad WireGuard and ClamAV

### Changed
- Moved 20 legacy documentation files to `docs/archive/` for historical reference
- Enabled Hyprland and Affinity Apps inputs in flake.nix
- Updated README.md to focus on staged installation approach
- Enhanced modules/software/creative.nix with Affinity Apps package

### Deprecated
- Direct full configuration installation (still available but not recommended)

---

## [0.5.10] - 25/01/2026

### Fixed
- Temporarily disabled Affinity Apps module for NixOS installation compatibility
- Fixed WireGuard module import structure by moving imports to top level
- Escaped empty strings in Neovim lualine configuration
- Removed duplicate zsh initExtra and Ubuntu-specific configuration
- Fixed sessionPath usage in Home Manager configuration
- Corrected Ubuntu font family name in configuration

---

## [0.5.0] - 25/01/2026

### Added
- Phase 6: Mullvad WireGuard VPN with multi-hop routing, kill switch, and split tunnelling
- Phase 7: Multi-engine malware scanner with ClamAV and fuzzing infrastructure
- Phase 8: Storage management with Restic backups, ZFS, and RAID support
- GitHub Actions workflows for NixOS configuration validation
- OpenRGB hardware control for RGB lighting management
- Comprehensive task automation with justfile
- Five new Rust CLI tools: wireguard-helper, malware-scanner, storage-manager components

### Changed
- Enhanced secrets-verify and agenix-helper with validation and error handling
- Updated package lists and module imports across configurations

---

## [0.4.0] - 24/01/2026

### Added
- Phase 2: Per-device secrets management with zero-trust architecture
- Two Rust CLI tools: secrets-verify and agenix-helper
- Auto-generated SSH configuration per device
- Two-tier security: passphrase for servers, none for GitHub keys
- Comprehensive secrets management documentation

### Changed
- Migrated to per-device SSH keys (not shared between devices)
- Enhanced flake.nix with Rust tooling development shell

---

## [0.3.0] - 24/01/2026

### Added
- Phase 4: Home Manager integration for declarative user environment
- Modular Hyprland configuration with separate .conf files
- Full Neovim IDE-like configuration with LSP and autocomplete
- DaVinci Resolve AMD GPU support for video editing
- Multi-account git configuration with conditional includes
- Complete Zed IDE configuration and settings

### Changed
- Integrated Home Manager into all host configurations
- Restructured dotfiles into Home Manager modules

### Removed
- Old standalone dotfiles (migrated to Home Manager)

---

## [0.2.0] - 24/01/2026

### Added
- Phase 1: Modular NixOS foundation with reusable module system
- Multi-device support for laptop-intel, framework, and devtower
- Core modules: base-configuration, common, users, nix-settings
- Hardware modules: intel-laptop, amd-laptop, amd-desktop, go-xlr
- Hyprland Wayland compositor desktop module
- Flake-based configuration with locked dependencies

---

## [0.1.0] - 14-20/01/2026

### Added
- Comprehensive Zed IDE configuration with language servers
- Multi-account git setup with conditional includes for 3 GitHub accounts
- Cross-platform installation wizard and verification script
- Linter configurations: EditorConfig, ESLint, Prettier, Ruff, Markdownlint
- Task automation with justfile
- Language server support for Python, TypeScript, Rust, Markdown, PHP

---

## [0.0.1] - 14/01/2026

### Added
- Initial repository with basic README

---

## Release Notes

### Versioning

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes (incompatible API changes)
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)

Pre-1.0 versions (0.x.x) indicate development phase where breaking changes may occur in minor versions.
