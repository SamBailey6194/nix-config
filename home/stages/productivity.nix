{ config, pkgs, ... }:

{
  # Stage 4: Productivity
  # Everything from dev + Productivity apps (Obsidian, Discord, etc.)

  imports = [
    ./dev.nix
  ];

  # Productivity packages
  home.packages = with pkgs; [
    obsidian
    discord
  ];
}
