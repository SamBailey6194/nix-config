# Hyprland Modular Configuration Summary

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
Created: 2026-01-24
Phase: 4 - Home Manager + Dotfiles Integration

## What Was Created

A complete modular Hyprland configuration structure in `config/hypr/` with:

### Base Configuration Files

| File | Purpose | Lines |
|------|---------|-------|
| `hyprland.conf` | Main config that sources all modules | 17 |
| `base.conf` | Core settings (modifier, layout, misc) | 42 |
| `monitors.conf` | Monitor configuration | 9 |
| `input.conf` | Keyboard, mouse, touchpad | 12 |
| `appearance.conf` | Decorations, blur, shadows | 19 |
| `animations.conf` | Animation settings | 14 |
| `keybinds.conf` | All keybindings | 75 |
| `windowrules.conf` | Window rules (float, opacity, workspace) | 15 |
| `autostart.conf` | Startup applications | 13 |

### Device-Specific Configurations

| File | Device | Customizations |
|------|--------|----------------|
| `devices/laptop-intel.conf` | Intel laptop (i5-10210U, 32GB) | Battery-optimized blur, brightness control |
| `devices/framework.conf` | Framework AMD (Ryzen + Radeon, 64GB) | High-DPI scaling (1.25), DaVinci workspace rules |
| `devices/devtower.conf` | AMD desktop (CPU + GPU, 64GB) | Multi-monitor setup, high-performance settings |

### Documentation

| File | Purpose |
|------|---------|
| `README.md` | User guide for standalone usage and customization |
| `INTEGRATION.md` | How configs integrate with Home Manager (NixOS) |
| `HYPRLAND-CONFIGS-SUMMARY.md` | This file - overview of what was created |

## Directory Structure

```
config/hypr/
├── hyprland.conf           # Main entry point
├── base.conf               # Core settings
├── monitors.conf           # Monitor setup
├── input.conf              # Input devices
├── appearance.conf         # Visual styling
├── animations.conf         # Animations
├── keybinds.conf           # Keybindings
├── windowrules.conf        # Window rules
├── autostart.conf          # Startup apps
├── devices/                # Device-specific overrides
│   ├── laptop-intel.conf
│   ├── framework.conf
│   └── devtower.conf
├── README.md               # User guide
└── INTEGRATION.md          # NixOS integration guide
```

## Key Features

### Modular Design
- **Base config** shared across all devices
- **Device-specific overrides** for unique hardware/workflows
- **Easy to customize** - edit individual files instead of one large config

### Vim-Style Navigation
- `Super+H/J/K/L` - Move focus
- `Super+Shift+H/J/K/L` - Move windows

### Workspaces
- `Super+1-0` - Switch workspace
- `Super+Shift+1-0` - Move window to workspace
- `Super+S` - Scratchpad

### Ayu Dark Theme
- Active border: Orange (#ffb454) → Blue (#59c2ff) gradient
- Inactive border: Gray (#595959)
- Consistent with Zed, git, and other configs

### Device Optimizations

**laptop-intel:**
- Reduced blur for battery life
- Brightness set to 50% on startup
- Optimized for single display

**framework:**
- High-DPI scaling (1.25)
- DaVinci Resolve on workspace 5
- Affinity apps on workspace 4
- Enhanced blur for creative work

**devtower:**
- Multi-monitor support (2x 4K @ 60Hz)
- High-performance settings
- Enhanced animations
- DaVinci Resolve, OBS, Affinity workspace rules

## Usage

### With NixOS/Home Manager (Current)
The Home Manager module (`home/modules/hyprland.nix`) handles all configuration declaratively. These files serve as:
1. Reference implementation
2. Documentation
3. Fallback for non-NixOS systems

### Standalone (Without NixOS)
1. Symlink configs to `~/.config/hypr/`
2. Edit `hyprland.conf` to enable device-specific config
3. Reload: `hyprctl reload`

See `config/hypr/README.md` for detailed instructions.

## Integration with Home Manager

Current implementation:
- **Nix declarative config** in `home/modules/hyprland.nix`
- **Device overrides** in `home/{laptop,framework,devtower}.nix`
- **.conf files** as reference/documentation

Future option:
- Use `extraConfig` to source `.conf` files from Home Manager
- See `config/hypr/INTEGRATION.md` for migration path

## Ecosystem Configured

All configs assume these packages are installed:
- **hyprland** - Wayland compositor
- **waybar** - Status bar
- **wofi** - App launcher
- **hyprpaper** - Wallpaper daemon
- **hypridle** - Idle management
- **hyprlock** - Screen locker
- **dunst** - Notifications
- **grim + slurp + swappy** - Screenshots
- **kitty** - Terminal
- **thunar** - File manager

These are all installed via `modules/desktop/hyprland/default.nix`.

## Next Steps

1. **Test on laptop-intel** after NixOS installation
2. **Adjust monitor configs** based on actual hardware
3. **Customize keybinds** if needed
4. **Add wallpapers** to `~/Pictures/wallpapers/`
5. **Fine-tune device-specific settings** after testing

## Files Modified

- `config/hypr/` - Created entire directory structure
- `.claude/CLAUDE.md` - Updated architecture diagram to include `config/hypr/`

## Related Documentation

- `PHASE-4-COMPLETE.md` - Home Manager integration completion
- `ARCHITECTURE.md` - Overall modular design
- `QUICK-START.md` - Installation guide
- `config/hypr/README.md` - Hyprland usage guide
- `config/hypr/INTEGRATION.md` - NixOS integration details
