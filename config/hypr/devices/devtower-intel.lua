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
--   2      file managers (Yazi, Thunar)           centre
--   3      mail (aerc + sheet, Claws Mail)        centre
--   4-9    LibreOffice Writer, Calc, Impress,     centre
--          Draw, Math, Base
--   10     comms (Teams, Zoom)                    centre
--   11     Zen (streaming)                        left
--   12     LibreWolf                              left
--   13     Firefox Developer Edition              centre
--   14     Brave                                  centre
--   15     video and image viewers                left
--   16-18  Affinity Designer, Photo, Publisher    centre
--   19     DaVinci Resolve                        left
--   20     spare; catches unassigned windows      centre
--   21-25  PhotoCraft, VectorCraft, LightCraft,   centre
--          PdfCraft, DesignCraft
--   26-28  SoundCraft, WordCraft, DeckCraft       centre
--   29-30  EffectCraft, FilmCraft                 left
--   31     nix-config dev layout                  centre
--   32-40  dev pool                               centre
--
-- Keys: SUPER + 1-9,0 -> 1-10, + SHIFT -> 11-20, + CTRL -> 21-30,
-- + ALT -> 31-40. Moving a window: SUPER + period, then the same chord
-- without SUPER (see "Workspace keybinds" below).

local placement = {
    [right] = { 1 },
    [left] = { 11, 12, 15, 19, 29, 30 },
}
local monitor_of = {}
for monitor, ids in pairs(placement) do
    for _, id in ipairs(ids) do monitor_of[id] = monitor end
end
local defaults = { [centre] = 2, [left] = 11, [right] = 1 }

for id = 1, 40 do
    local monitor = monitor_of[id] or centre
    hl.workspace_rule({
        workspace = tostring(id), monitor = monitor,
        default = defaults[monitor] == id,
        -- Do not persist empty dev-pool workspaces: dev-layout needs to
        -- discover them as free. Binding remains effective when created.
    })
end

-- ── Window placement ──────────────────────────────────────────────────
--
-- 70-windowrules.lua already registered the default map from 00-vars.lua.
-- Window rules apply in registration order and the last match wins, so the
-- catch-all goes first and this device's assignments after it, overriding
-- both. The ws1 dashboard panes are pinned by devtower-intel-dashboard.lua,
-- which is required after this file.
local vars = require("00-vars")
vars.mailWorkspace = 3

hl.window_rule({ name = "intel-default-catch-all", match = { class = ".*" }, workspace = "20" })

-- Class strings marked "unverified" are guesses: confirm with
-- `hyprctl clients` on first launch. A wrong class fails silently and the
-- window lands on the catch-all (20).
local assignments = {
    -- 2: file managers
    { "files-yazi", { class = "^(yazi)$" }, 2 },
    { "files-thunar", { class = "^(thunar)$" }, 2 },
    -- 3: mail
    { "mail-aerc", { class = "^(aerc)$" }, 3 },
    { "mail-aerc-keybinds", { class = "^(aerc-keybinds)$" }, 3 },
    { "mail-claws", { class = "^(claws-mail)$" }, 3 },
    -- 4-9: LibreOffice. Wayland app ids per module (unverified). The Start
    -- Center keeps its own id, so it opens with Writer.
    { "office-startcenter", { class = "^(libreoffice-startcenter)$" }, 4 },
    { "office-writer", { class = "^(libreoffice-writer)$" }, 4 },
    { "office-calc", { class = "^(libreoffice-calc)$" }, 5 },
    { "office-impress", { class = "^(libreoffice-impress)$" }, 6 },
    { "office-draw", { class = "^(libreoffice-draw)$" }, 7 },
    { "office-math", { class = "^(libreoffice-math)$" }, 8 },
    { "office-base", { class = "^(libreoffice-base)$" }, 9 },
    -- 10: comms
    { "comms-teams-for-linux", { class = "^(teams-for-linux)$" }, 10 },
    { "comms-zoom", { class = "^(zoom)$" }, 10 },
    -- 11-14: browsers
    { "browser-zen", { class = "^(zen-beta)$" }, 11 },
    { "browser-librewolf", { class = "^(librewolf)$" }, 12 },
    { "browser-firefox-devedition", { class = "^(firefox-devedition)$" }, 13 },
    { "browser-brave", { class = "^(brave-browser)$" }, 14 },
    -- 15: video and image viewers (modules/software/media.nix)
    { "viewer-vlc", { class = "^(vlc)$" }, 15 },
    { "viewer-mpv", { class = "^(mpv)$" }, 15 },
    { "viewer-imv", { class = "^(imv)$" }, 15 },
    -- 16-18: Affinity, one app per workspace
    { "affinity-designer", { class = "^(affinity-designer)$" }, 16 },
    { "affinity-photo", { class = "^(affinity-photo)$" }, 17 },
    { "affinity-publisher", { class = "^(affinity-publisher)$" }, 18 },
    -- 19: DaVinci Resolve (20 is the spare catch-all)
    { "resolve", { class = "^(resolve|Resolve|DaVinciResolve)$" }, 19 },
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
    { "nixcfg-term", { class = "^(nixcfg-term)$" }, 31 },
    { "nixcfg-nvim", { class = "^(nixcfg-nvim)$" }, 31 },
    -- Popups stay on the current workspace, over the app that asked.
    { "popup-file-picker", { class = "^(termfilechooser)$" }, "unset" },
    { "popup-ripdrag", { class = "^(it\\.catboy\\.ripdrag)$" }, "unset" },
}
for _, a in ipairs(assignments) do
    hl.window_rule({ name = "intel-" .. a[1], match = a[2], workspace = tostring(a[3]) })
end

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
local banks = { { "", 0 }, { "SHIFT + ", 10 }, { "CTRL + ", 20 }, { "ALT + ", 30 } }

for i = 1, 10 do
    hl.unbind(mod .. " + SHIFT + " .. i % 10)
end

-- Bank 1 (SUPER + number -> 1-10) is already bound by 60-keybinds.lua.
for b = 2, #banks do
    local prefix, offset = banks[b][1], banks[b][2]
    for i = 1, 10 do
        hl.bind(mod .. " + " .. prefix .. i % 10, hl.dsp.focus({ workspace = offset + i }))
    end
end

hl.bind(mod .. " + period", hl.dsp.submap("move-window"),
    { description = "Move window: then 1-0 (1-10), SHIFT (11-20), CTRL (21-30), ALT (31-40)" })
hl.define_submap("move-window", "reset", function()
    for _, bank in ipairs(banks) do
        for i = 1, 10 do
            hl.bind(bank[1] .. i % 10, hl.dsp.window.move({ workspace = bank[2] + i }))
        end
    end
    hl.bind("escape", hl.dsp.submap("reset"))
end)
