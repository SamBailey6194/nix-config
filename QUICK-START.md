# Quick Start - NixOS Configuration

## What is this?

A declarative NixOS configuration with Hyprland, managing your entire system from bootloader to desktop environment.

## Current Status: Phase 1

**Ready for**: NixOS installation on Intel i5-10210U laptop

**What's configured**:
- ✅ Hyprland Wayland compositor with basic keybinds
- ✅ Essential desktop apps (kitty, firefox, wofi, waybar)
- ✅ Intel graphics and power management
- ✅ Home Manager for user environment
- ✅ Multi-account git setup (personal, syntek, missional-gen)
- ✅ Zed IDE configuration

## File Structure

```
nix-config/
├── flake.nix                    # Entry point - defines system
├── hosts/laptop-intel/          # Your current laptop config
│   ├── configuration.nix        # System settings
│   └── hardware-configuration.nix  # Hardware-specific (disks, etc.)
├── modules/                     # Reusable modules
│   ├── core/                    # Base system
│   └── desktop/hyprland/        # Hyprland desktop
└── home/                        # User environment
    └── default.nix              # Dotfiles, packages, programs
```

## Common Commands

### System Management

```bash
# Rebuild system after config changes
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel

# Test configuration without activating
sudo nixos-rebuild test --flake /etc/nixos/nix-config#laptop-intel

# Build without activating (safe)
sudo nixos-rebuild build --flake /etc/nixos/nix-config#laptop-intel

# Update flake inputs (nixpkgs, home-manager, etc.)
nix flake update

# Garbage collect old generations
sudo nix-collect-garbage -d

# List system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Hyprland Keybinds

**Basic**:
- `Super + Return` - Terminal (kitty)
- `Super + D` - App launcher (wofi)
- `Super + Q` - Close window
- `Super + Shift + E` - Exit Hyprland

**Window Management**:
- `Super + H/J/K/L` - Focus window (vim-style)
- `Super + Shift + H/J/K/L` - Move window
- `Super + F` - Toggle floating
- `Super + M` - Fullscreen

**Workspaces**:
- `Super + 1-5` - Switch workspace
- `Super + Shift + 1-5` - Move window to workspace

**Utilities**:
- `Print` - Screenshot (select area)

### Package Management

```bash
# Search for packages
nix search nixpkgs <package-name>

# Try package temporarily
nix shell nixpkgs#<package-name>

# Add package permanently: edit home/default.nix
# Then rebuild
```

## Making Changes

### Add a Package

1. Edit `home/default.nix`
2. Add package to `home.packages` list
3. Rebuild: `sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel`

### Modify Hyprland Config

1. Edit `home/default.nix` under `wayland.windowManager.hyprland.settings`
2. Rebuild to apply changes

### Change System Settings

1. Edit `hosts/laptop-intel/configuration.nix`
2. Rebuild with sudo

## Git Workflow

This repo uses multi-account git setup:

```bash
# Check current git identity
git config user.email

# Should show: sambailey6194@gmail.com (in ~/Repos/personal/)
```

To commit changes:

```bash
cd /etc/nixos/nix-config
git add .
git commit -m "Description of changes"
git push origin main
```

## Updating the System

```bash
# Update flake inputs (nixpkgs, home-manager, etc.)
cd /etc/nixos/nix-config
nix flake update

# Review what will change
git diff flake.lock

# Rebuild with new versions
sudo nixos-rebuild switch --flake .#laptop-intel
```

## Troubleshooting

### Configuration Doesn't Build

```bash
# Check syntax
nix flake check

# See detailed error
sudo nixos-rebuild build --flake .#laptop-intel --show-trace
```

### Hyprland Crashes or Freezes

```bash
# Switch to TTY (Ctrl+Alt+F2)
# Check logs
journalctl -b -u display-manager
journalctl --user -u hyprland

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Out of Disk Space

```bash
# Clean up old generations
sudo nix-collect-garbage -d

# Optimize nix store
nix-store --optimise
```

## Resources

- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **Home Manager**: https://nix-community.github.io/home-manager/
- **Hyprland Wiki**: https://wiki.hyprland.org/
- **Nix Package Search**: https://search.nixos.org/

## Next Steps

After successful Phase 1 installation:
1. **Phase 2**: Set up agenix for secrets (SSH keys, Wireguard keys)
2. **Phase 3**: Add second device (Framework or DevTower)
3. **Phase 4**: Full dotfiles integration with Home Manager

See `README.md` for the complete 12-phase roadmap.
