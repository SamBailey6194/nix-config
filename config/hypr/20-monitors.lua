-- Monitor Configuration
-- Default: auto-detect monitor settings
-- Device-specific overrides should be placed in devices/*.lua
--
-- An empty `output` is the catch-all rule (the hyprlang `monitor = ,...` form).

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Example multi-monitor setup (uncomment and customise as needed):
-- hl.monitor({ output = "DP-1",     mode = "3840x2160@60", position = "0x0",    scale = 1 })
-- hl.monitor({ output = "DP-2",     mode = "3840x2160@60", position = "3840x0", scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0",    scale = 1 })
