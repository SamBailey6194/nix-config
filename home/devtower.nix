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

  # Shell aliases for AMD GPU applications
  programs.zsh.shellAliases = {
    # DaVinci Resolve Studio with AMD GPU (Rusticl) support
    # Must run under XWayland (not native Wayland) due to qtwayland version mismatch
    resolve = "ROC_ENABLE_PRE_VEGA=1 RUSTICL_ENABLE=amdgpu,amdgpu-pro,radv,radeon,radeonsi DRI_PRIME=1 QT_QPA_PLATFORM=xcb davinci-resolve-studio";

    # Shorter alias
    dvr = "ROC_ENABLE_PRE_VEGA=1 RUSTICL_ENABLE=amdgpu,amdgpu-pro,radv,radeon,radeonsi DRI_PRIME=1 QT_QPA_PLATFORM=xcb davinci-resolve-studio";
  };

  # DevTower-specific Hyprland settings
  # Multi-monitor setup (when you have multiple monitors)
  # wayland.windowManager.hyprland.settings.monitor = [
  #   "DP-1,3840x2160@60,0x0,1"
  #   "DP-2,3840x2160@60,3840x0,1"
  # ];

  # More workspaces for creative workflow
  wayland.windowManager.hyprland.settings.bind = [
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
  ];
}
