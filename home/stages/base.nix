{ config, pkgs, lib, ... }:

{
  # Stage: Base
  # Minimal Home Manager configuration with no software
  # Just XDG directories, fonts, and basic settings

  # Home Manager state version
  home.stateVersion = "24.11";

  # ============================================================================
  # File Collision Prevention
  # ============================================================================
  # Home Manager refuses to overwrite existing files by default.
  # This activation script backs up existing files before Home Manager takes over.
  # Backups are stored in ~/.config/home-manager-backups/ with timestamps.
  #
  # Files that commonly conflict:
  # - ~/.zshrc (managed by programs.zsh)
  # - ~/.config/hypr/* (managed by wayland.windowManager.hyprland and home.file)
  # - ~/.config/zed/* (managed by home.file)
  # ============================================================================
  home.activation.backupExistingConfigs = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    backup_dir="$HOME/.config/home-manager-backups/$(date +%Y%m%d-%H%M%S)"

    backup_if_exists() {
      local file="$1"
      if [ -e "$file" ] && [ ! -L "$file" ]; then
        mkdir -p "$backup_dir"
        echo "Backing up existing file: $file -> $backup_dir/"
        cp -r "$file" "$backup_dir/"
        rm -rf "$file"
      fi
    }

    # Back up shell configs
    backup_if_exists "$HOME/.zshrc"
    backup_if_exists "$HOME/.zshenv"
    backup_if_exists "$HOME/.zprofile"

    # Back up Hyprland configs
    if [ -d "$HOME/.config/hypr" ] && [ ! -L "$HOME/.config/hypr" ]; then
      # Check if any files in hypr are NOT symlinks (i.e., manually created)
      has_real_files=false
      for f in "$HOME/.config/hypr"/*; do
        if [ -e "$f" ] && [ ! -L "$f" ]; then
          has_real_files=true
          break
        fi
      done

      if [ "$has_real_files" = true ]; then
        mkdir -p "$backup_dir"
        echo "Backing up existing Hyprland config: $HOME/.config/hypr -> $backup_dir/"
        cp -r "$HOME/.config/hypr" "$backup_dir/"
        # Remove individual files that Home Manager will manage
        rm -f "$HOME/.config/hypr/hyprland.conf"
        rm -f "$HOME/.config/hypr/base.conf"
        rm -f "$HOME/.config/hypr/monitors.conf"
        rm -f "$HOME/.config/hypr/input.conf"
        rm -f "$HOME/.config/hypr/appearance.conf"
        rm -f "$HOME/.config/hypr/animations.conf"
        rm -f "$HOME/.config/hypr/keybinds.conf"
        rm -f "$HOME/.config/hypr/windowrules.conf"
        rm -f "$HOME/.config/hypr/autostart.conf"
        rm -f "$HOME/.config/hypr/device.conf"
      fi
    fi

    # Back up Zed editor configs
    backup_if_exists "$HOME/.config/zed/settings.json"
    backup_if_exists "$HOME/.config/zed/keymap.json"
  '';

  # Enable XDG user directories
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    publicShare = "$HOME/Public";
    templates = "$HOME/Templates";
    videos = "$HOME/Videos";
  };

  # Custom directory structure for git repositories
  home.file."Repos/personal/.keep".text = "";
  home.file."Repos/syntek/.keep".text = "";
  home.file."Repos/missional-gen/.keep".text = "";

  # Fonts
  fonts.fontconfig.enable = true;

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;
}
