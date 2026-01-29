# Bug Fix: Multiple Configuration Errors in NixOS Flake

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
## Table of Contents

- [Overview](#overview)
- [Symptoms](#symptoms)
- [Root Cause Analysis](#root-cause-analysis)
- [The Fix](#the-fix)
- [Why This Fix Works](#why-this-fix-works)
- [Files Changed](#files-changed)
- [Prevention](#prevention)
- [Regression Testing](#regression-testing)
- [Related Issues](#related-issues)

---

## Overview

| Field               | Value                                              |
| ------------------- | -------------------------------------------------- |
| **Bug ID**          | BUG-001                                            |
| **Date Identified** | 27/01/2026                                         |
| **Date Fixed**      | 27/01/2026                                         |
| **Severity**        | High                                               |
| **Branch**          | main                                               |
| **Commit**          | TBD                                                |
| **Reporter**        | User                                               |
| **Fixed By**        | Claude Debug Agent                                 |

### Brief Description

Multiple dependency and configuration errors in the NixOS flake prevented successful evaluation. Issues included:

1. **affinity-nix.nixosModules.default** - Attribute does not exist (flake only provides packages)
2. **hardware.opengl.driSupport** - Deprecated option (moved to hardware.graphics)
3. **services.power-profiles-daemon vs services.tlp** - Conflicting services
4. **vaapiVdpau** - Package renamed to libva-vdpau-driver
5. **Kitty theme** - `theme` deprecated, use `themeFile`
6. **Hyprland settings syntax** - Strings not assigned to `bind` key
7. **OpenRGB server.enable** - Invalid option path

---

## Symptoms

### What Was Observed

Running `nix flake check` failed with multiple sequential errors as each issue was encountered:

```
error: attribute 'default' missing
at flake.nix:73:11 - affinity-nix.nixosModules.default

error: Failed assertions:
- The option definition `hardware.opengl.driSupport' no longer has any effect
- services.power-profiles-daemon.enable conflicts with services.tlp.enable

error: 'vaapiVdpau' has been renamed to 'libva-vdpau-driver'

error: path 'kitty-themes' is not valid

error: syntax error, unexpected '"', expecting '.' or '='
at home/framework.nix:23:5

error: The option `services.hardware.openrgb.server.enable' does not exist
```

### Expected Behaviour

All NixOS configurations should evaluate successfully with `nix flake check`.

### Actual Behaviour

Sequential failures across different configurations due to deprecated options, missing attributes, and syntax errors.

### Affected Areas

- `flake.nix` - Incorrect module references
- `modules/hardware/amd-laptop.nix` - Deprecated options
- `modules/hardware/amd-desktop.nix` - Deprecated options
- `modules/hardware/openrgb.nix` - Invalid option
- `home/common.nix` - Deprecated kitty theme option
- `home/framework.nix` - Hyprland settings syntax
- `home/devtower.nix` - Hyprland settings syntax
- All creative and full stage configurations

---

## Root Cause Analysis

### Investigation Process

1. Ran `nix flake check` to identify failing configurations
2. Used `nix flake show` to verify affinity-nix outputs
3. Traced error messages to specific option definitions
4. Checked NixOS/home-manager documentation for option renames

### Issues Identified

| Issue | Root Cause | Affected Files |
|-------|-----------|----------------|
| affinity-nix.nixosModules.default | Flake only exports packages, not nixosModules | flake.nix |
| hardware.opengl.driSupport | Merged into hardware.graphics | amd-laptop.nix, amd-desktop.nix |
| power-profiles-daemon vs tlp | Cannot enable both simultaneously | amd-laptop.nix |
| vaapiVdpau | Package renamed upstream | amd-laptop.nix, amd-desktop.nix |
| programs.kitty.theme | Deprecated, use themeFile | home/common.nix |
| Hyprland settings syntax | Strings need to be in `bind` list | home/framework.nix, home/devtower.nix |
| openrgb.server.enable | Option does not exist | openrgb.nix |

---

## The Fix

### 1. affinity-nix Module Reference (flake.nix)

**Before:**
```nix
modules = [
  ./hosts/laptop-intel/configuration-creative.nix
  affinity-nix.nixosModules.default  # Does not exist
];
```

**After:**
```nix
modules = [
  ./hosts/laptop-intel/configuration-creative.nix
  # Affinity packages added via inputs in configuration files
];
```

Then in configuration files:
```nix
environment.systemPackages = with pkgs; [
  # ...
] ++ [
  inputs.affinity-nix.packages.${pkgs.system}.designer
  inputs.affinity-nix.packages.${pkgs.system}.photo
  inputs.affinity-nix.packages.${pkgs.system}.publisher
];
```

### 2. Deprecated hardware.opengl Options (amd-*.nix)

**Before:**
```nix
hardware.opengl = {
  driSupport = true;
  driSupport32Bit = true;
};
```

**After:**
```nix
# Removed - DRI support is automatic when hardware.graphics.enable = true
```

### 3. Conflicting Power Management (amd-laptop.nix)

**Before:**
```nix
services.power-profiles-daemon.enable = true;
services.tlp.enable = true;
```

**After:**
```nix
services.power-profiles-daemon.enable = false;  # Disabled - using TLP instead
services.tlp.enable = true;
```

### 4. Package Rename (amd-*.nix)

**Before:**
```nix
extraPackages = with pkgs; [
  vaapiVdpau
];
```

**After:**
```nix
extraPackages = with pkgs; [
  libva-vdpau-driver  # Renamed from vaapiVdpau
];
```

### 5. Kitty Theme (home/common.nix)

**Before:**
```nix
programs.kitty = {
  theme = "Tokyo Night";
};
```

**After:**
```nix
programs.kitty = {
  themeFile = "tokyo_night_night";
};
```

### 6. Hyprland Settings Syntax (home/framework.nix, home/devtower.nix)

**Before:**
```nix
wayland.windowManager.hyprland.settings = {
  "$mod, 6, workspace, 6"
  "$mod, 7, workspace, 7"
};
```

**After:**
```nix
wayland.windowManager.hyprland.settings.bind = [
  "$mod, 6, workspace, 6"
  "$mod, 7, workspace, 7"
];
```

### 7. OpenRGB Configuration (openrgb.nix)

**Before:**
```nix
services.hardware.openrgb = {
  enable = true;
  server.enable = true;  # Does not exist
};
```

**After:**
```nix
services.hardware.openrgb = {
  enable = true;
  # Server functionality via --server flag manually
};
```

---

## Files Changed

| File | Change Type | Description |
|------|-------------|-------------|
| `flake.nix` | Modified | Removed affinity-nix.nixosModules.default (6 occurrences) |
| `modules/hardware/amd-laptop.nix` | Modified | Fixed deprecated options, package rename, power management conflict |
| `modules/hardware/amd-desktop.nix` | Modified | Fixed deprecated options and package rename |
| `modules/hardware/openrgb.nix` | Modified | Removed invalid server.enable option |
| `home/common.nix` | Modified | Changed kitty theme to themeFile |
| `home/framework.nix` | Modified | Fixed Hyprland settings syntax |
| `home/devtower.nix` | Modified | Fixed Hyprland settings syntax |
| `hosts/laptop-intel/configuration-creative.nix` | Modified | Added Affinity packages via inputs |
| `hosts/laptop-intel/configuration-full.nix` | Modified | Added Affinity packages via inputs |
| `hosts/framework/configuration-creative.nix` | Modified | Added Affinity packages via inputs |
| `hosts/framework/configuration-full.nix` | Modified | Added Affinity packages via inputs |
| `hosts/devtower/configuration-creative.nix` | Modified | Added Affinity packages via inputs |
| `hosts/devtower/configuration-full.nix` | Modified | Added Affinity packages via inputs |

---

## Prevention

### How to Prevent Similar Bugs

1. **Verify flake outputs:** Run `nix flake show <flake>` before using external flakes
2. **Check option paths:** Use NixOS search (search.nixos.org) to verify option names
3. **Run flake check regularly:** Add `nix flake check` to CI/CD pipeline
4. **Review changelogs:** Check home-manager and NixOS changelogs for deprecations
5. **Test incrementally:** Test configuration changes in stages

### Recommended CI Check

```yaml
- name: Nix Flake Check
  run: nix --extra-experimental-features 'nix-command flakes' flake check --no-build
```

---

## Regression Testing

### Manual Testing Checklist

- [x] `nix flake check --no-build` passes
- [x] All laptop-intel configurations evaluate successfully
- [x] All framework configurations evaluate successfully
- [x] All devtower configurations evaluate successfully
- [x] devShells evaluate successfully

### Remaining Warnings (Non-Breaking)

The following deprecation warnings should be addressed in a future update:

1. `programs.zsh.initExtra` -> `programs.zsh.initContent`
2. `xfce.thunar-volman` -> `pkgs.thunar-volman`
3. `xfce.thunar-archive-plugin` -> `pkgs.thunar-archive-plugin`
4. `programs.neovim.extraLuaConfig` -> `programs.neovim.initLua`
5. `programs.git.aliases` -> `programs.git.settings.alias`
6. `programs.git.userEmail` -> `programs.git.settings.user.email`
7. `programs.git.userName` -> `programs.git.settings.user.name`
8. `programs.git.extraConfig` -> `programs.git.settings`
9. `programs.zsh.dotDir` default changing in 26.05
10. `'system'` deprecated, use `stdenv.hostPlatform.system`

---

## Related Issues

### Related Bugs

- None

### External References

- affinity-nix: https://github.com/mrshmllow/affinity-nix
- NixOS Options Search: https://search.nixos.org/options
- Home Manager Options: https://nix-community.github.io/home-manager/options.html
