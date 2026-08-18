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

-- ── Workspace assignments ─────────────────────────────────────────────
--
-- Single source of truth for "this app always opens on that workspace".
-- 70-windowrules.lua registers these for every device. A device that also
-- wants a default-workspace catch-all (see devices/laptop-intel.lua) has to
-- re-register them AFTERWARDS, because window rules are applied in
-- registration order and the last matching rule wins — so a later catch-all
-- would otherwise clobber them.
--
-- Keeping the list here means it is written once. Under hyprlang it had to be
-- duplicated by hand into the device catch-all's regex, which is exactly the
-- maintenance trap that made the old rule wrong.
M.workspaceAssignments = {
    -- Browsers (workspace 3)
    --
    -- These are the only four browsers this config installs; regular Firefox,
    -- Google Chrome and Chromium were removed. Zen is the default handler
    -- (see home/modules/browsers.nix).
    --
    -- The class strings are each device's StartupWMClass, not the command
    -- name. Zen, LibreWolf and Firefox Developer Edition pass `--name <x>` in
    -- their .desktop Exec so class == command, but Brave's binary is `brave`
    -- while its window class is `brave-browser` — verified live with
    -- `hyprctl clients`. Get one of these wrong and the rule silently never
    -- matches, exactly like the old lookahead catch-all did.
    { class = "zen-beta",          workspace = "3" },
    { class = "brave-browser",     workspace = "3" },
    { class = "librewolf",         workspace = "3" },
    { class = "firefox-devedition", workspace = "3" },
    -- Communication
    { class = "teams-for-linux",   workspace = "9" },
    { class = "zoom",              workspace = "9" },
    { class = "discord",           workspace = "9" },
    -- Affinity Suite
    { class = "affinity-designer",  workspace = "4" },
    { class = "affinity-photo",     workspace = "4" },
    { class = "affinity-publisher", workspace = "4" },
}

-- Register every assignment above as a window rule.
--
-- `prefix` disambiguates the rule names, since a device that re-registers the
-- set would otherwise collide with the names 70-windowrules.lua already used.
function M.apply_workspace_assignments(prefix)
    for _, a in ipairs(M.workspaceAssignments) do
        hl.window_rule({
            name      = prefix .. "-" .. a.class,
            match     = { class = "^(" .. a.class .. ")$" },

            workspace = a.workspace,
        })
    end
end

return M
