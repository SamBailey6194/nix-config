# Hyprland Configuration Integration Guide

This document explains how the modular Hyprland configs in `config/hypr/` integrate with the NixOS Home Manager configuration.

## Current Setup (Phase 4)

### Home Manager Configuration
The Home Manager module (`home/modules/hyprland.nix`) currently uses Nix's declarative syntax to configure Hyprland:

```nix
wayland.windowManager.hyprland = {
  enable = true;
  settings = {
    # All settings defined in Nix
  };
};
```

This generates `~/.config/hypr/hyprland.conf` automatically.

### Modular Config Files
The `config/hypr/` directory contains modular configuration files that:
1. Provide a **reference implementation** of the same settings
2. Can be used **standalone** (without NixOS)
3. Serve as **documentation** for the configuration structure
4. Allow for **easier editing** (`.conf` syntax vs Nix syntax)

## Integration Options

### Option 1: Keep Current Approach (Recommended for NixOS)
**Pros:**
- Declarative and reproducible
- Version controlled in Nix
- Easy to understand what's applied
- Can use Nix variables and logic

**Cons:**
- Less familiar syntax (Nix vs `.conf`)
- Harder to quickly tweak settings

**Status:** This is the current approach.

### Option 2: Source Config Files from Home Manager
You can configure Home Manager to source these `.conf` files:

```nix
wayland.windowManager.hyprland = {
  enable = true;
  extraConfig = ''
    source = ${./../../config/hypr/base.conf}
    source = ${./../../config/hypr/monitors.conf}
    # ... etc
  '';
};
```

**Pros:**
- Easier to edit `.conf` files directly
- Familiar Hyprland syntax
- Can still version control

**Cons:**
- Less Nix-native
- Harder to use Nix variables

### Option 3: Hybrid Approach
Use Nix for core settings, `.conf` files for device-specific overrides:

```nix
wayland.windowManager.hyprland = {
  enable = true;
  settings = {
    # Core settings in Nix
  };
  extraConfig = ''
    # Device-specific overrides
    source = ${./../../config/hypr/devices/${device}.conf}
  '';
};
```

## Current File Mapping

| Config File | Home Manager Equivalent | Purpose |
|-------------|-------------------------|---------|
| `base.conf` | `settings.general`, `settings.misc` | Core settings |
| `monitors.conf` | `settings.monitor` | Monitor configuration |
| `input.conf` | `settings.input` | Keyboard, mouse, touchpad |
| `appearance.conf` | `settings.decoration` | Visual styling |
| `animations.conf` | `settings.animations` | Animation settings |
| `keybinds.conf` | `settings.bind`, `settings.bindm` | Keybindings |
| `windowrules.conf` | `settings.windowrulev2` | Window rules |
| `autostart.conf` | `settings.exec-once` | Startup apps |
| `devices/*.conf` | `home/{laptop,framework,devtower}.nix` | Device overrides |

## Device-Specific Settings

### Current Implementation (Home Manager)
Each device has a separate file:
- `home/laptop.nix` → imports `home/common.nix` (which imports `home/modules/hyprland.nix`)
- `home/framework.nix` → same, with overrides
- `home/devtower.nix` → same, with overrides

### Config File Implementation
Each device has a separate `.conf`:
- `config/hypr/devices/laptop-intel.conf`
- `config/hypr/devices/framework.conf`
- `config/hypr/devices/devtower.conf`

## Migration Path (Future)

If you want to migrate to `.conf` files:

1. **Update `home/modules/hyprland.nix`:**
   ```nix
   { config, pkgs, lib, ... }:

   {
     wayland.windowManager.hyprland = {
       enable = true;
       extraConfig = builtins.readFile ../../config/hypr/hyprland.conf;
     };

     # Still configure hyprpaper, hypridle, hyprlock, waybar, wofi in Nix
   }
   ```

2. **Update device-specific files:**
   ```nix
   # home/laptop.nix
   { config, pkgs, ... }:

   {
     imports = [ ./common.nix ];

     # Symlink device-specific config
     home.file.".config/hypr/device.conf".source =
       ../config/hypr/devices/laptop-intel.conf;
   }
   ```

3. **Update `config/hypr/hyprland.conf`:**
   ```conf
   source = ~/.config/hypr/base.conf
   # ... other sources
   source = ~/.config/hypr/device.conf  # Device-specific
   ```

## Recommendation

**For NixOS users:** Keep the current Nix-based approach. It's more declarative and reproducible.

**For non-NixOS users:** Use the `.conf` files directly (see `config/hypr/README.md`).

**For quick tweaks:** Edit the `.conf` files, then migrate changes back to Nix when stable.

## Testing Changes

### With Home Manager (Current)
```bash
# Edit home/modules/hyprland.nix or home/{device}.nix
sudo nixos-rebuild switch --flake ~/.config/nix-config#{device}
# or
home-manager switch --flake ~/.config/nix-config#{device}
```

### With Config Files (If Migrated)
```bash
# Edit config/hypr/*.conf
hyprctl reload
```

## See Also

- `config/hypr/README.md` - Standalone usage guide
- `home/modules/hyprland.nix` - Current Home Manager implementation
- `CLAUDE.md` - Project overview and phase tracking
