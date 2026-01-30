# Legacy File Cleanup Implementation Summary

**Date**: 30/01/2026
**Issue**: Home Manager file collisions with mimeapps.list and other dotfiles
**Resolution**: Comprehensive backup and cleanup system

## Problem

When running `nixos-rebuild switch --flake .#laptop-intel-creative`, Home Manager was failing with file collision errors:

```
mimeapps.list exists at both:
  - ~/.config/mimeapps.list
  - ~/.local/share/applications/mimeapps.list
```

This happens when:
1. Ubuntu or previous installations left legacy dotfiles
2. Home Manager tries to manage the same files
3. File collisions prevent Home Manager activation

## Solution

Created a comprehensive **once-per-installation** backup and cleanup system that:

1. ✅ Backs up all legacy dotfiles to timestamped directory
2. ✅ Removes conflicting files before Home Manager activation
3. ✅ Runs once, then creates marker file to prevent re-running
4. ✅ Preserves user data (nothing is deleted without backup)
5. ✅ Handles all common dotfiles (git, zsh, hyprland, editors, etc.)

## Files Changed

### Created
- `home/modules/legacy-cleanup.nix` - Main cleanup module
- `docs/LEGACY-FILE-CLEANUP.md` - User documentation
- `docs/LEGACY-CLEANUP-IMPLEMENTATION.md` - This file

### Modified
- `home/stages/base.nix` - Replaced inline backup script with module import
- `home/stages/desktop.nix` - Removed inline mimeapps.list cleanup (now handled by module)

## How It Works

### 1. Module Import
```nix
# home/stages/base.nix
imports = [
  ../modules/legacy-cleanup.nix  # Backup and remove legacy dotfiles
];
```

### 2. Activation Script
Runs before Home Manager's `checkLinkTargets`:

```nix
home.activation.backupLegacyFiles = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
  # Check for marker file
  # If not found, backup and remove legacy files
  # Create marker to prevent re-running
'';
```

### 3. Files Backed Up

**Complete list** (40+ files/directories):

- **Git**: `.gitconfig`, `.gitconfig-*`, `.gitmessage`
- **Shell**: `.zshrc`, `.bashrc`, `.profile`, `.oh-my-zsh/`
- **Editors**: `.config/nvim/`, `.config/zed/`
- **Hyprland**: `.config/hypr/*.conf`
- **Terminal**: `.config/terminator/`, `.config/kitty/`
- **Desktop**: `.config/dunst/`, `.config/waybar/`, `.config/wofi/`
- **XDG**: `.config/mimeapps.list`, `.local/share/applications/mimeapps.list`

### 4. Backup Location
```
~/nixos-legacy-backup-YYYY-MM-DD-HHMMSS/
```

### 5. Marker File
```
~/.config/nixos-legacy-cleanup-done
```

Prevents re-running on subsequent rebuilds.

## Benefits

### User Safety
- ✅ Nothing is deleted without backup
- ✅ Easy to restore individual files if needed
- ✅ Timestamped backups prevent overwriting

### Automation
- ✅ Runs automatically on first rebuild
- ✅ No manual intervention required
- ✅ Prevents all file collision errors

### Maintainability
- ✅ Centralized in single module
- ✅ Easy to add new files to backup list
- ✅ Clear documentation for users

### Consistency
- ✅ All hosts use the same cleanup system
- ✅ Works across all stages (minimal, desktop, dev, etc.)
- ✅ Respects Home Manager's dry-run mode

## Testing

### On Fresh Install
```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

**Expected output**:
```
========================================
Legacy File Cleanup and Backup
========================================

Found legacy file/directory: .zshrc
  → Backed up to: ~/nixos-legacy-backup-2026-01-30-143022/.zshrc
  → Removed original

Found legacy file/directory: .config/hypr
  → Backed up to: ~/nixos-legacy-backup-2026-01-30-143022/.config/hypr
  → Removed original

========================================
Backup Summary
========================================
Legacy files backed up to:
  ~/nixos-legacy-backup-2026-01-30-143022

Created marker file: ~/.config/nixos-legacy-cleanup-done
This cleanup will not run again on future rebuilds.
```

### On Subsequent Rebuilds
```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

**Expected output**: (nothing - cleanup is skipped)

## User Instructions

### Normal Usage
Just rebuild - the cleanup happens automatically:
```bash
sudo nixos-rebuild switch --flake .#laptop-intel-creative
```

### Restoring a File
```bash
# Restore .zshrc example
cp ~/nixos-legacy-backup-2026-01-30-143022/.zshrc ~/
```

### Cleaning Up Backups
After verifying everything works:
```bash
rm -rf ~/nixos-legacy-backup-*
```

### Manual Re-run
If needed:
```bash
rm ~/.config/nixos-legacy-cleanup-done
sudo nixos-rebuild switch --flake .#laptop-intel
```

## Future Improvements

### Potential Enhancements
1. Add `--restore` flag to easily restore from backup
2. Add `--list-backups` to show available backups
3. Add automatic backup cleanup after 30 days
4. Add `--skip-cleanup` flag for advanced users

### Adding New Files
Edit `home/modules/legacy-cleanup.nix`:
```nix
# Add to appropriate section
if backup_and_remove ".config/myapp/config.toml"; then FOUND_LEGACY=1; fi
```

## Technical Details

### DAG Ordering
```
home.activation.backupLegacyFiles = lib.hm.dag.entryBefore ["checkLinkTargets"]
```

Ensures cleanup runs **before** Home Manager checks for symlink conflicts.

### Dry Run Support
```bash
$DRY_RUN_CMD rm -rf "$full_path"
```

Respects Home Manager's `$DRY_RUN_CMD` variable for safe testing.

### Error Handling
- Checks if file exists before backing up
- Creates backup directory only if files found
- Preserves symlinks (`cp -P`)
- Handles both files and directories (`cp -r`)

## Related Documentation

- [LEGACY-FILE-CLEANUP.md](./LEGACY-FILE-CLEANUP.md) - User guide
- [STAGED-INSTALLATION-GUIDE.md](./STAGED-INSTALLATION-GUIDE.md) - Installation process
- [CLAUDE.md](../CLAUDE.md) - Main project documentation

## Verification Checklist

After running on laptop-intel, verify:

- [ ] `mimeapps.list` collision is resolved
- [ ] Backup directory was created
- [ ] Marker file exists at `~/.config/nixos-legacy-cleanup-done`
- [ ] All legacy files backed up correctly
- [ ] Home Manager activation successful
- [ ] Desktop environment works (Hyprland)
- [ ] Git configuration works (multi-account)
- [ ] Shell configuration works (Zsh with Oh My Zsh)
- [ ] Editors work (Zed, Neovim)
- [ ] Subsequent rebuilds skip cleanup (no duplicate backups)
