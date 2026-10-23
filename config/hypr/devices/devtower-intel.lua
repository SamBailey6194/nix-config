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

-- ── Workspace map (devtower-intel only; laptop-intel keeps 00-vars.lua's) ──
--
--   1      dashboard: keybinds, btop, nvtop       right (portrait)
--   2      four Kitty terminals, 2x2 grid         centre
--   3      file managers (Yazi, Thunar)           centre
--   4      mail (aerc + sheet, Claws Mail)        centre
--   5-10   LibreOffice Writer, Calc, Impress,     centre
--          Draw, Math, Base
--   11     comms (Teams, Zoom)                    centre
--   12     Zen (streaming)                        left
--   13     LibreWolf                              left
--   14     Firefox Developer Edition              centre
--   15     Brave                                  centre
--   16     video and image viewers                left
--   17-19  Affinity Designer, Photo, Publisher    centre
--   20     DaVinci Resolve                        left
--   21-25  PhotoCraft, VectorCraft, LightCraft,   centre
--          PdfCraft, DesignCraft
--   26-28  SoundCraft, WordCraft, DeckCraft       centre
--   29-30  EffectCraft, FilmCraft                 left
--   31     nix-config dev layout                  centre
--   32-40  dev pool                               centre
--   41+    unassigned windows, first free one     centre
--
-- Keys: SUPER + 1-9,0 -> 1-10, + SHIFT -> 11-20, + CTRL -> 21-30,
-- + ALT -> 31-40. Moving a window: SUPER + period, then the same chord
-- without SUPER (see "Workspace keybinds" below). SUPER + comma moves the
-- focused workspace between the centre and left monitors.

local placement = {
    [right] = { 1 },
    [left] = { 12, 13, 16, 20, 29, 30 },
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
-- Overflow workspaces for unassigned windows (see below): centre, never
-- anyone's default, created and destroyed on demand.
for id = 41, 99 do
    hl.workspace_rule({ workspace = tostring(id), monitor = centre })
end

-- ── Window placement ──────────────────────────────────────────────────
--
-- 70-windowrules.lua already registered the default map from 00-vars.lua.
-- Window rules apply in registration order and the last match wins, so the
-- catch-all goes first and this device's assignments after it, overriding
-- both. The ws1 dashboard panes and the ws2 terminals are pinned by
-- devtower-intel-dashboard.lua, which is required after this file.
local vars = require("00-vars")
vars.mailWorkspace = 4

-- Unassigned windows are parked, out of sight, on a holding special
-- workspace; the window.open handler below moves each one on to the first
-- free workspace from 41 up. A static rule cannot name "the first free
-- workspace", and parking first means the window never flashes on whichever
-- workspace happened to be active.
local holding = "unassigned"
hl.window_rule({
    name = "intel-default-catch-all", match = { class = ".*" },
    workspace = "special:" .. holding .. " silent",
})

-- Class strings marked "unverified" are guesses: confirm with
-- `hyprctl clients` on first launch. A wrong class fails silently and the
-- window lands on the first free workspace from 41 up.
local assignments = {
    -- 3: file managers
    { "files-yazi", { class = "^(yazi)$" }, 3 },
    { "files-thunar", { class = "^(thunar)$" }, 3 },
    -- 4: mail
    { "mail-aerc", { class = "^(aerc)$" }, 4 },
    { "mail-aerc-keybinds", { class = "^(aerc-keybinds)$" }, 4 },
    { "mail-claws", { class = "^(claws-mail)$" }, 4 },
    { "mail-calendar", { class = "^(khal)$" }, 4 },
    -- 5-10: LibreOffice. Wayland app ids per module (unverified). The Start
    -- Center keeps its own id, so it opens with Writer.
    { "office-startcenter", { class = "^(libreoffice-startcenter)$" }, 5 },
    { "office-writer", { class = "^(libreoffice-writer)$" }, 5 },
    { "office-calc", { class = "^(libreoffice-calc)$" }, 6 },
    { "office-impress", { class = "^(libreoffice-impress)$" }, 7 },
    { "office-draw", { class = "^(libreoffice-draw)$" }, 8 },
    { "office-math", { class = "^(libreoffice-math)$" }, 9 },
    { "office-base", { class = "^(libreoffice-base)$" }, 10 },
    -- 11: comms
    { "comms-teams-for-linux", { class = "^(teams-for-linux)$" }, 11 },
    { "comms-zoom", { class = "^(zoom)$" }, 11 },
    -- 12-15: browsers
    { "browser-zen", { class = "^(zen-beta)$" }, 12 },
    { "browser-librewolf", { class = "^(librewolf)$" }, 13 },
    { "browser-firefox-devedition", { class = "^(firefox-devedition)$" }, 14 },
    { "browser-brave", { class = "^(brave-browser)$" }, 15 },
    -- 16: video and image viewers (modules/software/media.nix)
    { "viewer-vlc", { class = "^(vlc)$" }, 16 },
    { "viewer-mpv", { class = "^(mpv)$" }, 16 },
    { "viewer-imv", { class = "^(imv)$" }, 16 },
    -- 17-19: Affinity, one app per workspace
    { "affinity-designer", { class = "^(affinity-designer)$" }, 17 },
    { "affinity-photo", { class = "^(affinity-photo)$" }, 18 },
    { "affinity-publisher", { class = "^(affinity-publisher)$" }, 19 },
    -- 20: DaVinci Resolve
    { "resolve", { class = "^(resolve|Resolve|DaVinciResolve)$" }, 20 },
    -- 21-30: the Craft suite (modules/software/craft-apps.nix). Wayland
    -- app_id = the desktop file id (ai.storyteller.<app>), read from the
    -- shipped .desktop StartupWMClass and the binaries.
    -- PhotoCraft: unverified — confirm with hyprctl clients. Its launcher
    -- falls back to Xwayland (pen tablet or preference), where the X11
    -- class is the bare "photocraft".
    { "craft-photo", { class = "^(ai\\.storyteller\\.photocraft|photocraft)$" }, 21 },
    { "craft-vector", { class = "^(ai\\.storyteller\\.vectorcraft)$" }, 22 },
    { "craft-light", { class = "^(ai\\.storyteller\\.lightcraft)$" }, 23 },
    { "craft-pdf", { class = "^(ai\\.storyteller\\.pdfcraft)$" }, 24 },
    { "craft-design", { class = "^(ai\\.storyteller\\.designcraft)$" }, 25 },
    { "craft-sound", { class = "^(ai\\.storyteller\\.soundcraft)$" }, 26 },
    { "craft-word", { class = "^(ai\\.storyteller\\.wordcraft)$" }, 27 },
    { "craft-deck", { class = "^(ai\\.storyteller\\.deckcraft)$" }, 28 },
    { "craft-effect", { class = "^(ai\\.storyteller\\.effectcraft)$" }, 29 },
    { "craft-film", { class = "^(ai\\.storyteller\\.filmcraft)$" }, 30 },
    -- 31: nix-config dev layout (class + title for Zed; see 00-vars.lua)
    { "nixcfg-editor", { class = "^(dev\\.zed\\.Zed)$", title = "^(nix-config)$" }, 31 },
    { "nixcfg-nvim", { class = "^(nixcfg-nvim)$" }, 31 },
    -- Popups stay on the current workspace, over the app that asked.
    { "popup-file-picker", { class = "^(termfilechooser)$" }, "unset" },
    { "popup-ripdrag", { class = "^(it\\.catboy\\.ripdrag)$" }, "unset" },
}
for _, a in ipairs(assignments) do
    hl.window_rule({ name = "intel-" .. a[1], match = a[2], workspace = tostring(a[3]) })
end

-- ── Overflow: the first free workspace from 41 up ─────────────────────
--
-- Each new unassigned window takes the lowest 41+ workspace with no windows
-- (or not existing at all); follow = true takes focus there, on the centre
-- monitor (workspace rules above). Dialogs are the exception: a floating
-- window whose process already has a window on a normal workspace joins it
-- (the active workspace first), so a Save dialog or Zed's project picker
-- opens over the app that asked rather than on a workspace of its own. Tiled
-- windows always get a fresh workspace, so a second Zed project does not pile
-- onto the nix-config layout on 31.
local overflow_first = 41

local function is_holding(workspace)
    return workspace ~= nil and workspace.special
        and workspace.name:gsub("^special:", "") == holding
end

local function parent_workspace(window)
    if not window.floating then return nil end
    local active = hl.get_active_workspace()
    local found
    for _, other in ipairs(hl.get_windows()) do
        local ws = other.workspace
        if other.address ~= window.address and other.pid == window.pid
            and ws and not ws.special and ws.id then
            if active and active.id == ws.id then return ws.id end
            found = found or ws.id
        end
    end
    return found
end

local function free_workspace()
    local busy = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id and ws.windows > 0 then busy[ws.id] = true end
    end
    local id = overflow_first
    while busy[id] do id = id + 1 end
    return id
end

hl.on("window.open", function(window)
    if not is_holding(window.workspace) then return end
    hl.dispatch(hl.dsp.window.move({
        window = window,
        workspace = parent_workspace(window) or free_workspace(),
        follow = true,
    }))
end)

-- dev-layout reads these from its environment, which it inherits from
-- Hyprland through the SUPER + (SHIFT|CTRL) + Z / RETURN keybinds.
hl.env("DEV_LAYOUT_NIX_CONFIG_WS", "31")
hl.env("DEV_LAYOUT_POOL_FIRST", "32")
hl.env("DEV_LAYOUT_POOL_LAST", "40")

-- ── Workspace keybinds ────────────────────────────────────────────────
--
-- Four banks of ten, one per modifier. SUPER + SHIFT + number moved a
-- window in the shared config (60-keybinds.lua); it is unbound here and
-- moving goes through a submap instead: SUPER + period, then the number with
-- the bank's modifier minus SUPER (1 -> ws 1, SHIFT + 1 -> ws 11,
-- CTRL + 1 -> ws 21, ALT + 1 -> ws 31). The submap resets after one move;
-- Escape cancels.
local mod = vars.mod
hl.bind(mod .. " + SHIFT + C", function()
    hl.dispatch(hl.dsp.focus({ workspace = 4 }))
    hl.exec_cmd("kitty --class khal -e khal interactive")
end, { description = "Calendar: khal alongside mail on workspace 4" })

local banks = { { "", 0 }, { "SHIFT + ", 10 }, { "CTRL + ", 20 }, { "ALT + ", 30 } }

-- Every number key below also has its numpad twin (vars.number_keys).
for i = 1, 10 do
    for _, key in ipairs(vars.number_keys(i % 10)) do
        hl.unbind(mod .. " + SHIFT + " .. key)
    end
end

-- Bank 1 (SUPER + number -> 1-10) is already bound by 60-keybinds.lua.
for b = 2, #banks do
    local prefix, offset = banks[b][1], banks[b][2]
    for i = 1, 10 do
        for _, key in ipairs(vars.number_keys(i % 10)) do
            hl.bind(mod .. " + " .. prefix .. key, hl.dsp.focus({ workspace = offset + i }))
        end
    end
end

hl.bind(mod .. " + period", hl.dsp.submap("move-window"),
    { description = "Move window: then 1-0 (1-10), SHIFT (11-20), CTRL (21-30), ALT (31-40)" })
hl.define_submap("move-window", "reset", function()
    for _, bank in ipairs(banks) do
        for i = 1, 10 do
            for _, key in ipairs(vars.number_keys(i % 10)) do
                hl.bind(bank[1] .. key, hl.dsp.window.move({ workspace = bank[2] + i }))
            end
        end
    end
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- ── Moving a workspace between centre and left ────────────────────────
--
-- SUPER + comma sends the focused workspace, windows and all, across to the
-- other of the centre and left monitors and follows it there. Meant for the
-- 41+ overflow workspaces, which all open on the centre monitor, but it
-- works on any of them. The right (portrait) monitor is left alone.
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
