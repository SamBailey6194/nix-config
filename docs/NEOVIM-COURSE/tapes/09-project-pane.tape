Source tapes/_shared/settings.tape
Output media/09-project-pane/09-project-pane.gif
Output media/09-project-pane/09-project-pane.mp4
Require nvim

# tapes/09-project-pane.tape - Lesson 09: <leader>ff finds the justfile
# (fzf suffix syntax), <leader>fg live-greps the banner rulers with the
# regex ^# =+, <C-q> sends the results to a quickfix list, <CR> and ]q ]q
# walk it, then <leader>o opens the Aerial outline of models.py.
#
# Records examples/session-browser/SB2's models.py and a read-only copy of the
# repository's justfile - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/09-project-pane.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/09-project-pane/ really holds the GIF, the MP4 and the five PNGs.
#
# The tape only READS the repository: the hidden setup copies the justfile
# (../../justfile, the file lesson 09 investigates) and the worked example's
# SB2 models.py (examples/session-browser/SB2/src/session_browser/models.py,
# the milestone lesson 09 starts from) into /tmp/nvim-course/09-project-pane,
# and Neovim works on those copies. Nothing is saved and nothing is written to
# the repo. Recipes added to the justfile later (lesson 28 adds some) move
# line numbers only, which no anchor depends on.
#
# Deterministic by design:
#   - The folder holds only justfile and models.py, so find_files lists two
#     files, and every live grep result for ^# =+ comes from one file, in
#     line order. The quickfix list is therefore the same on every run (a
#     repo-wide grep would mix in course files, in ripgrep's thread order).
#   - Anchors: the Telescope prompt titles "Find Files" and "Live Grep"
#     (telescope builtin/__files.lua at the pinned revision), a result line
#     "justfile:<line>:<col>:# =" (make_entry.gen_from_vimgrep's display) and
#     a quickfix line "justfile|<line> col <col>|" (Neovim's quickfix
#     format). Line numbers are matched with \d+, so edits to the justfile do
#     not break the tape. None of these strings is in the caption.
#   - The Aerial step has no anchor: its window shows symbol names that are
#     also in the code. It uses generous sleeps instead. models.py imports
#     only the standard library, so pyright and ruff attach quietly; if
#     pyright is not ready yet, Aerial falls back to treesitter
#     (backends = lsp, treesitter, ..., neovim.nix:691).
#   - 1440 px at FontSize 20 is roughly 115 columns (font-dependent), under
#     Telescope's preview_cutoff of 120 columns, so the pickers should show
#     no preview. That is expected; no anchor depends on the preview.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/09-project-pane.claude"
# claudecode.nvim starts its server on every Neovim start (auto_start = true,
# neovim.nix:830-833) and writes an IDE lock file under $CLAUDE_CONFIG_DIR/ide.
# A throwaway sibling of the copy keeps your real ~/.claude untouched.

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
# If a copy fails, the chain stops before cd, and the "Plain data types
# shared" Wait below times out.
Type `L=/tmp/nvim-course/09-project-pane && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp examples/session-browser/SB2/src/session_browser/models.py ../../justfile "$L/" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE models.py"
Enter
Wait+Screen /Plain data types shared/
# Give pyright time to attach before the outline step at the end.
Sleep 2s
Type@10ms ":echo 'Lesson 09 - find a file, grep a regex, walk the quickfix list, open the outline'"
Enter
Show

Sleep 1.5s

# --- Step 3: <leader>ff (neovim.nix:29). Typed briskly: no which-key popup.
Type " ff"
Wait+Screen /Find Files/
Sleep 1s
# fzf-native suffix syntax: paths that end with "justfile".
Type "justfile$"
Sleep 1.5s
Screenshot media/09-project-pane/find-files.png
Sleep 200ms
Enter
Sleep 1.5s

# --- Step 5: <leader>fg (neovim.nix:30). The prompt is a ripgrep regex.
Type " fg"
Wait+Screen /Live Grep/
Sleep 1s
Type "^# =+"
Wait+Screen /justfile:\d+:\d+:# =/
Sleep 1.5s
Screenshot media/09-project-pane/live-grep.png
Sleep 200ms

# --- Step 8: <C-q> in the picker = send every result to a new quickfix list
# and open it (botright copen); the cursor lands in the quickfix window.
Ctrl+Q
Wait+Screen /justfile\|\d+ col \d+\|/
Sleep 1.5s
Screenshot media/09-project-pane/quickfix.png
Sleep 200ms
# <CR> on the first line jumps to entry 1 in the window above. (]q straight
# after <C-q> would skip it: the list starts at entry 1 unvisited.)
Enter
Sleep 1.2s
# ]q (Neovim 0.11+ default = :cnext): the second ruler of the first banner,
# then the first ruler of the next banner.
Type "]q"
Sleep 1.2s
Type "]q"
Sleep 1.5s
Screenshot media/09-project-pane/cnext.png
Sleep 200ms

# --- Step 9: close the quickfix window, back to models.py, then the outline.
Type ":cclose"
Sleep 500ms
Enter
Sleep 800ms
Type ":b models"
Sleep 500ms
Enter
Wait+Screen /Plain data types shared/
Sleep 1s
# <leader>o = :AerialToggle (neovim.nix:26): far left, cursor moves in.
Type " o"
Sleep 3s
Screenshot media/09-project-pane/aerial.png
Sleep 200ms
# j j moves down the outline; <CR> jumps to that symbol in the code.
Type "j"
Sleep 700ms
Type "j"
Sleep 700ms
Enter
Sleep 1.5s
# <leader>o again, from the code window, closes the outline.
Type " o"
Sleep 2s

# --- Teardown (hidden). Quit explicitly so claudecode.nvim's VimLeavePre
# handler removes its lock file.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
