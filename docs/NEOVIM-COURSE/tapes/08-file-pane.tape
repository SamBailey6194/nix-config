Source tapes/_shared/settings.tape
Output media/08-file-pane/08-file-pane.gif
Output media/08-file-pane/08-file-pane.mp4
Require nvim

# tapes/08-file-pane.tape - Lesson 08: two buffers in the bufferline, <Tab>
# and ]b to switch, :ls, :b with part of a name (E93, then a match), a
# vertical split, <C-h>/<C-l>, <C-w>s _ = to split and resize, <C-q> to
# close a window, then the neo-tree buffers panel (<leader>b) where d deletes
# a buffer AND closes the window that showed it.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/08-file-pane.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B). Afterwards,
# check that media/08-file-pane/ holds the GIF, the MP4 and all six PNGs.
#
# Repository milestone: any. The tape neither reads nor writes the repo; it
# works on a throwaway copy of fixtures/08-file-pane (spec.md and the SB2
# models.py) in /tmp/nvim-course/08-file-pane. Nothing is saved.
#
# Deterministic by design:
#   - Two file arguments: argc() > 0, so no dock layout (neovim.nix:892).
#   - spec.md is Markdown (no language server). models.py imports only the
#     standard library, so pyright/ruff attach but report nothing, and the
#     bufferline shows no diagnostic marks.
#   - Anchors: "Session model" is only in spec.md, "class Source" only in
#     models.py, "Press ENTER" only in the :ls prompt, "E93" only in the :b
#     error. None of them is in the caption.
#   - <C-w> sequences: Ctrl+W and the next key are sent back to back, well
#     inside which-key's 200 ms delay and 'timeoutlen' (300 ms). If which-key
#     ever does show its window popup, the next key still runs the command.
#   - In the buffers panel, /spec is plain Vim search (neo-tree maps / only in
#     the filesystem source), so the cursor lands on spec.md whatever order
#     the panel lists the buffers in.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/08-file-pane.claude"
# claudecode.nvim starts its server on every Neovim start (auto_start = true,
# neovim.nix:830-833) and writes an IDE lock file under $CLAUDE_CONFIG_DIR/ide.
# A throwaway sibling of the fixture copy keeps your real ~/.claude untouched,
# even if a run is aborted.

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/08-file-pane && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/08-file-pane/. "$L" && cd "$L" && clear`
Enter
Wait
# -i NONE keeps the recording out of (and independent of) your ShaDa file.
Type "nvim -i NONE spec.md models.py"
Enter
Wait+Screen /Session model/
Sleep 1.5s
Type@10ms ":echo 'Lesson 08 - buffers, the bufferline, splits and the buffers panel'"
Enter
Show

# --- Step 2: the bufferline lists both buffers; spec.md is current.
Sleep 1.5s
Screenshot media/08-file-pane/bufferline.png
Sleep 200ms

# <Tab> = :bnext (neovim.nix:61) loads models.py for the first time.
Tab
Wait+Screen /class Source/
Sleep 1.2s
# <S-Tab> = :bprevious (neovim.nix:62)
Shift+Tab
Sleep 1.2s
# ]b and [b: the Neovim 0.11+ defaults, same job
Type "]b"
Sleep 1.2s
Type "[b"
Sleep 1.2s

# --- Step 3: :ls, then :b with part of a name.
Type ":ls"
Sleep 500ms
Enter
Wait+Screen /Press ENTER/
Sleep 1.5s
Screenshot media/08-file-pane/ls.png
Sleep 200ms
Enter
Sleep 800ms

# "e" is in the middle of both names: E93, more than one match.
Type ":b e"
Sleep 500ms
Enter
Wait+Screen /E93/
Sleep 1.8s
# A name that starts with what you typed wins outright.
Type ":b mod"
Sleep 500ms
Enter
Wait+Screen /class Source/
Sleep 1.2s
Type ":b spec"
Sleep 500ms
Enter
Wait+Screen /Session model/
Sleep 1s

# --- Step 4: <C-w>v splits side by side (splitright: the new window is on
# the right and takes the cursor), then :b mod shows models.py there.
Ctrl+W
Type "v"
Sleep 1s
Type ":b mod"
Sleep 500ms
Enter
Wait+Screen /class Source/
Sleep 1.5s
Screenshot media/08-file-pane/vsplit.png
Sleep 200ms

# --- Step 5: <C-h> / <C-l> move between the two windows (neovim.nix:68-71).
Ctrl+H
Sleep 1s
Ctrl+L
Sleep 1s

# --- Step 6: <C-w>s splits the right-hand window (splitbelow), <C-w>_
# maximises the new one, <C-w>= evens all three out.
Ctrl+W
Type "s"
Sleep 1.2s
Ctrl+W
Type "_"
Sleep 1.5s
Ctrl+W
Type "="
Sleep 1.5s
Screenshot media/08-file-pane/three-windows.png
Sleep 200ms
# <C-q> is :q on this window only (neovim.nix:65).
Ctrl+Q
Sleep 1.5s

# --- Step 8: <leader>b opens the buffers panel on the left and moves the
# cursor into it (neovim.nix:25). Typed briskly, so no which-key popup.
Type " b"
Sleep 2.5s
Screenshot media/08-file-pane/buffers-panel.png
Sleep 200ms
# Put the cursor on spec.md, then d = buffer_delete. The spec.md window on
# the left closes with the buffer.
Type "/spec"
Sleep 500ms
Enter
Sleep 1s
Type "d"
Sleep 2s
Screenshot media/08-file-pane/buffer-deleted.png
Sleep 200ms
# q closes the panel: models.py is left on its own.
Type "q"
Sleep 2s

# --- Teardown (hidden). Quit explicitly so claudecode.nvim's VimLeavePre
# handler removes its lock file.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
