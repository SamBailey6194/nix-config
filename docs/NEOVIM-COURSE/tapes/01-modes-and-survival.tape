Source tapes/_shared/settings.tape
Output media/01-modes-and-survival/01-modes-and-survival.gif
Output media/01-modes-and-survival/01-modes-and-survival.mp4
Require nvim

# tapes/01-modes-and-survival.tape - Lesson 01: the Insert-mode keys (i a I A
# o O), dot repeat, undo and redo, Ctrl-s saving, undo surviving a restart,
# and Ctrl-q closing a help WINDOW rather than Neovim.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/01-modes-and-survival.tape
#
# Deterministic:
#   - The fixture is a copy of practice/01-survival.txt. Plain text: no
#     language server attaches and conform has no formatter for it, so the
#     Ctrl-s save below changes nothing but the file on disk.
#   - It is copied to a fixed throwaway path, and XDG_STATE_HOME points inside
#     that path. The undo file this tape writes (undofile = true,
#     neovim.nix:266) therefore never lands in ~/.local/state/nvim/undo, and
#     every re-recording starts with no undo history. Neovim creates the undo
#     directory itself.
#   - Nothing is yanked or deleted, so the system clipboard is untouched.
#   - Wait+Screen anchors are texts that exist only after the step they wait
#     for (the INSERT mode message, the write message, the undo message, the
#     help text, the E37 error), never in the fixture or a caption.
#
# Privacy: claudecode.nvim starts its server on every Neovim start
# (auto_start = true, neovim.nix:830-833) and writes an IDE lock file under
# $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). CLAUDE_CONFIG_DIR points at
# a throwaway sibling of the fixture copy, so no run, not even an aborted
# one, leaves a stale lock in your real ~/.claude (tape 00's pattern).
#
# Needs VHS 0.12.1, which the config builds: 0.12.0 runs this tape, exits 0
# and writes NOTHING (charmbracelet/vhs#787), so `vhs --version` must print
# 0.12.1 (Appendix B). Then check that
# media/01-modes-and-survival/ holds the GIF, the MP4 and all nine PNGs.
Env XDG_STATE_HOME "/tmp/nvim-course/01-modes-and-survival/state"
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/01-modes-and-survival.claude"

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/01-modes-and-survival && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/01-modes-and-survival/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE 01-survival.txt"
Enter
Wait+Screen /LESSON 01 KATA/
Sleep 1.5s
Type@10ms ":echo 'Lesson 01 - Insert keys, dot, undo, Ctrl-s, and Ctrl-q closing a window'"
Enter
Show

Sleep 1.5s
# Relative numbers: the cursor line shows its real number, the rest show
# their distance from it.
Screenshot media/01-modes-and-survival/start.png
Sleep 200ms

# Exercise 1: i inserts before the cursor, a appends after it.
Type ":7"
Enter
Sleep 700ms
Type "l"
Sleep 600ms
Type "i"
Wait+Screen /-- INSERT --/
Sleep 1s
Screenshot media/01-modes-and-survival/insert-mode.png
Sleep 200ms
Type "u"
Sleep 600ms
Escape
Sleep 600ms
Type@200ms "llllll"
Sleep 500ms
Type "a"
Sleep 400ms
Type "i"
Sleep 500ms
Escape
Sleep 1s

# Exercise 2: I inserts at the first non-blank; . repeats the whole change.
Type ":11"
Enter
Sleep 700ms
Type "I"
Sleep 400ms
Type "just "
Sleep 400ms
Escape
Sleep 700ms
Type@600ms "j.j."
Sleep 1s

# Exercise 3: A appends at the end of the line.
Type ":17"
Enter
Sleep 700ms
Type "A"
Sleep 400ms
Type "."
Sleep 400ms
Escape
Sleep 700ms
Type@600ms "j.j."
Sleep 1s
Screenshot media/01-modes-and-survival/dot-repeat.png
Sleep 200ms

# Exercise 4: o opens a line below (autoindent keeps the 4 spaces), O above.
Type ":24"
Enter
Sleep 700ms
Type "o"
Sleep 400ms
Type "deadnix ."
Sleep 400ms
Escape
Sleep 700ms
Type ":23"
Enter
Sleep 700ms
Type "O"
Sleep 400ms
Type "# Lint Nix files"
Sleep 400ms
Escape
Sleep 1s
Screenshot media/01-modes-and-survival/open-lines.png
Sleep 200ms

# Exercise 5: eight undos take exercises 4, 3 and 2 back; two redos return
# the first two lines of exercise 2.
Type@400ms "uuuuuuuu"
Sleep 1.2s
Screenshot media/01-modes-and-survival/undo.png
Sleep 200ms
Ctrl+R
Sleep 700ms
Ctrl+R
Sleep 1s

# Exercise 6: Ctrl-s saves (Normal mode only), :q quits, and after a restart
# u still undoes: the undo history lives in an undo file.
Ctrl+S
Wait+Screen /written/
Sleep 1.2s
Screenshot media/01-modes-and-survival/saved.png
Sleep 200ms
Type ":q"
Enter
Wait
Sleep 1s
Type "nvim -i NONE 01-survival.txt"
Enter
Wait+Screen /LESSON 01 KATA/
Sleep 1.5s
Type "u"
Wait+Screen /before #/
Sleep 1.5s
Screenshot media/01-modes-and-survival/persistent-undo.png
Sleep 200ms

# Exercise 7: :help opens a WINDOW. Ctrl-q (= :q) closes that window only.
Type ":help i"
Enter
Wait+Screen /Insert text before the cursor/
Sleep 1.5s
Screenshot media/01-modes-and-survival/help-window.png
Sleep 200ms
Ctrl+Q
Sleep 1.5s
# Ctrl-q again, now on the last window with an unsaved change: Neovim refuses.
Ctrl+Q
Wait+Screen /E37/
Sleep 1.5s
Screenshot media/01-modes-and-survival/e37.png
Sleep 200ms
Sleep 1.5s

# --- Teardown (hidden). :qa! discards the undo above and quits, so
# claudecode.nvim's VimLeavePre handler removes its lock file from the
# throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
