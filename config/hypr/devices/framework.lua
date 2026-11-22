-- Device-specific Hyprland configuration for framework
-- User: sam-framework
-- Hardware: AMD Ryzen + Radeon, 64GB RAM
-- Software: DaVinci Resolve Studio, Affinity Apps
--
-- Migrated from framework.conf (hyprlang) to the Hyprland 0.56 Lua config provider.
-- This file is required LAST, after 00-vars .. 80-autostart, so every call here
-- overrides the shared defaults.

-- ══ WORKSPACES: THE SHARED MAP ═══════════════════════════════════════════
--
-- This hardware is not in use yet. Its workspaces follow the shared map in
-- 00-vars.lua (registered by 70-windowrules.lua, keyed by 60-keybinds.lua),
-- like every device: Resolve 20, comms 11, dev layouts 31-40 and so on.
-- The old per-device workspace rules (Resolve 5, Affinity 4) were removed
-- because they overrode it; Affinity has no workspace any more and opens on
-- the first free one from 51 up.
--
-- ═════════════════════════════════════════════════════════════════════════

-- Monitor configuration
-- Framework laptop display with high DPI scaling
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
})

-- AMD GPU optimisations
hl.env("WLR_DRM_NO_ATOMIC", "1") -- Helps with some AMD GPU issues

-- High-performance settings for creative work
-- Override decoration settings for creative work
hl.config({
    decoration = {
        blur = {
            size     = 4,
            passes   = 2,
            vibrancy = 0.2,
        },
    },
})

-- Framework-specific window rules
-- DaVinci Resolve: fullscreen (workspace 20, from the shared map)
hl.window_rule({
    name       = "framework-resolve-fullscreen",
    match      = { class = "^(resolve)$" },
    fullscreen = true,
})


-- Framework-specific autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("brightnessctl set 60%") -- Set initial brightness to 60%
    -- hl.exec_cmd("resolve") -- Uncomment to auto-start DaVinci Resolve
end)

-- Dual keyboard layout support
-- Built-in laptop keyboard: gb (UK) - set in 30-input.lua as default
-- HyperX Alloy Origins Core PBT: us (US) - override below

hl.device({
    name      = "hp--inc-hyperx-alloy-origins-core",
    kb_layout = "us",
})
