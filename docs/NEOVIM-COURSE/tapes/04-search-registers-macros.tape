Source tapes/_shared/settings.tape
Output media/04-search-registers-macros/04-search-registers-macros.gif
Output media/04-search-registers-macros/04-search-registers-macros.mp4
Require nvim
Require wl-copy

# tapes/04-search-registers-macros.tape - Lesson 04: / n N with hlsearch and
# smartcase, Space h to clear, * stopping inside lint-rust, :%s with a count
# message, cgn + dot (skipping one match), and two macros: recipe names into
# a Rust vec! and the just-panel-style caution table, plus :reg a.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/04-search-registers-macros.tape
#
# Deterministic: the fixture is a copy of practice/04-recipes.txt (plain text:
# no language server, no formatter), copied to a fixed throwaway path, and it
# is never saved.
#
# PRIVACY - read before editing this tape:
#   - which-key's registers plugin lists EVERY register, including "+ and "*
#     (your system clipboard and primary selection), the instant " is pressed
#     in Normal/Visual mode or Ctrl-r in Insert/Command-line mode (no delay for
#     plugin popups). This tape never presses either. Registers are shown only
#     with :reg a, never with a bare :registers / :reg.
#   - Second guard (plan rule for any tape that shows registers): the hidden
#     setup overwrites the clipboard AND the primary selection with the
#     harmless text "nvim-course" before Neovim starts, so even a slip that
#     opened the register list could not show what the recorder had copied.
#   - c and s write the text they replace to the system clipboard
#     (clipboard=unnamedplus, neovim.nix:257), so recording replaces what you
#     had copied with fixture text.
#   - CLAUDE_CONFIG_DIR points at a throwaway sibling of the fixture copy, so
#     the IDE lock file claudecode.nvim writes on every start (auto_start =
#     true, neovim.nix:830-833) never lands in ~/.claude/ide.
#
# Timing: Space h is typed in one Type (60 ms per key), so <leader>h fires
# without the which-key popup. Macros are recorded with the same keys the
# lesson teaches; nvim-autopairs is disabled while a macro records or runs
# (its disable_in_macro default), so the typed quotes arrive as typed.
#
# Needs VHS 0.12.1, which the config builds: 0.12.0 runs this tape, exits 0
# and writes NOTHING (charmbracelet/vhs#787), so `vhs --version` must print
# 0.12.1 (Appendix B). Then check that
# media/04-search-registers-macros/ holds the GIF, the MP4 and all eight PNGs.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/04-search-registers-macros.claude"

# --- Setup (hidden).
Hide
Type `printf 'nvim-course' | wl-copy && printf 'nvim-course' | wl-copy --primary && clear`
Enter
Wait
Type `L=/tmp/nvim-course/04-search-registers-macros && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/04-search-registers-macros/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE 04-recipes.txt"
Enter
Wait+Screen /LESSON 04 KATA/
Sleep 1.5s
Type@10ms ":echo 'Lesson 04 - search, substitute, cgn and dot, and two macros'"
Enter
Show

Sleep 1.5s

# / searches (incsearch shows matches while you type); hlsearch keeps them
# lit. Lower-case sudo also finds SUDO: ignorecase + smartcase.
Type "/sudo"
Sleep 1s
Enter
Sleep 1.2s
Screenshot media/04-search-registers-macros/search.png
Sleep 200ms
Type@800ms "nnn"
Sleep 700ms
Type "N"
Sleep 1s

# Space h runs :nohlsearch (Ctrl-l no longer does: it moves to the window on
# the right in this config).
Type " h"
Sleep 1.2s

# * searches for the word under the cursor, as \<lint\>. The - in lint-rust
# is not a word character, so it stops there too.
Type "9G0"
Sleep 800ms
Type "*"
Sleep 1.2s
Screenshot media/04-search-registers-macros/star.png
Sleep 200ms
Type " h"
Sleep 800ms

# :%s over the whole file; the count message confirms what changed.
Type ":%s/needs sudo/asks for your password/"
Sleep 1s
Enter
Wait+Screen /4 substitutions on 4 lines/
Sleep 1.5s
Screenshot media/04-search-registers-macros/substitute.png
Sleep 200ms
Type "u"
Sleep 1s

# cgn + dot: change one match, then . for each next one; n n skips one.
Type "/TODO"
Sleep 600ms
Enter
Sleep 900ms
Type "cgn"
Sleep 500ms
Type "DONE"
Sleep 500ms
Escape
Sleep 900ms
Type@800ms ".."
Sleep 600ms
Type@800ms "nn"
Sleep 600ms
Type "."
Sleep 1.2s
Screenshot media/04-search-registers-macros/cgn.png
Sleep 200ms
Type " h"
Sleep 800ms

# Macro 1: record on the first recipe name, then replay six times.
Type "25G"
Sleep 600ms
Type "zt"
Sleep 900ms
Type "27G0"
Sleep 800ms
Type "qa"
Wait+Screen /recording @a/
Sleep 900ms
Type "I"
Sleep 400ms
Type '    "'
Sleep 500ms
Escape
Sleep 500ms
Type "A"
Sleep 400ms
Type '",'
Sleep 500ms
Escape
Sleep 500ms
Type "j"
Sleep 900ms
Screenshot media/04-search-registers-macros/recording.png
Sleep 200ms
Type "q"
Sleep 900ms
Type "6@a"
Sleep 1.5s
Screenshot media/04-search-registers-macros/macro-vec.png
Sleep 200ms

# A macro is just text in a register.
Type ":reg a"
Sleep 600ms
Enter
Wait+Screen /Type Name Content/
Sleep 2s
Screenshot media/04-search-registers-macros/reg-a.png
Sleep 200ms
Enter
Sleep 900ms

# Macro 2: "name - reason" lines into ("name", "reason"), entries.
Type "37G0"
Sleep 800ms
Type "qb"
Wait+Screen /recording @b/
Sleep 700ms
Type "0i"
Sleep 400ms
Type '    ("'
Sleep 500ms
Escape
Sleep 500ms
Type "f 3s"
Sleep 500ms
Type '", "'
Sleep 500ms
Escape
Sleep 500ms
Type "A"
Sleep 400ms
Type '"),'
Sleep 500ms
Escape
Sleep 500ms
Type "j"
Sleep 500ms
Type "q"
Sleep 900ms
Type "4@b"
Sleep 1.5s
Screenshot media/04-search-registers-macros/macro-caution.png
Sleep 200ms
Sleep 2s

# --- Teardown (hidden). :qa! discards everything (the kata is never saved)
# and lets claudecode.nvim remove its lock file from the throwaway
# $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
