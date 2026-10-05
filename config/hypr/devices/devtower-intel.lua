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

local groups = {
    { monitor = centre, ids = { 2, 3, 4, 5, 8, 9, 10 }, default = 2 },
    { monitor = left, ids = { 7 }, default = 7 },
    { monitor = right, ids = { 1, 6 }, default = 1 },
}
for _, group in ipairs(groups) do
    for _, id in ipairs(group.ids) do
        hl.workspace_rule({
            workspace = tostring(id), monitor = group.monitor,
            default = id == group.default,
            -- Do not persist empty dev-pool workspaces: dev-layout needs to
            -- discover them as free. Binding remains effective when created.
        })
    end
end

-- Unassigned windows use the extra centre workspace. Reassert shared app
-- assignments after the catch-all so specific rules win (last match wins).
local vars = require("00-vars")
hl.window_rule({ name = "intel-default-catch-all", match = { class = ".*" }, workspace = "10" })
vars.apply_workspace_assignments("intel-shared")

-- Only Zen uses media workspace 7; the other browsers use workspace 10.
hl.window_rule({ name = "intel-brave-workspace", match = { class = "^(brave-browser)$" }, workspace = "10" })
hl.window_rule({ name = "intel-firefox-developer-workspace", match = { class = "^(firefox-devedition)$" }, workspace = "10" })
hl.window_rule({ name = "intel-librewolf-workspace", match = { class = "^(librewolf)$" }, workspace = "10" })
hl.window_rule({ name = "intel-resolve-workspace", match = { class = "^(resolve|Resolve|DaVinciResolve)$" }, workspace = "8" })
