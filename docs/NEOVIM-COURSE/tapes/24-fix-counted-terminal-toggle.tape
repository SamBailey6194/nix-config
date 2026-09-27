Source tapes/_shared/settings.tape
Output media/24-fix-counted-terminal-toggle/24-fix-counted-terminal-toggle.gif
Output media/24-fix-counted-terminal-toggle/24-fix-counted-terminal-toggle.mp4
Require nvim

# tapes/24-fix-counted-terminal-toggle.tape - Lesson 24, step 6: the counted
# <leader>t verified. :verbose nmap <leader>t shows the new rhs; Space t opens
# terminal 1; 2 then Space shows the which-key popup with the count pending,
# and t opens terminal 2 beside terminal 1; :TermSelect lists both; a bare
# Space t still hides both and brings both back.
#
# RECORD THIS AFTER LESSON 24'S FIX, rebuilt and with Neovim restarted. On a
# config without it, the first Wait (the new description in :verbose nmap)
# fails and the run stops before any terminal is opened.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/24-fix-counted-terminal-toggle.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# Repository: never read or written. Fixture: fixtures/24-fix-counted-
# terminal-toggle/notes.md, copied to /tmp/nvim-course/24-fix-counted-
# terminal-toggle. A file argument skips the dock layout, so no terminal
# exists until Space t. Codex is never started.
#
# The terminals run $SHELL, which VHS inherits from the shell you start vhs
# from: on laptop-intel your zsh, showing your usual prompt with the fixture
# path. Only printf commands are typed into them.
#
# Anchors:
#   - "Toggle terminal \[count\]" is the new description, shown in the popup
#     and by :verbose nmap; the old config says "Toggle terminal (bottom)".
#   - TERMINAL / NORMAL are the status line's mode names (laststatus=3, so
#     there is one status line, for the current window). TERMINAL after
#     "2 Space t" proves terminal 2 opened: without the fix the dock closes
#     and the current window is notes.md in NORMAL mode. The keys are pressed
#     from inside terminal 1 (Normal mode), where a new terminal keeps
#     Terminal mode.
#   - term-one / term-two are the OUTPUT of printf '%s-%s\n' term one (and
#     term two); the typed command shows the words with a space.
#   - "Please select a terminal" is toggleterm's :TermSelect prompt.
# Ctrl+\ then Ctrl+n is sent with a 500 ms gap, as in tape 06.

# claudecode.nvim starts its server on every Neovim start and writes an IDE
# lock file under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at
# a throwaway sibling of the fixture copy so that no run, not even an aborted
# one, can leave a stale lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/24-fix-counted-terminal-toggle.claude"

# The two toggleterm terminals run your real zsh, and this tape types into
# them. Stop zsh-autosuggestions from drawing lines of your real shell history
# as grey text while it types.
Env ZSH_AUTOSUGGEST_HISTORY_IGNORE "*"

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/24-fix-counted-terminal-toggle && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/24-fix-counted-terminal-toggle/. "$L" && cd "$L" && clear`
Enter
Wait
# -i NONE keeps ShaDa out.
Type "nvim -i NONE notes.md"
Enter
Wait+Screen /Counted terminal toggle/
Sleep 1.5s
Type@10ms ":echo 'Lesson 24 - after the fix: a count before Space t picks the terminal'"
Enter
Show

Sleep 1.5s

# --- 1. The map ---------------------------------------------------------------
# Waiting for the new description, not just any map, stops the run here on
# a config without the fix.
Type ":verbose nmap <leader>t"
Enter
Wait+Screen /Toggle terminal \[count\]/
Sleep 2s
Screenshot media/24-fix-counted-terminal-toggle/verbose-leader-t.png
Sleep 200ms
# Enter dismisses the hit-enter prompt.
Enter
Sleep 1s

# --- 2. Space t: terminal 1 ---------------------------------------------------
# Opens across the bottom in Terminal mode (start_in_insert, neovim.nix:777).
Type " t"
Wait+Screen /TERMINAL/
# Give zsh time to read its rc files and draw the prompt.
Sleep 2.5s
Type `printf '%s-%s\n' term one`
Sleep 300ms
Enter
Wait+Screen /term-one/
Sleep 1s
# Leave Terminal mode and stay in terminal 1. (From notes.md, toggleterm's
# persist_mode would open terminal 2 in Normal mode: lesson 24, step 6.)
Ctrl+\
Sleep 500ms
Ctrl+n
Wait+Screen /NORMAL/
Sleep 800ms

# --- 3. 2, then Space, pause: the popup with a count pending --------------------
# which-key replays the count in front of the keys once t is pressed.
Type "2"
Sleep 300ms
Space
Wait+Screen /Toggle terminal \[count\]/
Sleep 1.5s
Screenshot media/24-fix-counted-terminal-toggle/count-popup.png
Sleep 200ms
# t: :2ToggleTerm. Terminal 2 opens beside terminal 1, in Terminal mode.
Type "t"
Wait+Screen /TERMINAL/
Sleep 2.5s
Type `printf '%s-%s\n' term two`
Sleep 300ms
Enter
Wait+Screen /term-two/
Sleep 1.5s
Screenshot media/24-fix-counted-terminal-toggle/two-terminals.png
Sleep 200ms

# --- 4. :TermSelect lists both -----------------------------------------------
Ctrl+\
Sleep 500ms
Ctrl+n
Wait+Screen /NORMAL/
Sleep 800ms
Type ":TermSelect"
Sleep 500ms
Enter
Wait+Screen /Please select a terminal/
Sleep 1.5s
Screenshot media/24-fix-counted-terminal-toggle/termselect.png
Sleep 200ms
# An empty Enter cancels the list.
Enter
Sleep 1.5s

# --- 5. A bare Space t is still the smart toggle -------------------------------
# Terminal 2 was left in Normal mode, so Space reaches Neovim: both terminals
# hide, then both come back.
Type " t"
Sleep 2s
Type " t"
Sleep 2.5s

# --- Teardown (hidden). Leave any Terminal mode first, then quit everything:
# :qa! ends both shells, and claudecode.nvim's VimLeavePre handler removes its
# lock file.
Hide
Ctrl+\
Sleep 500ms
Ctrl+n
Sleep 300ms
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
