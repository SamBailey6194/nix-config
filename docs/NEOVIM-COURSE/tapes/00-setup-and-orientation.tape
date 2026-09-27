# tapes/00-setup-and-orientation.tape - Lesson 00: a bare `nvim` opens the
# dock layout (tree on the left, terminal across the bottom), Space opens the
# which-key popup, and :qa! quits every window at once.
#
# Run from docs/NEOVIM-COURSE/ (Source, Output, Screenshot and the fixture cp
# all resolve against the directory vhs is started in, not this file):
#   vhs tapes/00-setup-and-orientation.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
# Record it before lessons 24 and 26, which change the which-key popup it
# shows (Appendix B, "Record in this order").
#
# Deterministic by design: the fixture is one Markdown file and two
# placeholder folders; it is not a git repository (no git decorations), no
# source file is opened (no language server attaches) and no AI tool starts.
# The bottom pane is toggleterm running $SHELL, which VHS inherits from the
# shell you start vhs from. On laptop-intel that is your zsh, so the pane
# shows your usual prompt with the fixture path; nothing private.
#
# Two things differ from the other lesson tapes, on purpose:
#   1. `nvim -i NONE` is typed ON CAMERA, because "bare nvim" is the point.
#   2. Neovim quits ON CAMERA with :qa!, because quitting cleanly is taught
#      here. The usual hidden ":qa!" teardown would only reach bash, so the
#      teardown below just stops recording.
Source tapes/_shared/settings.tape
Output media/00-setup-and-orientation/00-setup-and-orientation.gif
Output media/00-setup-and-orientation/00-setup-and-orientation.mp4
Require nvim

# claudecode.nvim starts its server on every Neovim start (auto_start = true,
# home/modules/neovim.nix:830-833) and writes an IDE lock file under
# $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide); the pinned plugin reads this
# variable and creates the directory itself. Point it at a throwaway sibling
# of the fixture copy (NOT inside it, or neo-tree would list it) so that no
# run, not even an aborted one, can leave a stale lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/00-setup-and-orientation.claude"

# The terminal pane runs your real zsh. Nothing is typed into it, but if the
# focus guard below is removed and the terminal keeps focus, the guard's and
# the caption's keys would land there. This stops zsh-autosuggestions from
# ever drawing a line of your real history on screen.
Env ZSH_AUTOSUGGEST_HISTORY_IGNORE "*"

# --- Setup (hidden). Hide is the first non-Set command, so all of this runs
# before capturing starts. The fixture goes to a fixed throwaway path so the
# tree header and the terminal prompt are identical on every re-recording.
Hide
Type `L=/tmp/nvim-course/00-setup-and-orientation && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/00-setup-and-orientation/. "$L" && cd "$L" && clear`
Enter
Wait
Show

# --- The bare start, on camera. No file argument, so the VimEnter autocmd
# (neovim.nix:889-905) runs: tree first, then the terminal, then the cursor
# goes back to the editing window. -i NONE keeps the recording out of (and
# independent of) your ShaDa file; you type plain `nvim`.
Sleep 1s
Type "nvim -i NONE"
Sleep 500ms
Enter
Wait+Screen /WELCOME\.md/
# Give toggleterm time to start the shell and the scheduled wincmd to run.
Sleep 3s

# --- Focus guard and caption (hidden; this stretch is cut from the video).
# The autocmd should already have left the cursor in the editing window. If
# the terminal kept it (Terminal mode), these keys bring it back; in the
# editing window they change nothing: <C-\><C-n> is a no-op in Normal mode,
# and the autocmd's own `wincmd k` / `wincmd l` stop at the window edges.
# To check the unguarded behaviour on a newer Neovim, delete the six lines
# from Ctrl+\ to the Enter after the wincmd line and look at dock-layout.png.
Hide
Ctrl+\
Sleep 500ms
Ctrl+n
Sleep 300ms
Type ":wincmd k | wincmd l"
Enter
Sleep 500ms
# Caption: typed while hidden, so only the message is recorded.
Type@10ms ":echo 'Lesson 00 - bare nvim: tree left, editor right, terminal across the bottom'"
Enter
Show

Sleep 2s
Screenshot media/00-setup-and-orientation/dock-layout.png
Sleep 200ms

# Space is the leader (neovim.nix:210). which-key opens its popup after its
# 200 ms delay and then waits, because Space on its own runs nothing.
Space
Sleep 2500ms
Screenshot media/00-setup-and-orientation/which-key.png
Sleep 200ms

# Escape closes the popup without running anything.
Escape
Sleep 1s

# :qa! closes every window at once: tree, editor and the terminal with its
# shell. The lesson teaches :qa; the tape adds ! so a recording can never
# stop at "E37: No write since last change".
Type ":qa!"
Sleep 1s
Enter
# Line-scope Wait matches the VHS bash prompt again: Neovim has exited, and
# the screen shows the `nvim -i NONE` command it was started with.
Wait
Sleep 2s

# --- Teardown (hidden). Neovim already quit on camera, so VimLeavePre has run
# and claudecode.nvim has removed its lock file. Nothing is left to close.
Hide
Sleep 300ms
