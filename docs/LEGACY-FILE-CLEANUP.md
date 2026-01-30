# Legacy File Cleanup and Backup System

**Last Updated**: 30/01/2026
**Version**: 1.0.0

## Overview

The legacy file cleanup system automatically backs up and removes conflicting dotfiles from Ubuntu or previous installations before Home Manager tries to manage them. This prevents file collision errors during `nixos-rebuild switch`.

## How It Works

### Automatic Activation

The cleanup runs **once** during the first `nixos-rebuild switch` or Home Manager activation:

1. **Detection**: Checks for legacy files that Home Manager wants to manage
2. **Backup**: Copies all found files to a timestamped backup directory
3. **Removal**: Removes the original files to allow Home Manager to take over
4. **Marker**: Creates `~/.config/nixos-legacy-cleanup-done` to prevent re-running

### Files Automatically Backed Up

The system handles these categories of legacy files:

#### Git Configuration
- `.gitconfig`
- `.gitconfig-personal`
- `.gitconfig-syntek`
- `.gitconfig-missional-gen`
- `.gitmessage`

#### Shell Configuration
- `.zshrc`, `.zshenv`, `.zprofile`
- `.zshrc.pre-oh-my-zsh`
- `.oh-my-zsh/` (entire directory)
- `.zsh_history`
- `.bashrc`, `.bash_profile`, `.bash_history`
- `.profile`

#### Editor Configuration
- `.config/nvim/` (entire directory)
- `.config/zed/settings.json`
- `.config/zed/keymap.json`

#### Hyprland Configuration
- `.config/hypr/hyprland.conf`
- `.config/hypr/base.conf`
- `.config/hypr/monitors.conf`
- `.config/hypr/input.conf`
- `.config/hypr/appearance.conf`
- `.config/hypr/animations.conf`
- `.config/hypr/keybinds.conf`
- `.config/hypr/windowrules.conf`
- `.config/hypr/autostart.conf`
- `.config/hypr/device.conf`

#### Terminal Configuration
- `.config/terminator/config`
- `.config/kitty/` (entire directory)

#### Desktop Environment
- `.config/dunst/` (notifications)
- `.config/waybar/` (status bar)
- `.config/wofi/` (application launcher)

#### XDG MIME Associations
- `.local/share/applications/mimeapps.list` (legacy location)
- `.config/mimeapps.list` (current location)

## Backup Location

Backups are stored in:
```
~/nixos-legacy-backup-YYYY-MM-DD-HHMMSS/
```

For example:
```
~/nixos-legacy-backup-2026-01-30-143022/
```

The backup preserves the original directory structure, so `.config/hypr/hyprland.conf` becomes:
```
~/nixos-legacy-backup-2026-01-30-143022/.config/hypr/hyprland.conf
```

## Restoring Files

If you need to restore a file from the backup:

```bash
# Find your backup directory
ls -d ~/nixos-legacy-backup-*

# Restore a single file
cp ~/nixos-legacy-backup-2026-01-30-143022/.zshrc ~/

# Restore an entire directory
cp -r ~/nixos-legacy-backup-2026-01-30-143022/.config/hypr ~/.config/
```

**IMPORTANT**: After restoring, you'll need to remove the Home Manager-managed version first:

```bash
# Remove Home Manager's version
rm ~/.zshrc

# Restore your backup
cp ~/nixos-legacy-backup-2026-01-30-143022/.zshrc ~/

# Then decide: keep your version or let Home Manager manage it
```

## Cleaning Up Old Backups

After verifying Home Manager works correctly (usually after a few rebuilds), delete the backup:

```bash
# List all backups
ls -d ~/nixos-legacy-backup-*

# Delete a specific backup
rm -rf ~/nixos-legacy-backup-2026-01-30-143022

# Or delete all backups
rm -rf ~/nixos-legacy-backup-*
```

## Manual Cleanup

To manually trigger cleanup again:

```bash
# 1. Remove the marker file
rm ~/.config/nixos-legacy-cleanup-done

# 2. Run rebuild
sudo nixos-rebuild switch --flake .#laptop-intel

# The cleanup will run again
```

## Dry Run

Home Manager's dry-run mode respects the `$DRY_RUN_CMD` variable:

```bash
# See what would be backed up without actually doing it
home-manager build --flake .#laptop-intel
```

The cleanup script will show what files it would back up but won't actually remove them.

## Implementation Details

### Module Location
```
home/modules/legacy-cleanup.nix
```

### Imported By
```
home/stages/base.nix
```

This means **all** Home Manager configurations (minimal, desktop, dev, productivity, creative) automatically include the cleanup.

### Activation Timing

The cleanup runs **before** `checkLinkTargets` in the Home Manager activation DAG:

```nix
home.activation.backupLegacyFiles = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
  # Cleanup script here
'';
```

This ensures legacy files are removed before Home Manager tries to create symlinks to the Nix store.

## Troubleshooting

### "File collision" errors persist

If you still see file collision errors after the cleanup:

1. **Check the marker file exists**:
   ```bash
   ls -la ~/.config/nixos-legacy-cleanup-done
   ```

2. **Manually remove the conflicting file**:
   ```bash
   # Example for .zshrc
   rm ~/.zshrc
   sudo nixos-rebuild switch --flake .#laptop-intel
   ```

3. **Check for hidden files**:
   ```bash
   ls -la ~/
   ls -la ~/.config/
   ```

### Backup directory not created

If no backup was created, it means no legacy files were found. This is expected on:
- Fresh NixOS installations
- Systems that already had the cleanup run

### Want to add more files to backup

Edit `home/modules/legacy-cleanup.nix` and add your file to the appropriate section:

```nix
# Add your custom file
if backup_and_remove ".config/myapp/config.toml"; then FOUND_LEGACY=1; fi
```

Then remove the marker and rebuild:
```bash
rm ~/.config/nixos-legacy-cleanup-done
sudo nixos-rebuild switch --flake .#laptop-intel
```

## See Also

- [Home Manager Manual - Activation Scripts](https://nix-community.github.io/home-manager/index.xhtml#sec-usage-activation)
- [NixOS Manual - File Collisions](https://nixos.org/manual/nixos/stable/#sec-home-manager-troubleshooting)
- `home/modules/legacy-cleanup.nix` - Implementation
- `home/stages/base.nix` - Base configuration that imports the cleanup module
