# Bug Fix: Hyprland Systemd Service Symlink Collision

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
| **Bug ID**          | BUG-002                                            |
| **Date Identified** | 27/01/2026                                         |
| **Date Fixed**      | 27/01/2026                                         |
| **Severity**        | High                                               |
| **Branch**          | main                                               |
| **Commit**          | TBD (pending commit)                               |
| **Reporter**        | User                                               |
| **Fixed By**        | Claude Code Agent                                  |

### Brief Description

When building NixOS configurations that include both the NixOS Hyprland module (`programs.hyprland.enable = true`) and the Home Manager Hyprland module (`wayland.windowManager.hyprland.enable = true`), a symlink collision occurs because both modules attempt to create the same systemd user service file (`hyprland.service`).

---

## Symptoms

### What Was Observed

Build failure with error message:
```
failed to create symbolic link '........hyprland.service' : file exists
```

### Expected Behaviour

The NixOS configuration should build successfully with Hyprland enabled at both the system level (for session management, portals, etc.) and the user level (for window manager configuration).

### Actual Behaviour

The build fails during the activation phase when Home Manager attempts to create a symlink for `hyprland.service` that already exists from the NixOS module.

### Steps to Reproduce

1. Enable Hyprland in NixOS module:
   ```nix
   # modules/desktop/hyprland/default.nix
   programs.hyprland.enable = true;
   ```

2. Enable Hyprland in Home Manager module:
   ```nix
   # home/modules/hyprland.nix
   wayland.windowManager.hyprland.enable = true;
   ```

3. Build the configuration:
   ```bash
   sudo nixos-rebuild switch --flake .#laptop-intel
   ```

4. **Result:** Build fails with symlink collision error

### Affected Areas

- NixOS system configuration (Stage 6: Full)
- Home Manager user configuration
- Hyprland Wayland compositor setup

### Environment

| Environment | Affected |
| ----------- | -------- |
| Development | Yes      |
| Testing     | Yes      |
| Staging     | N/A      |
| Production  | N/A      |

---

## Root Cause Analysis

### Investigation Process

1. Examined the NixOS Hyprland module (`modules/desktop/hyprland/default.nix`)
2. Examined the Home Manager Hyprland module (`home/modules/hyprland.nix`)
3. Researched Hyprland wiki and NixOS wiki documentation
4. Found official guidance on proper configuration when using both modules

### Hypothesis Testing

| Hypothesis                                      | Result    | Notes                                                    |
| ----------------------------------------------- | --------- | -------------------------------------------------------- |
| Duplicate systemd service creation              | Confirmed | Both modules create `hyprland.service`                   |
| Missing package = null in Home Manager          | Confirmed | Package should be null when using NixOS module           |
| systemd.enable conflict with UWSM               | Confirmed | Home Manager systemd integration conflicts with UWSM     |

### The Root Cause

**Duplicate Hyprland enablement** across two independent NixOS modules:

1. **System-level NixOS module** (`programs.hyprland.enable = true`):
   - Installs Hyprland package
   - Creates systemd user services
   - Sets up XDG desktop portals
   - Configures session files for display managers

2. **Home Manager module** (`wayland.windowManager.hyprland.enable = true`):
   - Also attempts to install Hyprland package
   - Also creates systemd user services (collision!)
   - Configures window manager settings

Both modules independently create the `hyprland.service` systemd user service, causing a symlink collision during activation.

**Technical Details:**
```
# NixOS module creates:
/etc/systemd/user/hyprland.service

# Home Manager module also creates:
~/.config/systemd/user/hyprland.service

# During activation, Home Manager fails because the service already exists
```

### Why This Bug Occurred

1. **Incorrect assumptions**: The configuration assumed both modules could be enabled independently without coordination
2. **Missing documentation review**: The Hyprland wiki explicitly documents this conflict and the solution
3. **Default Home Manager behaviour**: Home Manager's Hyprland module defaults to installing its own package and systemd services

---

## The Fix

### Code Changes

Modified `home/modules/hyprland.nix` to:
1. Set `package = null` to use the system-level Hyprland package
2. Set `portalPackage = null` to use the system-level XDG portal
3. Set `systemd.enable = false` to prevent duplicate service creation

**Before:**
```nix
wayland.windowManager.hyprland = {
  enable = true;

  settings = {
    # ... configuration
  };
};
```

**After:**
```nix
wayland.windowManager.hyprland = {
  enable = true;

  # CRITICAL: Use the Hyprland package from NixOS module, not Home Manager
  # This prevents duplicate systemd services and symlink conflicts
  # Requires Home Manager 5dc1c2e40410f7dabef3ba8bf4fdb3145eae3ceb or later
  package = null;
  portalPackage = null;

  # CRITICAL: Disable systemd integration to prevent conflicts with UWSM
  # The NixOS module handles session management via UWSM (if enabled)
  # or via its own systemd integration
  systemd.enable = false;

  settings = {
    # ... configuration (unchanged)
  };
};
```

### Why This Fix Works

Setting these options tells Home Manager to:

1. **`package = null`**: Do not install Hyprland; use the package already installed by the NixOS module
2. **`portalPackage = null`**: Do not install XDG desktop portal; use the portal already configured by the NixOS module
3. **`systemd.enable = false`**: Do not create systemd user services; the NixOS module handles session management

