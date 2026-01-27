# NixOS Configuration Architecture

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

This document explains the modular architecture of this NixOS configuration.

## Design Philosophy

**DRY (Don't Repeat Yourself)**: Shared configuration is defined once in base modules, device-specific settings are isolated in focused modules.

**Composability**: Each host imports only the modules it needs, making the configuration clear and maintainable.

**Separation of Concerns**: Hardware, software, users, and desktop environment are separated into distinct modules.

## Directory Structure

```
nix-config/
├── flake.nix                  # Entry point - defines all hosts + stages
├── hosts/                     # Per-device configurations
│   ├── laptop-intel/
│   │   ├── configuration-minimal.nix      # Stage 1: Installation only
│   │   ├── configuration-desktop.nix      # Stage 2: + Hyprland
│   │   ├── configuration-dev.nix          # Stage 3: + Dev tools
│   │   ├── configuration-productivity.nix # Stage 4: + Office/comms
│   │   ├── configuration-creative.nix     # Stage 5: + Creative software
│   │   ├── configuration-full.nix         # Stage 6: Daily use (FULL)
│   │   └── hardware-configuration.nix     # Auto-generated
│   ├── framework/              # Same staged configs
│   └── devtower/               # Same staged configs
│
├── modules/                   # Reusable modules (the meat of the config)
│   ├── core/
│   │   ├── base-configuration.nix  # Shared settings for ALL devices
│   │   ├── common.nix              # Base system packages
│   │   └── nix-settings.nix        # Nix daemon settings
│   │
│   ├── hardware/              # Hardware-specific configurations
│   │   ├── intel-laptop.nix   # Intel CPU + integrated GPU
│   │   ├── amd-laptop.nix     # AMD CPU + dedicated GPU
│   │   ├── amd-desktop.nix    # AMD desktop (no battery)
│   │   └── go-xlr.nix         # Go XLR audio interface
│   │
│   ├── software/              # Software suites
│   │   └── creative.nix       # DaVinci Resolve Studio
│   │
│   ├── desktop/               # Desktop environments
│   │   └── hyprland/          # Hyprland Wayland compositor
│   │
│   └── users/                 # Device-specific user accounts
│       ├── laptop.nix         # sam-laptop
│       ├── framework.nix      # sam-framework
│       └── devtower.nix       # sam-desktop
│
└── home/                      # Home Manager (user environment)
    ├── common.nix             # Shared dotfiles, packages, programs
    ├── laptop.nix             # Laptop-specific additions
    ├── framework.nix          # Framework-specific additions
    └── devtower.nix           # DevTower-specific additions
```

## How It Works

### Host Configuration Example

Each host configuration is **minimal** - it just imports the relevant modules:

```nix
# hosts/laptop-intel/configuration.nix
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/base-configuration.nix  # Shared
    ../../modules/hardware/intel-laptop.nix    # Hardware-specific
    ../../modules/desktop/hyprland             # Desktop
    ../../modules/users/laptop.nix             # User
  ];

  networking.hostName = "laptop-intel";
}
```

### Module Composition

**Base Configuration** (`modules/core/base-configuration.nix`):
- Shared settings for ALL devices
- Boot loader, networking, time zone, locale
- Common packages (browsers, audio tools, etc.)
- Hyprland, PipeWire, SSH, firewall
- Affinity Apps (all devices get these)

**Hardware Modules** (`modules/hardware/*.nix`):
- CPU microcode (Intel vs AMD)
- GPU drivers (Intel integrated vs AMD Radeon)
- Power management (laptop vs desktop)
- Device-specific optimizations

**Software Modules** (`modules/software/*.nix`):
- Grouped by purpose (creative, development, etc.)
- Only imported by devices that need them
- Example: DaVinci Resolve Studio only on AMD GPU devices

**User Modules** (`modules/users/*.nix`):
- Device-specific user accounts
- Different username per device (sam-laptop, sam-framework, sam-desktop)
- Separate passwords and home directories

## Staged Installation Architecture

To avoid tmpfs space issues during installation and enable incremental testing, each device has **6 configuration stages**:

### Stage Progression

```
Stage 1 (Minimal)          → Base system only (for nixos-install)
  ↓
Stage 2 (Desktop)          → + Hyprland + zsh + SSH
  ↓
Stage 3 (Development)      → + Browsers + Zed + Neovim + dev tools
  ↓
Stage 4 (Productivity)     → + LibreOffice + communication + media
  ↓
Stage 5 (Creative)         → + DaVinci/Blender (GPU-dependent)
  ↓
Stage 6 (Full)             → Everything + Home Manager (DAILY USE)
```

### Configuration Files

Each host has 6 configuration files:

| File | Flake Target | Purpose |
|------|--------------|---------|
| `configuration-minimal.nix` | `{device}-minimal` | Installation only |
| `configuration-desktop.nix` | `{device}-desktop` | Desktop environment |
| `configuration-dev.nix` | `{device}-dev` | Development tools |
| `configuration-productivity.nix` | `{device}-productivity` | Office & communication |
| `configuration-creative.nix` | `{device}-creative` | Creative software |
| `configuration-full.nix` | `{device}` | **Daily use (all updates)** |

### Installation Workflow

```bash
# 1. Install with minimal config
nixos-install --flake .#laptop-intel-minimal

# 2-5. After reboot, progressively add features
sudo nixos-rebuild switch --flake .#laptop-intel-desktop
sudo nixos-rebuild switch --flake .#laptop-intel-dev
sudo nixos-rebuild switch --flake .#laptop-intel-productivity
sudo nixos-rebuild switch --flake .#laptop-intel-creative

# 6. Switch to full config (for all future updates)
sudo nixos-rebuild switch --flake .#laptop-intel
```

**Key Point**: Stages 1-5 are **one-time installation steps**. Stage 6 (`{device}`) is the **permanent configuration** used for all future updates.

**See**: `docs/STAGED-INSTALLATION-GUIDE.md` for complete details.

### Home Manager

**Common Configuration** (`home/common.nix`):
- Shared packages, dotfiles, programs
- Git, Zsh, Starship, Kitty, Zed
- Hyprland base keybinds

**Device-Specific** (`home/{laptop,framework,devtower}.nix`):
- Imports common.nix
- Adds device-specific packages or settings
- Example: DevTower adds OBS Studio, extra workspaces

## Device Matrix

| Device | User | CPU | GPU | RAM | Software |
|--------|------|-----|-----|-----|----------|
| laptop-intel | sam-laptop | Intel i5-10210U | Intel UHD | 32GB | Affinity Apps |
| framework | sam-framework | AMD Ryzen | AMD Radeon | 64GB | Affinity + DaVinci |
| devtower | sam-desktop | AMD | AMD Radeon | 64GB | Affinity + DaVinci + Go XLR |

## Adding a New Device

1. Create `hosts/{device-name}/configuration.nix` (full configuration)
2. Create `hosts/{device-name}/configuration-minimal.nix` (for installation)
   - See `docs/MINIMAL-CONFIG-TEMPLATE.md` for detailed guidance
   - Follow the standard pattern for consistency
3. Import relevant modules (base + hardware + software + user)
4. Create `modules/users/{device-name}.nix` if needed
5. Create `home/{device-name}.nix` that imports `common.nix`
6. Update `flake.nix` to add both full and minimal targets
7. Generate hardware-configuration.nix during installation

**Important**: Always create a minimal configuration for new devices to avoid tmpfs space issues during installation. The minimal config template supports workstations, servers, NAS, routers, and other device types.

## Adding a New Module

1. Create module file in appropriate directory
2. Define configuration options
3. Import module in relevant host configurations
4. Document in this file

## Benefits of This Architecture

**Maintainability**:
- Change shared settings once, all devices update
- Easy to see what's unique to each device
- No code duplication

**Clarity**:
- Each module has a single purpose
- Host configurations are minimal and readable
- Easy to understand what each device has

**Flexibility**:
- Add/remove modules per device easily
- Override settings in host config if needed
- Reuse modules across devices

**Scalability**:
- Adding new devices is straightforward
- New modules don't affect existing configs
- Easy to test changes in VMs first

## Examples

### Change Browser for All Devices

Edit `modules/core/base-configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  librewolf  # Change this
  firefox
  google-chrome
];
```

All devices get the change on next rebuild.

### Add Go XLR to Framework

Edit `hosts/framework/configuration.nix`:
```nix
imports = [
  # ... existing imports ...
  ../../modules/hardware/go-xlr.nix  # Add this
];
```

Framework now has Go XLR support, other devices unaffected.

### Add Device-Specific Package

Edit `home/devtower.nix`:
```nix
home.packages = with pkgs; [
  obs-studio  # Only on DevTower
];
```

## Future Enhancements

- Phase 2: Secrets module (agenix integration)
- Phase 6: Wireguard module (VPN mesh network)
- Phase 7: Server modules (nginx, cloudflared, gunicorn)
- Phase 10: Rust secrets wrapper integration

## Claude Code Plugins

**Where to configure**:
- Nix manages the Claude Code CLI binary
- Custom plugins (syntek-dev-suite, syntek-rust-security, syntek-infra) go in `~/.config/claude/` after installation
- These are user-specific, not managed by Nix (they're git repos)
- Recommended: Clone plugin repos to `~/Repos/personal/claude-plugins/` and symlink to `~/.config/claude/`
- Phase 4 may integrate this into Home Manager

---

**Summary**: This architecture separates shared configuration from device-specific settings, making the config maintainable, scalable, and easy to understand.
