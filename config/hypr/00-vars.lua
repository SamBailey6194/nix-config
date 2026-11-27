-- Hyprland Shared Variables
-- Replaces the hyprlang `$var = ...` mechanism, which has no equivalent in the
-- Lua config provider. Plain Lua locals are used instead.
--
-- This file is a MODULE: it is registered with `autoLoad = false` so Hyprland
-- never executes it on its own. Every other config file pulls it in with:
--
--     local vars = require("00-vars")
--     hl.bind(vars.mod .. " + Q", hl.dsp.window.close())

local M = {}

-- Modifier key (was `$mod = SUPER`)
M.mod = "SUPER"

-- Workspace the SUPER + E mail layout (60-keybinds.lua) focuses and gathers
-- aerc and its sheet onto. Read when the keybind fires, not at load time.
-- Every Lua config file shares one state, so require() returns this same table.
M.mailWorkspace = 4

-- ── The shared workspace map ──────────────────────────────────────────
--
-- One map for every device. Which MONITOR a workspace sits on is the only
-- per-device part: devtower-intel spreads them over left, centre and right
-- (devices/devtower-intel.lua); a laptop has one screen and needs nothing.
-- An app a device does not install simply never matches its rule.
--
--   1      dashboard (device file: laptop-intel, devtower-intel)
--   2      devtower-intel: four terminals; elsewhere an ordinary workspace
--   3      file manager (Yazi)
--   4      mail (aerc + keybind sheet; khal on devtower-intel)
--   5      Start Center, Writer + WordCraft
--   6      Impress + DeckCraft
--   7      Calc + GridCraft
--   8      PDFs: PdfCraft + Zathura
--   9      DesignCraft
--   10     Math + Base
--   11     comms (Teams, Zoom, Slack)
--   12     Zen (streaming)
--   13     LibreWolf
--   14     Firefox Developer Edition
--   15     Brave
--   16     video and image viewers (VLC, mpv, imv)
--   17     PhotoCraft + GIMP
--   18     Draw + VectorCraft
--   19     LightCraft
--   20     DaVinci Resolve
--   21     FilmCraft
--   22     EffectCraft
--   23     AniCraft
--   24     SoundCraft + Reaper + Audacity
--   25     Blender
--   26     MaterialCraft
--   27     TextureCraft
--   28     CADCraft
--   29     FigCraft
--   30     Playwright browser testing
--   31     nix-config dev layout (Zed or Neovim)   DEV_LAYOUT_NIX_CONFIG_WS
--   32-40  dev pool, one project per workspace     DEV_LAYOUT_POOL_FIRST/LAST
--   41     Replit desktop app (devtower, devtower-intel)
--   42     scrcpy phone mirror (phone-mirror, pkgs/phone-mirror.nix)
--   43-50  spare (keyed, never used by overflow)
--   51+    unassigned windows, the first free one  (70-windowrules.lua)
--
-- Affinity (Wine) stays installed but has no workspace: it opens on 51+.
--
-- Keys (60-keybinds.lua): SUPER + 1-9,0 -> 1-10, + SHIFT -> 11-20,
-- + CTRL -> 21-30, + ALT -> 31-40, + CTRL + SHIFT -> 41-50. Moving a window:
-- SUPER + period, then the same chord without SUPER.
M.overflowFirst = 51
M.devLayout = { nixConfig = 31, poolFirst = 32, poolLast = 40 }

-- ── Workspace assignments ─────────────────────────────────────────────
--
-- Single source of truth for "this app always opens on that workspace".
-- 70-windowrules.lua registers them for every device, straight after the
-- catch-all that parks every other window for the overflow handler. Window
-- rules apply in registration order and the last match wins, so these beat
-- the catch-all, and a device file (required last) can still pin its own
-- dashboard windows over both.
--
-- Each entry carries a full `match` table, passed straight through to
-- hl.window_rule, so a rule can match class AND title (the nix-config Zed
-- window below). Dots in reverse-DNS classes are escaped ("\\." in Lua, \.
-- for RE2) so a look-alike class does not match. Hyprland matches classes
-- case-sensitively.
--
-- Class strings marked "unverified" are guesses: confirm with
-- `hyprctl clients` on first launch. A wrong class fails silently and the
-- window lands on the first free workspace from 51 up.
local function assign(name, match, workspace)
    return { name = name, match = match, workspace = tostring(workspace) }
end

