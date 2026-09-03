-- Device-specific Hyprland configuration for devtower
-- User: sam-desktop
-- Hardware: AMD CPU + GPU, 64GB RAM, Go XLR
-- Software: DaVinci Resolve Studio, Affinity Apps, Go XLR Utility
--
-- Migrated from devtower.conf (hyprlang) to the Hyprland 0.56 Lua config provider.
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
--     every device. The three `devtower-affinity-*-workspace` rules below
--     still say workspace 4, from before the contract settled. Because this
--     file is required LAST and the last matching rule wins, workspace 4 is
--     what would actually happen here — silently disagreeing with every other
--     device, KEYBINDS.md and config/hypr/README.md.
--     Fix: drop these three rules and inherit workspace 8, or change the
--     shared contract deliberately.
--
--  2. RESOLVE AND OBS SIT INSIDE THE GENERIC DEV POOL.
--     Workspaces 3-5 are the generic dev pool: `SUPER + CTRL + Z` hands out
--     the lowest free one at launch (see rust/dev-layout). 60-keybinds.lua is
--     shared by EVERY device, so that keybind exists here too. Below,
--     `devtower-resolve-workspace` pins DaVinci Resolve to workspace 5, which
--     is still inside the pool, so a dev layout can land on top of Resolve
--     (whichever opened first keeps the workspace).
--
--     The pool narrowed from 3-6 to 3-5 when workspace 6 became mail, which
--     also moved OBS's workspace 6 out of the pool but INTO a collision with
--     Claws Mail instead. Both still need fixing for this device: move
--     Resolve off 5 and OBS off 6, or set DEV_LAYOUT_POOL_LAST here. This
--     also needs the three-monitor workspace design still outstanding for
--     devtower.
--
-- ═════════════════════════════════════════════════════════════════════════

-- Multi-monitor setup - Based on actual hardware configuration
-- Current Ubuntu/NVIDIA names: DP-2 (4K left), DP-4 (1440p center primary), HDMI-0 (1080p right vertical)
-- AMD/Wayland names will differ - update after installation (likely DP-1, DP-2, HDMI-A-1 or similar)
--
-- Layout (7480x2160 total):
--   ┌─────────────┐  ┌──────────┐  ┌───┐
--   │   DP-2      │  │  DP-4    │  │ H │ (rotated)
--   │  4K 3840x   │  │ 1440p    │  │ D │
--   │  2160@60Hz  │  │ 2560x    │  │ M │
--   │             │  │ 1440@60  │  │ I │
--   │  (Left)     │  │ (Primary)│  │ 0 │
--   └─────────────┘  └──────────┘  └───┘
--   Position: 0x0    Position:      Position:
--                    3840x0         6400x0
--
-- IMPORTANT: Monitor names will change on AMD GPU. Use `hyprctl monitors` to find correct names.
-- Common AMD/Wayland names: DP-1, DP-2, DP-3, HDMI-A-1, etc.

-- Left monitor: 4K (3840x2160@60Hz)
hl.monitor({
    output   = "DP-1",
    mode     = "3840x2160@60",
    position = "0x0",
    scale    = 1,
})

-- Center monitor: 1440p PRIMARY (2560x1440@60Hz)
hl.monitor({
    output   = "DP-2",
    mode     = "2560x1440@60",
    position = "3840x0",
    scale    = 1,
})

-- Right monitor: 1080p VERTICAL (1920x1080@60Hz, rotated right = 1080x1920)
hl.monitor({
    output    = "HDMI-A-1",
    mode      = "1920x1080@60",
    position  = "6400x0",
    scale     = 1,
    transform = 1,
})

-- Transform values: 0=normal, 1=90° (right), 2=180°, 3=270° (left)
-- HDMI-0 is rotated right (portrait mode), so transform = 1

-- Alternative single monitor setup (uncomment if using single monitor):
-- hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = 1 })

-- AMD GPU optimisations for desktop
hl.env("WLR_DRM_NO_ATOMIC", "1") -- Helps with some AMD GPU issues
hl.env("AMD_VULKAN_ICD", "RADV") -- Use RADV driver for Vulkan

-- Desktop high-performance settings
-- Override decoration settings for desktop
hl.config({
    decoration = {
        blur = {
            size     = 5,
            passes   = 2,
            vibrancy = 0.25,
        },
        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 4,
        },
    },
})

-- Override animation timings for desktop (faster)
--
-- NOTE on redefining `myBezier`: 50-animations.lua already defines a curve with
-- this name, and this file is loaded after it. Redefining is safe. Evidence:
--   * hl.curve() calls Hyprutils::Animation::CAnimationManager::addBezierWithName()
--     unconditionally - the binding has no "already exists" guard and no error path
--     (the only duplicate diagnostics in the binary are for events and plugin
--     namespaces, not curves), and addBezierWithName assigns through
--     std::unordered_map::operator[], so the later definition replaces the earlier one.
--   * hl.animation() stores the curve by NAME (it forwards a std::string to
--     Config::CAnimationTreeController::setConfigForNode), it does not capture a
--     curve object, so the replacement is picked up when the animation is resolved.
-- The six overrides below are re-declared after the curve anyway, so the ordering
-- holds regardless.
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows",     enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4, bezier = "default" })

