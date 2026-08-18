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

return M
