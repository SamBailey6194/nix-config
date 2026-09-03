{ config, pkgs, ... }:

{
  # Stage 4: Productivity
  # Everything from dev + Productivity apps (Obsidian, Discord, etc.)

  imports = [
    ./dev.nix
    ../modules/email.nix # Claws Mail, built without any browser engine
  ];

  # Productivity packages
  home.packages = with pkgs; [
    obsidian
    discord
  ];
}