-- Desktop-specific window rules for triple-monitor setup
-- Monitor 1 (Left 4K): Creative work - DaVinci Resolve, Affinity
-- Monitor 2 (Center 1440p PRIMARY): Main workspace - Code, browsing
-- Monitor 3 (Right 1080p VERTICAL): Communication, monitoring, documentation

-- DaVinci Resolve: fullscreen on workspace 5, left monitor (4K)
-- IMPORTANT: DaVinci Resolve runs under XWayland (not native Wayland due to qtwayland version mismatch)
-- Hyprland automatically handles this via QT_QPA_PLATFORM=xcb in the launch command
hl.window_rule({
    name      = "devtower-resolve-workspace",
    match     = { class = "^(resolve)$" },
    workspace = "5",
})
hl.window_rule({
    name       = "devtower-resolve-fullscreen",
    match      = { class = "^(resolve)$" },
    fullscreen = true,
})
-- hl.window_rule({ name = "devtower-resolve-monitor", match = { class = "^(resolve)$" }, monitor = "DP-1" }) -- Force to left 4K monitor

-- DaVinci Resolve must be launched with AMD GPU flags (see shell alias in home config):
-- ROC_ENABLE_PRE_VEGA=1 RUSTICL_ENABLE=amdgpu,amdgpu-pro,radv,radeon,radeonsi DRI_PRIME=1 QT_QPA_PLATFORM=xcb davinci-resolve-studio

-- Affinity apps: workspace 4, left monitor (4K for detail work)
hl.window_rule({
    name      = "devtower-affinity-photo-workspace",
    match     = { class = "^(affinity-photo)$" },
    workspace = "4",
})
hl.window_rule({
    name      = "devtower-affinity-designer-workspace",
    match     = { class = "^(affinity-designer)$" },
    workspace = "4",
})
hl.window_rule({
    name      = "devtower-affinity-publisher-workspace",
    match     = { class = "^(affinity-publisher)$" },
    workspace = "4",
})
-- hl.window_rule({ name = "devtower-affinity-photo-monitor", match = { class = "^(affinity-photo)$" }, monitor = "DP-1" })

-- OBS Studio: workspace 6, center monitor
hl.window_rule({
    name      = "devtower-obs-workspace",
    match     = { class = "^(obs)$" },
    workspace = "6",
})

-- Communication apps: workspace 9, right vertical monitor (perfect for chat)
hl.window_rule({
    name      = "devtower-discord-workspace",
    match     = { class = "^(discord)$" },
    workspace = "9",
})
hl.window_rule({
    name      = "devtower-slack-workspace",
    match     = { class = "^(slack)$" },
    workspace = "9",
})
hl.window_rule({
    name      = "devtower-element-workspace",
    match     = { class = "^(element)$" },
    workspace = "9",
})
-- hl.window_rule({ name = "devtower-discord-monitor", match = { class = "^(discord)$" }, monitor = "HDMI-A-1" }) -- Force to vertical monitor

-- Terminal/System monitoring: right vertical monitor is great for htop, logs, etc.
-- hl.window_rule({
--     name    = "devtower-htop-monitor",
--     match   = { class = "^(kitty)$", title = "^(htop)$" },
--     monitor = "HDMI-A-1",
-- })

-- Desktop-specific autostart
-- hl.on("hyprland.start", function()
--     hl.exec_cmd("resolve")         -- Uncomment to auto-start DaVinci Resolve
--     hl.exec_cmd("go-xlr-utility")  -- Uncomment to auto-start Go XLR Utility (when available)
-- end)

-- ──────────────────────────────────────────────────────────────────────────────
-- SETUP INSTRUCTIONS (After AMD GPU installation)
-- ──────────────────────────────────────────────────────────────────────────────
--
-- 1. Find your monitor names:
--    hyprctl monitors
--
-- 2. Update the hl.monitor({ ... }) calls above with actual AMD/Wayland names
--    (likely DP-1, DP-2, HDMI-A-1 instead of current placeholders)
--
-- 3. Verify refresh rates:
--    hyprctl monitors | grep -E "Monitor|refreshRate"
--    Your monitors support:
--      - Left 4K: 60Hz
--      - Center 1440p: 60Hz, 143.91Hz, 120Hz (use 144Hz if stable)
--      - Right 1080p vertical: 60Hz, 144Hz (use 144Hz if stable)
--
-- 4. Test configuration:
--    hyprctl reload
--    NOTE: under the Lua config provider `hyprctl keyword` no longer works;
--    edit this file and reload, or use `hyprctl dispatch "hl.dsp...."` / eval.
--
-- 5. Example final monitor config in Lua form (update names as needed):
--    hl.monitor({ output = "DP-1",     mode = "3840x2160@60",  position = "0x0",    scale = 1 })
--    hl.monitor({ output = "DP-2",     mode = "2560x1440@144", position = "3840x0", scale = 1 })                 -- Use 144Hz if supported
--    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "6400x0", scale = 1, transform = 1 })  -- 144Hz + vertical
