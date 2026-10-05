-- Development stages: three independent terminals stacked on portrait WS1.
-- Dedicated floating rectangles make placement independent of launch order,
-- cursor position and dwindle splits; they do not float across workspaces.
local vars = require("00-vars")
local panes = {
    { class = "ws1-keybinds", command = "less ~/.config/hypr/KEYBINDS.md" },
    { class = "ws1-monitor", command = "btop" },
    { class = "ws1-gpu", command = "nvtop" },
}
local pending = {}

for index, pane in ipairs(panes) do
    hl.window_rule({
        name = "intel-dashboard-" .. pane.class,
        match = { class = "^" .. pane.class .. "$" },
        workspace = "1 silent",
        float = true,
        -- Leave 40px for the bar plus outer margins and 8px between panes.
        size = { "monitor_w-20", "(monitor_h-76)/3" },
        move = { "10", "50+" .. tostring(index - 1) .. "*((monitor_h-76)/3+8)" },
        opacity = "0.95 0.95",
    })
end

local function dashboard()
    local active = hl.get_active_workspace()
    if not active or active.id ~= 1 then
        hl.dispatch(hl.dsp.focus({ workspace = 1 }))
    end
    for _, pane in ipairs(panes) do
        local window = hl.get_windows({ class = pane.class })[1]
        if window then
            if not window.workspace or window.workspace.id ~= 1 then
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = 1, follow = false }))
            end
        elseif not pending[pane.class] then
            local class, token = pane.class, {}
            pending[class] = token
            hl.exec_cmd("kitty --class " .. class .. " -e " .. pane.command)
            hl.timer(function()
                if pending[class] == token then pending[class] = nil end
            end, { timeout = 5000, type = "oneshot" })
        end
    end
end

hl.on("window.open", function(window)
    pending[window.class] = nil
end)
hl.bind(vars.mod .. " + Escape", dashboard,
    { description = "Portrait dashboard: keybindings, btop, nvtop" })
hl.on("hyprland.start", dashboard)
