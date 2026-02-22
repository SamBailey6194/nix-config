# Version History

**Last Updated**: 22/02/2026
**Version**: 1.2.1
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## Table of Contents

- [Unreleased](#unreleased)
- [1.2.1 - 22/02/2026](#121---22022026)
- [1.2.0 - 22/02/2026](#120---22022026)
- [1.1.0 - 22/02/2026](#110---22022026)
- [1.0.1 - 22/02/2026](#101---22022026)
- [0.12.0 - 30/01/2026](#0120---30012026)
- [0.11.0 - 30/01/2026](#0110---30012026)
- [0.10.0 - 30/01/2026](#0100---30012026)
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
- [0.5.9 - 25/01/2026](#059---25012026)
- [0.5.8 - 25/01/2026](#058---25012026)
- [0.5.7 - 25/01/2026](#057---25012026)
- [0.5.6 - 25/01/2026](#056---25012026)
- [0.5.5 - 25/01/2026](#055---25012026)
- [0.5.4 - 25/01/2026](#054---25012026)
- [0.5.3 - 25/01/2026](#053---25012026)
- [0.5.2 - 25/01/2026](#052---25012026)
- [0.5.1 - 25/01/2026](#051---25012026)
- [0.5.0 - 25/01/2026](#050---25012026)
- [0.4.0 - 24/01/2026](#040---24012026)
- [0.3.0 - 24/01/2026](#030---24012026)
- [0.2.0 - 24/01/2026](#020---24012026)
- [0.1.0 - 14-20/01/2026](#010---14-20012026)
- [0.0.1 - 14/01/2026](#001---14012026)

---

## [Unreleased]

### Technical Changes
- Nothing yet

---

## [1.2.1] - 22/02/2026

### Summary
Added flake.lock to version control for reproducible builds across all devices.

### Configuration Changes
| Change | Reason | Files |
|--------|--------|-------|
| Track flake.lock | Reproducible builds across devices | `flake.lock` |

### Files Changed
| File | Changes |
|------|---------|
| `flake.lock` | Locked dependency versions for all flake inputs (917 lines) |

---

## [1.2.0] - 22/02/2026

### Summary
Added development tooling: direnv with nix-direnv caching, DDEV for Docker-based PHP/Node.js development, and nixd language server for Zed IDE.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Direnv + nix-direnv | Auto-load dev environments with cached nix develop | `home/common.nix`, `modules/software/development.nix` |
| DDEV | Docker-based local PHP and Node.js environments | `modules/software/development.nix` |
| nixd language server | Nix LSP for Zed IDE (alongside nil for Neovim) | `modules/software/development.nix`, `flake.nix` |
| .envrc | Project-level `use flake` for auto dev shell | `.envrc` |

### Files Changed
| File | Changes |
|------|---------|
| `flake.nix` | Added nixd to Nix dev shell packages |
| `modules/software/development.nix` | Added direnv, ddev, nixd; clarified nil vs nixd usage |
| `home/common.nix` | Enabled programs.direnv with nix-direnv caching |
| `.envrc` | New file: `use flake` directive |

---

## [1.1.0] - 22/02/2026

### Summary
Activated per-device secrets management with real SSH keys and 9 encrypted `.age` secret files for laptop-intel. Secrets module now uses dynamic hostname interpolation for portable multi-device deployment.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Encrypted .age secrets | 9 per-device encrypted secrets for laptop-intel | `secrets/*.age` |
| Dynamic hostname paths | secrets-laptop.nix uses config.networking.hostName | `modules/core/secrets-laptop.nix` |
| LUKS passphrase secret | TPM2 fallback decryption key | `secrets/luks-passphrase-laptop-intel.age` |
| Malware scanner key | AES-GCM quarantine encryption key | `secrets/malware-scanner-quarantine-key-laptop-intel.age` |
| Vault master key | gocryptfs recovery key | `secrets/vault-master-key-laptop-intel.age` |
| Server ACME credentials | SSH key and passphrase for server deployment | `secrets/server-acme-laptop-intel-*.age` |

### Configuration Changes
| Change | Reason | Files |
|--------|--------|-------|
| Real SSH keys in secrets.nix | Replace placeholder keys with actual device keys | `secrets/secrets.nix` |
| Enabled secrets imports | Activate agenix decryption at boot | `hosts/laptop-intel/configuration-full.nix` |
| Allow .age in git | Encrypted files are safe to commit | `.gitignore` |
| Track flake.lock | Reproducible builds | `.gitignore` |

### Files Changed
| File | Changes |
|------|---------|
| `secrets/secrets.nix` | Real user/host keys, per-device agenix user key, tidied declarations |
| `modules/core/secrets-laptop.nix` | Dynamic hostname, 6 new secret declarations (LUKS, malware, vault, server) |
| `.gitignore` | Allow .age files, track flake.lock, protect unencrypted keys |
| `hosts/laptop-intel/configuration-full.nix` | Enabled secrets-laptop.nix and ssh-config.nix imports |
| `secrets/*.age` | 9 new encrypted secret files |

---

## [1.0.1] - 22/02/2026

### Summary
Bug fixes for Hyprland GSettings warnings, Neovim lualine separator escaping, and git safe directory configuration.

### Bugs Fixed
| Bug | Solution | Files |
|-----|----------|-------|
| GSettings "does not exist" warnings | Added gsettings-desktop-schemas and glib packages | `modules/desktop/hyprland/default.nix` |
| Cursor theme/size warnings | Added GSettings schema paths to XDG_DATA_DIRS | `modules/desktop/hyprland/default.nix` |
| Lualine separator escaping | Fixed empty string quoting in section_separators | `home/modules/neovim.nix` |
| Root git access denied | Added safe directory for /etc/nixos/nix-config | `modules/core/base-configuration.nix` |

### Files Changed
| File | Changes |
|------|---------|
| `modules/desktop/hyprland/default.nix` | Added gsettings-desktop-schemas, glib packages and XDG_DATA_DIRS session variable |
| `home/modules/neovim.nix` | Fixed lualine section_separators empty string escaping |
| `modules/core/base-configuration.nix` | Added /etc/gitconfig with safe directory for nix-config |

---

## [0.12.0] - 30/01/2026

### Added
- Native Nix package installation for Claude Code via `claude-code-nix` flake input from `github:sadjow/claude-code-nix`
- Nixpkgs overlay in `modules/core/base-configuration.nix` to provide `pkgs.claude-code` system-wide
- Automatic hourly updates for Claude Code through Nix package update mechanism

### Changed
- Replaced manual curl-based Claude Code installation with native Nix package in `home/common.nix`
- Removed `.local/bin` PATH addition from `home/modules/shell.nix` (no longer required for Claude Code)
- Updated documentation comment in `modules/core/nix-settings.nix` to clarify that Claude Code now uses Nix package instead of npm installation

### Technical Details
**Files Modified**:
- `flake.nix`: Added `claude-code-nix` input with nixpkgs follows, added to outputs parameters
- `modules/core/base-configuration.nix`: Created nixpkgs overlay for `claude-code` package
- `home/common.nix`: Added `claude-code` to package list with updated comment explaining native binary and hourly updates
- `home/modules/shell.nix`: Removed Claude Code PATH configuration (3 lines deleted)
- `modules/core/nix-settings.nix`: Updated nix-ld documentation to reflect Claude Code's native installation method

**Impact**: Claude Code is now managed as a first-class Nix package with automatic updates, eliminating the need for manual PATH configuration and npm-based installation

---

## [0.11.0] - 30/01/2026

### Added
- **OpenRGB Support**: Enabled RGB control for keyboard and mouse peripherals
- **Hyprland Desktop**: Enabled full Hyprland Wayland compositor environment
- **Mullvad WireGuard VPN**: Activated Phase 6 VPN with multi-hop routing, kill switch, and per-app VPN (Firefox, LibreWolf, Chrome, Transmission)
- **VPN Configuration**: UK exit location, 5-hop minimum, automatic weekly rotation (Sundays 3 AM), metrics logging

### Configuration
- Uncommented `modules/hardware/openrgb.nix` for RGB peripheral control
- Uncommented `modules/desktop/hyprland` for desktop environment
- Uncommented `modules/network/wireguard-mullvad.nix` for VPN functionality
- Enabled hostname `laptop-intel` identification
- Added LibreWolf and Chrome to VPN cgroup applications

### Technical Changes
- **File**: `hosts/laptop-intel/configuration.nix`
- Changed 45 insertions, 43 deletions (formatting and feature activation)

---

## [0.10.0] - 30/01/2026

### Added
- Python 3.14 as default Python version for new projects
- Python 3.13 maintained for legacy project compatibility
- pip and virtualenv packages for both Python 3.14 and 3.13

### Technical Details
**Module**: `modules/software/development.nix`

Upgraded Python development environment to support latest Python 3.14 whilst maintaining backwards compatibility with Python 3.13 for legacy projects. Both versions include complete package management tooling (pip, virtualenv) and integrate with UV for fast package installation.

**Impact**: Development environment now supports cutting-edge Python features whilst maintaining legacy project compatibility.

---

## [0.9.0] - 29/01/2026

### Technical Changes

#### Network - Tailscale VPN Integration
- **Module Created**: `modules/network/tailscale.nix`
- **Service Configuration**:
  - `services.tailscale.enable = true`
  - Network dependency: `wants = [ "network-online.target" ]`
  - Auto-start after network is ready
- **Firewall Rules**:
  - Trusted interface: `tailscale0`
  - UDP port: `config.services.tailscale.port` (default 41641)
  - Reverse path check: `loose` (required for Tailscale routing)
- **Packages**: `tailscale` CLI tool
- **Purpose**: Secure mesh VPN for remote access to client computers

#### Network - Remote Desktop Client
- **Module Created**: `modules/network/remote-desktop.nix`
- **Packages Installed**:
  - `remmina` - Remote desktop client (VNC, RDP, SSH protocols)
- **Optional Configuration** (commented out by default):
  - `x11vnc` server for incoming connections
  - systemd user service for x11vnc
  - Firewall rules for VNC port 5900 (Tailscale interface only)
- **Security**: VNC server disabled by default, only allows Tailscale connections when enabled

#### Documentation
- **File Created**: `docs/TAILSCALE-REMMINA-SETUP.md`
- **Contents**:
  - Initial Tailscale authentication steps
  - Client computer VNC server setup (x11vnc on Ubuntu/Linux)
  - Remmina configuration for VNC connections
  - Troubleshooting guide
  - Security best practices

#### Host Configuration Updates
- **Files Modified**:
  - `hosts/laptop-intel/configuration-full.nix`
  - `hosts/framework/configuration-full.nix`
  - `hosts/devtower/configuration-full.nix`
- **Changes**: Added imports for:
  - `../../modules/network/tailscale.nix`
  - `../../modules/network/remote-desktop.nix`

#### Use Case
- Remote support for client computers
- Secure VPN mesh network across all devices
- VNC/RDP access to clients from anywhere
- Works alongside existing Mullvad VPN (separate use cases)

---

## [0.8.0] - 29/01/2026

---

## [0.7.0] - 29/01/2026

### Summary
Added progressive staged installation with Home Manager integration and Hyprland display manager with greetd.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Progressive staged installation | Home Manager integration across all 6 stages | `hosts/*/configuration-*.nix` |
| Greetd display manager | Replaces LightDM for Hyprland session management | `modules/desktop/hyprland/default.nix` |
| Hyprland .conf files | Switched from Nix expressions to native .conf format | `config/hypr/*.conf` |
| UEFI boot management | Added efibootmgr for boot order control | `modules/core/base-configuration.nix` |

### Files Changed
| File | Changes |
|------|---------|
| `hosts/laptop-intel/configuration-desktop.nix` | Added Home Manager integration |
| `modules/desktop/hyprland/default.nix` | Added greetd display manager, converted to .conf format |
| `config/hypr/hyprland.conf` | Native Hyprland configuration format |
| `config/hypr/monitors.conf` | Modular monitor configuration |
| `config/hypr/binds.conf` | Keybinding configuration |
| `modules/core/base-configuration.nix` | Added efibootmgr package |

### Configuration Changes
| Component | Change | Impact |
|-----------|--------|--------|
| Display manager | LightDM → greetd | More lightweight, Wayland-native |
| Hyprland config | Nix expressions → .conf files | Better compatibility, easier to maintain |
| Home Manager | Added to desktop stage | Progressive installation support |

### Performance Notes
- Greetd has lower memory footprint than LightDM
- .conf files eliminate Nix evaluation overhead during Hyprland startup

---

## [0.6.7] - 28/01/2026

### Summary
Fixed xdg-desktop-portal-hyprland duplication issue.

### Bugs Fixed
| Bug | Solution | Files |
|-----|----------|-------|
| Duplicate xdg-desktop-portal-hyprland | Removed redundant declaration | `modules/desktop/hyprland/default.nix` |

### Files Changed
| File | Changes |
|------|---------|
| `modules/desktop/hyprland/default.nix` | Removed duplicate portal declaration |

---

## [0.6.6] - 28/01/2026

### Summary
Resolved systemd service symlink collision in Hyprland module.

### Bugs Fixed
| Bug | Solution | Files |
|-----|----------|-------|
| Systemd service symlink collision | Fixed service path configuration | `modules/desktop/hyprland/default.nix` |

### Files Changed
| File | Changes |
|------|---------|
| `modules/desktop/hyprland/default.nix` | Fixed systemd service paths |

---

## [0.6.5] - 28/01/2026

### Summary
Fixed dependency errors and deprecated Nix options.

### Bugs Fixed
| Bug | Solution | Files |
|-----|----------|-------|
| Deprecated nix.gc options | Updated to new syntax | `modules/core/nix-settings.nix` |
| Dependency resolution errors | Fixed package dependencies | Multiple modules |

### Files Changed
| File | Changes |
|------|---------|
| `modules/core/nix-settings.nix` | Updated deprecated options |
| `flake.nix` | Fixed dependency declarations |

---

## [0.6.4] - 27/01/2026

### Summary
Multiple Hyprland and system configuration fixes for NixOS installation.

### Bugs Fixed
| Bug | Solution | Files |
|-----|----------|-------|
| Invalid noto-fonts-cjk package | Corrected package name | `modules/desktop/hyprland/default.nix` |
| Invalid SSH options | Replaced programs.ssh with system-level config | `modules/core/ssh-config.nix` |
| Boot hang on rtsx_pci | Blacklisted problematic kernel modules | `hosts/laptop-intel/hardware-configuration.nix` |

### Files Changed
| File | Changes |
|------|---------|
| `modules/desktop/hyprland/default.nix` | Fixed font package name, updated multiple configuration files |
| `modules/core/ssh-config.nix` | Migrated to system-level SSH configuration |
| `hosts/laptop-intel/hardware-configuration.nix` | Added rtsx_pci module blacklist |
| `flake.nix` | Updated dependency versions |

### Hardware Compatibility
| Issue | Solution | Impact |
|-------|----------|--------|
| Realtek card reader boot hang | Blacklisted rtsx_pci, rtsx_pci_sdmmc, rtsx_pci_ms | Prevents 90-second boot timeout |

---

## [0.6.3] - 27/01/2026

### Summary
Added flake.lock for reproducible builds and then removed it from version control.

### Configuration Changes
| Change | Reason | Files |
|--------|--------|-------|
| Added flake.lock | Ensure reproducible builds | `flake.lock` |
| Removed flake.lock from git | User-specific lock file | `.gitignore` |

### Files Changed
| File | Changes |
|------|---------|
| `flake.lock` | Generated lock file (then removed from git) |
| `.gitignore` | Added flake.lock to ignore list |

---

## [0.6.2] - 27/01/2026

### Summary
Fixed storage module configuration for NixOS compatibility.

### Bugs Fixed
| Bug | Solution | Files |
|-----|----------|-------|
| Duplicate systemPackages | Consolidated package declarations | `modules/storage/restic.nix`, `modules/storage/zfs.nix`, `modules/storage/raid.nix` |
| ZFS module syntax errors | Updated to correct NixOS options | `modules/storage/zfs.nix` |

### Files Changed
| File | Changes |
|------|---------|
| `modules/storage/restic.nix` | Fixed package declarations |
| `modules/storage/zfs.nix` | Corrected module structure |
| `modules/storage/raid.nix` | Fixed syntax issues |

---

## [0.6.1] - 27/01/2026

### Summary
Created minimal installation configuration and documentation.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Minimal installation config | Bare-bones NixOS for initial installation | `hosts/laptop-intel/configuration-minimal.nix` |
| Minimal installation guide | Step-by-step minimal installation docs | `docs/MINIMAL-INSTALL-GUIDE.md` |
| Zsh in minimal | Enabled zsh shell in minimal installation | Multiple configs |

### Files Changed
| File | Changes |
|------|---------|
| `hosts/laptop-intel/configuration-minimal.nix` | Created minimal configuration |
| `docs/MINIMAL-INSTALL-GUIDE.md` | Created installation guide |
| `modules/core/base-configuration.nix` | Removed problematic packages |
| `modules/core/ssh-config.nix` | Added device SSH keys, then commented unused keys |

---

## [0.6.0] - 27/01/2026

### Summary
Documentation consolidation and module distribution implementation for NixOS configuration. Reduced documentation files from 29 to 9 active files (68% reduction), implemented 6-stage progressive installation system, and added Affinity Apps integration.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Documentation hub | Central navigation for all documentation | `docs/README.md` |
| Staged installation | 6 progressive stages to avoid tmpfs issues | `docs/INSTALLATION.md` |
| Multi-device configs | 18 configurations (3 devices × 6 stages) | `hosts/*/configuration-*.nix` |
| Affinity Apps | Designer, Photo, Publisher integration | `modules/software/creative.nix` |
| Storage in Stage 1 | Restic, ZFS, RAID available immediately | Multiple minimal configs |

### Documentation Structure
| New File | Purpose | Replaces |
|----------|---------|----------|
| `docs/README.md` | Central hub | Multiple scattered docs |
| `docs/INSTALLATION.md` | Comprehensive installation guide | 5+ installation docs |
| `docs/SECRETS.md` | Secrets management | Phase 2 docs |
| `docs/VPN.md` | VPN configuration | Phase 6 docs |
| `docs/STORAGE.md` | Storage management | Phase 8 docs |
| `docs/MALWARE-SCANNER.md` | Security documentation | Phase 7 docs |
| `docs/UPDATES.md` | Update procedures | Scattered update notes |
| `docs/ARCHITECTURE.md` | System architecture | Multiple design docs |

### Module Distribution
| Stage | Modules Added | Time Estimate |
|-------|---------------|---------------|
| 1 (Minimal) | Storage (Restic, ZFS, RAID) | 10-20 min |
| 2 (Desktop) | Hyprland, fonts, themes | 15-30 min |
| 3 (Development) | Browsers, dev tools, language servers | 20-40 min |
| 4 (Productivity) | Office, communication software | 15-25 min |
| 5 (Creative) | Affinity Apps, Blender, GIMP, DaVinci | 30-60 min |
| 6 (Full) | VPN, malware scanner | 5-30 min |

### Files Changed
| File | Changes |
|------|---------|
| `.claude/CLAUDE.md` | Updated installation instructions and documentation references |
| `README.md` | Restructured with staged installation focus |
| `flake.nix` | Enabled Hyprland and Affinity inputs, configured 18 host configurations |
| `modules/core/nix-settings.nix` | Enhanced Nix settings |
| `modules/software/creative.nix` | Added Affinity Apps integration |
| `hosts/laptop-intel/configuration-*.nix` | Created all 6 stages |
| `hosts/framework/configuration-*.nix` | Created all 6 stages |
| `hosts/devtower/configuration-*.nix` | Created all 6 stages |
| `docs/archive/*` | Archived 20 legacy documentation files |

### Migration Impact
| Change | Before | After | Benefit |
|--------|--------|-------|---------|
| Active docs | 29 files | 9 files | 68% reduction |
| Installation method | Single full config | 6 progressive stages | Avoids tmpfs issues |
| Device support | 1 device | 3 devices (18 configs) | Multi-device ready |

---

## [0.5.10] - 25/01/2026

### Summary
Multiple bug fixes for NixOS configuration compatibility.

### Bugs Fixed
| Bug | Solution | Files |
|-----|----------|-------|
| Affinity module disabled | Temporarily disabled for installation | `modules/core/base-configuration.nix` |
| WireGuard import errors | Moved imports to top level | `modules/network/wireguard-mullvad.nix` |
| Neovim lualine config | Escaped empty strings | `home/common.nix` |
| Duplicate zsh config | Removed Ubuntu-specific settings | `home/common.nix` |
| PATH configuration | Fixed sessionPath usage | `home/common.nix` |
| Font family errors | Corrected Ubuntu font family name | `home/common.nix` |

### Files Changed
| File | Changes |
|------|---------|
| `modules/core/base-configuration.nix` | Disabled Affinity Apps module |
| `modules/network/wireguard-mullvad.nix` | Fixed import structure |
| `home/common.nix` | Multiple configuration fixes |

---

## [0.5.9 - 0.5.1] - 25/01/2026

### Summary
Series of iterative fixes for Home Manager and NixOS configuration issues discovered during initial installation testing.

### Bugs Fixed (Cumulative)
- SSH configuration syntax errors
- Home Manager session path configuration
- Neovim Lua configuration escaping
- ZSH initialization duplication
- Font family name corrections
- WireGuard module structure
- Affinity Apps integration issues

---

## [0.5.0] - 25/01/2026

### Summary
Major feature release implementing Phases 6, 7, and 8: VPN, security, storage, and automation infrastructure.

### Features Added
| Phase | Feature | Description | Files |
|-------|---------|-------------|-------|
| Phase 6 | Mullvad WireGuard VPN | Multi-hop routing, kill switch, split tunnelling | `modules/network/wireguard-*.nix` |
| Phase 7 | Malware scanner | Multi-engine scanner with ClamAV, fuzzing infrastructure | `modules/security/malware-scanner.nix`, `rust/malware-scanner/` |
| Phase 8 | Storage management | Restic backups, ZFS, RAID management | `modules/storage/*.nix`, `rust/storage-manager/` |
| CI/CD | GitHub Actions | NixOS config validation workflows | `.github/workflows/*.yml` |
| Hardware | OpenRGB control | RGB lighting control | `home/common.nix` |
| Automation | Justfile | Task automation for common operations | `justfile` |

### Rust Tools Added
| Tool | Purpose | Location |
|------|---------|----------|
| wireguard-helper | VPN management CLI | `rust/wireguard-helper/` |
| malware-scanner | Multi-engine malware scanning | `rust/malware-scanner/` |
| storage-manager | Storage CLI (restic-manage, zfs-manage, raid-manage) | `rust/storage-manager/` |
| secrets-verify | Enhanced validation and error handling | `rust/secrets-verify/` |
| agenix-helper | Improved secrets management | `rust/agenix-helper/` |

### Storage Features
| Component | Features | Configuration |
|-----------|----------|---------------|
| Restic | Encrypted backups to S3/B2/local | Runtime-configurable repositories |
| ZFS | Pool management, snapshots, scrubs | Dynamic pool creation |
| RAID | Software RAID management | Multiple RAID levels |

### VPN Features
| Feature | Implementation | Benefits |
|---------|----------------|----------|
| Multi-hop routing | WireGuard chaining | Enhanced privacy |
| Kill switch | Firewall rules | Prevents IP leaks |
| Split tunnelling | Routing tables | Selective VPN use |
| Server rotation | wireguard-helper | Easy server switching |

### Security Features
| Feature | Implementation | Benefits |
|---------|----------------|----------|
| Multi-engine scanning | ClamAV + custom engines | Better detection |
| Fuzzing infrastructure | cargo-fuzz integration | Find vulnerabilities |
| Real-time protection | Daemon-based scanning | Automatic threat detection |
| Quarantine system | Isolated storage | Safe malware containment |

### Files Changed
| Component | Files |
|-----------|-------|
| VPN | `modules/network/wireguard-*.nix` (3 files) |
| Security | `modules/security/malware-scanner.nix` |
| Storage | `modules/storage/*.nix` (3 files) |
| Rust workspace | `rust/*/` (5 new tools) |
| CI/CD | `.github/workflows/*.yml` (3 workflows) |
| Automation | `justfile` |
| Documentation | `docs/PHASE-*.md` (3 files) |

### Dependencies Added
| Package | Purpose | Version |
|---------|---------|---------|
| wireguard-tools | VPN management | Latest |
| clamav | Malware scanning | Latest |
| restic | Backup system | Latest |
| zfs | Filesystem | Latest |
| mdadm | RAID management | Latest |

---

## [0.4.0] - 24/01/2026

### Summary
Complete implementation of Phase 2: Per-device secrets management with Rust tooling.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Per-device secrets | Zero-trust secrets architecture | `secrets/secrets.nix`, `secrets/*.age` |
| Rust secrets tools | secrets-verify and agenix-helper CLIs | `rust/secrets-verify/`, `rust/agenix-helper/` |
| Auto-generated SSH config | Per-device SSH key configuration | `modules/core/ssh-config.nix` |
| Two-tier security | Passphrase for servers, none for GitHub | `secrets/secrets.nix` |

### Security Architecture
| Component | Implementation | Security Level |
|-----------|----------------|----------------|
| Device secrets | Per-device SSH keys (not shared) | High |
| Server secrets | Password-protected SSH keys | Very High |
| GitHub secrets | No passphrase (convenience) | Medium |
| Host keys | Per-device ed25519 keys | High |

### Rust Tools
| Tool | Features | Commands |
|------|----------|----------|
| secrets-verify | Verify secrets deployed correctly, test GitHub SSH | `secrets-verify --test-github` |
| agenix-helper | Edit, list, rekey secrets, generate server keys | `agenix-helper add-server <name>` |

### Files Changed
| File | Changes |
|------|---------|
| `secrets/secrets.nix` | Per-device secrets configuration |
| `secrets/*.age` | Encrypted secrets (GitHub SSH keys per device) |
| `modules/core/ssh-config.nix` | Auto-generated SSH configuration |
| `rust/secrets-verify/` | Rust verification tool (new) |
| `rust/agenix-helper/` | Rust secrets management CLI (new) |
| `rust/Cargo.toml` | Workspace configuration |
| `flake.nix` | Added Rust tooling to dev shell |
| `justfile` | Secrets management tasks |

### Documentation Added
| File | Purpose |
|------|---------|
| `secrets/PER-DEVICE-SECRETS.md` | Zero-trust secrets architecture guide |
| `docs/PHASE-2-SECRETS-SETUP.md` | Step-by-step secrets setup |
| `rust/README.md` | Rust tooling overview |

---

## [0.3.0] - 24/01/2026

### Summary
Complete implementation of Phase 4: Home Manager integration with dotfiles.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Home Manager integration | Declarative user environment management | `home/*.nix` |
| Hyprland configs | Modular Hyprland configuration | `config/hypr/*.conf` |
| Neovim setup | Full IDE-like Neovim configuration | `home/common.nix` |
| DaVinci Resolve AMD | AMD GPU support for video editing | `modules/software/creative.nix` |
| Git configs | Multi-account git with conditional includes | `config/git/*` |
| Zed IDE | Full Zed IDE configuration | `config/zed/*` |

### Home Manager Structure
| File | Purpose | Applies To |
|------|---------|------------|
| `home/common.nix` | Shared dotfiles and packages | All devices |
| `home/laptop.nix` | Laptop-specific additions | laptop-intel |
| `home/framework.nix` | Framework-specific additions | framework |
| `home/devtower.nix` | Desktop-specific additions | devtower |

### Dotfiles Integrated
| Component | Configuration | Features |
|-----------|---------------|----------|
| Hyprland | `config/hypr/*.conf` | Wayland compositor, keybinds, monitors |
| Git | `config/git/*` | Multi-account support, hooks, templates |
| Zed | `config/zed/*` | IDE settings, keybinds, language servers |
| Neovim | Inline Lua | LSP, autocomplete, file tree |
| ZSH | Inline config | Aliases, prompt, PATH |

### Files Changed
| File | Changes |
|------|---------|
| `home/common.nix` | Created comprehensive user environment (new) |
| `home/laptop.nix` | Created laptop-specific config (new) |
| `home/framework.nix` | Created framework-specific config (new) |
| `home/devtower.nix` | Created desktop-specific config (new) |
| `config/hypr/*.conf` | Modular Hyprland configuration (new) |
| `modules/software/creative.nix` | Added DaVinci Resolve AMD support |
| `hosts/*/configuration.nix` | Integrated Home Manager |

### Removed Files
| File | Reason |
|------|--------|
| Old config files | Migrated to Home Manager |

---

## [0.2.0] - 24/01/2026

### Summary
Complete implementation of Phase 1: NixOS Foundation with modular architecture.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Modular architecture | Reusable module system | `modules/` directory structure |
| Multi-device support | Configurations for 3 devices | `hosts/` directory structure |
| Core modules | Base configuration, users, SSH, Nix settings | `modules/core/*.nix` |
| Hardware modules | Device-specific hardware support | `modules/hardware/*.nix` |
| Desktop module | Hyprland Wayland compositor | `modules/desktop/hyprland/*.nix` |
| Flake-based config | Modern Nix flakes setup | `flake.nix` |

### Module Structure
| Module Type | Modules | Purpose |
|-------------|---------|---------|
| Core | base-configuration, common, users, nix-settings | Shared base config |
| Hardware | intel-laptop, amd-laptop, amd-desktop, go-xlr | Hardware-specific |
| Desktop | hyprland | Desktop environment |
| Network | (future) | Network and VPN |
| Security | (future) | Security modules |
| Storage | (future) | Storage management |

### Host Configurations
| Host | User | Hardware | Status |
|------|------|----------|--------|
| laptop-intel | sam-laptop | Intel i5-10210U, 32GB RAM | Ready for install |
| framework | sam-framework | AMD Ryzen, 64GB RAM | Configured |
| devtower | sam-desktop | AMD desktop, 64GB RAM | Configured |

### Files Created
| File | Purpose |
|------|---------|
| `flake.nix` | Flake inputs and outputs |
| `flake.lock` | Dependency lock file |
| `modules/core/base-configuration.nix` | Shared base settings |
| `modules/core/common.nix` | Common packages |
| `modules/core/users.nix` | User account definitions |
| `modules/core/nix-settings.nix` | Nix daemon settings |
| `modules/hardware/*.nix` | Hardware modules (4 files) |
| `modules/desktop/hyprland/default.nix` | Hyprland configuration |
| `hosts/laptop-intel/configuration.nix` | Laptop configuration |
| `hosts/framework/configuration.nix` | Framework configuration |
| `hosts/devtower/configuration.nix` | Desktop configuration |

### Dependencies Added
| Input | Source | Purpose |
|-------|--------|---------|
| nixpkgs | NixOS/nixpkgs | Base system packages |
| home-manager | nix-community/home-manager | User environment |
| agenix | ryantm/agenix | Secrets management |
| hyprland | hyprwm/Hyprland | Wayland compositor |

---

## [0.1.0] - 14-20/01/2026

### Summary
Initial project setup with Zed IDE configuration, dotfiles, and cross-platform setup wizard.

### Features Added
| Feature | Description | Files |
|---------|-------------|-------|
| Zed IDE configuration | Complete IDE setup with language servers | `config/zed/*.json` |
| Git multi-account | Conditional includes for 3 GitHub accounts | `config/git/*` |
| Setup wizard | Cross-platform installation script | `install.sh` |
| Verification script | Verify installation success | `verify-setup.sh` |
| Linter configs | EditorConfig, ESLint, Prettier, Ruff, etc. | `linters/*` |
| Task automation | Justfile for common tasks | `justfile` |

### Language Servers Configured
| Language | Tools |
|----------|-------|
| Python | Ruff, Pyright, python-lsp-server |
| TypeScript/JavaScript | Prettier, ESLint, tsc |
| Rust | rustfmt, Clippy, rust-analyzer |
| Markdown | Prettier, markdownlint-cli2 |
| PHP | php-cs-fixer, Intelephense |

### Files Created
| File | Purpose |
|------|---------|
| `config/zed/settings.json` | Zed IDE settings |
| `config/zed/keymap.json` | Zed keybindings |
| `config/git/config` | Git main configuration |
| `config/git/config-personal` | Personal GitHub account |
| `config/git/config-syntek` | Syntek GitHub account |
| `config/git/config-missional-gen` | Missional Gen GitHub account |
| `config/git/gitmessage` | Git commit template |
| `config/git/hooks/pre-commit` | Pre-commit linting hook |
| `linters/.editorconfig` | EditorConfig settings |
| `linters/.prettierrc` | Prettier configuration |
| `linters/ruff.toml` | Python Ruff configuration |
| `linters/.eslintrc.json` | ESLint configuration |
| `install.sh` | Installation wizard |
| `verify-setup.sh` | Installation verification |
| `justfile` | Task automation |
| `CLAUDE.md` | Project documentation |

---

## [0.0.1] - 14/01/2026

### Summary
Initial repository creation with basic README.

### Files Created
| File | Purpose |
|------|---------|
| `README.md` | Project overview |

---

## Version Format

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes (incompatible API changes)
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)

Pre-1.0 versions (0.x.x) indicate development phase where breaking changes may occur in minor versions.
