-- Login terminal groups, each pinned to its own workspace and tiled by
-- dwindle like any other window:
--   ws1  btop over nvtop on the portrait monitor      SUPER + Escape
--   ws2  four plain shells on the centre monitor, for running commands and
--        SSH sessions                                SUPER + SHIFT + Escape
-- The keybinds build a missing group, refill closed panes and gather strays.
-- The keybinding sheet is on SUPER + /.
-- Login also opens Yazi (ws3), aerc + khal (ws4), Zen (ws12) and Brave
-- (ws15); see login_apps.
local vars = require("00-vars")

local groups = {
    {
        workspace = 1,
        description = "Portrait dashboard: btop, nvtop",
        bind = vars.mod .. " + Escape",
        panes = {
            { class = "ws1-monitor", command = "btop" },
            { class = "ws1-gpu", command = "nvtop" },
        },
    },
    {
        workspace = 2,
        description = "Terminals: four shells, tiled",
        bind = vars.mod .. " + SHIFT + Escape",
        -- No command: Kitty runs the login shell, in $HOME.
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
    for _, pane in ipairs(group.panes) do
        hl.window_rule({
            name = "intel-dashboard-" .. pane.class,
            match = { class = "^" .. pane.class .. "$" },
            workspace = tostring(group.workspace) .. " silent",
            opacity = "0.95 0.95",
        })
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

-- Tile pairs kept in order: the first before the second (left of it side
-- by side, above it when stacked). Dwindle puts a new tile on the side the
-- mouse is on, so launch order does not settle it; swap once both are tiled
-- on the workspace. Same fix as 60-keybinds.lua's mail_enforce_order, whose
-- strict x-then-y order this copies so a third window cannot make it swap
-- back and forth. Floating or fullscreen panes are left alone: a swap would
-- trade that state between the two.
local ordered_pairs = {
    { first = "ws1-monitor", second = "ws1-gpu", workspace = 1 }, -- btop over nvtop
    { first = "aerc", second = "khal", workspace = 4 },
}

local function tiled_on(w, workspace)
    return w ~= nil and w.workspace ~= nil and w.workspace.id == workspace
        and not w.floating and w.fullscreen == 0
end

local function enforce_order(pair)
    local a = hl.get_windows({ class = pair.first })[1]
    local b = hl.get_windows({ class = pair.second })[1]
    if tiled_on(a, pair.workspace) and tiled_on(b, pair.workspace)
        and (a.at.x > b.at.x or (a.at.x == b.at.x and a.at.y > b.at.y)) then
        hl.dispatch(hl.dsp.window.swap({ window = a, target = b }))
    end
end

hl.on("window.open", function(window)
    pending[window.class] = nil
    for _, pair in ipairs(ordered_pairs) do
        if window.class == pair.first or window.class == pair.second then
            enforce_order(pair)
        end
    end
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