M.workspaceAssignments = {
    -- 3: file manager. SUPER + F opens Yazi in kitty with the `yazi` class;
    -- udiskie's "browse" action launches the same class.
    assign("files-yazi", { class = "^(yazi)$" }, 3),

    -- 4: mail. aerc and its sheet are kitty windows launched with these
    -- classes by the SUPER + E layout (60-keybinds.lua), so they are certain.
    assign("mail-aerc", { class = "^(aerc)$" }, 4),
    assign("mail-aerc-keybinds", { class = "^(aerc-keybinds)$" }, 4),
    assign("mail-calendar", { class = "^(khal)$" }, 4),

    -- 5-10: documents, each LibreOffice module beside its Craft equivalent.
    -- LibreOffice classes are per module (unverified). A document opened
    -- from the Start Center reuses its window, so it stays on 5 whatever the
    -- module; documents opened directly land on their own workspace.
    assign("office-startcenter", { class = "^(libreoffice-startcenter)$" }, 5),
    assign("office-writer", { class = "^(libreoffice-writer)$" }, 5),
    assign("office-impress", { class = "^(libreoffice-impress)$" }, 6),
    assign("office-calc", { class = "^(libreoffice-calc)$" }, 7),
    -- Zathura's class confirmed with hyprctl clients (22/11/2026).
    assign("viewer-zathura", { class = "^(org\\.pwmt\\.zathura)$" }, 8),
    assign("office-math", { class = "^(libreoffice-math)$" }, 10),
    assign("office-base", { class = "^(libreoffice-base)$" }, 10),

    -- 11: comms. Slack: its StartupWMClass "Slack" (unverified).
    assign("comms-teams-for-linux", { class = "^(teams-for-linux)$" }, 11),
    assign("comms-zoom", { class = "^(zoom)$" }, 11),
    assign("comms-slack", { class = "^(Slack|slack)$" }, 11),

    -- 12-15: browsers. These are the only four browsers this config installs
    -- (regular Firefox, Google Chrome and Chromium were removed; Zen is the
    -- default handler, home/modules/browsers.nix). The classes are each
    -- browser's StartupWMClass, not its command: Brave's binary is `brave`
    -- but its class is `brave-browser` (verified with hyprctl clients).
    assign("browser-zen", { class = "^(zen-beta)$" }, 12),
    assign("browser-librewolf", { class = "^(librewolf)$" }, 13),
    assign("browser-firefox-devedition", { class = "^(firefox-devedition)$" }, 14),
    assign("browser-brave", { class = "^(brave-browser)$" }, 15),

    -- 16: video and image viewers (modules/software/media.nix)
    assign("viewer-vlc", { class = "^(vlc)$" }, 16),
    assign("viewer-mpv", { class = "^(mpv)$" }, 16),
    assign("viewer-imv", { class = "^(imv)$" }, 16),

    -- 17-30: creative apps, each non-Craft app beside its Craft equivalent.
    -- Non-Craft classes are their StartupWMClass plus the Wayland app_id
    -- form (unverified).
    assign("creative-gimp", { class = "^(gimp|Gimp.*)$" }, 17),
    assign("office-draw", { class = "^(libreoffice-draw)$" }, 18),
    assign("resolve", { class = "^(resolve|Resolve|DaVinciResolve)$" }, 20),
    assign("creative-reaper", { class = "^(REAPER|reaper)$" }, 24),
    assign("creative-audacity",
        { class = "^(org\\.audacityteam\\.Audacity|Audacity( 4)?|audacity)$" }, 24),
    assign("creative-blender", { class = "^(Blender|blender)$" }, 25),

    -- The Craft suite (modules/software/craft-apps.nix). The class is the
    -- desktop file id (ai.storyteller.<app>), on Wayland and Xwayland alike;
    -- confirmed with hyprctl clients (22/11/2026). PhotoCraft also keeps the
    -- bare "photocraft", its pre-0.23 StartupWMClass, for its Xwayland
    -- fallback (pen tablet or preference). MaterialCraft and TextureCraft
    -- carry no reverse-DNS id: their class is the capitalised product name,
    -- not the lower-case StartupWMClass they ship, so those rules list every
    -- form.
    assign("craft-word", { class = "^(ai\\.storyteller\\.wordcraft)$" }, 5),
    assign("craft-deck", { class = "^(ai\\.storyteller\\.deckcraft)$" }, 6),
    assign("craft-grid", { class = "^(ai\\.storyteller\\.gridcraft)$" }, 7),
    assign("craft-pdf", { class = "^(ai\\.storyteller\\.pdfcraft)$" }, 8),
    assign("craft-design", { class = "^(ai\\.storyteller\\.designcraft)$" }, 9),
    assign("craft-photo", { class = "^(ai\\.storyteller\\.photocraft|photocraft)$" }, 17),
    assign("craft-vector", { class = "^(ai\\.storyteller\\.vectorcraft)$" }, 18),
    assign("craft-light", { class = "^(ai\\.storyteller\\.lightcraft)$" }, 19),
    assign("craft-film", { class = "^(ai\\.storyteller\\.filmcraft)$" }, 21),
    assign("craft-effect", { class = "^(ai\\.storyteller\\.effectcraft)$" }, 22),
    assign("craft-ani", { class = "^(ai\\.storyteller\\.anicraft)$" }, 23),
    assign("craft-sound", { class = "^(ai\\.storyteller\\.soundcraft)$" }, 24),
    assign("craft-material",
        { class = "^(ai\\.storyteller\\.materialcraft|materialcraft|MaterialCraft)$" }, 26),
    assign("craft-texture",
        { class = "^(ai\\.storyteller\\.texturecraft|texturecraft|TextureCraft)$" }, 27),
    assign("craft-cad", { class = "^(ai\\.storyteller\\.cadcraft)$" }, 28),
    assign("craft-fig", { class = "^(ai\\.storyteller\\.figcraft)$" }, 29),

    -- 30: Playwright browser testing. The Playwright MCP server opens its own
    -- bundled Chromium (PLAYWRIGHT_MCP_BROWSER=chromium); no other Chromium
    -- is installed, so the class is Playwright's alone (unverified).
    assign("testing-playwright", { class = "^(chromium|Chromium|chromium-browser)$" }, 30),

    -- 31: the nix-config dev layout, Zed or Neovim (rust/dev-layout).
    --
    -- Zed has no --class flag, so every Zed window reports `dev.zed.Zed`; a
    -- class-only rule would drag every project's editor here. Zed's title is
    -- the project folder name, so class + title singles out this checkout.
    -- The Neovim variant is one Kitty window with a class of its own, so it
    -- needs no title. The 32-40 pool needs no rule here: dev-layout picks a
    -- free workspace at launch and registers a rule for it then.
    assign("nixcfg-editor", { class = "^(dev\\.zed\\.Zed)$", title = "^(nix-config)$" }, 31),
    assign("nixcfg-nvim", { class = "^(nixcfg-nvim)$" }, 31),

    -- 41: Replit (pkgs/replit-desktop.nix, the towers only; the laptops use
    -- replit.com in a browser, which stays on its browser's workspace). Its
    -- class is "replit" on native Wayland (hyprctl clients, 27/11/2026).
    -- The first of the 41-50 spares; overflow skips all of 41-50 anyway.
    assign("dev-replit", { class = "^(replit|Replit)$" }, 41),

    -- 42: scrcpy, the Android phone (or emulator) mirror. nixpkgs wraps the
    -- binary, so its Wayland app_id is ".scrcpy-wrapped" (hyprctl clients,
    -- 27/11/2026); plain "scrcpy" covers an unwrapped build.
    assign("dev-scrcpy", { class = "^(\\.scrcpy-wrapped|scrcpy)$" }, 42),

    -- Popups that belong to whatever you are doing: the Yazi file picker
    -- (xdg-desktop-portal-termfilechooser's kitty) and ripdrag's drag window.
    -- "unset" cancels the earlier catch-all, so they open on the CURRENT
    -- workspace, over the app that asked. Hyprland 0.56 handles the literal
    -- "unset" in Window.cpp (requestedWorkspace = ""). Floating and size are
    -- in 70-windowrules.lua.
    assign("popup-file-picker", { class = "^(termfilechooser)$" }, "unset"),
    assign("popup-ripdrag", { class = "^(it\\.catboy\\.ripdrag)$" }, "unset"),
}

-- ── Number keys ───────────────────────────────────────────────────────
--
-- Every workspace number bind fires from the numpad as well as the top row.
-- The numpad is bound by XKB keycode (evdev code + 8; `wev` shows them), not
-- keysym, because NumLock and SHIFT both turn KP_1 into KP_End and so on: a
-- keycode bind works either way.
M.numpadCodes = { 87, 88, 89, 83, 84, 85, 79, 80, 81, [0] = 90 }

-- The keys for digit n (0-9): the top-row key and its numpad twin. Bind (and
-- unbind) through this so the two can never drift apart.
function M.number_keys(n)
    return { tostring(n), "code:" .. M.numpadCodes[n] }
end

-- Register every assignment above as a window rule, named prefix-name.
function M.apply_workspace_assignments(prefix)
    for _, a in ipairs(M.workspaceAssignments) do
        hl.window_rule({
            name      = prefix .. "-" .. a.name,
            match     = a.match,

            workspace = a.workspace,
        })
    end
end

return M
