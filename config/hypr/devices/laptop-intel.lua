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
-- Workspace 1 is a fixed dashboard: the keybind cheatsheet (left) and a plain
-- kitty terminal (right), and NOTHING else. The two dashboard terminals are
-- launched with custom classes so they can be pinned here; every other window is
-- pushed to workspace 2 by the catch-all below — so apps default to ws2 instead
-- of opening on whatever workspace is focused.
--
-- !! KNOWN BROKEN — the catch-all below does NOT work, and never has. !!
--
-- Its pattern uses a PCRE negative lookahead `(?!...)`. Hyprland matches window
-- rules with RE2 (`Desktop::Rule::CRegexMatchEngine` is built on
-- `re2::RE2` + `re2::RE2::FullMatchN`), and RE2 has no lookaround support. The
-- engine's constructor has no error path, so an uncompilable pattern degrades
-- silently to "never matches" — no log line, no warning. Net effect: new
-- windows open on whatever workspace is focused, rather than defaulting to
-- workspace 2.
--
-- This is NOT a regression from the .conf -> .lua migration: RE2 has been the
-- rule engine since at least Hyprland 0.53, so this rule was already inert
-- before the move to Lua. It is translated faithfully here so that the
-- migration changes no behaviour; fixing it is a separate decision.
--
-- To actually fix it, the lookahead has to go. Express it by ordering instead:
-- register a broad `match = { class = ".*" }, workspace = "2 silent"` catch-all
-- BEFORE the specific assignments, and let the later, more specific rules
-- (ws1-keybinds, ws1-term, and the ws9/ws4 rules in 70-windowrules.lua) win.
-- That requires the catch-all to load ahead of 70-windowrules.lua, so it cannot
-- simply stay in this 90-device file. Verify any such change with
-- `hyprctl clients` — a broken pattern produces no error to notice.
--
-- The `workspace` rule value is a plain string in the Lua API, so the hyprlang
-- payload ("1 silent" / "2 silent") carries over verbatim. The catch-all regex
-- is wrapped in a Lua long-bracket string so it is passed through byte-for-byte
-- with no escaping.
hl.window_rule({
    name      = "ws1-dashboard-keybinds",
    match     = { class = "^(ws1-keybinds)$" },

    workspace = "1 silent",
})

hl.window_rule({
    name      = "ws1-dashboard-term",
    match     = { class = "^(ws1-term)$" },

    workspace = "1 silent",
})

hl.window_rule({
    name      = "ws1-dashboard-catch-all",
    match     = { class = [[^(?!ws1-keybinds$|ws1-term$|discord$|teams-for-linux$|zoom$|affinity-designer$|affinity-photo$|affinity-publisher$).*$]] },

    workspace = "2 silent",
})

-- Laptop-specific autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("brightnessctl set 50%") -- Set initial brightness to 50%

    -- Populate the workspace-1 dashboard at login. The keybind viewer launches first
    -- (left tile); the half-second delay makes the plain terminal land on the right.
    hl.exec_cmd([[sh -c 'kitty --class ws1-keybinds -e less ~/.config/hypr/KEYBINDS.md & sleep 0.5 ; kitty --class ws1-term &']])
end)

-- Dual keyboard layout support
-- Built-in laptop keyboard: gb (UK) - set in 30-input.lua as default
-- HyperX Alloy Origins Core PBT: us (US) - override below
-- Device name from `hyprctl devices`: hp--inc-hyperx-alloy-origins-core

hl.device({
    name      = "hp--inc-hyperx-alloy-origins-core",
    kb_layout = "us",
})
