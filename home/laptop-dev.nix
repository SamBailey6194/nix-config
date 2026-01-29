{ config, pkgs, ... }:

{
  # Stage 3: Development configuration for laptop-intel
  # User: sam-laptop
  # Hardware: Intel i5-10210U, 32GB RAM, Intel UHD Graphics

  imports = [
    ./stages/dev.nix
  ];

  # Copy device-specific Hyprland config to standard location
  home.file.".config/hypr/device.conf".source =
    ../config/hypr/devices/laptop-intel.conf;
}
