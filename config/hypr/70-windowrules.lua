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
-- launched under. The Neovim layouts tag their single Kitty window so the
-- workspace rules can pin it, and a bare ^(kitty)$ match would have left those
-- tagged windows fully opaque — making the dev layouts and the ws1 dashboard
-- look different from an ordinary terminal for no reason. The alternation
-- therefore lists them all (Zed layouts launch no Kitty windows):
--
--   kitty              plain terminal (SUPER + Return)
--   nixcfg-nvim        the workspace 31 Neovim layout: its one and only window,
--                      filling the workspace
--   devpool-nvim-N     a pool Neovim layout's single window, one class per
--                      pool workspace (32-40), so any number matches
--   ws1-keybinds       the dashboard's KEYBINDS.md viewer (laptop-intel)
--   ws1-monitor        the dashboard's btop pane
--   yazi               Yazi, the file manager (SUPER + F)
--   aerc               aerc, the mail client (SUPER + E)
--   aerc-keybinds      aerc's keybind sheet, beside it
--   termfilechooser    Yazi as an app's Open / Save dialog (the portal's kitty)
--
-- Kept RE2-compatible: alternation and a character class only, no lookaround
-- (see devices/laptop-intel.lua for what silently happens when a rule pattern
-- uses lookaround).
hl.window_rule({
    name  = "opacity-kitty",
    match = { class = "^(kitty|nixcfg-nvim|devpool-nvim-[0-9]+|ws1-keybinds|ws1-monitor|yazi|aerc|aerc-keybinds|termfilechooser)$" },

    opacity = "0.95 0.95",
})


-- ── File picker and drag popups ───────────────────────────────────────
--
-- Both open on the current workspace (their "unset" workspace rules live in
-- vars.workspaceAssignments, registered after the catch-all below). Here
-- they are only made to float.
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
-- The shared map in 00-vars.lua, registered for every device. Window rules
-- apply in registration order and the last match wins, so the order is:
--
--   1. a catch-all that parks EVERY window on a hidden special workspace
--   2. vars.workspaceAssignments, which send known apps to their workspace
--   3. (device file, required last) dashboard panes pinned to 1 and 2
--
-- A parked window is one with no workspace of its own; the window.open
-- handler below moves it on to the first free workspace from 51 up. A static
-- rule cannot name "the first free workspace", and parking first means the
-- window never flashes on whichever workspace happened to be active.

local vars = require("00-vars")

local holding = "unassigned"
hl.window_rule({
    name = "workspace-default-catch-all", match = { class = ".*" },
    workspace = "special:" .. holding .. " silent",
})

vars.apply_workspace_assignments("workspace")

-- ── Overflow: the first free workspace from 51 up ─────────────────────
--
-- Each new parked window takes the lowest 51+ workspace with no windows (or
-- not existing at all); follow = true takes focus there. Dialogs are the
-- exception: a floating window whose process already has a window on a
-- normal workspace joins it (the active workspace first), so a Save dialog or
-- Zed's project picker opens over the app that asked rather than on a
-- workspace of its own. Tiled windows always get a fresh workspace, so a
-- second Zed project does not pile onto the nix-config layout on 31.
-- 41-50 are keyed (60-keybinds.lua; 41 is Replit, 42-50 spares), so
-- overflow skips them even while they are empty.

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
    local id = vars.overflowFirst
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
hl.env("DEV_LAYOUT_NIX_CONFIG_WS", tostring(vars.devLayout.nixConfig))
hl.env("DEV_LAYOUT_POOL_FIRST", tostring(vars.devLayout.poolFirst))
hl.env("DEV_LAYOUT_POOL_LAST", tostring(vars.devLayout.poolLast))
