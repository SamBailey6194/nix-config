{ config, pkgs, ... }:

{
  # Stage 2: Desktop configuration for laptop-intel
  # User: sam-laptop
  # Hardware: Intel i5-10210U, 32GB RAM, Intel UHD Graphics

  imports = [
    ./stages/desktop.nix
  ];

  # Copy device-specific Hyprland config to standard location
  # The main hyprland.conf sources ~/.config/hypr/device.conf
  # Each device links its specific config to this standard name
  home.file.".config/hypr/device.conf".source =
    ../config/hypr/devices/laptop-intel.conf;
}
