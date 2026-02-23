{ config, lib, pkgs, ... }:

{
  # Legacy File Cleanup and Backup
  #
  # This module automatically backs up and removes legacy dotfiles from Ubuntu
  # or previous installations that would conflict with Home Manager.
  #
  # Runs once on first activation, then creates a marker file to prevent
  # re-running on subsequent rebuilds.
  #
  # Backup location: ~/nixos-legacy-backup-YYYY-MM-DD-HHMMSS/

  home.activation.backupLegacyFiles = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    # Check if we've already run this cleanup
    MARKER_FILE="$HOME/.config/nixos-legacy-cleanup-done"

    if [ ! -f "$MARKER_FILE" ]; then
      # First run - perform legacy cleanup

      # Create timestamped backup directory
      BACKUP_DIR="$HOME/nixos-legacy-backup-$(date +%Y-%m-%d-%H%M%S)"

      # Function to backup and remove a file or directory
      backup_and_remove() {
        local path="$1"
        local full_path="$HOME/$path"

        if [ -e "$full_path" ] || [ -L "$full_path" ]; then
          echo "Found legacy file/directory: $path"

          # Create backup directory structure
          local backup_path="$BACKUP_DIR/$path"
          local backup_parent=$(dirname "$backup_path")
          mkdir -p "$backup_parent"

          # Copy to backup (preserve symlinks)
          if [ -L "$full_path" ]; then
            cp -P "$full_path" "$backup_path"
          else
            cp -r "$full_path" "$backup_path"
          fi

          # Remove original
          $DRY_RUN_CMD rm -rf "$full_path"
          echo "  Backed up to: $backup_path"
          echo "  Removed original"

          return 0
        fi

        return 1
      }

      echo "========================================"
      echo "Legacy File Cleanup and Backup"
      echo "========================================"
      echo ""

      # Track if we found any legacy files
      FOUND_LEGACY=0

      # Git configuration files
      if backup_and_remove ".gitconfig"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".gitconfig-personal"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".gitconfig-syntek"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".gitconfig-missional-gen"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".gitmessage"; then FOUND_LEGACY=1; fi

      # Shell configuration files
      if backup_and_remove ".zshrc"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".zshrc.pre-oh-my-zsh"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".zshenv"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".zprofile"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".oh-my-zsh"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".zsh_history"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".bashrc"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".bash_profile"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".bash_history"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".profile"; then FOUND_LEGACY=1; fi

      # Editor configuration files
      if backup_and_remove ".config/nvim"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/zed/settings.json"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/zed/keymap.json"; then FOUND_LEGACY=1; fi

      # Hyprland configuration files
      if backup_and_remove ".config/hypr/hyprland.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/base.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/monitors.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/input.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/appearance.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/animations.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/keybinds.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/windowrules.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/autostart.conf"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/hypr/device.conf"; then FOUND_LEGACY=1; fi

      # Terminal configuration files
      if backup_and_remove ".config/terminator/config"; then FOUND_LEGACY=1; fi
      if backup_and_remove ".config/kitty"; then FOUND_LEGACY=1; fi

      # XDG MIME associations (legacy location)
      if backup_and_remove ".local/share/applications/mimeapps.list"; then FOUND_LEGACY=1; fi

      # Also backup the correct XDG location if it exists (might be from Ubuntu)
      if backup_and_remove ".config/mimeapps.list"; then FOUND_LEGACY=1; fi

      # Notification daemon configs
      if backup_and_remove ".config/dunst"; then FOUND_LEGACY=1; fi

      # Waybar configs (if present from previous Hyprland install)
      if backup_and_remove ".config/waybar"; then FOUND_LEGACY=1; fi

      # Wofi configs
      if backup_and_remove ".config/wofi"; then FOUND_LEGACY=1; fi

      echo ""

      if [ "$FOUND_LEGACY" -eq 1 ]; then
        echo "========================================"
        echo "Backup Summary"
        echo "========================================"
        echo "Legacy files backed up to:"
        echo "  $BACKUP_DIR"
        echo ""
        echo "You can restore any file from this backup if needed."
        echo "To restore: cp -r $BACKUP_DIR/path/to/file ~/path/to/file"
        echo ""
        echo "After verifying Home Manager works correctly, you can delete:"
        echo "  rm -rf $BACKUP_DIR"
        echo "========================================"
      else
        echo "No legacy files found. Proceeding with clean Home Manager activation."
        # Remove backup directory if we created it but found nothing
        [ -d "$BACKUP_DIR" ] && rmdir "$BACKUP_DIR" 2>/dev/null || true
      fi

      # Create marker file to prevent re-running
      mkdir -p "$HOME/.config"
      touch "$MARKER_FILE"
      echo ""
      echo "Created marker file: $MARKER_FILE"
      echo "This cleanup will not run again on future rebuilds."
      echo ""
    fi
  '';
}
