Source tapes/_shared/settings.tape
Output media/26-fix-close-buffer-key/26-fix-close-buffer-key.gif
Output media/26-fix-close-buffer-key/26-fix-close-buffer-key.mp4
Require nvim

# tapes/26-fix-close-buffer-key.tape - Lesson 26: close-buffer lives on
# <leader>q now, and <leader>x is only the +diagnostics group, so a pause
# after Space x closes nothing.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/26-fix-close-buffer-key.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# *** Record AFTER lesson 26's fix. ***  It demonstrates the verification
# step, so it needs the new config: apply the change, `just rebuild`, then
# record (a fresh vhs starts a fresh Neovim, which reads the new init.lua).
# On a config without the fix the first Wait+Screen (/Close buffer/, from
# `:verbose nmap <leader>q`) times out and VHS writes nothing.
#
# Deterministic: three plain-text files from fixtures/26-fix-close-buffer-key/
# copied to a fixed throwaway path. Plain text, so no language server attaches
# and the leader popup holds only the global maps. Nothing is saved, no
# terminal is opened and no register is shown, so neither the clipboard nor
# shell history can appear. No repository is read or written.
#
# Timing rules this tape relies on:
#   - which-key opens its popup 200 ms after Space and then waits.
#   - The x after the root popup arrives about 1.5 s after Space, well past
#     'timeoutlen' (300 ms): on the fixed config that shows the +diagnostics
#     group, and nothing closes. That pause is the point of the screenshot.
#   - " q" is typed as ONE Type at the shared 60 ms: it fires at once.
#   - Wait+Screen anchors ("Close buffer", "All diagnostics", "Toggle file
#     tree", "Buffer diagnostics", "NOTES:") appear only in :verbose output,
#     in the popup or in notes.txt, never in spec.txt or the caption.

# claudecode.nvim starts its server on every Neovim start and writes an IDE
# lock file under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a
# throwaway sibling of the fixture copy so no run, not even an aborted one,
# can leave a stale lock in your real ~/.claude.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/26-fix-close-buffer-key.claude"

# --- Setup (hidden: Hide is the first command after the Env line, so none of
# this is recorded).
Hide
Type `L=/tmp/nvim-course/26-fix-close-buffer-key && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/26-fix-close-buffer-key/. "$L" && cd "$L" && clear`
Enter
Wait
# Three file arguments: three listed buffers in the bufferline, spec.txt
# shown. A file argument skips the dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE spec.txt notes.txt todo.txt"
Enter
Wait+Screen /SPEC:/
Sleep 1.5s
Type@10ms ":echo 'Lesson 26 - Space q closes a buffer at once; Space x is only a group'"
Enter
Show

Sleep 1.5s

# 1. The new key and where it comes from. The listing is taller than the
# command line, so Neovim waits at a hit-enter prompt; Enter dismisses it.
Type ":verbose nmap <leader>q"
Enter
Wait+Screen /Close buffer/
Sleep 2s
Screenshot media/26-fix-close-buffer-key/verbose-q.png
Sleep 200ms
Enter
Sleep 1s

# 2. <leader>x: only <Space>xw and <Space>xx are left, no <Space>x of its own.
# (Typed at the command line, the listing does not include which-key's
# buffer-local <Space> trigger; lesson 26, step 6.)
Type ":verbose nmap <leader>x"
Enter
Wait+Screen /All diagnostics/
Sleep 2s
Screenshot media/26-fix-close-buffer-key/verbose-x.png
Sleep 200ms
Enter
Sleep 1s

# 3. Space, then a pause: the root popup lists q "Close buffer" beside
# x "+diagnostics".
Space
Wait+Screen /Toggle file tree/
Sleep 1.5s
Screenshot media/26-fix-close-buffer-key/which-key.png
Sleep 200ms

# 4. x, long after 'timeoutlen': the +diagnostics group opens and waits.
# spec.txt stays in the bufferline and in the window.
Type "x"
Wait+Screen /Buffer diagnostics/
Sleep 1.5s
Screenshot media/26-fix-close-buffer-key/group-waits.png
Sleep 200ms
Escape
Sleep 300ms
Sleep 1s

# 5. Space q, briskly: spec.txt goes at once and notes.txt fills the window.
Type " q"
Wait+Screen /NOTES:/
Sleep 1.5s
Screenshot media/26-fix-close-buffer-key/closed.png
Sleep 200ms
Sleep 1.5s

# --- Teardown (hidden). Quit cleanly so claudecode.nvim's VimLeavePre handler
# removes its lock file from the throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
