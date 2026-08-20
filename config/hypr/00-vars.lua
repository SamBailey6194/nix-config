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
--
-- SHAPE OF AN ENTRY
--
-- Each entry carries a full `match` table, passed straight through to
-- hl.window_rule, plus its own rule `name`. Earlier versions stored a bare
-- class string and built "^(" .. class .. ")$" here, which could only ever
-- express a class match — not enough for the nix-config editor below, which
-- needs class AND title. Writing the regexes out in full also keeps the
-- anchoring visible at the point of use.
--
-- WORKSPACE MAP (see devices/laptop-intel.lua for the full picture)
--
--   1     dashboard (laptop only)
--   2     nix-config dev layout           (reserved, assigned here)
--   3-6   generic dev pool                (rule registered at launch, not here)
--   7     browsers
--   8     Affinity Suite
--   9     comms
--   10    catch-all for everything else   (laptop only)
M.workspaceAssignments = {
    -- Browsers (workspace 7)
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
    {
        name      = "browser-zen",
        match     = { class = "^(zen-beta)$" },
        workspace = "7",
    },
    {
        name      = "browser-brave",
        match     = { class = "^(brave-browser)$" },
        workspace = "7",
    },
    {
        name      = "browser-librewolf",
        match     = { class = "^(librewolf)$" },
        workspace = "7",
    },
    {
        name      = "browser-firefox-devedition",
        match     = { class = "^(firefox-devedition)$" },
        workspace = "7",
    },

    -- Communication (workspace 9)
    {
        name      = "comms-teams-for-linux",
        match     = { class = "^(teams-for-linux)$" },
        workspace = "9",
    },
    {
        name      = "comms-zoom",
        match     = { class = "^(zoom)$" },
        workspace = "9",
    },
    {
        name      = "comms-discord",
        match     = { class = "^(discord)$" },
        workspace = "9",
    },

    -- Affinity Suite (workspace 8)
    {
        name      = "affinity-designer",
        match     = { class = "^(affinity-designer)$" },
        workspace = "8",
    },
    {
        name      = "affinity-photo",
        match     = { class = "^(affinity-photo)$" },
        workspace = "8",
    },
    {
        name      = "affinity-publisher",
        match     = { class = "^(affinity-publisher)$" },
        workspace = "8",
    },

    -- nix-config dev layout (workspace 2, reserved)
    --
    -- The editor is matched on class AND title together, which is why entries
    -- carry a whole `match` table rather than a bare class.
    --
    --   * Zed has no --class flag, so EVERY Zed window reports the same class
    --     `dev.zed.Zed`. A class-only rule would drag every project's editor
    --     onto ws2, including the generic dev-pool ones.
    --   * Zed's title is the project folder name, so the nix-config window
    --     reports the title `nix-config` exactly — verified live with
    --     `hyprctl clients`. Class + title is therefore the only way to single
    --     out this one editor.
    --   * The dots in dev.zed.Zed are RE2 metacharacters (any character), so
    --     they are escaped as \. — written "\\." in a normal Lua string, which
    --     RE2 finally sees as ^(dev\.zed\.Zed)$. Unescaped it would also match
    --     things like `devxzedxZed`; more importantly, escaping is what makes
    --     the intent obvious to the next reader.
    --
    -- The terminals are the easy half: kitty DOES support --class, so the
    -- nix-config layout launches them with `--class nixcfg-term` and a plain
    -- class match is enough.
    {
        name      = "nixcfg-editor",
        match     = { class = "^(dev\\.zed\\.Zed)$", title = "^(nix-config)$" },
        workspace = "2",
    },
    {
        name      = "nixcfg-term",
        match     = { class = "^(nixcfg-term)$" },
        workspace = "2",
    },
}

-- Register every assignment above as a window rule.
--
-- `prefix` disambiguates the rule names, since a device that re-registers the
-- set would otherwise collide with the names 70-windowrules.lua already used.
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
