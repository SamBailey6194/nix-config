Source tapes/_shared/settings.tape
Output media/25-fix-pyright-diagnostic-mode/25-fix-pyright-diagnostic-mode.gif
Output media/25-fix-pyright-diagnostic-mode/25-fix-pyright-diagnostic-mode.mp4
Require nvim

# tapes/25-fix-pyright-diagnostic-mode.tape - Lesson 25, step 6: pyright in
# workspace mode, verified. The settings Neovim sends pyright show
# diagnosticMode = "workspace"; Space x x (Trouble) lists the error in
# never_opened.py, a file that is never opened; :ls! shows it is a buffer only
# because pyright reported on it (unlisted, never loaded).
#
# RECORD THIS AFTER LESSON 25'S FIX, rebuilt and with Neovim restarted. On a
# config without it the first Wait (diagnosticMode = "workspace") fails and
# the run stops.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/25-fix-pyright-diagnostic-mode.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# Repository: never read or written. Fixture: fixtures/25-fix-pyright-
# diagnostic-mode/ (pyproject.toml, so the copy is pyright's root; opened.py,
# clean; never_opened.py, one type error), copied to
# /tmp/nvim-course/25-fix-pyright-diagnostic-mode. No venv, nothing installed:
# both Python files use the language only. pyright is the one the config pins;
# ruff also attaches to opened.py and has nothing to say.
#
# Timing: the hidden setup waits (vim.wait, up to 60 s) until pyright has
# published any diagnostic. opened.py is clean, so the first one is
# never_opened.py's, and it only arrives in workspace mode.
#
# Anchors: 'diagnosticMode = "workspace"' (the corrected key; the old config
# prints diagnosticsMode next to diagnosticMode = "openFilesOnly"),
# never_opened.py (only in Trouble and :ls!, never in opened.py or the caption),
# and 'line 0' in :ls! (a buffer that was never loaded).
#   - Space x x is typed in ONE Type at 60 ms per key: slower, and <leader>x
#     (close buffer) would fire after 'timeoutlen' (300 ms).

# claudecode.nvim starts its server on every Neovim start and writes an IDE
# lock file under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a
# throwaway sibling of the fixture copy so that no run, not even an aborted
# one, can leave a stale lock in your real ~/.claude. No terminal is opened
# and no register is shown, so no clipboard or shell-history guard is needed.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/25-fix-pyright-diagnostic-mode.claude"

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/25-fix-pyright-diagnostic-mode && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/25-fix-pyright-diagnostic-mode/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE opened.py"
Enter
Wait+Screen /The one file you open/
Sleep 1s
Type ":lua vim.wait(60000, function() return #vim.diagnostic.get() > 0 end, 250)"
Enter
Sleep 1s
Type@10ms ":echo 'Lesson 25 - after the fix: pyright reports on files you never opened'"
Enter
Show

Sleep 1.5s

# --- 1. The settings Neovim sends pyright ---------------------------------------
# Six lines of output, so Neovim waits at a hit-enter prompt.
Type ":lua =vim.lsp.config.pyright.settings.python.analysis"
Enter
Wait+Screen /diagnosticMode = "workspace"/
Sleep 2s
Screenshot media/25-fix-pyright-diagnostic-mode/settings.png
Sleep 200ms
# Enter dismisses the hit-enter prompt.
Enter
Sleep 1s

# --- 2. Trouble lists the file you never opened -----------------------------------
Type " xx"
Wait+Screen /never_opened\.py/
Sleep 2.5s
Screenshot media/25-fix-pyright-diagnostic-mode/trouble.png
Sleep 200ms

# --- 3. :ls! - a buffer only because pyright reported on it ----------------------
# Trouble opens without taking focus, so this runs from opened.py. u = unlisted;
# no a or h flag and "line 0" = never loaded.
Type ":ls!"
Enter
Wait+Screen /never_opened\.py" +line 0/
Sleep 2s
Screenshot media/25-fix-pyright-diagnostic-mode/ls.png
Sleep 200ms
Enter
Sleep 1s
# Space x x again closes Trouble.
Type " xx"
Sleep 1.5s

# --- Teardown (hidden). Quit cleanly so claudecode.nvim's VimLeavePre handler
# removes its lock file from the throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
