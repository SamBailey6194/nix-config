-- Hyprland Base Configuration
-- Core settings shared across all devices
--
-- The `$mod = SUPER` variable that used to live here now lives in 00-vars.lua,
-- which is a Lua module (`require("00-vars")`) rather than a config statement.

-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- General window settings
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,

        -- Ayu Dark colours
        col = {
            active_border   = { colors = { "rgba(ffb454ee)", "rgba(59c2ffee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,

        layout = "dwindle",
    },
})

-- Layout: Dwindle
-- NOTE: `pseudotile` was removed as a dwindle option in Hyprland 0.55.
-- Pseudotiling is now per-window only: use the `pseudo` dispatcher
-- (e.g. `hl.bind(mod .. " + P", hl.dsp.window.pseudo())`) or a window rule
-- with `pseudo = true`.
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-- Layout: Master
hl.config({
    master = {
        new_status = "master",
    },
})

-- Misc settings
hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- Disable startup splash
        disable_splash_rendering = true,
    },
})

-- Debug settings
-- Suppress verbose logging for cleaner output
-- NOTE: pixman_region32_init_rect warnings are internal to the rendering
-- pipeline and typically harmless - they occur when window dimensions
-- are briefly invalid during animations or XWayland app startup
hl.config({
    debug = {
        -- Set to 0 for normal operation, increase for debugging
        -- damage_tracking = 2, -- Full damage tracking (default)
        disable_logs = false, -- Set to true if logs are too verbose
    },
})