This approach follows the official Hyprland documentation's "recommended configuration" for using both the NixOS module and Home Manager module together.

**Key points:**
1. The NixOS module (`programs.hyprland.enable`) handles all system-level concerns (package, portals, session files, systemd services)
2. The Home Manager module ONLY provides user-level configuration (keybindings, settings, appearance)
3. This separation of concerns prevents resource conflicts and follows the principle of "single source of truth"

### Alternative Solutions Considered

| Solution                        | Pros                            | Cons                                          | Why Rejected/Chosen |
| ------------------------------- | ------------------------------- | --------------------------------------------- | ------------------- |
| Disable NixOS module            | Simpler, single source          | Loses session management, portal integration  | Rejected - loses critical functionality |
| Disable Home Manager module     | Simpler                         | Loses declarative Hyprland config             | Rejected - want declarative config |
| Use only Home Manager (no UWSM) | Full HM control                 | No UWSM benefits, manual session management   | Rejected - UWSM is recommended |
| **Set package/portal to null**  | **Best of both worlds**         | **Requires understanding the relationship**   | **Chosen - official recommendation** |

---

## Files Changed

| File                          | Change Type | Description                                                    |
| ----------------------------- | ----------- | -------------------------------------------------------------- |
| `home/modules/hyprland.nix`   | Modified    | Added `package = null`, `portalPackage = null`, `systemd.enable = false` |

### Code Diff Summary

The change adds three configuration options to the Home Manager Hyprland module that delegate package installation and systemd service management to the NixOS module, preventing the symlink collision.

---

## Prevention

### How to Prevent Similar Bugs

1. **Documentation Review**: Always consult the official Hyprland wiki when configuring:
   - https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/
   - https://wiki.hypr.land/Nix/Hyprland-on-NixOS/
   - https://wiki.nixos.org/wiki/Hyprland

2. **Understand Module Responsibilities**:
   - NixOS modules: System-level configuration (packages, services, session management)
   - Home Manager modules: User-level configuration (settings, dotfiles, appearance)

3. **Code Review Checklist**:
   - When enabling a program in both NixOS and Home Manager, check if coordination is needed
   - Look for `package = null` patterns in Home Manager when NixOS provides the package

4. **Testing**: Always test configuration builds before deploying:
   ```bash
   nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run
   ```

### Linting/Static Analysis

Currently, there is no linting rule to catch this specific issue. Future consideration could be:
- A custom NixOS/Home Manager linting rule that warns when both modules enable the same service without proper coordination

### Pre-Commit Checks

Consider adding a configuration validation step:
```bash
# In pre-commit or CI
nix flake check
```

---

## Regression Testing

### Test Cases to Add

| Test Case                         | Description                                           | Priority |
| --------------------------------- | ----------------------------------------------------- | -------- |
| `test_hyprland_builds`            | Verify full configuration builds without errors       | High     |
| `test_no_duplicate_services`      | Verify no duplicate systemd service definitions       | Medium   |
| `test_hyprland_session`           | Verify Hyprland session starts correctly              | High     |

### Manual Testing Checklist

- [ ] Build `laptop-intel` configuration without errors
- [ ] Build `framework` configuration without errors
- [ ] Build `devtower` configuration without errors
- [ ] Verify Hyprland session starts correctly after switch
- [ ] Verify Home Manager Hyprland settings are applied (keybindings, etc.)
- [ ] Verify waybar, hyprpaper, and other services start correctly

### Automated Test Example

```bash
#!/usr/bin/env bash
# test_hyprland_build.sh

set -euo pipefail

echo "Testing Hyprland configuration builds..."

for host in laptop-intel framework devtower; do
    echo "Building $host..."
    nix build .#nixosConfigurations.$host.config.system.build.toplevel \
        --dry-run \
        --no-link \
        2>&1 || {
            echo "FAIL: $host failed to build"
            exit 1
        }
    echo "PASS: $host"
done

echo "All Hyprland configurations build successfully"
```

---

## Related Issues

### Related Bugs

- None currently identified

### Related User Stories

- N/A (infrastructure configuration)

### Related PRs

- N/A (direct commit to main)

### External References

- [Hyprland on Home Manager - Hyprland Wiki](https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/)
- [Hyprland on NixOS - Hyprland Wiki](https://wiki.hypr.land/Nix/Hyprland-on-NixOS/)
- [Hyprland - NixOS Wiki](https://wiki.nixos.org/wiki/Hyprland)
- [NixOS Discourse: Hyprland crashes with wayland.windowManager.hyprland.enable](https://discourse.nixos.org/t/hyprland-crashes-when-wayland-windowmanager-hyprland-enable-is-used/57023)
- [GitHub Issue: uwsm breaks some services](https://github.com/hyprwm/Hyprland/issues/9265)

---

## Summary

This bug was caused by enabling Hyprland in both the NixOS module and Home Manager module without proper coordination. The fix follows the official Hyprland documentation's recommendation to set `package = null`, `portalPackage = null`, and `systemd.enable = false` in the Home Manager module, delegating all system-level concerns to the NixOS module while retaining declarative user-level configuration in Home Manager.
