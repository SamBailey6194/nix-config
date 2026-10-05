{ lib, osConfig ? { }, ... }:

{
  # Replace the future AMD tower's monitor/app rules entirely on this PC.
  wayland.windowManager.hyprland.extraLuaFiles."90-device" = {
    content = lib.mkForce ../config/hypr/devices/devtower-intel.lua;
    autoLoad = true;
  };
  wayland.windowManager.hyprland.extraLuaFiles."96-dashboard" = lib.mkIf
    (osConfig.services.localLlm.enable or false) {
      content = ../config/hypr/devices/devtower-intel-dashboard.lua;
      autoLoad = true;
    };
}
