Source tapes/_shared/settings.tape
Output media/28-going-further/28-going-further.gif
Output media/28-going-further/28-going-further.mp4
Require nvim
Require git

# tapes/28-going-further.tape - Lesson 28, section 1: the gitsigns hunk keys.
# ]h and [h jump between hunks, Space g p previews one, Space g a stages one,
# the Space g popup lists the new keys, and :verbose nmap ]h shows where the
# map was set.
#
# Run from docs/NEOVIM-COURSE (Source/Output/Screenshot paths are relative to
# the directory vhs is started in, not to this file):
#   vhs tapes/28-going-further.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# Record this AFTER lesson 28's section 1 is applied: the gitsigns keys added
# to the keymaps list, `just rebuild` run, and a fresh shell to start vhs from.
# On the config as the earlier lessons teach it, ]h, [h, Space g p and
# Space g a do nothing and the first Wait+Screen after them times out. Record
# tape 05 BEFORE that change, because its Space g popup gains a, b, p and r.
#
# Deterministic and private. The hidden setup builds a THROWAWAY repo in
# /tmp/nvim-course/28-going-further: it copies fixtures/28-going-further/v1,
# commits it with a demo identity (repo-local git config, and the GIT_* Env
# lines below beat any user.* config), then copies fixtures/28-going-further/v2
# over the top. Every run therefore starts from the same three hunks in
# `justfile`, as gitsigns numbers them:
#   line 11      changed  (the test-rust comment)
#   line 14      deleted  (the lint-rust recipe was below it)
#   lines 19-26  added    (the vhs-validate and vhs-record recipes)
# The repo has no remote, no terminal is opened and no register is shown, so
# nothing private can appear. Anchor texts (Test every Rust crate, Hunk 1 of 3,
# Toggle file tree, Preview hunk, Last set from) appear in no caption.

# Demo identity for the one commit the setup makes, whatever your environment
# holds: GIT_AUTHOR_*/GIT_COMMITTER_* beat any user.* config.
Env GIT_AUTHOR_NAME "Course Demo"
Env GIT_AUTHOR_EMAIL "demo@example.invalid"
Env GIT_COMMITTER_NAME "Course Demo"
Env GIT_COMMITTER_EMAIL "demo@example.invalid"

# claudecode.nvim starts its server on every Neovim start and writes an IDE
# lock file under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a
# throwaway sibling of the demo repo so no run can leave a lock in ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/28-going-further.claude"

# --- Setup (hidden: Hide comes straight after the Set, Output, Require and
# Env lines, so none of this is recorded).
Hide
Type `C=$PWD && L=/tmp/nvim-course/28-going-further && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/28-going-further/v1/. "$L" && cd "$L"`
Enter
Wait
Type `git init -q -b main && git config user.name "Course Demo" && git config user.email "demo@example.invalid"`
Enter
Wait
Type `git add . && git commit -q -m "chore: demo justfile" && cp -r "$C"/fixtures/28-going-further/v2/. . && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE justfile"
Enter
Wait+Screen /Test every Rust crate/
# gitsigns attaches asynchronously; give the signs time to appear.
Sleep 2s
Type@10ms ":echo 'Lesson 28 - ]h and [h jump between hunks, Space g p previews, Space g a stages'"
Enter
Show

# The three hunks in the sign column: ~ changed, _ deleted, + added.
Sleep 1.5s
Screenshot media/28-going-further/signs.png
Sleep 200ms

# ]h three times: line 11, line 14, line 19 (the first line of each hunk).
# Each ]h is typed as one sequence, well inside which-key's 200 ms delay, so
# the ] popup never opens.
Type "]h"
Sleep 1s
Type "]h"
Sleep 1s
Type "]h"
Sleep 1s
# [h twice: back to line 14, then line 11. [h lands on the LAST line of the
# previous hunk, which for these two is also their first.
Type "[h"
Sleep 1s
Type "[h"
Sleep 1s

# Space g p, typed as one sequence: the floating preview of hunk 1.
Type " gp"
Wait+Screen /Hunk 1 of 3/
Sleep 1.5s
Screenshot media/28-going-further/preview.png
Sleep 200ms
# Moving the cursor closes the preview.
Type "j"
Sleep 500ms
Type "k"
Sleep 1s

# Two more ]h to the added hunk (line 19), then Space g a stages it: its +
# signs turn into gitsigns' staged bar.
Type "]h"
Sleep 800ms
Type "]h"
Sleep 800ms
Type " ga"
Sleep 2s
Screenshot media/28-going-further/staged.png
Sleep 200ms

# Space, a pause, then g: which-key's +git popup now lists a, b, p and r.
Space
Wait+Screen /Toggle file tree/
Sleep 1s
Type "g"
Wait+Screen /Preview hunk/
Sleep 1.5s
Screenshot media/28-going-further/leader-g.png
Sleep 200ms
Escape
Sleep 1s

# Where does ]h come from? The listing is three lines, taller than the
# command line, so Neovim waits at a hit-enter prompt.
Type ":verbose nmap ]h"
Enter
Wait+Screen /Last set from/
Sleep 2s
Screenshot media/28-going-further/verbose.png
Sleep 200ms
# Enter dismisses the hit-enter prompt.
Enter
Sleep 1s

# --- Teardown (hidden). Quit cleanly so claudecode.nvim's VimLeavePre handler
# removes its lock file from the throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
