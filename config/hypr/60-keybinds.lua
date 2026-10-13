-- Keybindings Configuration
-- Keyboard shortcuts for applications, window management, and workspaces
--
-- Translated from keybinds.conf (hyprlang) to the Hyprland 0.56 Lua config
-- provider. Behaviour is a faithful 1:1 port of the hyprlang bindings.

local vars = require("00-vars")
local mod = vars.mod

-- ── Applications ──────────────────────────────────────────────────────

-- Terminal, and the Neovim dev layouts.
--
-- The RETURN family mirrors the Z family below one-for-one, so the modifier
-- means the same thing in both: SHIFT is the reserved nix-config layout, CTRL
-- is the wofi picker onto the dev pool. RETURN is Neovim-in-Kitty, Z is Zed.
--
--   RETURN        a plain terminal
--   SHIFT+RETURN  nix-config layout, Neovim  (mirrors SHIFT + Z)
--   CTRL+RETURN   dev pool picker,  Neovim  (mirrors CTRL  + Z)
--   ALT+RETURN    a terminal that just runs nvim, with no layout at all
--
-- The mirror is in WHERE the layout goes, and both shapes are now a single
-- window filling the workspace: a Zed layout is Zed alone, and a Neovim layout
-- is ONE Kitty window, because the keybind reference, file tree, git panel and
-- shell all live inside Neovim (home/modules/neovim.nix builds them on a bare
-- start). See rust/dev-layout for the launcher.
--
-- ALT+RETURN is the escape hatch that used to live on SHIFT+RETURN: one nvim,
-- no workspace claimed, no window rule, so it lands wherever an ordinary
-- window would. "No layout" means no COMPOSITOR layout: it is still a bare
-- start, so Neovim builds its own panes inside the window just the same (the
-- git panel among them only inside a git work tree).
hl.bind(mod .. " + RETURN",         hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("dev-layout --nvim"))
hl.bind(mod .. " + CTRL + RETURN",  hl.dsp.exec_cmd("dev-layout-pick --nvim"))
hl.bind(mod .. " + ALT + RETURN",   hl.dsp.exec_cmd("kitty -e nvim"))

-- Launcher
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("wofi --show drun"))

-- Editor
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("zeditor -n"))

-- Dev layouts, Zed variants. The Neovim mirrors are on the RETURN family
-- above; both go through the same `dev-layout` binary, which takes --nvim.
--
-- Two variants, deliberately on separate keybinds:
--   SHIFT — the reserved nix-config layout, always built on workspace 2, so
--           this repository is only ever open in one known place.
--   CTRL  — a generic dev layout, placed on the next free workspace from the
--           3-5 dev pool, so several unrelated projects can be open at once.
--
-- CTRL goes through the `dev-layout-pick` wofi picker rather than calling
-- dev-layout directly. dev-layout needs a project PATH — the folder name is
-- Zed's window title, and that title is the only thing the placement rule can
-- match on. A keybind inherits Hyprland's working directory ($HOME), which is
-- not a project, so the path has to be chosen interactively.
hl.bind(mod .. " + SHIFT + Z", hl.dsp.exec_cmd("dev-layout"))
hl.bind(mod .. " + CTRL + Z",  hl.dsp.exec_cmd("dev-layout-pick"))

-- File managers: Yazi is the main one, Thunar the backup (SHIFT). Both land on
-- workspace 10 and take you there (vars.workspaceAssignments in 00-vars.lua).
-- Yazi runs in kitty with its own `yazi` class so the rule can tell it apart
-- from an ordinary terminal; inside it, F1 opens its keybind sheet. Configured
-- in home/modules/file-manager.nix.
hl.bind(mod .. " + F",         hl.dsp.exec_cmd("kitty --class yazi yazi"))
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd("thunar"))

