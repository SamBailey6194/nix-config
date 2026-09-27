Source tapes/_shared/settings.tape
Output media/27-fix-claude-diff-review/27-fix-claude-diff-review.gif
Output media/27-fix-claude-diff-review/27-fix-claude-diff-review.mp4
Require nvim
Require claude
Require jq
Env IS_DEMO "1"
Env CLAUDE_CODE_HIDE_CWD "1"

# tapes/27-fix-claude-diff-review.tape - Lesson 27: with
# permissions.defaultMode = "default" in claude.nix, a fresh Claude opened
# with <leader>cc starts in Manual mode, and the edit it asks for arrives in
# Neovim as a diff that you accept with <C-s>.
#
# *** LIVE TAPE ***  Not deterministic, signed in and billed. It starts the
# real `claude`, which must be logged in, and it SUBMITS ONE SHORT PROMPT, so
# the recording uses a little of your plan's allowance and shows a few lines
# of model output. Frames differ between runs (versions, notices, the words
# Claude chooses). Never put anything private in the fixture or the prompt.
#
# *** Record AFTER lesson 27's fix. ***  It demonstrates the verification
# step: apply the change, `just rebuild`, `/exit` every running Claude, then
# record. On a config without the fix, jq prints no "defaultMode", so the
# Wait+Screen for it times out after 20 s and VHS writes nothing, before Claude
# is started or billed. If the setting is there but Claude still starts in
# another mode (a flag, or a project's .claude/settings.json), the Wait+Screen
# for "manual mode on" times out after 60 s instead. Either way it is the tape
# telling you the fix is not in effect.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/27-fix-claude-diff-review.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B). Like tape 13
# it is recorded by hand, never in a render-all loop.
#
# CLAUDE_CONFIG_DIR is deliberately NOT redirected: this tape checks your real
# ~/.claude/settings.json (the file lesson 27 changes), and Claude would start
# logged out in a throwaway directory. The first screenshot shows only the
# `permissions` object of that file. claudecode.nvim's lock file in
# ~/.claude/ide is removed by the hidden :qa! at the end. No zsh is typed
# into: `:!jq` runs through a non-interactive shell and claude runs without
# one, so no shell history can appear.
#
# One-off MANUAL step before the first recording. The folder-trust question
# cannot be answered safely by a script, so answer it once by hand. Claude
# remembers the answer per path, so the rm -rf and re-copy below keep it:
#   mkdir -p /tmp/nvim-course/27-fix-claude-diff-review
#   cd /tmp/nvim-course/27-fix-claude-diff-review
#   claude     # accept the folder-trust question, then type /exit
# If you skip this, a Wait below times out and VHS writes no GIF.
#
# Privacy. IS_DEMO=1 hides your e-mail and organisation name in Claude Code's
# header and CLAUDE_CODE_HIDE_CWD=1 hides the working directory in its logo
# (the same guards as tape 13; verify on laptop-intel that 2.1.278 honours
# both). Step through every frame before publishing (lesson 27, Recording).
#
# Anchors: "defaultMode" (the jq output), "manual mode on" (Claude's mode
# line) and "proposed)" (the diff's right-hand buffer name, which ends in
# "(proposed)"). None of them appears in the fixture, the prompt or the
# caption.

# --- Setup (hidden).
Hide
Type `L=/tmp/nvim-course/27-fix-claude-diff-review && rm -rf "$L" && mkdir -p "$L" && cp -r fixtures/27-fix-claude-diff-review/. "$L" && cd "$L" && clear`
Enter
Wait
Type "nvim -i NONE notes.md"
Enter
Wait+Screen /Release notes/
Sleep 1.5s
Type@10ms ":echo 'Lesson 27 (LIVE) - Claude starts in Manual mode; its edit arrives as a diff'"
Enter
Show

Sleep 1.5s

# 1. The generated settings file now carries the default. :! shows the
# output above a hit-enter prompt; Enter dismisses it.
Type ":!jq .permissions ~/.claude/settings.json"
Enter
Wait+Screen /defaultMode/
Sleep 2s
Screenshot media/27-fix-claude-diff-review/settings.png
Sleep 200ms
Enter
Sleep 1s

# 2. <leader>cc: a fresh Claude, started with no --permission-mode flag and
# no Shift+Tab. Its mode line must already say Manual.
Type " cc"
Wait+Screen@60s /manual mode on/
Sleep 4s
Screenshot media/27-fix-claude-diff-review/claude-manual.png
Sleep 200ms

# 3. Ask for a one-word edit. The claudecode split opened in Terminal mode,
# so the text goes straight to Claude's prompt.
Type "In notes.md, change the word draft on the Status line to reviewed. Change nothing else."
Sleep 800ms
Enter

# 4. Manual mode asks before it edits, and in Neovim that question is a diff:
# notes.md on the left, notes.md (proposed) on the right, cursor on the right.
Wait+Screen@120s /proposed\)/
Sleep 4s
Screenshot media/27-fix-claude-diff-review/diff.png
Sleep 200ms

# 5. <C-s> in the proposed buffer accepts: Claude writes the file and
# notes.md reloads with the change.
Ctrl+S
Sleep 8s
Screenshot media/27-fix-claude-diff-review/accepted.png
Sleep 200ms
Sleep 2s

# --- Teardown (hidden). Leave any Terminal mode first, then quit everything:
# :qa! stops Claude, and claudecode.nvim's VimLeavePre handler removes its
# ~/.claude/ide/<port>.lock file.
Hide
Ctrl+\
Ctrl+n
Sleep 300ms
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 1s
