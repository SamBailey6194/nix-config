{ config, pkgs, ... }:

{
  # Stage 6: Full configuration for laptop-intel
  # User: sam-laptop
  # Hardware: Intel i5-10210U, 32GB RAM, Intel UHD Graphics

  imports = [
    ./stages/full.nix
  ];

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
  # live in config/hypr/devices/laptop-intel.lua
  wayland.windowManager.hyprland.extraLuaFiles."90-device" = {
    content = ../config/hypr/devices/laptop-intel.lua;
    autoLoad = true;
  };
}
