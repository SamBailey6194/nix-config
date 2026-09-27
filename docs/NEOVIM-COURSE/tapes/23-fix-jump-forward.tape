Source tapes/_shared/settings.tape
Output media/23-fix-jump-forward/23-fix-jump-forward.gif
Output media/23-fix-jump-forward/23-fix-jump-forward.mp4
Require nvim

# tapes/23-fix-jump-forward.tape - Lesson 23, step 6: the <C-i> fix verified.
# :verbose nmap <C-i> shows the new map; G, Ctrl+O and <C-i> land on the last
# line again; <Tab> still opens the next buffer; KEYBINDS.md has the new row.
#
# RECORD THIS AFTER LESSON 23'S FIX, rebuilt and with Neovim restarted. It
# shows the fixed config, and its first Wait (/Last set from/, printed only
# when <C-i> has a map) stops the run on a config without the fix.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/23-fix-jump-forward.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# Repository: never read or written. Fixture: fixtures/23-fix-jump-forward/
# (jumps.md, 80 lines; other.md), copied to /tmp/nvim-course/23-fix-jump-forward.
# The tape also opens ~/.config/nvim/KEYBINDS.md read-only: it is generated
# from the config and holds key descriptions only.
#
# Why nvim_input: VHS types through xterm.js, which sends byte 9 for both Tab
# and Ctrl+I, so pressing Ctrl+I here would be <Tab>. Neovim's own terminal UI
# hands keys to the editor with nvim_input, so
#   :lua vim.api.nvim_input('<C-i>')
# delivers <C-i> exactly as Kitty's Ctrl+I arrives (src/nvim/tui/input.c:207).
#
# Anchors: "Last set from" (a map exists), "bottom of the file" (jumps.md
# line 80 only), "top of the file" (line 3 only), "The other buffer"
# (other.md), "Jump forward" (the KEYBINDS.md row). None of them is in the
# caption.

# claudecode.nvim starts its server on every Neovim start and writes an IDE
# lock file under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a
# throwaway sibling of the fixture copy so that no run, not even an aborted
# one, can leave a stale lock in your real ~/.claude. No terminal is opened
# and no register is shown, so no clipboard or shell-history guard is needed.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/23-fix-jump-forward.claude"

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/23-fix-jump-forward && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/23-fix-jump-forward/. "$L" && cd "$L" && clear`
Enter
Wait
# File arguments skip the bare-start dock layout; -i NONE keeps ShaDa (and
# with it any old jumplist) out.
Type "nvim -i NONE jumps.md other.md"
Enter
Wait+Screen /Jumplist practice/
Sleep 1.5s
Type@10ms ":echo 'Lesson 23 - after the fix: <C-i> has its own map, <Tab> keeps its own'"
Enter
Show

Sleep 1.5s

# --- 1. The map ---------------------------------------------------------------
# Three lines of output, so Neovim waits at a hit-enter prompt.
Type ":verbose nmap <C-i>"
Enter
Wait+Screen /Last set from/
Sleep 2s
Screenshot media/23-fix-jump-forward/verbose-c-i.png
Sleep 200ms
# Enter dismisses the hit-enter prompt.
Enter
Sleep 1s

# --- 2. Jump, come back, jump forward -----------------------------------------
Type "G"
Wait+Screen /bottom of the file/
Sleep 1s
Ctrl+O
Wait+Screen /top of the file/
Sleep 1.5s
Type ":lua vim.api.nvim_input('<C-i>')"
Sleep 500ms
Enter
Wait+Screen /bottom of the file/
Sleep 1.5s
Screenshot media/23-fix-jump-forward/jump-forward.png
Sleep 200ms

# --- 3. <Tab> is still the next buffer -----------------------------------------
# VHS's Tab is byte 9, which the <Tab> map keeps (lesson 23, step 2).
Tab
Wait+Screen /The other buffer/
Sleep 1.5s
Screenshot media/23-fix-jump-forward/tab-next-buffer.png
Sleep 200ms
# Shift+Tab (ESC [ Z) is <S-Tab>: back to jumps.md.
Shift+Tab
Wait+Screen /bottom of the file/
Sleep 1s

# --- 4. The generated reference --------------------------------------------------
# splitright puts KEYBINDS.md on the right and moves the cursor there.
Type ":vsplit ~/.config/nvim/KEYBINDS.md"
Enter
Wait+Screen /Neovim keybinds/
Sleep 1s
# Search for the new row; zz centres it with the rest of the Buffers table.
Type "/<C-i>"
Enter
Sleep 500ms
Type "zz"
Wait+Screen /Jump forward/
Sleep 1.5s
Screenshot media/23-fix-jump-forward/keybinds.png
Sleep 200ms
# <leader>h = Space h: clear the search highlight (typed as one sequence).
Type " h"
Sleep 1.5s

# --- Teardown (hidden). Quit cleanly so claudecode.nvim's VimLeavePre handler
# removes its lock file from the throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
