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
-- launched under. The layouts each tag their terminals so the workspace rules
-- can pin them, and a bare ^(kitty)$ match would have left those tagged
-- windows fully opaque — making the two dev layouts and the ws1 dashboard look
-- different from an ordinary terminal for no reason. The alternation therefore
-- lists them all:
--
--   kitty              plain terminal (SUPER + Return, and the pool layout's
--                      terminals if the launcher stops tagging them)
--   nixcfg-term        the workspace 2 nix-config layout's two terminals
--   devpool-term-3..6  the generic dev pool layout's terminals, one class per
--                      pool workspace, matched with the range [3-6]
--   ws1-keybinds       the dashboard's KEYBINDS.md viewer (laptop only)
--   ws1-monitor        the dashboard's htop pane (laptop only)
--
-- Kept RE2-compatible: alternation and a character class only, no lookaround
-- (see devices/laptop-intel.lua for what silently happens when a rule pattern
-- uses lookaround).
hl.window_rule({
    name  = "opacity-kitty",
    match = { class = "^(kitty|nixcfg-term|devpool-term-[3-6]|ws1-keybinds|ws1-monitor)$" },

    opacity = "0.95 0.95",
})

hl.window_rule({
    name  = "opacity-thunar",
    match = { class = "^(thunar)$" },

    opacity = "0.95 0.95",
})

-- ── Workspace Assignments ─────────────────────────────────────────────
--
-- Generated from vars.workspaceAssignments so the list lives in exactly one
-- place. devices/laptop-intel.lua re-registers the same set after its
-- default-workspace catch-all; see 00-vars.lua for why.

local vars = require("00-vars")

vars.apply_workspace_assignments("workspace")
