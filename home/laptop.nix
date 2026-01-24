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

  # Device-specific Hyprland overrides (if any)
  # wayland.windowManager.hyprland.settings = {
  #   # Add laptop-specific Hyprland settings here
  # };
}
