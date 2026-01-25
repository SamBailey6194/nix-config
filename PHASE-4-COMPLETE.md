# Phase 4: Home Manager + Dotfiles - COMPLETE ✅

**Date Completed**: 2026-01-24
**Branch**: feature/nix-barebones

## What Was Accomplished

Phase 4 successfully integrates all existing dotfiles with Home Manager and organizes software into modular, composable packages.

### ✅ Home Manager Integration

**Created modular home configuration**:
- `home/common.nix` - Imports all modules, manages XDG directories
- `home/modules/git.nix` - Multi-account git with conditional includes
- `home/modules/editor.nix` - Complete Zed configuration (settings + keymaps)
- `home/modules/shell.nix` - Zsh + Oh My Zsh integration
- `home/modules/hyprland.nix` - Hyprland with Waybar, Wofi, Hypridle, Hyprlock

**Integrated existing configs**:
- Git multi-account setup (personal, syntek, missional-gen)
- Zed settings.json (all language configs, LSP settings)
- Zed keymap.json (workspace, editor, terminal bindings)
- Zsh .zshrc with Oh My Zsh, custom prompt, aliases
- Hyprland keybinds and window rules

### ✅ Software Modules Organization

Created purpose-specific software modules in `modules/software/`:

| Module | Purpose | Key Packages |
|--------|---------|--------------|
| `browsers.nix` | Web browsers | LibreWolf, Firefox, Chrome |
| `communication.nix` | Chat & collaboration | **Discord, Teams, Zoom**, Slack, Obsidian |
| `media.nix` | Media & entertainment | VLC, **Spotify**, Audacity, image viewers |
| `development.nix` | Dev tools | VS Code, Docker, Python, Node.js, language servers |
| `office.nix` | Productivity | LibreOffice, PDF tools |
| `creative.nix` | Creative suite | DaVinci Resolve, Blender, Reaper (GPU devices only) |

**Note**: Gaming module NOT created per user request (Windows device for gaming)

### ✅ Software Now Installed on All Devices

**Communication** (all devices):
- ✅ Discord
- ✅ Microsoft Teams
- ✅ Zoom
- ✅ Slack
- ✅ Obsidian

**Media** (all devices):
- ✅ Spotify
- ✅ VLC
- ✅ Audacity

**All other base software** from previous phases remains.

### ✅ Home Manager Features

**Git Configuration**:
- Multi-account support with conditional includes
- Automatic account switching based on directory
- Commit message template
- Git aliases (st, co, br, lg, etc.)

**Zed Editor**:
- Full settings.json with language-specific configs
- Python (Ruff + Pyright), TypeScript (Prettier + ESLint), Rust, etc.
- Custom keybindings (VS Code-style)
- LSP configurations for all languages
- Ubuntu Mono font

**Zsh Shell**:
- Oh My Zsh with robbyrussell theme
- Custom prompt (green arrow, cyan directory, yellow input)
- Git, Docker, Docker-Compose plugins
- Aliases for Claude Code, apt (legacy Ubuntu)
- NVM integration
- Android SDK paths

**Hyprland Desktop**:
- Vim-style navigation (Super+H/J/K/L)
- 10 workspaces
- Waybar status bar with system info
- Wofi app launcher (Ayu Dark theme)
- Hypridle for power management
- Hyprlock screen locker
- Dunst notifications
- GTK/Qt theming (Adwaita Dark)

### ✅ XDG User Directories

Home Manager now manages:
- Desktop, Documents, Downloads
- Music, Pictures, Videos
- Public, Templates

All created automatically on first login.

### ✅ Session Variables

**All devices**:
- `EDITOR=zed --wait`
- `BROWSER=/path/to/google-chrome`
- Wayland environment variables
- UV package manager settings
- Android SDK paths

## Architecture Improvements

### Before (Phase 3)
```
home/common.nix  - Everything inline, basic configs
```

### After (Phase 4)
```
home/
├── common.nix           # Imports all modules
├── modules/
│   ├── git.nix          # Multi-account git
│   ├── editor.nix       # Zed configuration
│   ├── shell.nix        # Zsh + Oh My Zsh
│   └── hyprland.nix     # Desktop environment
├── laptop.nix           # Device-specific
├── framework.nix
└── devtower.nix
```

