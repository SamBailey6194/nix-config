-- devtower-intel overrides (loaded after devtower.lua)
-- On this PC the 4K AOC U2879G6 is DP-3, not DP-1. The DP-2 (1440p) and
-- HDMI-A-1 (1080p portrait) rules in devtower.lua already match.
-- TODO: switch to desc: matching once `hyprctl monitors all` shows the strings
hl.monitor({
    output   = "DP-3",
    mode     = "3840x2160@60",
    position = "0x0",
    scale    = 1,
})
