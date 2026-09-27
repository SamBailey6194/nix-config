Source tapes/_shared/settings.tape
Output media/22-making-the-config-yours/22-making-the-config-yours.gif
Output media/22-making-the-config-yours/22-making-the-config-yours.mp4
Require nvim

# tapes/22-making-the-config-yours.tape - Lesson 22: the keymaps list, the
# KEYBINDS.md it generates, and asking Neovim what a key really does with
# :verbose nmap.
#
# Run from docs/NEOVIM-COURSE (Source/Output/Screenshot paths are relative to
# the directory vhs is started in, not to this file):
#   vhs tapes/22-making-the-config-yours.tape
# with VHS 0.12.1, which the config builds: 0.12.0 exits 0 and writes no GIF,
# MP4 or PNG, so `vhs --version` must print 0.12.1 (Appendix B).
#
# Repository: none. No tag is needed and the repo is never read or written;
# the tape works on a copy of its fixture only.
#
# Record this BEFORE lessons 23, 24 and 26 (Appendix B, "Record in this
# order"): it shows the config as lessons 00 to 21 teach it. After lesson 23,
# `:verbose nmap <C-i>` finds a mapping; lesson 24 changes the description
# of `t` in the Space popup, and lesson 26 adds `q` to it.
#
# Fixture: fixtures/22-making-the-config-yours/
#   neovim-keymaps.nix  lines 10-105 of home/modules/neovim.nix, verbatim, with
#                       the line numbers kept (the <Tab> entry is on line 61)
#   KEYBINDS.md         exactly what those lines render to

# claudecode.nvim starts its server on every Neovim start and writes an IDE
# lock file under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a
# throwaway sibling of the fixture copy so that no run, not even an aborted
# one, can leave a stale lock in your real ~/.claude. No terminal is opened and
# no register is shown, so no clipboard or shell-history guard is needed.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/22-making-the-config-yours.claude"

# --- Setup (hidden). Env is applied before the shell starts, and Hide is the
# first command after it, so all of this runs before capture starts (checked:
# the first frame of a VHS 0.12.1 render is the caption). The fixture goes to
# a fixed throwaway path so every re-recording shows the same paths and never
# touches the real config.
Hide
Type `L=/tmp/nvim-course/22-making-the-config-yours && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/22-making-the-config-yours/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
# +61 lands on the <Tab> entry, the line the lesson starts from.
Type "nvim -i NONE +61 neovim-keymaps.nix"
Enter
Wait+Screen /Next buffer/
# nil (the Nix language server) attaches in the background: let it settle.
Sleep 3s
# zz centres line 61 so the whole Buffers group is on screen.
Type "zz"
Sleep 500ms
Type@10ms ":echo 'Lesson 22 - the keymaps list, the KEYBINDS.md it writes, :verbose nmap'"
Enter
Show

Sleep 2s
Screenshot media/22-making-the-config-yours/attrset.png
Sleep 200ms

# The generated reference beside its source (splitright puts it on the right
# and moves the cursor there).
Type ":vsplit KEYBINDS.md"
Enter
Wait+Screen /Neovim keybinds/
Sleep 1s
# Jump to the Buffers section and put it at the top of the window.
Type "/## Buffers"
Enter
Sleep 500ms
Type "zt"
Sleep 1.5s
Screenshot media/22-making-the-config-yours/keybinds-split.png
Sleep 200ms

# <leader>h = Space h: clear the search highlight (typed as one sequence).
Type " h"
Sleep 1s

# What does <Tab> really do, and where was it defined? The listing is longer
# than the command line, so Neovim waits at a hit-enter prompt.
Type ":verbose nmap <Tab>"
Enter
Wait+Screen /Last set from/
Sleep 2s
Screenshot media/22-making-the-config-yours/verbose-tab.png
Sleep 200ms
# Enter dismisses the hit-enter prompt.
Enter
Sleep 1s

# <C-i> has no mapping of its own. No Wait here on purpose: on a config where
# lesson 23 is applied the text differs, and a Wait timeout would abort the
# whole recording.
Type ":verbose nmap <C-i>"
Enter
Sleep 2s
Screenshot media/22-making-the-config-yours/verbose-c-i.png
Sleep 200ms
# Escape clears a hit-enter prompt if there is one and does nothing otherwise.
Escape
Sleep 500ms

# which-key renders the same desc strings: pause after Space and the popup
# lists them, with x shown as the +diagnostics group, not "Close buffer".
Space
Sleep 2.5s
Screenshot media/22-making-the-config-yours/which-key.png
Sleep 200ms
Escape
Sleep 1s

# --- Teardown (hidden). Quit cleanly so claudecode.nvim's VimLeavePre handler
# removes its lock file from the throwaway $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
