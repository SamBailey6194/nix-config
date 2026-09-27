Source tapes/_shared/settings.tape
Output media/13-claude-code-and-codex/13-claude-code-and-codex.gif
Output media/13-claude-code-and-codex/13-claude-code-and-codex.mp4
Require nvim
Require claude
Require codex
Env IS_DEMO "1"
Env CLAUDE_CODE_HIDE_CWD "1"

# tapes/13-claude-code-and-codex.tape - Lesson 13: the Claude Code split and
# the hidden Codex terminal, driven from the keyboard.
#
# *** LIVE TAPE ***  Not deterministic. It starts the real `claude` and
# `codex` CLIs, which must be signed in, and starting them makes network
# calls that count as account activity. It shows UI and navigation only:
# NO PROMPT IS EVER SUBMITTED, so there is no model output on screen. Frames
# differ between runs (versions, notices, the mode Claude starts in).
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/13-claude-code-and-codex.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B). Appendix B's
# render-all loop skips this tape: record it by hand, and before lesson 27,
# which makes Claude start in Manual mode and so changes the first screenshot.
#
# CLAUDE_CONFIG_DIR is deliberately NOT redirected here (unlike the other
# tapes): Claude would start logged out. The lock file claudecode.nvim writes
# in ~/.claude/ide is removed by the hidden :qa! at the end. No zsh is typed
# into: claude runs without a shell, and codex under `$SHELL -c` (no prompt).
#
# One-off MANUAL step before the first recording. First-run questions cannot
# be answered safely by a script, so answer them once by hand. Both tools
# remember the answer per path, so the rm -rf and re-copy below keep it:
#   mkdir -p /tmp/nvim-course/13-claude-code-and-codex
#   cd /tmp/nvim-course/13-claude-code-and-codex
#   claude     # accept the folder-trust question, then type /exit
#   codex      # answer the trust question; if it offers an update, choose to
#              # skip it until the next version; then /quit
# If you skip this, a Wait below times out and VHS writes no GIF.
#
# Privacy. The Env lines above reach claude through vhs -> bash -> nvim ->
# claudecode.nvim's terminal: IS_DEMO=1 hides your e-mail and organisation
# name in Claude Code's header, CLAUDE_CODE_HIDE_CWD=1 hides the working
# directory in its logo (documented Claude Code variables; verify on
# laptop-intel that 2.1.278 honours both). Codex's header shows the model and
# /tmp/nvim-course/13-claude-code-and-codex, nothing about the account. Still
# check every frame before publishing (lesson 13, Recording).
#
# Anchors: "Claude Code" (Claude's logo), "manual mode on" (Claude's mode
# line in Manual mode) and "OpenAI Codex" (Codex's header box). None of them
# appears in the fixture or the caption.

# --- Setup (hidden).
Hide
Type `L=/tmp/nvim-course/13-claude-code-and-codex && rm -rf "$L" && mkdir -p "$L" && cp -r fixtures/13-claude-code-and-codex/. "$L" && cd "$L" && clear`
Enter
Wait
Type "nvim -i NONE panel.md"
Enter
Wait+Screen /just-panel: review notes/
Sleep 1.5s
Type@10ms ":echo 'Lesson 13 (LIVE) - the AI split and the hidden terminal; no prompt is sent'"
Enter
Show

Sleep 1.5s

# <leader>cc: the Claude split opens on the right (30 %) in Terminal mode.
# Whatever mode it starts in shows on its mode line: on this config that is
# usually auto mode, the trap the lesson starts with.
Type " cc"
Wait+Screen@60s /Claude Code/
Sleep 6s
Screenshot media/13-claude-code-and-codex/claude-first-launch.png
Sleep 200ms

# Every key but Ctrl+\ goes to Claude. Ctrl+\ Ctrl+n leaves Terminal mode;
# then <C-h> is the normal window-left map again.
Ctrl+\
Ctrl+n
Sleep 800ms
Ctrl+h
Sleep 1s

# Back into Claude: <C-l> lands in Normal mode, i enters Terminal mode.
# /exit ends the process (a local command: nothing goes to the model).
Ctrl+l
Sleep 800ms
Type "i"
Sleep 800ms
Type "/exit"
Sleep 1s
Enter
Sleep 4s

# Arguments only count when no Claude process exists - hence the /exit.
Type ":ClaudeCode --permission-mode manual"
Sleep 800ms
Enter
Wait+Screen@60s /manual mode on/
Sleep 3s
Screenshot media/13-claude-code-and-codex/claude-manual.png
Sleep 200ms

# Leave Terminal mode, back to the code, send the whole buffer as context.
# Focus stays in the editor; the mention waits in Claude's input, unsent.
Ctrl+\
Ctrl+n
Sleep 800ms
Ctrl+h
Sleep 1s
Type " cb"
Sleep 3s
Screenshot media/13-claude-code-and-codex/send-buffer.png
Sleep 200ms

# <leader>co: the hidden Codex terminal at the bottom (Terminal mode).
Type " co"
Wait+Screen@60s /OpenAI Codex/
Sleep 5s
Screenshot media/13-claude-code-and-codex/codex.png
Sleep 200ms

# Out of Terminal mode, up to the code, then hide both panes again:
# the processes keep running.
Ctrl+\
Ctrl+n
Sleep 800ms
Ctrl+k
Sleep 1s
Type " co"
Sleep 1.5s
Type " cc"
Sleep 2s
Screenshot media/13-claude-code-and-codex/both-hidden.png
Sleep 200ms

# And back: the same Claude (the unsent mention is still in its input).
Type " cc"
Sleep 3s

# --- Teardown (hidden). Leave any Terminal mode first, then quit everything:
# :qa! stops both CLIs, and claudecode.nvim's VimLeavePre handler removes its
# ~/.claude/ide/<port>.lock file.
Hide
Ctrl+\
Ctrl+n
Sleep 300ms
Type ":qa!"
Enter
Sleep 1s
