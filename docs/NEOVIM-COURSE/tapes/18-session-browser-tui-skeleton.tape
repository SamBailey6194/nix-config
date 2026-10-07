Source tapes/_shared/settings.tape
Output media/18-session-browser-tui-skeleton/18-session-browser-tui-skeleton.gif
Output media/18-session-browser-tui-skeleton/18-session-browser-tui-skeleton.mp4
Require nvim
Require uv
# toggleterm starts Neovim's 'shell', which defaults to $SHELL. /bin/sh reads
# no rc file, so the terminal inside Neovim shows a plain prompt instead of
# your own zsh prompt, and nothing lands in your zsh history.
Env SHELL "/bin/sh"
# The app shows times in local time; pin the zone the lesson's table uses.
Env TZ "Europe/London"
# ...and say where that zone lives. uv's Python runs on a glibc that looks
# for zones in /usr/share/zoneinfo, which NixOS does not have (its zones are
# in /etc/zoneinfo). Without TZDIR it cannot find Europe/London and silently
# shows UTC, an hour behind the lesson. VHS's bash reads no profile, so it
# cannot rely on TZDIR being exported. (With TZ unset, as in your own shell,
# glibc reads /etc/localtime and needs no TZDIR.) Neovim and its terminal
# inherit both lines.
Env TZDIR "/etc/zoneinfo"
# claudecode.nvim writes an IDE lock file under $CLAUDE_CONFIG_DIR/ide when
# Neovim starts. Keep it in a throwaway sibling of the copy, never in your
# ~/.claude. The app's own command lines set CLAUDE_CONFIG_DIR to the fixture
# copy, which overrides this.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/18-session-browser-tui-skeleton.claude"

# tapes/18-session-browser-tui-skeleton.tape - Lesson 18: session-browser SB5.
# app.py and app.tcss side by side (:vsplit, then the lesson's command for a
# reopened .tcss, `:setlocal filetype= syntax=css`), K on DataTable,
# the app in Neovim's bottom terminal via :TermExec ... go_back=0, then the app
# at full size: the list, the preview following the cursor, and "[/bold]"
# shown as text.
#
# Records examples/session-browser/SB5 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/18-session-browser-tui-skeleton.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/18-session-browser-tui-skeleton/ really holds the GIF, the MP4
# and the six PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/session-browser/SB5 (a uv project) to
# /tmp/nvim-course/18-session-browser-tui-skeleton/python/session-browser and
# works only there: `uv sync --frozen` creates the copy's own .venv from its
# uv.lock. If the copy or uv sync fails, the setup never prints READY and VHS
# stops with a Wait timeout.
#
# PRIVACY: the app only ever sees a copy of fixtures/sessions/ (synthetic),
# through CLAUDE_CONFIG_DIR, CODEX_HOME and --kitty-sessions-dir, all set on
# the visible command lines via $F. The Kitty fixtures get a fixed date so the
# list order matches the lesson (a fresh copy is dated "now" and would sort
# first). Your ~/.claude, ~/.codex and Kitty sessions are never read.
#
# Anchors: "RECENT_MESSAGES = " (app.py line 18, on the first screen),
# "border-left" (only in app.tcss), "class DataTable" (only in the K float),
# "9 sessions" (the app's header), "exit status 0" (only in echo's output).

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded). Everything that uses a relative path runs before the cd.
Hide
Type `L=/tmp/nvim-course/18-session-browser-tui-skeleton && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/sessions/. "$L/sessions" && touch -d "2026-09-20 12:00:00 UTC" "$L"/sessions/kitty/*.kitty-session && export F="$L/sessions"`
Enter
Wait
# RE""ADY prints READY, but the typed line itself never matches /READY/.
Type `mkdir -p "$L/python" && cp -r examples/session-browser/SB5/. "$L/python/session-browser" && cd "$L/python/session-browser" && uv sync --frozen -q && clear && echo RE""ADY`
Enter
Wait+Screen@180s /READY/
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE src/session_browser/app.py"
Enter
Wait+Screen /RECENT_MESSAGES = /
# pyright attaches asynchronously. Block (hidden) until it has, so K below is
# the LSP hover and not Neovim's keywordprg fallback; then give it time to
# read Textual from the copy's .venv.
Type ":lua vim.wait(30000, function() return #vim.lsp.get_clients({ bufnr = 0, name = 'pyright' }) > 0 end)"
Enter
Sleep 5s
Type@10ms ":echo 'Lesson 18 - code and stylesheet side by side, then the app on synthetic sessions'"
Enter
Show

