Source tapes/_shared/settings.tape
Output media/05-your-keybindings/05-your-keybindings.gif
Output media/05-your-keybindings/05-your-keybindings.mp4
Require nvim

# tapes/05-your-keybindings.tape - Lesson 05: Space and the which-key groups
# (+find, +git, +code / AI, +diagnostics), then where <leader>x comes from
# (:verbose nmap <leader>x).
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/05-your-keybindings.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B). Afterwards,
# check that media/05-your-keybindings/ holds the GIF, the MP4 and all six
# PNGs.
# Record it before lessons 24 and 26 and lesson 28's gitsigns keys, which
# change the popups and the :verbose listing it shows (Appendix B, "Record in
# this order").
#
# Deterministic: a Markdown fixture (no language server attaches, so the
# leader popup holds only the global maps), copied to a fixed throwaway path.
# Nothing is saved and no real repo, Claude or Codex data is touched.
#
# Timing rules this tape relies on (Appendix B, "Tape conventions"):
#   - which-key opens 200 ms after Space and then waits for the next key.
#   - <leader>x is BOTH :bdelete and the +diagnostics group. The x below is
#     typed more than 1 s after Space, i.e. after 'timeoutlen' (300 ms), so
#     which-key opens the group instead of closing the buffer. Never shorten
#     the Sleep between that Space and that x.
#   - Wait+Screen anchors are descriptions that appear only in the popup or
#     in the :verbose output, never in the fixture or the caption.
#
# No shell is typed into inside Neovim (a file argument means no dock
# terminal), so no zsh history guard is needed.

# claudecode.nvim starts its server on every Neovim start (auto_start = true,
# home/modules/neovim.nix:830-833) and writes an IDE lock file under
# $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a throwaway
# sibling of the fixture copy (tape 00's pattern) so that no run, not even an
# aborted one, can leave a stale lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/05-your-keybindings.claude"

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/05-your-keybindings && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/05-your-keybindings/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE keys.md"
Enter
Wait+Screen /Your keybinding system/
Sleep 1.5s
Type@10ms ":echo 'Lesson 05 - Space opens which-key: groups, Backspace goes up, Escape cancels'"
Enter
Show

Sleep 1.5s

# Leader alone: the root popup (Panels keys, <leader>h, and four groups).
Space
Wait+Screen /Toggle file tree/
Sleep 1.5s
Screenshot media/05-your-keybindings/leader.png
Sleep 200ms

# f: into +find
Type "f"
Wait+Screen /Live grep/
Sleep 1.5s
Screenshot media/05-your-keybindings/leader-f.png
Sleep 200ms

# Backspace: up one level, back to the leader root
Backspace
Wait+Screen /Toggle file tree/
Sleep 1.5s

# g: into +git
Type "g"
Wait+Screen /Full git UI/
Sleep 1.5s
Screenshot media/05-your-keybindings/leader-g.png
Sleep 200ms

# Escape: close the popup without running anything
Escape
Sleep 1s

# c: +code / AI (Claude Code, Codex and the conform format key)
Space
Wait+Screen /Toggle file tree/
Sleep 1s
Type "c"
Wait+Screen /Toggle Codex CLI/
Sleep 1.5s
Screenshot media/05-your-keybindings/leader-c.png
Sleep 200ms
Escape
Sleep 1s

# x: +diagnostics. x arrives about 1 s after Space (well past timeoutlen),
# so which-key continues into the group and :bdelete does NOT run.
Space
Wait+Screen /Toggle file tree/
Sleep 1s
Type "x"
Wait+Screen /Buffer diagnostics/
Sleep 1.5s
Screenshot media/05-your-keybindings/leader-x.png
Sleep 200ms
Escape
Sleep 1s

# Where does <leader>x come from? :verbose adds a "Last set from" line.
Type ":verbose nmap <leader>x"
Sleep 800ms
Enter
Wait+Screen /Last set from/
Sleep 2s
Screenshot media/05-your-keybindings/verbose-x.png
Sleep 200ms
Sleep 2.5s

# --- Teardown (hidden). Quit explicitly so claudecode.nvim's VimLeavePre
# handler removes its lock file from the throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
