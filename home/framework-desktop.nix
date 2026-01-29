{ config, pkgs, ... }:

{
  # Stage 2: Desktop configuration for framework
  # User: sam-framework
  # Hardware: AMD Ryzen + Radeon, 64GB RAM

  imports = [
    ./stages/desktop.nix
  ];

  # Copy device-specific Hyprland config to standard location
  home.file.".config/hypr/device.conf".source =
    ../config/hypr/devices/framework.conf;
}
