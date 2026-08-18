-- Autostart Configuration
-- Applications and services to start automatically
--
-- Translated from autostart.conf (hyprlang) to the Hyprland 0.56 Lua config
-- provider. The `exec-once = ...` lines become a single "hyprland.start"
-- event handler containing one hl.exec_cmd call per program, matching the
-- pattern used by the example Lua config shipped with Hyprland.

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")    -- Status bar
    hl.exec_cmd("hyprpaper") -- Wallpaper daemon
    hl.exec_cmd("dunst")     -- Notification daemon
    hl.exec_cmd("nm-applet") -- NetworkManager applet

    -- Optional: Polkit authentication agent
    -- hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Optional: Auto-start applications
    -- hl.exec_cmd("discord")
    -- hl.exec_cmd("spotify")
end)
