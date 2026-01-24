{ config, pkgs, ... }:

{
  # Device-specific home config for devtower
  # User: sam-desktop
  # Hardware: AMD CPU + GPU, 64GB RAM, Go XLR
  # Software: DaVinci Resolve Studio, Affinity Apps, Go XLR Utility

  imports = [
    ./common.nix
  ];

  # DevTower-specific packages
  home.packages = with pkgs; [
    # Additional productivity tools for desktop
    # OBS Studio for streaming (if needed with Go XLR)
    obs-studio

    # Video/audio utilities
    # (DaVinci Resolve Studio and Go XLR Utility are in system packages)
  ];

  # DevTower-specific Hyprland settings
  wayland.windowManager.hyprland.settings = {
    # Multi-monitor setup (when you have multiple monitors)
    # monitor = [
    #   "DP-1,3840x2160@60,0x0,1"
    #   "DP-2,3840x2160@60,3840x0,1"
    # ];

    # More workspaces for creative workflow
    "$mod, 6, workspace, 6"
    "$mod, 7, workspace, 7"
    "$mod, 8, workspace, 8"
    "$mod, 9, workspace, 9"
    "$mod, 0, workspace, 10"

    "$mod SHIFT, 6, movetoworkspace, 6"
    "$mod SHIFT, 7, movetoworkspace, 7"
    "$mod SHIFT, 8, movetoworkspace, 8"
    "$mod SHIFT, 9, movetoworkspace, 9"
    "$mod SHIFT, 0, movetoworkspace, 10"
  };
}
