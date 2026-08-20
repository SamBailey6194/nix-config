-- Device-specific Hyprland configuration for framework
-- User: sam-framework
-- Hardware: AMD Ryzen + Radeon, 64GB RAM
-- Software: DaVinci Resolve Studio, Affinity Apps
--
-- Migrated from framework.conf (hyprlang) to the Hyprland 0.56 Lua config provider.
-- This file is required LAST, after 00-vars .. 80-autostart, so every call here
-- overrides the shared defaults.

-- ══ DEFERRED — KNOWN CLASHES WITH THE SHARED CONFIG ══════════════════════
--
-- This hardware is not in use yet and this file has NOT been revisited since
-- the shared workspace contract changed. It is left untouched on purpose: the
-- rules below are an untested translation of the old hyprlang config, so
-- nothing here should be trusted until the machine actually exists.
--
-- Two clashes are already known. Whoever picks this device up should settle
-- them BEFORE the first rebuild — nothing below has been changed to fix them.
--
--  1. AFFINITY IS ON THE WRONG WORKSPACE.
--     The shared table in 00-vars.lua (M.workspaceAssignments) sends all three
--     Affinity apps to workspace 8, and 70-windowrules.lua registers that for
--     every device. The three `framework-affinity-*-workspace` rules below
--     still say workspace 4, from before the contract settled. Because this
--     file is required LAST and the last matching rule wins, workspace 4 is
--     what would actually happen here — silently disagreeing with every other
--     device, KEYBINDS.md and config/hypr/README.md.
--     Fix: drop these three rules and inherit workspace 8, or change the
--     shared contract deliberately.
--
--  2. DAVINCI RESOLVE SITS INSIDE THE GENERIC DEV POOL.
--     Workspaces 3-6 are now the generic dev pool: `SUPER + CTRL + Z` hands
--     out the lowest free one at launch (see rust/dev-layout). 60-keybinds.lua
--     is shared by EVERY device, so that keybind exists here too. The
--     `framework-resolve-workspace` rule below pins Resolve to workspace 5,
--     inside that pool, so a dev layout could be built on top of Resolve or
--     vice versa — whichever opened first simply keeps the workspace.
--     Fix: move Resolve out of 3-6, or narrow the pool for this device.
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
