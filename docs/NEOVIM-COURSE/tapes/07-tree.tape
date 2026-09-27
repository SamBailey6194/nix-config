Source tapes/_shared/settings.tape
Output media/07-tree/07-tree.gif
Output media/07-tree/07-tree.mp4
Require nvim
Require git

# tapes/07-tree.tape - Lesson 07: the neo-tree filesystem tree. Space e opens
# it on the file being edited; j, Enter and C expand and collapse a folder;
# a creates docs/ideas.md; r renames it to drafts.md; d deletes it after the
# y/n confirmation; H hides and shows the dimmed ignored folder; / filters
# the tree; ? lists the keys; q closes the tree.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/07-tree.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B). Afterwards,
# check that media/07-tree/ holds the GIF, the MP4 and all seven PNGs.
#
# Repository: this tape neither reads nor writes the repo, so it can be
# recorded at any milestone. Everything happens in a throwaway copy of
# fixtures/07-tree/ at /tmp/nvim-course/07-tree.
#
# Deterministic by design. The hidden setup makes the copy a git repository
# with no commits and no remote (for the git marks), writes a .gitignore
# holding target/ and creates target/output.txt (for the dimmed entry and H).
# The same commands are the practice setup in the lesson. Markdown and plain
# text only, so no language server attaches. Starting on docs/plan.md means
# follow_current_file (neovim.nix:650) opens the tree with docs expanded and
# its cursor on plan.md, so `a` always creates inside docs.
#
# Why drafts.md: ideas.md and drafts.md both sort first in docs, so after the
# rename the cursor is on the renamed file whether neo-tree keeps the line or
# follows the node. The delete Wait names drafts.md: if the cursor were
# anywhere else, the Wait would time out and stop the recording instead of
# deleting the wrong file on camera.
#
# Anchors, each present only in the UI it waits for (never in plan.md, which
# is the only fixture file on screen, nor in the caption):
#   .gitignore                   the tree itself
#   Enter name / Enter new name  the add and rename prompts
#   delete .drafts\.md           the delete prompt
#   Filter: / 2025-review        the fuzzy filter and its match
#   Press the corresponding key  the ? key list

# claudecode.nvim writes an IDE lock file under $CLAUDE_CONFIG_DIR/ide.
# Point it at a throwaway sibling of the fixture copy (NOT inside it, or the
# tree would list it) so no run can leave a stale lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/07-tree.claude"

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/07-tree && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/07-tree/. "$L" && cd "$L"`
Enter
Wait
Type `git init -q && printf 'target/\n' > .gitignore && mkdir -p target && printf 'build output\n' > target/output.txt && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE docs/plan.md"
Enter
Wait+Screen /Sketch the screens/
Sleep 1.5s
# Caption: typed while hidden, so only the message is recorded.
Type@10ms ":echo 'Lesson 07 - Space e, a r d in the tree, H, / and ?'"
Enter
Show

Sleep 1.5s

# Space e: the tree opens on the left and takes the cursor; it follows the
# current file, so docs is expanded and the cursor is on plan.md.
Type " e"
Wait+Screen /\.gitignore/
# git status and the ignored check run asynchronously.
Sleep 2.5s
Screenshot media/07-tree/tree.png
Sleep 200ms

# Navigation: j onto notes, Enter expands it, C collapses it, k back to plan.md.
Type "j"
Sleep 800ms
Enter
Sleep 1.2s
Type "C"
Sleep 1s
Type "k"
Sleep 1s

# a: add a file next to plan.md, i.e. inside docs.
Type "a"
Wait+Screen /Enter name/
Sleep 1s
Screenshot media/07-tree/add-prompt.png
Sleep 200ms
Type "ideas.md"
Sleep 500ms
Enter
Sleep 2s
Screenshot media/07-tree/added.png
Sleep 200ms

# r: rename. The prompt is pre-filled with "ideas.md", cursor at the end.
Type "r"
Wait+Screen /Enter new name/
Sleep 1s
Backspace 12
Sleep 300ms
Type "drafts.md"
Sleep 500ms
Enter
Sleep 2s

# d: delete, after the y/n confirmation.
Type "d"
Wait+Screen /delete .drafts\.md/
Sleep 1.2s
Screenshot media/07-tree/delete-confirm.png
Sleep 200ms
Type "y"
Sleep 400ms
Enter
Sleep 2s

# H: hide the dimmed, git-ignored target folder; H again brings it back.
Type "H"
Sleep 2s
Screenshot media/07-tree/hidden-toggled.png
Sleep 200ms
Type "H"
Sleep 2s

# /: filter as you type; Escape closes the filter and restores the tree.
Type "/"
Wait+Screen /Filter:/
Sleep 800ms
Type "review"
Wait+Screen /2025-review/
Sleep 1.5s
Screenshot media/07-tree/fuzzy-filter.png
Sleep 200ms
Escape
Sleep 1.5s

# ?: every key of the tree; Escape closes the list.
Type "?"
Wait+Screen /Press the corresponding key/
Sleep 2s
Screenshot media/07-tree/help.png
Sleep 200ms
Escape
Sleep 1s

# q: close the tree.
Type "q"
Sleep 1.5s

# --- Teardown (hidden). Quit explicitly so claudecode.nvim's VimLeavePre
# handler removes its lock file.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