-- Web browsers
hl.bind(mod .. " + W",         hl.dsp.exec_cmd("zen-beta"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("brave"))
hl.bind(mod .. " + ALT + W",   hl.dsp.exec_cmd("librewolf"))
hl.bind(mod .. " + CTRL + W",  hl.dsp.exec_cmd("firefox-devedition"))

-- Mail, on workspace vars.mailWorkspace: 6 by default (00-vars.lua pins all
-- three windows there), 4 on devtower-intel (devices/devtower-intel.lua).
--
--   E        aerc, the default (home/modules/aerc.nix), with its keybind
--            sheet beside it: aerc first (left, or top on a portrait
--            monitor), the sheet second
--   SHIFT+E  Claws Mail, the GUI backup (home/modules/email.nix)
--
-- E works like the laptop's ws1 dashboard (devices/laptop-intel.lua, which
-- explains the API and the reasoning in full): it focuses the mail workspace and
-- makes sure each pane exists exactly once - left alone if it is there,
-- brought back if it was moved away, launched if it is not open. So a second
-- press never starts a second aerc, and reopens the sheet after `q` closed it.
--
-- Launch order does not decide the side a tile lands on (dwindle puts it on
-- the side the mouse is on), so the panes are swapped afterwards if the sheet
-- came out first. Only two tiled panes are swapped; a swap would trade the
-- floating state of a floated pane.
-- Looked up on every call rather than captured here: the device file that
-- overrides vars.mailWorkspace is required after this one.
local function mail_ws()
    return vars.mailWorkspace or 6
end

local MAIL = {
    { class = "aerc",          cmd = "kitty --class aerc -e aerc" },
    { class = "aerc-keybinds", cmd = "kitty --class aerc-keybinds -e less ~/.config/aerc/KEYBINDS.md" },
}

local mail_pending = {}

local function mail_find(class)
    return hl.get_windows({ class = class })[1]
end

local function on_mail_ws(w)
    local ws = w and w.workspace
    return ws ~= nil and ws.id == mail_ws()
end

-- `fullscreen` is an integer mode, and 0 is truthy in Lua, so compare it.
local function mail_tiled(w)
    return not w.floating and w.fullscreen == 0
end

-- aerc before the sheet: left of it side by side, above it when stacked.
-- The order is strict (x first, then y) so one swap always settles it: with
-- a third window on the mail workspace (Claws) the two can sit diagonally, and "x OR y
-- greater" would then swap them back and forth on every press.
local function mail_enforce_order()
    local client, sheet = mail_find("aerc"), mail_find("aerc-keybinds")
    if on_mail_ws(client) and on_mail_ws(sheet)
        and mail_tiled(client) and mail_tiled(sheet)
        and (client.at.x > sheet.at.x
             or (client.at.x == sheet.at.x and client.at.y > sheet.at.y)) then
        hl.dispatch(hl.dsp.window.swap({ window = client, target = sheet }))
    end
end

local function mail_layout()
    local ws     = mail_ws()
    local active = hl.get_active_workspace()
    if not active or active.id ~= ws then
        hl.dispatch(hl.dsp.focus({ workspace = ws }))
    end

    for _, pane in ipairs(MAIL) do
        local cls = pane.class
        local w   = mail_find(cls)
        if w then
            if not on_mail_ws(w) then
                hl.dispatch(hl.dsp.window.move({ window = w, workspace = ws, follow = false }))
            end
        elseif not mail_pending[cls] then
            local token = {}
            mail_pending[cls] = token
            hl.exec_cmd(pane.cmd)
            hl.timer(function()
                if mail_pending[cls] == token then mail_pending[cls] = nil end
            end, { timeout = 5000, type = "oneshot" })
        end
    end

    mail_enforce_order()
end

hl.on("window.open", function(w)
    local cls = w.class
    if cls == "aerc" or cls == "aerc-keybinds" then
        mail_pending[cls] = nil
        mail_enforce_order()
    end
end)

hl.bind(mod .. " + E", mail_layout,
    { description = "Mail: aerc + keybind sheet, reopen any missing pane" })
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("claws-mail"))

