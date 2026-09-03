-- Device-specific Hyprland configuration for laptop-intel
-- User: sam-laptop
-- Hardware: Intel i5-10210U, 32GB RAM, Intel UHD Graphics
--
-- This file is required LAST, after 10-base .. 80-autostart, so anything set
-- here overrides the shared defaults.

-- Monitor configuration
-- Single laptop display, optimise for battery life
-- Detected: 1920x1080@60.02400 at 0x0
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

-- Power-optimised settings for laptop
-- Override decoration settings for battery life
--
-- NOTE: hl.config() MERGES rather than replaces. It walks the table it is
-- given, builds the dotted config key for each leaf (decoration.blur.size,
-- decoration.blur.passes) and writes only those keys; every key it does not
-- mention keeps whatever value it already had. So the blur.enabled/vibrancy and
-- the rounding/opacity/shadow settings from 40-appearance.lua all survive — only
-- size and passes are lowered here.
hl.config({
    decoration = {
        blur = {
            size   = 2,
            passes = 1,
        },
    },
})

-- Laptop-specific workspace count (5 workspaces is usually enough for laptop)
-- Base keybinds already include 1-10, no override needed

-- Laptop-specific window rules
-- Make certain apps float on laptop (smaller screen)
hl.window_rule({
    name  = "laptop-float-gnome-calculator",
    match = { class = "^(gnome-calculator)$" },

    float = true,
})

hl.window_rule({
    name  = "laptop-float-blueman-manager",
    match = { class = "^(blueman-manager)$" },

    float = true,
})

-- ── Workspace 1: reserved dashboard ───────────────────────────────────
--
-- Workspace 1 is a fixed dashboard: the keybind cheatsheet (left) and htop
-- (right, the same system monitor SUPER + M opens), and NOTHING else. The two
-- dashboard terminals are launched with custom classes so they can be pinned
-- here; every other window is pushed to workspace 10 by the catch-all below —
-- so apps default to ws10 instead of opening on whatever workspace happens to
-- be focused.
--
-- THE WORKSPACE MAP
--
--   1     dashboard — ws1-keybinds + ws1-monitor, pinned in step 2 below
--   2     nix-config dev layout (RESERVED: never allocated to anything else)
--   3-5   generic dev pool, handed out one workspace at a time when a generic
--         dev layout is launched. Not covered by a rule in THIS file: a
--         static rule cannot express "the next free workspace", so the
--         launcher picks one at runtime and registers a class+title rule for
--         it through `hyprctl eval` just before launching. That rule beats
--         this catch-all by being registered later — last match wins.
--   6     mail (Claws Mail)
--   7     browsers
--   8     Affinity Suite
--   9     comms
--   10    catch-all — every ordinary window, via the rule below
--
-- Workspaces 2 and 7-9 come from vars.workspaceAssignments; only ws1 and ws10
-- are laptop-specific and live here.
--
-- HOW THE ORDERING WORKS
--
-- Window rules are applied in registration order and, where two rules match
-- the same window and set the same property, THE LAST ONE WINS. (Verified on
-- 0.56: with a broad rule sending a class to ws8 registered first and a
-- narrower rule sending it to ws7 registered second, the window landed on
-- ws7.) So the sequence below is deliberate:
--
--   1. the broad `.*` catch-all              -> everything to ws10
--   2. the two ws1 dashboard classes         -> back to ws1
--   3. re-register the shared assignments    -> back to ws2 / ws7 / ws8 / ws9
--
-- Step 3 is required because 70-windowrules.lua registered those assignments
-- BEFORE this file runs, so the catch-all in step 1 would otherwise override
-- them. The list is re-applied from vars.workspaceAssignments rather than
-- retyped, so adding an app there fixes both places at once — no per-device
-- edit needed.
--
-- This replaces a PCRE negative lookahead that never worked: window rules are
-- matched with RE2 (Desktop::Rule::CRegexMatchEngine -> re2::RE2::FullMatchN),
-- which has no lookaround, and whose constructor has no error path — so the
-- pattern compiled to "never matches" silently, with nothing in the log.
--
-- NOTE: the catch-all changes real behaviour. It had been inert since at least
-- Hyprland 0.53, so windows were in practice opening on the focused workspace;
-- they now land on ws10 instead (previously ws2, before ws2 was reserved for
-- the nix-config layout). To go back to the old (accidental) behaviour,
-- comment out the catch-all rule alone.

local vars = require("00-vars")

-- 1. Everything defaults to workspace 10.
hl.window_rule({
    name      = "ws-default-catch-all",
    match     = { class = ".*" },

    workspace = "10 silent",
})

-- 2. The dashboard pair is pinned to workspace 1.
hl.window_rule({
    name      = "ws1-dashboard-keybinds",
    match     = { class = "^(ws1-keybinds)$" },

    workspace = "1 silent",
})

hl.window_rule({
    name      = "ws1-dashboard-monitor",
    match     = { class = "^(ws1-monitor)$" },

    workspace = "1 silent",
})

-- 3. Re-assert the shared per-app assignments so they beat the catch-all.
vars.apply_workspace_assignments("ws-reassert")


-- Laptop-specific autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("brightnessctl set 50%") -- Set initial brightness to 50%

    -- Populate the workspace-1 dashboard at login. The keybind viewer launches first
    -- (left tile); the half-second delay makes htop land on the right. htop is the
    -- same system monitor SUPER + M opens, so the tile matches the keybind.
    hl.exec_cmd([[sh -c 'kitty --class ws1-keybinds -e less ~/.config/hypr/KEYBINDS.md & sleep 0.5 ; kitty --class ws1-monitor -e htop &']])
end)

-- Dual keyboard layout support
-- Built-in laptop keyboard: gb (UK) - set in 30-input.lua as default
-- HyperX Alloy Origins Core PBT: us (US) - override below
-- Device name from `hyprctl devices`: hp--inc-hyperx-alloy-origins-core

hl.device({
    name      = "hp--inc-hyperx-alloy-origins-core",
    kb_layout = "us",
})
