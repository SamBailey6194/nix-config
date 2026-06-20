{ config, pkgs, lib, ... }:

{
  # Stage: Base
  # Minimal Home Manager configuration with no software
  # Just XDG directories, fonts, and basic settings

  imports = [
    ../modules/legacy-cleanup.nix  # Backup and remove legacy dotfiles
  ];

  # Home Manager state version
  home.stateVersion = "24.11";

  # ============================================================================
  # File Collision Prevention
  # ============================================================================
  # Legacy dotfile cleanup is handled by modules/legacy-cleanup.nix
  # This module backs up and removes all conflicting files from Ubuntu or
  # previous installations before Home Manager tries to manage them.
  #
  # Backup location: ~/nixos-legacy-backup-YYYY-MM-DD-HHMMSS/
  # Runs once per installation (creates marker file to prevent re-running)
  # ============================================================================

  # Enable XDG user directories
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true; # Keep legacy behaviour (was default before 26.05)
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
