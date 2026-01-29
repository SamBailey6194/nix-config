{ config, pkgs, ... }:

{
  # Stage: Base
  # Minimal Home Manager configuration with no software
  # Just XDG directories, fonts, and basic settings

  # Home Manager state version
  home.stateVersion = "24.11";

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
