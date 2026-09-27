-- fixtures/10-lsp/wait-for-rust-analyzer.lua
--
-- Helper for tapes/10-lsp.tape, not part of the lesson. The tape copies this
-- file to /tmp/nvim-course/10-lsp/ and runs it with :source while recording
-- is hidden, with just-panel/src/justfile.rs (the worked example JP3, copied
-- to /tmp/nvim-course/10-lsp/rust) as the current buffer.
--
-- rust-analyzer loads the workspace before it can answer, and on a cold
-- start it also runs `cargo clippy` over it. That takes from seconds to
-- minutes, so a fixed Sleep would be a guess. Instead this:
--
--   1. asks rust-analyzer once a second for the hover of `Value` on the
--      `use serde_json::Value;` line, until the answer carries serde_json's
--      documentation ("Represents any valid JSON value.");
--   2. then waits until rust-analyzer has sent no progress report (indexing,
--      cargo clippy, ...) for 8 seconds, because a request made while it is
--      still busy can come back "content modified" and show nothing;
--   3. echoes "rust-analyzer ready", which the tape waits for.
--
-- It also defines NvimCourseWaitForDiagnostic(text), which echoes
-- "diagnostic arrived" once the current buffer has a diagnostic whose message
-- contains `text` (or whose code is E0004), for the tape's ]d step.
--
-- Nothing here writes a file.

local buf = vim.api.nvim_get_current_buf()
local QUIET_MS = 8000
local GIVE_UP_S = 600

local function echo(text, hl)
  vim.api.nvim_echo({ { text, hl or 'Normal' } }, false, {})
end

-- Where to hover: the `Value` in `use serde_json::Value;`.
local row, col
for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
  local start = line:find('use serde_json::Value;', 1, true)
  if start then
    row = i - 1
    col = start - 1 + #'use serde_json::'
    break
  end
end
if not row then
  echo('wait-for-rust-analyzer: no `use serde_json::Value;` line in this buffer', 'ErrorMsg')
  return
end

-- Every progress report from rust-analyzer moves this clock forward.
local last_progress = vim.uv.now()
local group = vim.api.nvim_create_augroup('NvimCourseWaitForRA', { clear = true })
vim.api.nvim_create_autocmd('LspProgress', {
  group = group,
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.name == 'rust_analyzer' then
      last_progress = vim.uv.now()
    end
  end,
})

local timer = assert(vim.uv.new_timer())
local finished, waiting, hover_ok, seconds = false, false, false, 0

local function finish(text, hl)
  if finished then
    return
  end
  finished = true
  timer:stop()
  timer:close()
  pcall(vim.api.nvim_del_augroup_by_id, group)
  echo(text, hl)
end

timer:start(1000, 1000, vim.schedule_wrap(function()
  if finished then
    return
  end
  seconds = seconds + 1
  if seconds > GIVE_UP_S then
    finish('rust-analyzer not ready after ' .. GIVE_UP_S .. ' s', 'ErrorMsg')
    return
  end
  if hover_ok then
    if vim.uv.now() - last_progress > QUIET_MS then
      finish('rust-analyzer ready')
    end
    return
  end
  if waiting then
    return
  end
  local client = vim.lsp.get_clients({ bufnr = buf, name = 'rust_analyzer' })[1]
  if not client then
    return
  end
  waiting = true
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = row, character = col },
  }
  client:request('textDocument/hover', params, function(err, result)
    waiting = false
    if finished or err or not result then
      return
    end
    if vim.inspect(result.contents):find('Represents any valid JSON value', 1, true) then
      hover_ok = true
    end
  end, buf)
end))

function _G.NvimCourseWaitForDiagnostic(text)
  local target = vim.api.nvim_get_current_buf()
  local poll = assert(vim.uv.new_timer())
  local done, ticks = false, 0
  local function stop(message, hl)
    if done then
      return
    end
    done = true
    poll:stop()
    poll:close()
    echo(message, hl)
  end
  poll:start(200, 200, vim.schedule_wrap(function()
    if done then
      return
    end
    ticks = ticks + 1
    for _, d in ipairs(vim.diagnostic.get(target)) do
      if d.code == 'E0004' or d.message:find(text, 1, true) then
        stop('diagnostic arrived')
        return
      end
    end
    if ticks > 300 then
      stop('no diagnostic after 60 s', 'ErrorMsg')
    end
  end))
end
