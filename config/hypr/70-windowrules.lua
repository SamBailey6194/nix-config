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

hl.window_rule({
    name  = "float-rustdesk",
    match = { class = "^(org.rustdesk.rustdesk)$" },

    float = true,
})

-- ── Opacity Rules ─────────────────────────────────────────────────────
--
-- The `opacity` rule effect is a string-valued rule, parsed by the same
-- parser hyprlang used, so the original "<active> <inactive>" pair is kept
-- verbatim as a single string rather than split into two Lua fields.

hl.window_rule({
    name  = "opacity-kitty",
    match = { class = "^(kitty)$" },

    opacity = "0.95 0.95",
})

hl.window_rule({
    name  = "opacity-thunar",
    match = { class = "^(thunar)$" },

    opacity = "0.95 0.95",
})

-- ── Workspace Assignments ─────────────────────────────────────────────

-- Communication (workspace 9)

hl.window_rule({
    name  = "workspace-teams-for-linux",
    match = { class = "^(teams-for-linux)$" },

    workspace = "9",
})

hl.window_rule({
    name  = "workspace-zoom",
    match = { class = "^(zoom)$" },

    workspace = "9",
})

hl.window_rule({
    name  = "workspace-discord",
    match = { class = "^(discord)$" },

    workspace = "9",
})

-- Affinity Suite (workspace 4)

hl.window_rule({
    name  = "workspace-affinity-designer",
    match = { class = "^(affinity-designer)$" },

    workspace = "4",
})

hl.window_rule({
    name  = "workspace-affinity-photo",
    match = { class = "^(affinity-photo)$" },

    workspace = "4",
})

hl.window_rule({
    name  = "workspace-affinity-publisher",
    match = { class = "^(affinity-publisher)$" },

    workspace = "4",
})
