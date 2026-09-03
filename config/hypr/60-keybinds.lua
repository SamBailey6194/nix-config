-- Keybindings Configuration
-- Keyboard shortcuts for applications, window management, and workspaces
--
-- Translated from keybinds.conf (hyprlang) to the Hyprland 0.56 Lua config
-- provider. Behaviour is a faithful 1:1 port of the hyprlang bindings.

local vars = require("00-vars")
local mod = vars.mod

-- ── Applications ──────────────────────────────────────────────────────

-- Terminal
hl.bind(mod .. " + RETURN",         hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("kitty -e nvim"))

-- Launcher
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("wofi --show drun"))

-- Editor
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("zeditor -n"))

-- Dev layouts. Two variants, deliberately on separate keybinds:
--   SHIFT — the reserved nix-config layout, always built on workspace 2, so
--           this repository is only ever open in one known place.
--   CTRL  — a generic dev layout, placed on the next free workspace from the
--           3-6 dev pool, so several unrelated projects can be open at once.
--
-- CTRL goes through the `dev-layout-pick` wofi picker rather than calling
-- dev-layout directly. dev-layout needs a project PATH — the folder name is
-- Zed's window title, and that title is the only thing the placement rule can
-- match on. A keybind inherits Hyprland's working directory ($HOME), which is
-- not a project, so the path has to be chosen interactively.
hl.bind(mod .. " + SHIFT + Z", hl.dsp.exec_cmd("dev-layout"))
hl.bind(mod .. " + CTRL + Z",  hl.dsp.exec_cmd("dev-layout-pick"))

-- File manager
hl.bind(mod .. " + F", hl.dsp.exec_cmd("thunar"))

-- Web browsers
hl.bind(mod .. " + W",         hl.dsp.exec_cmd("zen-beta"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("brave"))
hl.bind(mod .. " + ALT + W",   hl.dsp.exec_cmd("librewolf"))
hl.bind(mod .. " + CTRL + W",  hl.dsp.exec_cmd("firefox-devedition"))

-- Communication
hl.bind(mod .. " + T", hl.dsp.exec_cmd("teams-for-linux"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("zoom"))

-- Remote desktop
hl.bind(mod .. " + R", hl.dsp.exec_cmd("rustdesk"))

-- System monitor
hl.bind(mod .. " + M", hl.dsp.exec_cmd("kitty -e htop"))

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
-- as the hyprlang config did.
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
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +5%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))

-- ── Mouse Bindings ────────────────────────────────────────────────────

-- SUPER + left-click drag: move/reposition tiled windows (drag to swap tile positions)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- SUPER + right-click drag: resize window
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