Sleep 1.5s

# The stylesheet in a vertical split: splitright puts it on the right. .tcss
# has no filetype of its own, and this file is already saved, so Neovim
# guesses conf from the "#sessions" line. Step 3's gotcha for a reopened file:
# clear the filetype and borrow CSS colours, so the status line shows no
# filetype, as in the learner's new buffer. Nothing is typed into it.
Type ":vsplit src/session_browser/app.tcss"
Sleep 400ms
Enter
Wait+Screen /border-left/
Sleep 800ms
Type ":setlocal filetype= syntax=css"
Sleep 400ms
Enter
Sleep 1s
Screenshot media/18-session-browser-tui-skeleton/split.png
Sleep 200ms

# Back to app.py, onto DataTable in compose(), and hover.
Ctrl+h
Sleep 600ms
Type "/DataTable("
Sleep 400ms
Enter
Sleep 800ms
Type "K"
Wait+Screen@60s /class DataTable/
Sleep 1.5s
Screenshot media/18-session-browser-tui-skeleton/hover.png
Sleep 200ms
# Any cursor movement closes the float.
Type "j"
Sleep 800ms

# The app in the bottom terminal. go_back=0 leaves the cursor in the
# terminal, in Terminal mode, so the arrow keys reach the app. $F is expanded
# by Neovim (expandcmd) from the environment set up above.
Type@35ms `:TermExec cmd="CLAUDE_CONFIG_DIR=$F/claude CODEX_HOME=$F/codex uv run session-browser --kitty-sessions-dir $F/kitty" go_back=0`
Sleep 600ms
Enter
Wait+Screen@60s /9 sessions/
Sleep 1.5s
Down@600ms 2
Sleep 1s
Screenshot media/18-session-browser-tui-skeleton/termexec.png
Sleep 200ms
# q quits the app, not Neovim.
Type "q"
Sleep 2s

# --- Leave Neovim (hidden). Terminal mode first, then a clean quit so
# claudecode.nvim removes its lock file.
Hide
Ctrl+\
Sleep 500ms
Ctrl+n
Sleep 500ms
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 1s
Type "clear"
Enter
Sleep 500ms
Show

# The same command at full size, in VHS's own shell.
Type@35ms "CLAUDE_CONFIG_DIR=$F/claude CODEX_HOME=$F/codex uv run session-browser --kitty-sessions-dir $F/kitty"
Sleep 600ms
Enter
Wait+Screen@60s /9 sessions/
Sleep 1.5s
Screenshot media/18-session-browser-tui-skeleton/list.png
Sleep 200ms

# Three rows down: a Claude session with its conversation in the preview.
Down@600ms 3
Sleep 1.5s
Screenshot media/18-session-browser-tui-skeleton/preview.png
Sleep 200ms

# Five more: the last row, whose title contains "[/bold]", shown as text.
Down@400ms 5
Sleep 1.5s
Screenshot media/18-session-browser-tui-skeleton/markup.png
Sleep 200ms

Type "q"
Sleep 1.5s
Type `echo "exit status $?"`
Sleep 400ms
Enter
Wait+Screen /exit status 0/
Sleep 2s

# --- Teardown (hidden). Neovim was already quit above.
Hide
Type "clear"
Enter
Sleep 300ms
