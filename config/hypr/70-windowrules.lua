-- Window Rules Configuration
-- Floating, opacity, and workspace rules for specific applications
--
-- Translated from windowrules.conf (hyprlang) to the Hyprland 0.56 Lua config
-- provider. Each `windowrule = match:class ^(x)$, <prop>` line becomes one
-- hl.window_rule({ ... }) call. Every rule is given a unique, descriptive
-- `name` so it can be identified in `hyprctl` output and toggled at runtime
-- via the returned handle's :set_enabled().

-- ── Float Rules ───────────────────────────────────────────────────────

hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },

    float = true,
})

hl.window_rule({
    name  = "float-qpwgraph",
    match = { class = "^(qpwgraph)$" },

    float = true,
})

hl.window_rule({
    name  = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },

    float = true,
})

hl.window_rule({
    name  = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },

    float = true,
})

-- RustDesk's class is a reverse-DNS string, so the dots are escaped for the
-- same reason 00-vars.lua escapes them in `dev.zed.Zed`: an unescaped `.` is
-- an RE2 metacharacter matching any character, so the pattern would also fire
-- on e.g. `orgxrustdeskxrustdesk`. Written "\\." in a Lua string, which RE2
-- sees as ^(org\.rustdesk\.rustdesk)$.
hl.window_rule({
    name  = "float-rustdesk",
    match = { class = "^(org\\.rustdesk\\.rustdesk)$" },

    float = true,
})

-- ── Opacity Rules ─────────────────────────────────────────────────────
--
-- The `opacity` rule effect is a string-valued rule, parsed by the same
-- parser hyprlang used, so the original "<active> <inactive>" pair is kept
-- verbatim as a single string rather than split into two Lua fields.

-- Every kitty window gets the same 0.95 opacity, whatever class it was
-- launched under. The layouts each tag their Kitty windows (Zed's terminals,
-- or the single Neovim window) so the workspace rules can pin them, and a
-- bare ^(kitty)$ match would have left those tagged windows fully opaque —
-- making the two dev layouts and the ws1 dashboard look different from an
-- ordinary terminal for no reason. The alternation therefore lists them all:
--
--   kitty              plain terminal (SUPER + Return, and the pool layout's
--                      terminals if the launcher stops tagging them)
--   nixcfg-term        the workspace 2 Zed layout's two terminals (a Neovim
--                      layout has none)
--   nixcfg-nvim        the workspace 2 Neovim layout: its one and only window,
--                      filling the workspace
--   devpool-term-3..5  a Zed pool layout's terminals, one class per pool
--                      workspace, matched with the range [3-5]
--   devpool-nvim-3..5  the same, for a pool Neovim layout's single window
--   ws1-keybinds       the dashboard's KEYBINDS.md viewer (laptop only)
--   ws1-monitor        the dashboard's btop pane (laptop only)
--   yazi               Yazi, the file manager (SUPER + F)
--   termfilechooser    Yazi as an app's Open / Save dialog (the portal's kitty)
--
-- Kept RE2-compatible: alternation and a character class only, no lookaround
-- (see devices/laptop-intel.lua for what silently happens when a rule pattern
-- uses lookaround).
hl.window_rule({
    name  = "opacity-kitty",
    match = { class = "^(kitty|nixcfg-term|nixcfg-nvim|devpool-term-[3-5]|devpool-nvim-[3-5]|ws1-keybinds|ws1-monitor|yazi|termfilechooser)$" },

    opacity = "0.95 0.95",
})

hl.window_rule({
    name  = "opacity-thunar",
    match = { class = "^(thunar)$" },

    opacity = "0.95 0.95",
})

-- ── File picker and drag popups ───────────────────────────────────────
--
-- Both open on the current workspace (their "unset" workspace rules live in
-- vars.workspaceAssignments, so they are re-asserted after a device
-- catch-all). Here they are only made to float.
--
-- termfilechooser: the Yazi "Open / Save file" dialog, a kitty window that
-- xdg-desktop-portal-termfilechooser starts with this class
-- (home/modules/file-manager.nix). Floated and centred over the app that
-- asked, at a size that still shows Yazi's three columns. `center` must come
-- with `size`: it positions against the final size.
hl.window_rule({
    name  = "float-file-picker",
    match = { class = "^(termfilechooser)$" },

    float  = true,
    size   = { "monitor_w*0.6", "monitor_h*0.65" },
    center = true,
})

-- ripdrag (ALT + d in Yazi): a small GTK 4 window holding the files to drag.
-- Pinned so it stays visible while you switch workspace to the drop target.
hl.window_rule({
    name  = "float-ripdrag",
    match = { class = "^(it\\.catboy\\.ripdrag)$" },

    float = true,
    pin   = true,
})

-- ── Workspace Assignments ─────────────────────────────────────────────
--
-- Generated from vars.workspaceAssignments so the list lives in exactly one
-- place. devices/laptop-intel.lua re-registers the same set after its
-- default-workspace catch-all; see 00-vars.lua for why.

local vars = require("00-vars")

vars.apply_workspace_assignments("workspace")
