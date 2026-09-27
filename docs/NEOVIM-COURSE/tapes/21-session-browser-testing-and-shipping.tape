Source tapes/_shared/settings.tape
Output media/21-session-browser-testing-and-shipping/21-session-browser-testing-and-shipping.gif
Output media/21-session-browser-testing-and-shipping/21-session-browser-testing-and-shipping.mp4
Require nvim
Require uv
Require ruff
Require pyright
# toggleterm starts Neovim's 'shell', which defaults to $SHELL. /bin/sh has no
# rc file, so the terminal inside Neovim shows VHS's bare "> " prompt instead
# of your own zsh prompt, nothing lands in your zsh history, and direnv does
# not load the repository's flake.
Env SHELL "/bin/sh"
# claudecode.nvim writes its IDE lock file under $CLAUDE_CONFIG_DIR/ide: keep
# it in the throwaway folder, not in your ~/.claude. The tests are unaffected:
# tests/conftest.py sets CLAUDE_CONFIG_DIR itself for every test.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/21-session-browser-testing-and-shipping/claude"

# tapes/21-session-browser-testing-and-shipping.tape - Lesson 21: session-browser
# SB8. A Pilot test in Neovim, then the whole suite, ruff and pyright in the
# bottom terminal (Space t), and one test file re-run with :TermExec and %.
#
# Records examples/session-browser/SB8 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/21-session-browser-testing-and-shipping.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/21-session-browser-testing-and-shipping/ really holds the GIF,
# the MP4 and the four PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/session-browser/SB8 (a uv project, its
# snapshot baseline included) to
# /tmp/nvim-course/21-session-browser-testing-and-shipping/python/session-browser
# and works only there: `uv sync --frozen` creates the copy's own .venv from
# its uv.lock. It never runs --snapshot-update. If the copy or uv sync fails,
# the setup never prints READY and VHS stops with a Wait timeout.
#
# The worked example passes its suite, ruff and pyright; if one of them
# fails on your machine, the && chain below stops there and its Wait times
# out.
#
# PRIVACY: the tests never read your real sessions (tests/conftest.py points
# HOME and all three stores at temporary and fixture folders). A passing
# `pytest -q` prints no paths.
#
# Anchors: "READY" (the setup's own echo), "driven through Pilot"
# (test_app.py, line 1), "\d+ passed" (pytest's summary),
# "\d+ errors?, \d+ warnings?" (pyright's summary) and "16 passed"
# (test_app.py alone; a count the earlier runs never print).

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded). The example is copied relative to docs/NEOVIM-COURSE before the cd.
Hide
Type `L=/tmp/nvim-course/21-session-browser-testing-and-shipping && rm -rf "$L" && mkdir -p "$L/python" && cp -r examples/session-browser/SB8/. "$L/python/session-browser" && cd "$L/python/session-browser" && uv sync --frozen -q && clear && echo RE""ADY`
Enter
Wait+Screen@180s /READY/
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE tests/test_app.py"
Enter
Wait+Screen /driven through Pilot/
Sleep 2s
Type@10ms ":echo 'Lesson 21 - Pilot tests, then pytest, ruff and pyright without leaving Neovim'"
Enter
Show

Sleep 2s

# A Pilot test: a fake launcher, keys pressed through Pilot, then asserts on
# the Launch the app would have run.
Type "/def test_enter_resumes_claude"
Sleep 500ms
Enter
Sleep 500ms
Type "zt"
Sleep 2s
Screenshot media/21-session-browser-testing-and-shipping/pilot-test.png
Sleep 200ms
Sleep 1.5s

# Space t: the bottom terminal, in Terminal mode, in the project folder.
Type " t"
Sleep 2s
Type "uv run pytest -q"
Sleep 500ms
Enter
Wait+Screen@120s /\d+ passed/
Sleep 2.5s
Screenshot media/21-session-browser-testing-and-shipping/pytest.png
Sleep 200ms

# Lint, format check and types, with the system ruff and pyright.
Type "ruff check && ruff format --check && pyright"
Sleep 500ms
Enter
Wait+Screen@120s /\d+ errors?, \d+ warnings?/
Sleep 2.5s
Screenshot media/21-session-browser-testing-and-shipping/checks.png
Sleep 200ms

# Back to the test file: leave Terminal mode, then window up.
Ctrl+\
Sleep 300ms
Ctrl+n
Sleep 500ms
Ctrl+k
Sleep 1s

# Only this file, from the command line: % is the current file, and the
# cursor stays in the test file.
Type ':TermExec cmd="uv run pytest -q %"'
Sleep 800ms
Enter
Wait+Screen@120s /16 passed/
Sleep 2.5s
Screenshot media/21-session-browser-testing-and-shipping/termexec.png
Sleep 200ms
Sleep 1s

# --- Teardown (hidden). :qa! also ends the terminal's shell, and the clean
# quit lets claudecode.nvim remove its lock file.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 1s
Type "clear"
Enter
Sleep 300ms
