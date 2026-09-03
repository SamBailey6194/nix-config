-- Autostart Configuration
-- Applications and services to start automatically
--
-- Translated from autostart.conf (hyprlang) to the Hyprland 0.56 Lua config
-- provider. The `exec-once = ...` lines become a single "hyprland.start"
-- event handler containing one hl.exec_cmd call per program, matching the
-- pattern used by the example Lua config shipped with Hyprland.

-- waybar and hyprpaper are NOT started here. Home Manager already defines
-- waybar.service and hyprpaper.service, wanted by graphical-session.target,
-- and since wayland.windowManager.hyprland.systemd.enable was turned on that
-- target actually comes up. Starting them here as well would give two bars and
-- two wallpaper daemons. dunst is Type=dbus with no [Install], so it is only
-- ever activated on demand and still needs an explicit start; nm-applet has no
-- Home Manager service at all.

hl.on("hyprland.start", function()
    hl.exec_cmd("dunst")     -- Notification daemon
    hl.exec_cmd("nm-applet") -- NetworkManager applet

    -- Optional: Polkit authentication agent
    -- hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Optional: Auto-start applications
    -- hl.exec_cmd("discord")
    -- hl.exec_cmd("spotify")
end)
