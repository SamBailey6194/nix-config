{ config, pkgs, ... }:

{
  # Stage 3: Development configuration for devtower
  # User: sam-desktop
  # Hardware: AMD CPU + GPU, 64GB RAM, Go XLR

  imports = [
    ./stages/dev.nix
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
  # live in config/hypr/devices/devtower.lua
  wayland.windowManager.hyprland.extraLuaFiles."90-device" = {
    content = ../config/hypr/devices/devtower.lua;
    autoLoad = true;
  };
}
