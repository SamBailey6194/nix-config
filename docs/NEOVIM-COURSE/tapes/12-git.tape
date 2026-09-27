Source tapes/_shared/settings.tape
Output media/12-git/12-git.gif
Output media/12-git/12-git.mp4
Require nvim
Require git

# Demo identity for every commit this tape makes, whatever your environment
# holds: GIT_AUTHOR_*/GIT_COMMITTER_* beat any user.* config, so your real
# name and address can never reach the demo repo's log or Neogit's Head line.
Env GIT_AUTHOR_NAME "Course Demo"
Env GIT_AUTHOR_EMAIL "demo@example.invalid"
Env GIT_COMMITTER_NAME "Course Demo"
Env GIT_COMMITTER_EMAIL "demo@example.invalid"

# claudecode.nvim starts its server on every Neovim start (auto_start = true,
# home/modules/neovim.nix:830-833) and writes an IDE lock file under
# $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a throwaway
# sibling of the demo repo so no run can leave a lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/12-git.claude"

# tapes/12-git.tape - Lesson 12: gitsigns hunks (signs, preview, stage one
# hunk), the neo-tree git_status panel, staging with s and committing in
# Neogit, then Diffview open (<leader>gd) and close (<leader>gq).
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/12-git.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# No shell is typed into on camera: the only shell is VHS's own bash (Set
# Shell), used by the hidden setup, and no Neovim terminal is opened.
#
# Deterministic and private. The hidden setup builds a THROWAWAY repo in
# /tmp/nvim-course/12-git: it copies fixtures/12-git/v1, sets a demo identity
# in that repo only (git config without --global, as the lesson does; the
# GIT_* Env lines above make sure of it), commits, then copies
# fixtures/12-git/v2 over the top. So every run starts from the same two
# modified files. The tape commits into that repo only; it has no remote, so
# nothing can be pushed. Your real repos and identity are never touched.
#
# What v1 -> v2 changes, which the anchors below rely on:
#   panel.md  line 3 changed ("...for the whole justfile."), line 10 added
#             ("- / filters the list"), last line deleted ("- clean-cache")
#   notes.md  one line added
# Anchor texts (panel for the justfile, notes.md, Unstaged changes, Extend,
# Commands:, Head:, Changes) appear in no fixture and in no caption, so each
# Wait only matches the UI it waits for. The commit editor anchor is Neogit's
# own "# Commands:" help block, which it inserts at the first lone "#" line
# (line 10 with the repo's ~/.gitmessage). git's "Please enter the commit
# message" comment sits near line 30, below the bottom of the ~15-row editor
# window (the staged diff takes the other half), so it cannot be the anchor.
# Checked headless with the pinned Neogit (5adc81b) at 115x34.
#
# Git's global config still applies inside the demo repo: commit.template
# (~/.gitmessage from home/modules/git.nix) fills the commit editor, which is
# exactly what the learner sees.

# --- Setup (hidden: Hide comes straight after the Set, Output, Require and
# Env lines, so none of this is recorded).
Hide
Type `C=$PWD && L=/tmp/nvim-course/12-git && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/12-git/v1/. "$L" && cd "$L"`
Enter
Wait
Type `git init -q -b main && git config user.name "Course Demo" && git config user.email "demo@example.invalid"`
Enter
Wait
Type `git add . && git commit -q -m "docs: first draft" && cp -r "$C"/fixtures/12-git/v2/. . && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE panel.md"
Enter
Wait+Screen /just-panel: notes/
# gitsigns attaches asynchronously; give the signs time to appear.
Sleep 2s
Type@10ms ":echo 'Lesson 12 - hunks in the gutter, the status panel, Neogit, Diffview'"
Enter
Show

Sleep 1.5s
# Three unstaged hunks: ~ on line 3, + on line 10, _ under the last line.
Screenshot media/12-git/signs.png
Sleep 200ms

# gitsigns has no keymaps in this config: drive it with :Gitsigns.
# From line 1, the next hunk is the change on line 3.
Type ":Gitsigns nav_hunk next"
Sleep 400ms
Enter
Sleep 800ms
Type ":Gitsigns preview_hunk"
Sleep 400ms
Enter
# The old text only exists in the preview float.
Wait+Screen /panel for the justfile/
Sleep 1.5s
Screenshot media/12-git/preview-hunk.png
Sleep 200ms

# Any cursor movement closes the float.
Type "j"
Sleep 800ms

# Next hunk: the added line 10. Stage only this hunk.
Type ":Gitsigns nav_hunk next"
Sleep 400ms
Enter
Sleep 800ms
Type ":Gitsigns stage_hunk"
Sleep 400ms
Enter
Sleep 1.5s
# Line 10 now carries the staged-style sign; lines 3 and 16 are unchanged.
Screenshot media/12-git/staged-sign.png
Sleep 200ms

# <leader>gs: the neo-tree git_status panel on the right (focus moves in).
Type " gs"
Wait+Screen /notes\.md/
Sleep 1.5s
Screenshot media/12-git/git-status-panel.png
Sleep 200ms
# q closes the panel. (Never gg here: in this panel it commits AND pushes.)
Type "q"
Sleep 1s

# <leader>gg: Neogit in its own tab.
Type " gg"
Wait+Screen /Unstaged changes/
Sleep 2s
Screenshot media/12-git/neogit-status.png
Sleep 200ms

# A plain search puts the cursor on the notes.md entry; s stages the file.
Type "/notes\.md"
Sleep 400ms
Enter
Sleep 800ms
Type "s"
Sleep 1.5s
# <leader>h clears the search highlight.
Type " h"
Sleep 800ms
Screenshot media/12-git/neogit-staged.png
Sleep 200ms

# c opens the commit popup ...
Type "c"
Wait+Screen /Extend/
Sleep 1.5s
Screenshot media/12-git/commit-popup.png
Sleep 200ms
# ... and c again opens the commit editor in a new tab.
Type "c"
Wait+Screen /Commands:/
Sleep 2s
# Normal mode whatever the editor started in, then replace the empty first
# line. Escape (not Enter) ends Insert mode, so an open completion menu
# never inserts anything.
Escape
Sleep 300ms
Type "ggcc"
Sleep 300ms
Type "docs(demo): note the filter key and the resume key"
Sleep 300ms
Escape
Sleep 800ms
Screenshot media/12-git/commit-editor.png
Sleep 200ms
# <c-c><c-c> submits.
Ctrl+C
Ctrl+C
# The Head line shows the new commit once Neogit has refreshed.
Wait+Screen /Head:.*note the filter key/
Sleep 2s

# q closes Neogit's tab and returns to panel.md, where only the two
# uncommitted hunks keep their signs.
Type "q"
Wait+Screen /whole justfile/
Sleep 1.5s

# <leader>gd: Diffview of what is left (working tree against the index).
Type " gd"
Wait+Screen /Changes/
Sleep 2.5s
Screenshot media/12-git/diffview.png
Sleep 200ms
# Diffview has no q: <leader>gq closes it.
Type " gq"
Sleep 2.5s

# --- Teardown (hidden). Quit explicitly so claudecode.nvim's VimLeavePre
# handler removes its lock file from the throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
