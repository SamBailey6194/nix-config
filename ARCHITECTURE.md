# NixOS Configuration Architecture

This document explains the modular architecture of this NixOS configuration.

## Design Philosophy

**DRY (Don't Repeat Yourself)**: Shared configuration is defined once in base modules, device-specific settings are isolated in focused modules.

**Composability**: Each host imports only the modules it needs, making the configuration clear and maintainable.

**Separation of Concerns**: Hardware, software, users, and desktop environment are separated into distinct modules.

## Directory Structure

```
nix-config/
├── flake.nix                  # Entry point - defines all hosts
├── hosts/                     # Per-device configurations (minimal)
│   ├── laptop-intel/
│   │   ├── configuration.nix  # Just imports modules + hostname
│   │   └── hardware-configuration.nix
│   ├── framework/
│   └── devtower/
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

1. Create `hosts/{device-name}/configuration.nix`
2. Import relevant modules (base + hardware + software + user)
3. Create `modules/users/{device-name}.nix` if needed
4. Create `home/{device-name}.nix` that imports `common.nix`
5. Update `flake.nix` to add the new host
6. Generate hardware-configuration.nix during installation

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
