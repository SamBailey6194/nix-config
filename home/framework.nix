{ config, pkgs, ... }:

{
  # Device-specific home config for framework
  # User: sam-framework
  # Hardware: AMD Ryzen + Radeon, 64GB RAM
  # Software: DaVinci Resolve Studio, Affinity Apps

  imports = [
    ./common.nix
  ];

  # Framework-specific packages
  home.packages = with pkgs; [
    # Video editing utilities
    # (DaVinci Resolve Studio is in system packages)
  ];

  # Copy device-specific Hyprland config to standard location
  # The main hyprland.conf sources ~/.config/hypr/device.conf
  # Each device links its specific config to this standard name
  home.file.".config/hypr/device.conf".source =
    ../config/hypr/devices/framework.conf;
}
