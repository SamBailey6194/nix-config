-- Intel desktop: EDIDs and Ubuntu layout audited 2026-10-05.
-- Match description prefixes instead of Ubuntu's X11 connector names, which
-- differ from DRM/Wayland (4K: X11 DP-4, DRM DP-3).
local left = "desc:AOC U2879G6"
local centre = "desc:AOC AG271QG4"
local right = "desc:AOC 27G2WG3-"

-- Positions are logical pixels: 3840 / 1.5 = 2560 on the left display.
hl.monitor({ output = left, mode = "3840x2160@60", position = "0x0", scale = 1.5 })
hl.monitor({ output = centre, mode = "2560x1440@143.91", position = "2560x0", scale = 1 })
-- Preserve Ubuntu's counter-clockwise portrait rotation (xrandr "left").
hl.monitor({ output = right, mode = "1920x1080@144", position = "5120x0", scale = 1, transform = 1 })

-- ── Workspace placement (devtower-intel only) ─────────────────────────
--
-- The workspace map itself is shared by every device (00-vars.lua,
-- registered by 70-windowrules.lua, keyed by 60-keybinds.lua). This file only
-- decides which monitor each workspace opens on, adds the ws1 and ws2
-- dashboards (devtower-intel-dashboard.lua, required after this file), the
-- khal key and SUPER + comma.
--
--   right (portrait)  1 (dashboard: btop, nvtop)
--   left              12 Zen, 13 LibreWolf, 16 viewers, 20 Resolve,
--                     21 FilmCraft, 22 EffectCraft, 23 AniCraft
--   centre            everything else, including 41-50 and the 51+ overflow
--
-- SUPER + comma moves the focused workspace between the centre and left
-- monitors.

local placement = {
    [right] = { 1 },
    [left] = { 12, 13, 16, 20, 21, 22, 23 },
}
local monitor_of = {}
for monitor, ids in pairs(placement) do
    for _, id in ipairs(ids) do monitor_of[id] = monitor end
end
local defaults = { [centre] = 2, [left] = 12, [right] = 1 }

for id = 1, 40 do
    local monitor = monitor_of[id] or centre
    hl.workspace_rule({
        workspace = tostring(id), monitor = monitor,
        default = defaults[monitor] == id,
        -- Do not persist empty dev-pool workspaces: dev-layout needs to
        -- discover them as free. Binding remains effective when created.
    })
end
-- 41-50 (spares) and the overflow workspaces for unassigned windows (51 up,
-- 70-windowrules.lua): centre, never anyone's default, created and destroyed
-- on demand.
for id = 41, 99 do
    hl.workspace_rule({ workspace = tostring(id), monitor = centre })
end

-- ── Calendar ──────────────────────────────────────────────────────────
--
-- khal is installed on devtower-intel only (hosts/devtower-intel/calendar.nix);
-- its window rule (workspace 4, beside aerc) is in the shared map.
local vars = require("00-vars")
local mod = vars.mod
hl.bind(mod .. " + SHIFT + C", function()
    hl.dispatch(hl.dsp.focus({ workspace = vars.mailWorkspace }))
    hl.exec_cmd("kitty --class khal -e khal interactive")
end, { description = "Calendar: khal alongside mail on workspace 4" })

-- ── Moving a workspace between centre and left ────────────────────────
--
-- SUPER + comma sends the focused workspace, windows and all, across to the
-- other of the centre and left monitors and follows it there. Meant for the
-- 41+ workspaces (spares and overflow), which all open
-- on the centre monitor, but it works on any of them. The right (portrait) monitor is left alone.
--
-- The move lasts while the workspace exists. Once it empties and Hyprland
-- destroys it, the number reopens on the monitor its workspace rule names.
local function swap_side()
    local ws = hl.get_active_workspace()
    if not ws or ws.special or not ws.id or not ws.monitor then return end
    local target
    local on_centre, on_left = hl.get_monitor(centre), hl.get_monitor(left)
    if on_centre and ws.monitor.id == on_centre.id then
        target = left
    elseif on_left and ws.monitor.id == on_left.id then
        target = centre
    else
        return
    end
    hl.dispatch(hl.dsp.workspace.move({ workspace = ws.id, monitor = target }))
    hl.dispatch(hl.dsp.focus({ workspace = ws.id }))
end

hl.bind(mod .. " + comma", swap_side,
    { description = "Move the focused workspace between the centre and left monitors" })
