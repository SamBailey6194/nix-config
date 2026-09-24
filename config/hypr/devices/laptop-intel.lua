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
-- Workspace 1 is a fixed dashboard: the keybind cheatsheet (left) and btop
-- (right, the same system monitor SUPER + M opens), and NOTHING else. The two
-- dashboard terminals are launched with custom classes so they can be pinned
-- here; every other window is pushed to workspace 10 by the catch-all below —
-- so apps default to ws10 instead of opening on whatever workspace happens to
-- be focused. SUPER + Escape jumps back to it and reopens whichever pane was
-- closed (see "Workspace-1 dashboard launcher" further down).
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


-- ── Workspace-1 dashboard launcher ────────────────────────────────────
--
-- One function, used twice: at login (hyprland.start) and on SUPER + Escape.
-- It focuses workspace 1, then makes sure each dashboard pane exists exactly
-- once:
--
--   open on ws1          left alone
--   open elsewhere       moved back to ws1 (never a second copy)
--   not open             launched; the ws1 rules above pin it
--
-- WHY THE PANES ARE SWAPPED AFTER THEY OPEN
--
-- Launch order does not decide which side a tile lands on. With dwindle's
-- defaults (force_split = 0, use_active_for_splits = true) a new tile goes to
-- the side of the split the MOUSE is on (DwindleAlgorithm.cpp, addTarget). The
-- old `keybinds & sleep 0.5 ; monitor` launch could therefore come out
-- reversed, and did: the live session had the monitor as the LEFT tile. So
-- order is fixed up instead: once both panes are on ws1, if the keybinds pane
-- is to the right of the monitor, swap them. window.open fires after layout
-- placement, so `at` is final by then.
-- The swap warps the cursor to the keybinds pane (cursor:no_warps is off).
--
-- Only two TILED panes are reordered. A swap trades the floating state
-- between the two windows (ITarget::swap), so floating the cheatsheet with
-- SUPER + V and then pressing SUPER + Escape would otherwise turn btop into
-- the floating one. Fullscreen panes are left alone for the same reason.
--
-- API NOTES (Hyprland 0.56, verified in source)
--
--   hl.get_windows({ class = ... })  EXACT app_id match, not a regex (unlike
--                                    window rules), across all workspaces,
--                                    mapped windows only
--   hl.exec_cmd(cmd)                 runs through /bin/sh -c, so ~ expands;
--                                    returns nothing, so no PID to track
--   hl.bind(key, fn)                 a Lua function is a valid action; a
--                                    runtime error in it (or in an hl.on
--                                    callback) pops a 5 s "Runtime error in
--                                    lua" notification and goes to
--                                    hyprland.log, NOT the config error bar
--
-- `pending` stops a double press from launching two copies. A pane counts as
-- open only once it is MAPPED, so there is a gap between launch and map. The
-- flag clears on window.open, or after 5 s if kitty never shows up. Each
-- launch's flag is a fresh token, so the 5 s timer from an EARLIER launch
-- (timers cannot be cancelled) cannot clear the flag of a newer one.

local mod = vars.mod

local DASHBOARD = {
    { class = "ws1-keybinds", cmd = "kitty --class ws1-keybinds -e less ~/.config/hypr/KEYBINDS.md" },
    { class = "ws1-monitor",  cmd = "kitty --class ws1-monitor -e btop" },
}

local pending = {}

local function find(class)
    return hl.get_windows({ class = class })[1]
end

local function on_ws1(w)
    local ws = w and w.workspace
    return ws ~= nil and ws.id == 1
end

-- `fullscreen` is an integer mode, and 0 is truthy in Lua, so compare it.
local function tiled(w)
    return not w.floating and w.fullscreen == 0
end

-- Keybinds on the left, monitor on the right.
local function enforce_order()
    local kb, mon = find("ws1-keybinds"), find("ws1-monitor")
    if on_ws1(kb) and on_ws1(mon) and tiled(kb) and tiled(mon)
        and kb.at.x > mon.at.x then
        hl.dispatch(hl.dsp.window.swap({ window = kb, target = mon }))
    end
end

local function ws1_dashboard()
    -- Guarded so it stays a no-op on ws1 even if binds:workspace_back_and_forth
    -- is ever turned on (focusing the current workspace would then bounce away).
    local active = hl.get_active_workspace()
    if not active or active.id ~= 1 then
        hl.dispatch(hl.dsp.focus({ workspace = 1 }))
    end

    for _, pane in ipairs(DASHBOARD) do
        local cls = pane.class
        local w   = find(cls)
        if w then
            if not on_ws1(w) then
                hl.dispatch(hl.dsp.window.move({ window = w, workspace = 1, follow = false }))
            end
        elseif not pending[cls] then
            local token = {}
            pending[cls] = token
            hl.exec_cmd(pane.cmd)
            hl.timer(function()
                if pending[cls] == token then pending[cls] = nil end
            end, { timeout = 5000, type = "oneshot" })
        end
    end

    -- Covers panes that were already open (or just moved back) in the wrong
    -- order; newly launched ones are handled by window.open below.
    enforce_order()
end

hl.on("window.open", function(w)
    local cls = w.class
    if cls == "ws1-keybinds" or cls == "ws1-monitor" then
        pending[cls] = nil
        enforce_order()
    end
end)

hl.bind(mod .. " + Escape", ws1_dashboard,
    { description = "Workspace 1 dashboard: focus it, reopen any missing pane" })

-- Laptop-specific autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("brightnessctl set 50%") -- Set initial brightness to 50%

    -- Populate the workspace-1 dashboard at login.
    ws1_dashboard()
end)

-- Dual keyboard layout support
-- Built-in laptop keyboard: gb (UK) - set in 30-input.lua as default
-- HyperX Alloy Origins Core PBT: us (US) - override below
-- Device name from `hyprctl devices`: hp--inc-hyperx-alloy-origins-core

hl.device({
    name      = "hp--inc-hyperx-alloy-origins-core",
    kb_layout = "us",
})
