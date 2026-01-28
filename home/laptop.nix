{ config, pkgs, ... }:

{
  # Device-specific home config for laptop-intel
  # User: sam-laptop
  # Hardware: Intel i5-10210U, 32GB RAM, Intel UHD Graphics

  imports = [
    ./common.nix
  ];

  # Device-specific packages (if any)
  # home.packages = with pkgs; [
  #   # Add laptop-specific packages here
  # ];

  # Copy device-specific Hyprland config to standard location
  # The main hyprland.conf sources ~/.config/hypr/device.conf
  # Each device links its specific config to this standard name
  home.file.".config/hypr/device.conf".source =
    ../config/hypr/devices/laptop-intel.conf;
}
