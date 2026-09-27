Source tapes/_shared/settings.tape
Output media/11-completion-formatting-diagnostics/11-completion-formatting-diagnostics.gif
Output media/11-completion-formatting-diagnostics/11-completion-formatting-diagnostics.mp4
Require nvim
Require ruff

# claudecode.nvim starts its server on every Neovim start (auto_start = true,
# home/modules/neovim.nix:830-833) and writes an IDE lock file under
# $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a throwaway
# sibling of the fixture copy so no run can leave a lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/11-completion-formatting-diagnostics.claude"

# tapes/11-completion-formatting-diagnostics.tape - Lesson 11: the nvim-cmp
# menu (<C-n> to move, <C-e> to back out), format on save with ruff, and the
# Trouble list (Space x x, <C-j> into it, } and Enter to jump).
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/11-completion-formatting-diagnostics.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# No shell is typed into on camera: the only shell is VHS's own bash (Set
# Shell), used by the hidden setup, and no Neovim terminal is opened.
#
# Deterministic and private: fixtures/11-completion-formatting-diagnostics/ is
# copied to /tmp/nvim-course/11-completion-formatting-diagnostics and edited
# THERE. It is a tiny standard-library-only Python project: pyproject.toml
# marks the root for pyright and ruff, and kitty_demo.py is deliberately
# untidy (single quotes, one 100-column line), imports `sys` without using it
# (ruff F401) and adds an int to a str (a pyright error). Saving that copy is
# the formatting demo; no file in the repo is written. It never reads the
# capstones or the worked examples either, so it records the same at any
# point in the course.
#
# Needs pyright (pinned in neovim.nix) and `ruff` on PATH (conform's
# ruff_format; system package from modules/software/development.nix). No venv.
#
# Timing rules:
#   - wait-for-diagnostics.lua echoes "diagnostics ready" once ruff AND
#     pyright have published for the buffer (both are needed for Trouble).
#   - Anchors: read_bytes appears only in the completion menu; ".kitty-session"
#     in double quotes only after the formatter ran; "imported but unused"
#     only in the Trouble list (virtual text is off).
#   - Space x x is typed in ONE Type at 60 ms per key. Slower, and <leader>x
#     (close buffer) fires after 'timeoutlen' (300 ms).
#   - The menu is never confirmed: <CR> would accept the first item, whatever
#     it is. <C-e> puts back what was typed, and u removes the line.

# --- Setup (hidden) --------------------------------------------------------
Hide
Type `L=/tmp/nvim-course/11-completion-formatting-diagnostics && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/11-completion-formatting-diagnostics/. "$L" && cd "$L" && clear`
Enter
Wait
Type "nvim -i NONE kitty_demo.py"
Enter
Wait+Screen /first draft of a Kitty session reader/
Sleep 1s
Type ":source /tmp/nvim-course/11-completion-formatting-diagnostics/wait-for-diagnostics.lua"
Enter
Wait+Screen@60s /diagnostics ready/
Sleep 500ms
Type@10ms ":echo 'Lesson 11 - the completion menu, <C-e>, format on save, Trouble'"
Enter
Show

Sleep 2s
Screenshot media/11-completion-formatting-diagnostics/start.png
Sleep 200ms

# --- 1. The completion menu --------------------------------------------------
# Open a line below `lines = path...` and type a method prefix: pyright
# offers read_text and read_bytes.
Type "/lines = path"
Enter
Sleep 800ms
Type "o"
Sleep 400ms
Type "path.read_"
Wait+Screen@30s /read_bytes/
Sleep 2s
Screenshot media/11-completion-formatting-diagnostics/completion.png
Sleep 200ms
# <C-n> twice: each press selects the next item AND inserts its text.
Ctrl+N
Sleep 1.2s
Ctrl+N
Sleep 1.2s
# <C-e>: close the menu and put back exactly what was typed.
Ctrl+E
Sleep 1.5s
Escape
Sleep 300ms
# u removes the whole line opened with o.
Type "u"
Sleep 1s
# Space h: clear the search highlight (<leader>h).
Type " h"
Sleep 800ms

# --- 2. Format on save --------------------------------------------------------
# <C-s> is the config's Normal-mode save (:w). conform runs ruff format first.
Ctrl+S
Wait+Screen /"\.kitty-session"/
Sleep 2.5s
Screenshot media/11-completion-formatting-diagnostics/formatted.png
Sleep 200ms

# --- 3. Trouble ---------------------------------------------------------------
Type " xx"
Wait+Screen /imported but unused/
Sleep 2.5s
Screenshot media/11-completion-formatting-diagnostics/trouble.png
Sleep 200ms
# Trouble opens without taking focus: <C-j> (window down) goes into it.
Ctrl+J
Sleep 1s
# } moves to the next item, Enter jumps to it in the file.
Type "}"
Sleep 1.2s
Enter
Sleep 2s
# Space x x again closes the list.
Type " xx"
Sleep 1.5s

# --- Teardown (hidden) ------------------------------------------------------
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
