{ ... }:

{
  # devtower-intel only: loaded after 90-device (devtower.lua) because Lua
  # requires are sorted by name, so these rules override devtower's
  wayland.windowManager.hyprland.extraLuaFiles."95-devtower-intel" = {
    content = ../config/hypr/devices/devtower-intel.lua;
    autoLoad = true;
  };
}
