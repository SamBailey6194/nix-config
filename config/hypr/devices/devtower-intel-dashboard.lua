-- Login terminal groups, each pinned to its own workspace:
--   ws1  three independent terminals stacked on the portrait monitor
--        (keybinding sheet, btop, nvtop)            SUPER + Escape
--   ws2  four plain shells in a 2x2 grid on the centre monitor, for running
--        commands and SSH sessions                  SUPER + SHIFT + Escape
-- Dedicated floating rectangles make placement independent of launch order,
-- cursor position and dwindle splits; they do not float across workspaces.
-- The keybinds build a missing group, refill closed panes and gather strays.
local vars = require("00-vars")

-- Margins: 10px sides and bottom, 50px top (40px bar plus margin), 8px
-- between panes.
local groups = {
    {
        workspace = 1,
        description = "Portrait dashboard: keybindings, btop, nvtop",
        bind = vars.mod .. " + Escape",
        panes = {
            { class = "ws1-keybinds", command = "less ~/.config/hypr/KEYBINDS.md" },
            { class = "ws1-monitor", command = "btop" },
            { class = "ws1-gpu", command = "nvtop" },
        },
        geometry = function(index)
            return { "monitor_w-20", "(monitor_h-76)/3" },
                { "10", "50+" .. tostring(index - 1) .. "*((monitor_h-76)/3+8)" }
        end,
    },
    {
        workspace = 2,
        description = "Terminal grid: four shells, 2x2",
        bind = vars.mod .. " + SHIFT + Escape",
        -- No command: Kitty runs the login shell, in $HOME.
        panes = {
            { class = "ws2-term-1" }, -- top left
            { class = "ws2-term-2" }, -- top right
            { class = "ws2-term-3" }, -- bottom left
            { class = "ws2-term-4" }, -- bottom right
        },
        geometry = function(index)
            local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
            return { "(monitor_w-28)/2", "(monitor_h-68)/2" },
                { column == 0 and "10" or "18+(monitor_w-28)/2",
                  row == 0 and "50" or "58+(monitor_h-68)/2" }
        end,
    },
}
local pending = {}

for _, group in ipairs(groups) do
    for index, pane in ipairs(group.panes) do
        local size, move = group.geometry(index)
        hl.window_rule({
            name = "intel-dashboard-" .. pane.class,
            match = { class = "^" .. pane.class .. "$" },
            workspace = tostring(group.workspace) .. " silent",
            float = true,
            size = size,
            move = move,
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

hl.on("window.open", function(window)
    pending[window.class] = nil
end)
for _, group in ipairs(groups) do
    hl.bind(group.bind, function() build(group) end, { description = group.description })
end
-- ws1 is on the right monitor and ws2 on the centre one, so both stay
-- visible; building ws2 last leaves focus on the centre monitor at login.
hl.on("hyprland.start", function()
    for _, group in ipairs(groups) do build(group) end
end)
