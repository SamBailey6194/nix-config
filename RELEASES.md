# Release Notes

**Last Updated**: 22/02/2026
**Version**: 1.4.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## Table of Contents

- [Latest Release](#latest-release)
- [Previous Releases](#previous-releases)

---

## Latest Release

### Version 1.4.0 - 22 February 2026

#### What's New

**System-Wide Management Tools**
All management tools are now available everywhere in your system without any setup:
- Type `secrets-verify` to check your encrypted secrets are working
- Use `agenix-helper` to manage encrypted passwords and keys
- Run `wireguard-helper` to manage your VPN connections
- Execute `malware-scanner` to scan for security threats
- Configure backups with `restic-manage`
- Manage advanced storage with `zfs-manage`, `raid-manage`, `luks-manage`
- Control security hardware with `tpm-manage`

These tools are automatically available on all your devices - no need to activate developer mode or run special commands.

**Real Hardware Configuration**
Your laptop now has its actual hardware configuration instead of a template:
- **Encrypted Storage**: Your entire system drive is encrypted for security
- **Efficient Filesystem**: Uses BTRFS with automatic compression to save space
- **Smart Organisation**: System files, your documents, and backups are neatly separated
- **Optimised Boot**: EFI boot partition configured for fast, reliable startup
- **CPU Updates**: Automatic Intel microcode updates for better performance and security

#### How This Helps You

**Simpler Workflow**
Previously, you needed to enter a special developer environment to use these management tools. Now they're just there whenever you need them - type the command and it works.

**Better Organisation**
Instead of installing tools separately on each computer, they're configured once and available everywhere. This means:
- Consistent tools across all your devices
- Easier to maintain (update in one place, works everywhere)
- No duplicated configuration

**Production Ready**
Your laptop configuration is now based on the actual hardware in the device, not a generic template. This means better performance and reliability.

#### Coming Soon

- Complete NixOS installation process
- Multi-device file synchronisation
- Enhanced security features

---

## Previous Releases

### Version 0.6.7 - 28 January 2026

#### Bug Fixes
- Fixed duplicate system components that could cause conflicts

---

### Version 0.6.6 - 28 January 2026

#### Bug Fixes
- Resolved startup service conflicts that prevented proper system boot

---

### Version 0.6.5 - 28 January 2026

#### Improvements
- Updated system maintenance settings for better compatibility
- Fixed package management issues

---

### Version 0.6.4 - 27 January 2026

#### Bug Fixes

**Faster Boot Times**
Fixed an issue where the system would hang for 90 seconds during boot on Intel laptops:
- Disabled problematic card reader drivers
- Boot now completes in seconds instead of minutes

**Better Font Support**
- Corrected font package names for international character support
- Improved text rendering across all applications

**Improved SSH Configuration**
- Fixed SSH settings that weren't compatible with NixOS
- Remote connections now work reliably

---

### Version 0.6.3 - 27 January 2026

#### Technical Improvements
- Added build reproducibility (your system builds the same way every time)
- Improved version locking for dependencies

---

### Version 0.6.2 - 27 January 2026

#### Bug Fixes
- Fixed storage management tools that had configuration conflicts
- Improved ZFS filesystem support
- Resolved package installation issues

---

### Version 0.6.1 - 27 January 2026

#### What's New

**Minimal Installation Option**
You can now install a bare-bones NixOS system first:
- Gets you up and running in 10-20 minutes
- Includes essential storage tools from day one
- Add features progressively without reinstalling

**Better Installation Documentation**
- Step-by-step minimal installation guide
- Clear instructions for each stage
- Troubleshooting tips included

---

### Version 0.6.0 - 27 January 2026

#### What's New

**Streamlined Documentation**
Your documentation is now organised in a single `docs/` directory:
- Reduced from 29 files to just 9 active guides
- Central navigation hub for easy access
- Everything you need in one place

**Quick Access Guides**:
- Installation Guide - Progressive 6-stage installation
- Secrets Management - Secure SSH key setup
- VPN Setup - Privacy-focused VPN configuration
- Storage Management - Backups, ZFS, and RAID
- Security - Malware protection

**Progressive Installation System**
Install your system in 6 stages to prevent failures:

1. **Minimal** (10-20 min) - Base system with storage tools
2. **Desktop** (15-30 min) - Beautiful Hyprland desktop
3. **Development** (20-40 min) - Browsers and coding tools
4. **Productivity** (15-25 min) - Office and communication apps
5. **Creative** (30-60 min) - Design and video editing software
6. **Full** (5-30 min) - Complete system with VPN and security

Each stage verifies the previous one works before adding more.

**Affinity Apps Integration**
Professional creative software now available:
- **Affinity Designer** - Vector graphics and illustration
- **Affinity Photo** - Professional photo editing
- **Affinity Publisher** - Desktop publishing and layout

Perfect for creative professionals who need industry-standard tools.

**Multi-Device Ready**
Pre-configured for three types of devices:
- **Laptop** - Intel laptop with power efficiency settings
- **Framework** - AMD laptop with dedicated graphics
- **Desktop** - High-performance workstation with audio interface

#### Improvements

- **Storage from Day 1**: Backup tools available immediately in minimal installation
- **Better Organisation**: Logical module distribution across stages
- **Clearer Navigation**: Easy-to-find documentation
- **Historical Archive**: Old documentation preserved for reference

#### Installation

```bash
# Stage 1: Minimal installation
nixos-install --flake .#laptop-intel-minimal

# After reboot, progressively add features:
sudo nixos-rebuild switch --flake .#laptop-intel-desktop       # Stage 2
sudo nixos-rebuild switch --flake .#laptop-intel-dev           # Stage 3
sudo nixos-rebuild switch --flake .#laptop-intel-productivity  # Stage 4
sudo nixos-rebuild switch --flake .#laptop-intel-creative      # Stage 5
sudo nixos-rebuild switch --flake .#laptop-intel               # Stage 6
```

---

### Version 0.5.10 - 25 January 2026

#### Bug Fixes
- Fixed configuration compatibility issues for initial installation
- Resolved font rendering problems
- Fixed shell configuration conflicts
- Improved VPN module structure

---

### Version 0.5.0 - 25 January 2026

#### What's New

**Privacy-Focused VPN**
Connect to Mullvad VPN with advanced privacy features:
- **Multi-hop routing** - Your traffic goes through multiple servers for extra privacy
- **Kill switch** - Internet blocked if VPN disconnects (prevents IP leaks)
- **Split tunnelling** - Choose which apps use the VPN
- **Easy server switching** - Change VPN servers with simple commands

**Comprehensive Security**
Protect your system with multi-engine malware scanning:
- Real-time protection scans files as you use them
- Multiple scanning engines catch more threats
- Quarantine system safely isolates suspicious files
- Automatic virus definition updates

**Professional Storage Management**
Keep your data safe with multiple backup options:
- **Encrypted backups** to cloud storage (AWS S3, Backblaze B2) or external drives
- **ZFS filesystem** for data integrity and snapshots
- **RAID support** for redundancy and performance
- Easy-to-use management tools for all storage systems

**Automation Tools**
Common tasks are now automated:
- Simple commands for system updates
- One-command secret management
- Automated backup configuration
- Quick VPN server rotation

**Hardware Control**
- RGB lighting control for compatible devices
- Custom lighting effects and profiles

#### Improvements

- Better error handling in security tools
- Enhanced secrets management with validation
- Automated testing with GitHub Actions
- Comprehensive documentation for all new features

---

### Version 0.4.0 - 24 January 2026

#### What's New

**Secure Secrets Management**
Your sensitive information is now properly encrypted and managed:
- Each device has its own unique encryption keys
- SSH keys for GitHub and servers are encrypted at rest
- Easy commands to manage secrets: `secrets-verify`, `agenix-helper`
- Two-tier security: extra protection for server keys

**Zero-Trust Architecture**
- Secrets are specific to each device (not shared)
- Compromising one device doesn't affect others
- Server keys require passwords for extra security
- GitHub keys optimised for convenience

**Management Tools**
- Verify all secrets deployed correctly with one command
- Test GitHub SSH connections automatically
- Edit encrypted secrets easily
- Generate new device keys when adding machines

---

### Version 0.3.0 - 24 January 2026

#### What's New

**Personalised User Environment**
Your settings and configurations are now managed declaratively:
- Consistent environment across all devices
- Settings automatically applied on login
- Easy to backup and restore your preferences

**Beautiful Desktop Experience**
Hyprland Wayland compositor provides:
- Smooth animations and modern interface
- Highly customisable keybindings and appearance
- Better performance than traditional X11
- Multi-monitor support with easy configuration

**Powerful Text Editor**
Neovim configured with IDE features:
- Code completion and suggestions
- Error checking while you type
- File tree navigation
- Support for all major programming languages

**Professional Video Editing**
DaVinci Resolve configured for AMD graphics:
- Hardware-accelerated video rendering
- Professional colour grading tools
- Multi-track audio editing
- Optimised for AMD GPU performance

**Multi-Account Git Support**
Seamlessly work with multiple GitHub accounts:
- Automatically uses correct account based on project directory
- No manual account switching needed
- Separate commit signatures for work and personal projects

---

### Version 0.2.0 - 24 January 2026

#### What's New

**Modular System Architecture**
Built a flexible foundation for your NixOS system:
- Reusable configuration modules
- Easy to add or remove features
- Consistent settings across all devices
- Hardware-specific optimisations

**Multi-Device Support**
Pre-configured for three different devices:
- Intel laptop with integrated graphics
- AMD Framework laptop with dedicated GPU
- High-performance AMD desktop with audio interface

**Modern Desktop Environment**
Hyprland Wayland compositor provides:
- Smooth, modern interface
- Energy-efficient for laptops
- Highly customisable
- Great multi-monitor support

---

### Version 0.1.0 - 14-20 January 2026

#### What's New

**Complete Development Environment**
Professional code editor (Zed) configured with:
- IntelliSense and code completion
- Integrated debugging
- Support for Python, TypeScript, Rust, PHP, and more
- Beautiful themes and customisable keybindings

**Multi-Account Git**
Work with multiple GitHub accounts effortlessly:
- Automatic account switching based on project location
- Personal, work, and organisation accounts
- Pre-commit hooks to ensure code quality
- Custom commit message templates

**Code Quality Tools**
Automated linting and formatting:
- Python: Ruff and Pyright for type checking
- JavaScript/TypeScript: ESLint and Prettier
- Markdown: Automated formatting and link checking
- Consistent code style across all projects

**Easy Setup**
- Automated installation wizard
- Cross-platform support (Linux and macOS)
- Verification script to check everything works
- Comprehensive documentation

---

### Version 0.0.1 - 14 January 2026

#### What's New
- Initial project setup
- Basic project structure and README

---

## About Releases

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 0.7.0)
- **MAJOR**: Breaking changes requiring manual intervention
- **MINOR**: New features that don't break existing functionality
- **PATCH**: Bug fixes and small improvements

Pre-1.0 versions (0.x.x) indicate active development phase. Expect frequent updates and new features!

---

## Getting Help

- **Installation Guide**: [docs/INSTALLATION.md](docs/INSTALLATION.md)
- **Documentation Hub**: [docs/README.md](docs/README.md)
- **Architecture Guide**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Secrets Setup**: [docs/SECRETS.md](docs/SECRETS.md)
- **VPN Configuration**: [docs/VPN.md](docs/VPN.md)
- **Storage Management**: [docs/STORAGE.md](docs/STORAGE.md)
