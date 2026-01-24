# Configuration Refactor Summary

## What Changed

Refactored from monolithic host configurations to a **modular, composable architecture** based on user request for "one global configuration with device-specific additions."

## Architecture Improvements

### Before (Monolithic)
```
hosts/laptop-intel/configuration.nix  (95 lines, all settings inline)
home/default.nix                      (133 lines, all settings inline)
```

### After (Modular)
```
hosts/laptop-intel/configuration.nix  (27 lines, just imports modules)
modules/core/base-configuration.nix   (Shared settings for ALL devices)
modules/hardware/intel-laptop.nix     (Intel-specific settings)
modules/users/laptop.nix              (Device-specific user)
home/common.nix                       (Shared dotfiles/packages)
home/laptop.nix                       (Device-specific additions)
```

## Benefits

1. **DRY**: Shared configuration defined once, not repeated
2. **Clarity**: Easy to see what's shared vs device-specific
3. **Maintainability**: Change once, all devices update
4. **Scalability**: Adding devices is straightforward

## New Features Added

### Multi-Device Support
- ✅ laptop-intel (Intel i5-10210U, 32GB, Intel UHD)
- ✅ framework (AMD Ryzen + Radeon, 64GB) - configured but not yet installed
- ✅ devtower (AMD CPU + GPU, 64GB, Go XLR) - configured but not yet installed

### Separate Users Per Device
- **sam-laptop** (laptop-intel)
- **sam-framework** (framework)
- **sam-desktop** (devtower)

Each user has separate password and home directory.

### Creative Software
- **Affinity Apps** (Designer, Photo, Publisher) - ALL devices
- **DaVinci Resolve Studio** - Framework and DevTower only (requires AMD GPU)
- **Go XLR Utility** - DevTower only

### Enhanced Audio
- qpwgraph (PipeWire graph manager)
- pavucontrol (Volume control)
- Device-specific latency settings (desktop: 256, laptop: 1024)

### Browsers
- **LibreWolf** - Personal use, hardened security
- **Firefox** - Dev testing
- **Chrome** - Claude Chrome extension

### Fonts
- Ubuntu Mono - configured in Zed

## Module Categories

| Category | Purpose | Example |
|----------|---------|---------|
| `core/` | Shared base configuration | base-configuration.nix |
| `hardware/` | Hardware-specific settings | intel-laptop.nix, go-xlr.nix |
| `software/` | Software suites | creative.nix (DaVinci) |
| `desktop/` | Desktop environments | hyprland/ |
| `users/` | Device-specific users | laptop.nix, framework.nix |

## How Device Configuration Works

Each host imports only what it needs:

### laptop-intel
```nix
imports = [
  base-configuration.nix
  intel-laptop.nix      # Intel hardware
  hyprland/
  users/laptop.nix      # sam-laptop user
];
```

### framework
```nix
imports = [
  base-configuration.nix
  amd-laptop.nix        # AMD hardware
  creative.nix          # DaVinci Resolve
  hyprland/
  users/framework.nix   # sam-framework user
];
```

### devtower
```nix
imports = [
  base-configuration.nix
  amd-desktop.nix       # AMD desktop hardware
  go-xlr.nix            # Go XLR audio
  creative.nix          # DaVinci Resolve
  hyprland/
  users/devtower.nix    # sam-desktop user
];
```

## Home Manager Changes

### Shared (home/common.nix)
- VS Code, Git, CLI tools
- Zed, Zsh, Starship, Kitty
- Hyprland base keybinds (Super+H/J/K/L, etc.)

### Device-Specific
- **laptop.nix**: No additions (uses common only)
- **framework.nix**: Workspaces 1-9 for video editing
- **devtower.nix**: OBS Studio, Workspaces 1-10, multi-monitor config

## File Count

**Created**:
- 5 new core/hardware/software modules
- 3 user modules (laptop, framework, devtower)
- 1 shared home-manager config
- 3 device-specific home configs
- 2 new host configurations (framework, devtower)
- 1 architecture documentation

**Modified**:
- flake.nix (added affinity-nix input, activated framework/devtower)
- laptop-intel configuration (now modular)
- CLAUDE.md (updated architecture section)

## Configuration Settings

### Fixed
- **Timezone**: Changed from Australia/Melbourne to Europe/London (UK GMT)
- **Locale**: Changed from en_AU.UTF-8 to en_GB.UTF-8

### Maintained
- All existing laptop-intel functionality preserved
- Hyprland keybinds unchanged
- Development tools unchanged

## Claude Code Plugins

**Decision**: Plugins (syntek-dev-suite, syntek-rust-security, syntek-infra) are **not** managed by Nix.

**Rationale**:
- They're git repositories
- User-specific configuration
- Managed separately in `~/.config/claude/`

**Recommendation**: Phase 4 may add symlink management via Home Manager.

## Testing Status

- ✅ Configuration builds (syntax valid)
- ✅ Modular design verified
- ⏳ Runtime testing: Awaiting NixOS installation on laptop-intel

## Next Steps

1. Install NixOS on laptop-intel using this configuration
2. Verify all features work (Affinity Apps, browsers, audio, Hyprland)
3. Proceed to Phase 2: Secrets management with agenix
4. Eventually install Framework and DevTower when hardware arrives

## Documentation

- `ARCHITECTURE.md` - Detailed explanation of modular design
- `INSTALL.md` - Installation instructions (unchanged)
- `QUICK-START.md` - Commands reference (unchanged)
- `CLAUDE.md` - Updated with new architecture

---

**Result**: Clean, maintainable, scalable NixOS configuration ready for multi-device deployment! 🎉
