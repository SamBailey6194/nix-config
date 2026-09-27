Source tapes/_shared/settings.tape
Output media/19-session-browser-filter-and-search/19-session-browser-filter-and-search.gif
Output media/19-session-browser-filter-and-search/19-session-browser-filter-and-search.mp4
Require nvim
Require uv
# The app shows times in local time; pin the zone lesson 18's table uses.
Env TZ "Europe/London"
# claudecode.nvim writes an IDE lock file under $CLAUDE_CONFIG_DIR/ide when
# Neovim starts. Keep it in a throwaway sibling of the copy, never in your
# ~/.claude. The app's command line sets CLAUDE_CONFIG_DIR to the fixture
# copy, which overrides this.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/19-session-browser-filter-and-search.claude"

# tapes/19-session-browser-filter-and-search.tape - Lesson 19: session-browser
# SB6. gd from SessionTable's base class into Textual's DataTable to read the
# action names it reuses, then the app at full size: l/h through the source
# tabs (wrapping both ways), j/k/G/g on the list, / and a live search, Esc back
# to the list.
#
# Records examples/session-browser/SB6 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/19-session-browser-filter-and-search.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/19-session-browser-filter-and-search/ really holds the GIF, the
# MP4 and the five PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/session-browser/SB6 (a uv project) to
# /tmp/nvim-course/19-session-browser-filter-and-search/python/session-browser
# and works only there: `uv sync --frozen` creates the copy's own .venv from
# its uv.lock. If the copy or uv sync fails, the setup never prints READY and
# VHS stops with a Wait timeout.
#
# PRIVACY: the app only ever sees a copy of fixtures/sessions/ (synthetic),
# through CLAUDE_CONFIG_DIR, CODEX_HOME and --kitty-sessions-dir on the
# visible command line, via $F. The Kitty fixtures get a fixed date so the
# order matches the lesson (a fresh copy is dated "now" and would sort
# first). Neovim's terminal is not used here.
#
# Counts the anchors rely on (fixtures/sessions/): All 9, Claude 4, Codex 3,
# Kitty 2; the search "panel" on All leaves 3. Other anchors:
# "RECENT_MESSAGES = " (app.py line 19), "_data_table" (the file gd opens),
# "scroll_bottom" (in DataTable's BINDINGS), "class SessionTable" (app.py).

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded). Everything that uses a relative path runs before the cd.
Hide
Type `L=/tmp/nvim-course/19-session-browser-filter-and-search && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/sessions/. "$L/sessions" && touch -d "2026-09-20 12:00:00 UTC" "$L"/sessions/kitty/*.kitty-session && export F="$L/sessions"`
Enter
Wait
# RE""ADY prints READY, but the typed line itself never matches /READY/.
Type `mkdir -p "$L/python" && cp -r examples/session-browser/SB6/. "$L/python/session-browser" && cd "$L/python/session-browser" && uv sync --frozen -q && clear && echo RE""ADY`
Enter
Wait+Screen@180s /READY/
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE src/session_browser/app.py"
Enter
Wait+Screen /RECENT_MESSAGES = /
# pyright attaches asynchronously. Block (hidden) until it has, so gd below is
# the LSP definition and not Neovim's built-in local search; then give it time
# to read Textual from the copy's .venv.
Type ":lua vim.wait(30000, function() return #vim.lsp.get_clients({ bufnr = 0, name = 'pyright' }) > 0 end)"
Enter
Sleep 5s
Type@10ms ":echo 'Lesson 19 - gd into DataTable for its action names, then tabs, search and Vim keys'"
Enter
Show

Sleep 1.5s

# Onto DataTable in "class SessionTable(DataTable):", then into Textual.
Type "/DataTable):"
Sleep 400ms
Enter
Sleep 1s
Type "gd"
Wait+Screen@60s /_data_table/
Sleep 800ms
# zt puts the class line at the top, so BINDINGS is in view below it.
Type "zt"
Wait+Screen /scroll_bottom/
Sleep 2s
Screenshot media/19-session-browser-filter-and-search/datatable-bindings.png
Sleep 200ms
# Back to app.py.
Ctrl+o
Wait+Screen /class SessionTable/
Sleep 1.5s

# --- Leave Neovim (hidden), cleanly, so claudecode.nvim removes its lock.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 1s
Type "clear"
Enter
Sleep 500ms
Show

# The app at full size, on the synthetic sessions.
Type@35ms "CLAUDE_CONFIG_DIR=$F/claude CODEX_HOME=$F/codex uv run session-browser --kitty-sessions-dir $F/kitty"
Sleep 600ms
Enter
Wait+Screen@60s /9 of 9 sessions/
Sleep 1.5s
Screenshot media/19-session-browser-filter-and-search/all.png
Sleep 200ms

# l: the next source tab.
Type "l"
Wait+Screen /4 of 9 sessions/
Sleep 1.5s
Screenshot media/19-session-browser-filter-and-search/claude-tab.png
Sleep 200ms
Type "l"
Wait+Screen /3 of 9 sessions/
Sleep 1s
Type "l"
Wait+Screen /2 of 9 sessions/
Sleep 1s
# Past Kitty, l wraps round to All; from All, h wraps back to Kitty.
Type "l"
Wait+Screen /9 of 9 sessions/
Sleep 1s
Type "h"
Wait+Screen /2 of 9 sessions/
Sleep 1s
Type "l"
Wait+Screen /9 of 9 sessions/
Sleep 1s

# j three times, G to the last row, g to the first, k stays at the top.
Type@500ms "jjj"
Sleep 800ms
Type "G"
Sleep 1.2s
Type "g"
Sleep 1.2s
Type "k"
Sleep 800ms

# / puts the cursor in the search box; the list filters as you type.
Type "/"
Sleep 800ms
Type@150ms "panel"
Wait+Screen /3 of 9 sessions/
Sleep 1.5s
Screenshot media/19-session-browser-filter-and-search/search.png
Sleep 200ms

# Esc: the list has its keys again (the search is kept). G to its last row.
Escape
Sleep 800ms
Type "G"
Sleep 1.2s
Screenshot media/19-session-browser-filter-and-search/filtered-list.png
Sleep 200ms

# q quits from the list.
Type "q"
Sleep 1.5s

# --- Teardown (hidden). Neovim was already quit above.
Hide
Type "clear"
Enter
Sleep 300ms