## File Locations After Home Manager

Home Manager will symlink configs to:

| Config | Source | Symlinked To |
|--------|--------|--------------|
| Git | `home/modules/git.nix` | `~/.gitconfig`, `~/.gitconfig-*` |
| Zed | `home/modules/editor.nix` | `~/.config/zed/settings.json`, `keymap.json` |
| Zsh | `home/modules/shell.nix` | `~/.zshrc`, Oh My Zsh config |
| Hyprland | `home/modules/hyprland.nix` | `~/.config/hypr/hyprland.conf` |
| Waybar | `home/modules/hyprland.nix` | `~/.config/waybar/` |
| Wofi | `home/modules/hyprland.nix` | `~/.config/wofi/` |
| Kitty | `home/common.nix` | `~/.config/kitty/kitty.conf` |
| Dunst | `home/common.nix` | `~/.config/dunst/dunstrc` |

## Legacy Files (Now Managed by Nix)

These files in `config/` are now declaratively managed:

- `config/git/*` → `home/modules/git.nix`
- `config/zed/*` → `home/modules/editor.nix`
- Your `.zshrc` → `home/modules/shell.nix`

The `config/` directory can remain for reference but is no longer used directly.

## Benefits

**Declarative Management**:
- All dotfiles in version control
- Reproducible across devices
- Atomic updates (rollback if issues)

**Modular Organization**:
- Easy to see what's configured
- Simple to add/remove software
- Device-specific customization

**Home Manager Power**:
- Automatic symlink management
- XDG directory creation
- Session variable management
- Service management (Dunst, Waybar, etc.)

## Testing

After NixOS installation:

```bash
# Rebuild system
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel

# Check Home Manager activated
ls -la ~/.config/zed/settings.json  # Should be a symlink
cat ~/.gitconfig                     # Should have your config

# Test Zsh
zsh
echo $PROMPT                         # Should show custom prompt

# Test Hyprland
# Log out, select Hyprland session
# Super+Return should open Kitty
# Super+D should open Wofi
```

## Next Steps

**Immediate**:
1. Install NixOS on laptop-intel
2. Verify all Home Manager symlinks work
3. Test Hyprland, Zed, Git multi-account

**Phase 2 - Secrets**:
- Move `CLAUDE_CODE_OAUTH_TOKEN` to agenix
- Encrypt SSH keys for GitHub accounts
- Manage Wireguard keys

**Phase 4 Additional** (optional enhancements):
- Add Neovim configuration (currently just basic)
- Create wallpaper directory structure
- Add more Hyprland workspace rules
- Customize Waybar modules per device

## Software Module Summary

**Installed on ALL devices**:
- Browsers: LibreWolf, Firefox, Chrome
- Communication: Discord, Teams, Zoom, Slack, Obsidian
- Media: VLC, Spotify, Audacity
- Development: VS Code, Docker, Python, Node.js
- Office: LibreOffice

**Installed on creative devices only** (Framework, DevTower):
- DaVinci Resolve Studio (requires AMD GPU)
- Blender
- Reaper DAW

**Device-specific additions**:
- DevTower: Go XLR Utility, OBS Studio
- Framework: Video editing workflow extras
- Laptop-intel: Basic setup only

## Files Created in Phase 4

**Home Manager Modules**:
- `home/common.nix` (updated with imports)
- `home/modules/git.nix`
- `home/modules/editor.nix`
- `home/modules/shell.nix`
- `home/modules/hyprland.nix`

**Software Modules**:
- `modules/software/browsers.nix`
- `modules/software/communication.nix`
- `modules/software/media.nix`
- `modules/software/development.nix`
- `modules/software/office.nix`
- `modules/software/creative.nix` (enhanced)
- `modules/software/README.md`

**Updated**:
- `modules/core/base-configuration.nix` (imports software modules)

---

**Status**: Phase 4 Complete! 🎉

All dotfiles are now declaratively managed by Home Manager, organized into modular configurations. Software is categorized by purpose and easily manageable. Ready for NixOS installation and testing!
