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
--   3-5   generic dev pool                (rule registered at launch, not here)
--   6     mail (Claws Mail)               (assigned here)
--   7     browsers
--   8     Affinity Suite
--   9     comms
--   10    file managers (assigned here); catch-all for everything else
--         on laptop-intel and devtower-intel
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

    -- Mail (workspace 6)
    --
    -- Claws Mail gets a fixed home for the same reason the browsers and comms
    -- do: it is a long-running window you want to find in a known place. The
    -- generic dev pool was narrowed from 3-6 to 3-5 to free this workspace
    -- (rust/dev-layout, DEFAULT_POOL_LAST) - otherwise a dev layout could be
    -- built straight on top of the mail client.
    --
    -- The class is unverified: claws-mail's .desktop file sets no
    -- StartupWMClass, so GTK derives WM_CLASS from the binary name. Confirm
    -- with `hyprctl clients | grep -i claws` on first launch and correct this
    -- if it differs - a wrong class here fails silently, exactly like the
    -- brave/brave-browser case documented above.
    {
        name      = "mail-claws",
        match     = { class = "^(claws-mail)$" },
        workspace = "6",
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

    -- File managers (workspace 10)
    --
    -- SUPER + F opens Yazi in kitty with the `yazi` class; SUPER + SHIFT + F
    -- opens Thunar. On laptop-intel and devtower-intel the catch-all already
    -- sends them to 10, but the laptop's is "10 silent" — the window would
    -- open out of sight. These rules are not silent, so you follow it there.
    -- udiskie's "browse" action launches the same `yazi` class.
    --
    -- Files opened FROM a file manager need nothing here: each app's window
    -- is placed by its own rule (browsers to 7, mail to 6, ...) or, with
    -- none, by the device catch-all — i.e. 10, next to the file manager.
    {
        name      = "files-yazi",
        match     = { class = "^(yazi)$" },
        workspace = "10",
    },
    {
        name      = "files-thunar",
        match     = { class = "^(thunar)$" },
        workspace = "10",
    },

    -- Popups that belong to whatever you are doing: the Yazi file picker
    -- (xdg-desktop-portal-termfilechooser's kitty) and ripdrag's drag window.
    -- "unset" cancels any earlier workspace rule, so they open on the CURRENT
    -- workspace, over the app that asked for them, instead of being thrown
    -- to 10 by the catch-all. Hyprland 0.56 handles the literal "unset" in
    -- Window.cpp (requestedWorkspace = ""). Floating and size are in
    -- 70-windowrules.lua.
    {
        name      = "popup-file-picker",
        match     = { class = "^(termfilechooser)$" },
        workspace = "unset",
    },
    {
        name      = "popup-ripdrag",
        match     = { class = "^(it\\.catboy\\.ripdrag)$" },
        workspace = "unset",
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
    -- The Zed layout's two terminals are the easy half: kitty DOES support
    -- --class, so the nix-config layout launches them with
    -- `--class nixcfg-term` and a plain class match is enough. Only the Zed
    -- layout has them; the Neovim one below is a single window.
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

    -- The Neovim variant of the same layout (SUPER + SHIFT + RETURN), which
    -- shares workspace 2 with the Zed one: dev-layout refuses to build a
    -- second layout there and focuses the existing one instead.
    --
    -- This one rule places the WHOLE Neovim layout: it is a single Kitty
    -- window filling the workspace, with the keybind reference, file tree,
    -- git panel and shell as panes and tabs inside Neovim, so there are no
    -- nixcfg-term windows to go with it.
    --
    -- Note how much smaller this rule is than nixcfg-editor above. Neovim runs
    -- inside Kitty and Kitty supports --class, so there is no title clause and
    -- no dependency on the checkout still being called "nix-config".
    {
        name      = "nixcfg-nvim",
        match     = { class = "^(nixcfg-nvim)$" },
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
