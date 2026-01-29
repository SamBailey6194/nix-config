{ config, pkgs, ... }:

{
  # Stage 2: Desktop configuration for devtower
  # User: sam-desktop
  # Hardware: AMD CPU + GPU, 64GB RAM, Go XLR

  imports = [
    ./stages/desktop.nix
  ];

  # Copy device-specific Hyprland config to standard location
  home.file.".config/hypr/device.conf".source =
    ../config/hypr/devices/devtower.conf;
}
