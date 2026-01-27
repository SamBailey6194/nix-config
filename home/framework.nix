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

  # Framework-specific Hyprland keybindings
  # Higher workspace count for video editing workflow
  wayland.windowManager.hyprland.settings.bind = [
    "$mod, 6, workspace, 6"
    "$mod, 7, workspace, 7"
    "$mod, 8, workspace, 8"
    "$mod, 9, workspace, 9"

    "$mod SHIFT, 6, movetoworkspace, 6"
    "$mod SHIFT, 7, movetoworkspace, 7"
    "$mod SHIFT, 8, movetoworkspace, 8"
    "$mod SHIFT, 9, movetoworkspace, 9"
  ];
}
