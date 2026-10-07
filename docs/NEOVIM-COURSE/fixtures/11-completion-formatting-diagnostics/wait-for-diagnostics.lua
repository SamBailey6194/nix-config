-- fixtures/11-completion-formatting-diagnostics/wait-for-diagnostics.lua
--
-- Helper for tapes/11-completion-formatting-diagnostics.tape, not part of the
-- lesson. The tape copies this folder to
-- /tmp/nvim-course/11-completion-formatting-diagnostics/ and runs this file
-- with :source while recording is hidden, with kitty_demo.py as the current
-- buffer.
--
-- It waits until BOTH Python servers have published their first diagnostics
-- for the buffer, then echoes "diagnostics ready" for the tape to wait on:
--
--   ruff server:  "`sys` imported but unused"             (rule F401)
--   pyright:      'Operator "+" not supported for types'  (str + int)
--
-- ruff also reports PIE810 ("Call `startswith` once with a `tuple`") on the
-- long line; the tape does not wait on it, but it shows as a second W sign.
--
-- Matching on the messages rather than on each server's `source` name keeps
-- this independent of how either server labels itself. Nothing is written.

local buf = vim.api.nvim_get_current_buf()
local timer = assert(vim.uv.new_timer())
local done, ticks = false, 0

local function stop(text, hl)
  if done then
    return
  end
  done = true
  timer:stop()
  timer:close()
  vim.api.nvim_echo({ { text, hl or 'Normal' } }, false, {})
end

timer:start(250, 250, vim.schedule_wrap(function()
  if done then
    return
  end
  ticks = ticks + 1
  local ruff, pyright = false, false
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    if d.message:find('imported but unused', 1, true) then
      ruff = true
    end
    if d.message:find('not supported for types', 1, true) then
      pyright = true
    end
  end
  if ruff and pyright then
    stop('diagnostics ready')
  elseif ticks > 240 then -- 60 s
    stop('diagnostics not ready after 60 s', 'ErrorMsg')
  end
end))
