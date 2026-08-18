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

  # Device-specific Hyprland configuration (Lua config provider)
  #
  # Declared through extraLuaFiles rather than home.file so Home Manager emits the
  # matching `require("90-device")` in the generated hyprland.lua. A plain
  # home.file drop would land in ~/.config/hypr but would never be required, so
  # the device overrides would silently do nothing.
  #
  # Home Manager sorts the autoLoad requires alphabetically, so the 90- prefix
  # guarantees this file is required LAST — after 10-base .. 80-autostart — and
  # therefore wins over the shared defaults.
  # Device-specific settings (monitors, extra workspaces, power tuning, etc.)
  # live in config/hypr/devices/devtower.lua
  wayland.windowManager.hyprland.extraLuaFiles."90-device" = {
    content = ../config/hypr/devices/devtower.lua;
    autoLoad = true;
  };
}
