{ config, pkgs, ... }:

{
  # Stage 6: Full configuration for devtower
  # User: sam-desktop
  # Hardware: AMD CPU + GPU, 64GB RAM, Go XLR
  # Software: DaVinci Resolve Studio, Affinity Apps, Go XLR Utility

  imports = [
    ./stages/full.nix
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

  # Copy device-specific Hyprland config to standard location
  # The main hyprland.conf sources ~/.config/hypr/device.conf
  # Each device links its specific config to this standard name
  # Device-specific settings (multi-monitor, extra workspaces, etc.)
  # are in config/hypr/devices/devtower.conf
  home.file.".config/hypr/device.conf".source =
    ../config/hypr/devices/devtower.conf;
}
