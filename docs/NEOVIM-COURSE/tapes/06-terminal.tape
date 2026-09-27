Source tapes/_shared/settings.tape
Output media/06-terminal/06-terminal.gif
Output media/06-terminal/06-terminal.mp4
Require nvim

# tapes/06-terminal.tape - Lesson 06: the toggleterm dock. Space t opens
# terminal 1 and a command runs in it; Ctrl+\ Ctrl+n leaves Terminal mode;
# gg scrolls the output in Normal mode; Ctrl+K / Ctrl+J move between the
# file and the terminal; :2ToggleTerm opens a second terminal beside the
# first; :TermSelect picks between them; Space t hides and restores both.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/06-terminal.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B). Afterwards,
# check that media/06-terminal/ holds the GIF, the MP4 and all five PNGs.
#
# Repository: this tape neither reads nor writes the repo, so it can be
# recorded at any milestone. Everything happens in a throwaway copy of
# fixtures/06-terminal/ at /tmp/nvim-course/06-terminal.
#
# Deterministic by design: one Markdown file (no language server attaches),
# no tree (a file argument skips the dock layout), no AI tool. The terminals
# run $SHELL, which VHS inherits from the shell you start vhs from: on
# laptop-intel your zsh, showing your usual prompt with the fixture path.
# The fixture has no .envrc, so direnv loads nothing.
#
# Anchors (Appendix B, "Tape conventions"):
#   - TERMINAL / NORMAL are the status line's mode names.
#   - dock-one and term-two are the OUTPUT of printf '%s-%s\n' dock one (and
#     term two). The typed command line shows those words with a space, so
#     each Wait only ends once the command has actually run.
#   - "Please select a terminal" is toggleterm's :TermSelect prompt.
#   None of them appears in notes.md or in the caption.
# Ctrl+\ then Ctrl+n is sent with a 500 ms gap, which proved reliable in
# test renders.

# claudecode.nvim starts its server on every Neovim start and writes an IDE
# lock file under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at
# a throwaway sibling of the fixture copy so that no run, not even an aborted
# one, can leave a stale lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/06-terminal.claude"

# The two toggleterm terminals run your real zsh, and this tape types into
# them. Stop zsh-autosuggestions from drawing lines of your real shell history
# as grey text while it types.
Env ZSH_AUTOSUGGEST_HISTORY_IGNORE "*"

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/06-terminal && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/06-terminal/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE notes.md"
Enter
Wait+Screen /Terminal practice/
Sleep 1.5s
# Caption: typed while hidden, so only the message is recorded.
Type@10ms ":echo 'Lesson 06 - Space t, Ctrl-\ Ctrl-n, window moves, :2ToggleTerm, :TermSelect'"
Enter
Show

Sleep 1.5s

# Space t: terminal 1 opens across the bottom, in Terminal mode
# (start_in_insert, neovim.nix:777).
Type " t"
Wait+Screen /TERMINAL/
# Give zsh time to read its rc files and draw the prompt.
Sleep 2.5s
Type `printf '%s-%s\n' dock one`
Sleep 300ms
Enter
Wait+Screen /dock-one/
Sleep 1s
Screenshot media/06-terminal/terminal-open.png
Sleep 200ms

# Some output worth scrolling back through.
Type "seq 1 60"
Sleep 300ms
Enter
Sleep 1.5s

# Ctrl+\ Ctrl+n: out of Terminal mode. The terminal is now a read-only buffer.
Ctrl+\
Sleep 500ms
Ctrl+n
Wait+Screen /NORMAL/
Sleep 1s

# gg: the top of the scrollback; G: back to the bottom.
Type "gg"
Sleep 1.5s
Screenshot media/06-terminal/normal-scrollback.png
Sleep 200ms
Type "G"
Sleep 1s

# Ctrl+K: up into notes.md (with no tree, that is the only window above).
Ctrl+K
Sleep 1.5s
Screenshot media/06-terminal/window-up.png
Sleep 200ms

# Ctrl+J: back down. toggleterm restores the mode the terminal was left in
# (persist_mode), so it is still Normal mode; i goes back to the prompt.
Ctrl+J
Sleep 1.5s
Type "i"
Wait+Screen /TERMINAL/
Sleep 1s

# A second terminal: out of Terminal mode, then :2ToggleTerm. It opens beside
# terminal 1, in Terminal mode.
Ctrl+\
Sleep 500ms
Ctrl+n
Wait+Screen /NORMAL/
Sleep 800ms
Type ":2ToggleTerm"
Sleep 500ms
Enter
Wait+Screen /TERMINAL/
Sleep 2.5s
Type `printf '%s-%s\n' term two`
Sleep 300ms
Enter
Wait+Screen /term-two/
Sleep 1s
Screenshot media/06-terminal/two-terminals.png
Sleep 200ms

# :TermSelect lists both; 1 and Enter focus terminal 1.
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
Screenshot media/06-terminal/termselect.png
Sleep 200ms
Type "1"
Sleep 300ms
Enter
Sleep 1.5s

# Space t hides both terminals, and Space t brings both back. Terminal 1 was
# left in Normal mode, so these keys reach Neovim; the hidden Ctrl+\ Ctrl+n
# only makes sure of it (it is a no-op in Normal mode).
Hide
Ctrl+\
Sleep 500ms
Ctrl+n
Sleep 300ms
Show
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
