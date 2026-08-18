-- Device-specific Hyprland configuration for framework
-- User: sam-framework
-- Hardware: AMD Ryzen + Radeon, 64GB RAM
-- Software: DaVinci Resolve Studio, Affinity Apps
--
-- Migrated from framework.conf (hyprlang) to the Hyprland 0.56 Lua config provider.
-- This file is required LAST, after 00-vars .. 80-autostart, so every call here
-- overrides the shared defaults.

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
-- DaVinci Resolve: maximise on workspace 5
hl.window_rule({
    name      = "framework-resolve-workspace",
    match     = { class = "^(resolve)$" },
    workspace = "5",
})
hl.window_rule({
    name       = "framework-resolve-fullscreen",
    match      = { class = "^(resolve)$" },
    fullscreen = true,
})

-- Affinity apps: assign to specific workspaces
hl.window_rule({
    name      = "framework-affinity-photo-workspace",
    match     = { class = "^(affinity-photo)$" },
    workspace = "4",
})
hl.window_rule({
    name      = "framework-affinity-designer-workspace",
    match     = { class = "^(affinity-designer)$" },
    workspace = "4",
})
hl.window_rule({
    name      = "framework-affinity-publisher-workspace",
    match     = { class = "^(affinity-publisher)$" },
    workspace = "4",
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