-- Communication
hl.bind(mod .. " + T", hl.dsp.exec_cmd("teams-for-linux"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("zoom"))

-- Remote desktop
hl.bind(mod .. " + R", hl.dsp.exec_cmd("rustdesk"))

-- System monitor: btop is the main one, htop the backup (SHIFT) for when btop
-- cannot draw. Both are installed and btop configured in
-- home/modules/system-monitor.nix.
hl.bind(mod .. " + M",         hl.dsp.exec_cmd("kitty -e btop"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("kitty -e htop"))

-- Keybinds help
hl.bind(mod .. " + slash", hl.dsp.exec_cmd("kitty -e less ~/.config/hypr/KEYBINDS.md"))

-- Affinity Suite (Wine/Bottles)
-- TODO: Update these commands to match your Wine/Bottles setup.
-- Examples:
--   bottles -b "Affinity Designer 2"
--   wine ~/.wine/drive_c/.../Designer.exe
--   flatpak run com.usebottles.bottles -b AffinityDesigner
hl.bind(mod .. " + D", hl.dsp.exec_cmd("affinity-designer"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("affinity-photo"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("affinity-publisher"))

-- ── Window Management ─────────────────────────────────────────────────

hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F11",       hl.dsp.window.fullscreen())
-- dwindle: toggle split direction (0.55: togglesplit moved under layoutmsg)
hl.bind(mod .. " + grave", hl.dsp.layout("togglesplit"))

-- ── Session Control ────────────────────────────────────────────
--
-- Lock, sleep and log out, all grouped under SUPER + CTRL so the three
-- session actions share one modifier and none of them sit next to a
-- destructive neighbour. Every one of them requires the password again:
--
--   lock   hyprlock, with grace 0 (the CLI default since 0.9.6)
--   sleep  locks BEFORE suspending - see the lock-and-suspend wrapper in
--          home/modules/hyprland.nix, which refuses to suspend if the lock
--          did not come up
--   exit   drops to greetd/tuigreet, which asks for the password anyway
--
-- Note SUPER + SHIFT + Q above is the pre-existing exit bind and still works.
-- It is kept for muscle memory, but it lives one SHIFT away from
-- SUPER + Q (close window), so SUPER + CTRL + Q is the safer one to learn.
--
-- Lock is deliberately routed through loginctl rather than calling hyprlock
-- directly: that is the same D-Bus path suspend uses, so if the keybind works
-- the suspend path works too, and hypridle stays the single owner of the
-- "is something already locking?" question (its lock_cmd is
-- `pidof hyprlock || hyprlock`, so this cannot stack two lock screens).

hl.bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("lock-and-suspend"))
hl.bind(mod .. " + CTRL + Q", hl.dsp.exit())

-- ── Focus Navigation ──────────────────────────────────────────────────

-- Vim-style
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Arrow keys
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- ── Move Windows ──────────────────────────────────────────────────────

-- Vim-style
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Arrow keys
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- ── Workspace Navigation ─────────────────────────────────────────────

-- Switch workspaces with mod + [0-9], and move the active window to a
-- workspace with mod + SHIFT + [0-9]. Key 0 maps to workspace 10, exactly
-- as the hyprlang config did. devtower-intel replaces the SHIFT half with
-- workspaces 11-20 and moves windows through a submap instead
-- (devices/devtower-intel.lua). hl.unbind matches on these key strings
-- (spaces and case ignored), so keep the two files' spellings in step.
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ── Screenshots ───────────────────────────────────────────────────────

-- Region select (slurp) then annotate in swappy; full screen with mod held.
hl.bind("Print",             hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(mod .. " + Print",   hl.dsp.exec_cmd('grim - | swappy -f -'))

-- ── Media / Hardware Keys ─────────────────────────────────────────────

-- NOTE: these are plain binds (no `locked` / `repeating` options), matching
-- the previous hyprlang config exactly. The Hyprland 0.56 sample config marks
-- the equivalent binds `{ locked = true, repeating = true }` so they keep
-- working on the lock screen and auto-repeat when held; adopt that only as a
-- deliberate behaviour change.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
-- Keyboard fallback for the SteelSeries volume roller, which misses turns.
-- Repeats while held, unlike the media keys above.
hl.bind(mod .. " + equal", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind(mod .. " + minus", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +5%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))

-- ── Mouse Bindings ────────────────────────────────────────────────────

-- SUPER + left-click drag: move/reposition tiled windows (drag to swap tile positions)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- SUPER + right-click drag: resize window
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
