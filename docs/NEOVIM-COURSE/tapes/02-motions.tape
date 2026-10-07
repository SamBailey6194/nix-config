Source tapes/_shared/settings.tape
Output media/02-motions/02-motions.gif
Output media/02-motions/02-motions.mp4
Require nvim

# tapes/02-motions.tape - Lesson 02: counts read off the relative numbers,
# word motions (w versus W on hyphenated recipe names), 0 ^ $, f ; , and %,
# paragraphs, scrolling, a mark, the which-key marks list and the jumplist.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/02-motions.tape
#
# Deterministic: the fixture is a copy of practice/02-motions.txt (plain text,
# so no language server attaches), copied to a fixed throwaway path. The tape
# only moves the cursor: nothing is typed into the file, saved, yanked or
# deleted, so the system clipboard is untouched.
#
# Timing rules this tape relies on:
#   - Single-key motions are typed slowly (Type@...) so each step is visible.
#   - Two-key commands that share a prefix (gg, zt, zz, zb) are typed in one
#     Type at the shared 60 ms speed, well inside which-key's 200 ms delay.
#   - The marks list pops up with NO delay when ' is pressed (which-key's marks
#     plugin); the tape pauses on it deliberately for one screenshot.
#   - <C-i> is never pressed: <Tab> owns it in this config (neovim.nix:61).
#
# Privacy: CLAUDE_CONFIG_DIR points at a throwaway sibling of the fixture
# copy, so the IDE lock file claudecode.nvim writes on every start
# (auto_start = true, neovim.nix:830-833) never lands in ~/.claude/ide.
#
# Needs VHS 0.12.1, which the config builds: 0.12.0 runs this tape, exits 0
# and writes NOTHING (charmbracelet/vhs#787), so `vhs --version` must print
# 0.12.1 (Appendix B). Then check that
# media/02-motions/ holds the GIF, the MP4 and all five PNGs.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/02-motions.claude"

# --- Setup (hidden).
Hide
Type `L=/tmp/nvim-course/02-motions && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/02-motions/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE 02-motions.txt"
Enter
Wait+Screen /LESSON 02 KATA/
Sleep 1.5s
Type@10ms ":echo 'Lesson 02 - counts, words, f and %, paragraphs, scrolling, marks and jumps'"
Enter
Show

Sleep 1.5s

# Counts: jump to rebuild, put it at the top, read the distance to check: in
# the gutter (17), then move exactly that far.
Type "36G"
Sleep 800ms
Type "zt"
Sleep 1.2s
Screenshot media/02-motions/relative-numbers.png
Sleep 200ms
Type "17j"
Sleep 1.5s

# Words: w stops at every - in lint-rust, W jumps whole recipe names.
Type "89G0"
Sleep 1s
Type@500ms "wwwww"
Sleep 800ms
Type "0"
Sleep 600ms
Type@600ms "WW"
Sleep 1.2s
Screenshot media/02-motions/w-and-W.png
Sleep 200ms

# Line positions, then f { ; and , along the fuzz body, then %.
Type "86G0"
Sleep 900ms
Type "^"
Sleep 700ms
Type "$"
Sleep 900ms
Type "0"
Sleep 700ms
Type "f{"
Sleep 800ms
Type@700ms ";;"
Sleep 600ms
Type ","
Sleep 900ms
Type "0"
Sleep 600ms
Type "%"
Sleep 1.2s
Screenshot media/02-motions/percent.png
Sleep 200ms
Type "%"
Sleep 1s

# Paragraphs: } and { hop between blank lines.
Type "36G0"
Sleep 800ms
Type@800ms "}}"
Sleep 700ms
Type "{"
Sleep 1s

# Scrolling: half pages, whole pages, then H M L inside the window. <C-b>
# leaves the cursor on the bottom visible line, so H goes first: L straight
# after <C-b> would not move at all.
Type "gg"
Sleep 900ms
Ctrl+D
Sleep 1s
Ctrl+D
Sleep 1s
Ctrl+U
Sleep 1s
Ctrl+F
Sleep 1s
Ctrl+B
Sleep 1s
Type@800ms "HML"
Sleep 1s

# zt zz zb move the view, not the cursor.
Type "85G"
Sleep 900ms
Type "zt"
Sleep 1s
Type "zz"
Sleep 1s
Type "zb"
Sleep 1.2s

# A mark: mr on rebuild, jump away, then ' (which-key lists the marks at
# once) and r to come back.
Type "36G"
Sleep 800ms
Type "mr"
Sleep 700ms
Type "G"
Sleep 1s
Type "'"
Sleep 1.5s
Screenshot media/02-motions/marks-popup.png
Sleep 200ms
Type "r"
Sleep 1.2s

# The jumplist: gg, 85G and G are jumps; Ctrl-o walks back through them.
Type "gg"
Sleep 800ms
Type "85G"
Sleep 800ms
Type "G"
Sleep 900ms
Ctrl+O
Sleep 1.2s
Ctrl+O
Sleep 1.2s
Type ":jumps"
Enter
Wait+Screen /jump line  col file/
Sleep 2s
Screenshot media/02-motions/jumps.png
Sleep 200ms
Sleep 1.5s

# --- Teardown (hidden). Escape dismisses the :jumps prompt; :qa! quits so
# claudecode.nvim's VimLeavePre handler removes its lock file from the
# throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
