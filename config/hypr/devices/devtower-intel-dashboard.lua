-- Login terminal groups, each pinned to its own workspace:
--   ws1  two terminals stacked on the portrait monitor (btop, nvtop), as
--        floating rectangles                        SUPER + Escape
--   ws2  four plain shells on the centre monitor, for running commands and
--        SSH sessions, tiled by dwindle             SUPER + SHIFT + Escape
-- The ws1 rectangles make placement independent of launch order, cursor
-- position and dwindle splits; they do not float across workspaces. The ws2
-- shells are ordinary tiles (a group without `geometry` is not floated), so
-- dwindle arranges them and SUPER + V is not needed to tile them.
-- The keybinds build a missing group, refill closed panes and gather strays.
-- The keybinding sheet is still on SUPER + /.
-- Login also opens Yazi (ws3), aerc + khal (ws4), Zen (ws12) and Brave
-- (ws15); see login_apps.
local vars = require("00-vars")

-- ws1 margins: 10px sides and bottom, 50px top (40px bar plus margin), 8px
-- between panes. Two panes: each (monitor_h - 50 - 10 - 8) / 2 high.
local groups = {
    {
        workspace = 1,
        description = "Portrait dashboard: btop, nvtop",
        bind = vars.mod .. " + Escape",
        panes = {
            { class = "ws1-monitor", command = "btop" },
            { class = "ws1-gpu", command = "nvtop" },
        },
        geometry = function(index)
            return { "monitor_w-20", "(monitor_h-68)/2" },
                { "10", "50+" .. tostring(index - 1) .. "*((monitor_h-68)/2+8)" }
        end,
    },
    {
        workspace = 2,
        description = "Terminals: four shells, tiled",
        bind = vars.mod .. " + SHIFT + Escape",
        -- No command: Kitty runs the login shell, in $HOME. No geometry:
        -- the shells tile like any other window.
        panes = {
            { class = "ws2-term-1" },
            { class = "ws2-term-2" },
            { class = "ws2-term-3" },
            { class = "ws2-term-4" },
        },
    },
}
local pending = {}

for _, group in ipairs(groups) do
    for index, pane in ipairs(group.panes) do
        local rule = {
            name = "intel-dashboard-" .. pane.class,
            match = { class = "^" .. pane.class .. "$" },
            workspace = tostring(group.workspace) .. " silent",
            opacity = "0.95 0.95",
        }
        if group.geometry then
            rule.float = true
            rule.size, rule.move = group.geometry(index)
        end
        hl.window_rule(rule)
    end
end

-- Spawns are flagged pending until their window opens (or for 5 s if it
-- never does), so pressing the keybind twice does not launch duplicates.
local function build(group)
    local active = hl.get_active_workspace()
    if not active or active.id ~= group.workspace then
        hl.dispatch(hl.dsp.focus({ workspace = group.workspace }))
    end
    for _, pane in ipairs(group.panes) do
        local window = hl.get_windows({ class = pane.class })[1]
        if window then
            if not window.workspace or window.workspace.id ~= group.workspace then
                hl.dispatch(hl.dsp.window.move({
                    window = window, workspace = group.workspace, follow = false,
                }))
            end
        elseif not pending[pane.class] then
            local class, token = pane.class, {}
            pending[class] = token
            local command = "kitty --directory ~ --class " .. class
            if pane.command then command = command .. " -e " .. pane.command end
            hl.exec_cmd(command)
            hl.timer(function()
                if pending[class] == token then pending[class] = nil end
            end, { timeout = 5000, type = "oneshot" })
        end
    end
end

-- aerc left of khal. Dwindle puts a new tile on the side the mouse is on, so
-- launch order does not settle it; swap once both are tiled on ws4 (the same
-- fix as 60-keybinds.lua's mail_enforce_order, whose x-then-y order this
-- copies so a third window cannot make it swap back and forth).
local function on_ws4_tiled(w)
    return w ~= nil and w.workspace ~= nil and w.workspace.id == 4
        and not w.floating and w.fullscreen == 0
end

local function mail_calendar_order()
    local client = hl.get_windows({ class = "aerc" })[1]
    local calendar = hl.get_windows({ class = "khal" })[1]
    if on_ws4_tiled(client) and on_ws4_tiled(calendar)
        and (client.at.x > calendar.at.x
             or (client.at.x == calendar.at.x and client.at.y > calendar.at.y)) then
        hl.dispatch(hl.dsp.window.swap({ window = client, target = calendar }))
    end
end

hl.on("window.open", function(window)
    pending[window.class] = nil
    if window.class == "aerc" or window.class == "khal" then mail_calendar_order() end
end)
for _, group in ipairs(groups) do
    hl.bind(group.bind, function() build(group) end, { description = group.description })
end
-- Apps opened at login on their usual workspaces (devtower-intel.lua's map).
-- The per-launch rule adds "silent" so none of them steals focus; their own
-- keybinds still follow the window there. Mail at login is aerc with khal's
-- interactive calendar (ikhal) beside it; aerc's keybind sheet is left to
-- SUPER + E, which still opens it.
local login_apps = {
    { workspace = 3, command = "kitty --class yazi yazi" },
    { workspace = 4, command = "kitty --class aerc -e aerc" },
    { workspace = 4, command = "kitty --class khal -e khal interactive" },
    { workspace = 12, command = "zen-beta" },
    { workspace = 15, command = "brave" },
}

-- ws1 is on the right monitor and ws2 on the centre one, so both stay
-- visible; building ws2 last leaves focus on the centre monitor at login.
hl.on("hyprland.start", function()
    for _, app in ipairs(login_apps) do
        hl.exec_cmd(app.command, { workspace = app.workspace .. " silent" })
    end
    for _, group in ipairs(groups) do build(group) end
end)
