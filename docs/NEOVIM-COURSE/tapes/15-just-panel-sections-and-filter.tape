Source tapes/_shared/settings.tape
Output media/15-just-panel-sections-and-filter/15-just-panel-sections-and-filter.gif
Output media/15-just-panel-sections-and-filter/15-just-panel-sections-and-filter.mp4
Require cargo
Require just
# One target directory for every capstone tape: the dependencies are built
# once, and each tape rebuilds only just-panel itself.
Env CARGO_TARGET_DIR "/tmp/nvim-course/cargo-target"
# No Neovim runs here, so claudecode.nvim cannot write an IDE lock file; the
# redirect only matters if someone adds a Neovim step later.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/15-just-panel-sections-and-filter.claude"

# tapes/15-just-panel-sections-and-filter.tape - Lesson 15: just-panel at JP6.
# Section headers in the list (j skips them), the / filter (typing, Enter
# keeps it, Esc clears it and keeps the selection), and the ? help popup.
#
# Records examples/just-panel/JP6 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/15-just-panel-sections-and-filter.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/15-just-panel-sections-and-filter/ really holds the GIF, the MP4
# and the five PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/just-panel/JP6 (a mini Cargo workspace:
# Cargo.toml, Cargo.lock and just-panel/) to
# /tmp/nvim-course/15-just-panel-sections-and-filter/rust and the demo
# justfile to docs/NEOVIM-COURSE/fixtures/just/ beside it, the repo's own
# layout, so the recorded command is the lesson's own. It builds there with
# --locked into the shared CARGO_TARGET_DIR above. cp gives every copied file
# a fresh time stamp, so cargo never mistakes another milestone's build in
# that directory (tape 14's JP5, say) for this one
# (examples/just-panel/MILESTONES.md has the trap).
#
# The build in the hidden setup takes a minute or two if the target directory
# is empty, seconds after another just-panel tape. If it fails, the Wait after
# it times out after 5 minutes and VHS prints the last screen: the cargo error
# is there.
#
# Harmless and deterministic: JP6 cannot run recipes, and the panel reads the
# demo justfile (fixtures/just/justfile) through `just --dump` only.
# Anchor texts: "Lesson 15 - " is printed by printf from "Lesson %s - ", so
# the typed command never matches it; "help . q quit" is JP6's hint line
# (JP5 has no "? help"); "Secrets Management" is a header that only JP6
# shows at start-up; "filter: lint" is the list title while a filter is set;
# "any key closes" is the popup's bottom title. None is in the caption.

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/15-just-panel-sections-and-filter && rm -rf "$L" "$L.claude" && mkdir -p "$L/docs/NEOVIM-COURSE/fixtures" && cp -r fixtures/just "$L/docs/NEOVIM-COURSE/fixtures/" && cp -r examples/just-panel/JP6/. "$L/rust" && cd "$L/rust"`
Enter
Wait
# Build first, so the recorded `cargo run` starts the panel at once. `clear`
# then wipes the typed command, and printf leaves only the caption.
Type `cargo build --locked -q -p just-panel && clear && printf 'Lesson %s - just-panel JP6: section headers, the / filter, the ? popup\n' 15`
Enter
Wait+Screen@300s /Lesson 15 - /
Show

Sleep 1s
Type "cargo run -p just-panel -- -f ../docs/NEOVIM-COURSE/fixtures/just/justfile"
Sleep 500ms
Enter
Wait+Screen /Secrets Management/
Wait+Screen /help . q quit/
Sleep 1.5s
Screenshot media/15-just-panel-sections-and-filter/headers.png
Sleep 200ms

# j skips the "Secrets Management" header: default, then edit-secret.
Type "j"
Wait+Screen /Edit an encrypted secret/
Sleep 1.5s

# / starts a filter: the status line shows what you type, with a cursor, and
# the list keeps only the matches, each under its section's header.
Type "/"
Sleep 1s
Type@400ms "lint"
Wait+Screen /filter: lint/
Sleep 1.5s
Screenshot media/15-just-panel-sections-and-filter/filter-typing.png
Sleep 200ms

# Enter keeps the filter (it stays in the title) and gives j and k back.
Enter
Wait+Screen /(?s)filter: lint.*help . q quit/
Sleep 1s
Type "j"
Wait+Screen /Group +rust/
Sleep 1.5s
Screenshot media/15-just-panel-sections-and-filter/filter-kept.png
Sleep 200ms

# Esc clears the kept filter. Every section is back, and lint-rust is still
# the selected recipe.
Escape
Wait+Screen /Secrets Management/
Sleep 1.5s
Screenshot media/15-just-panel-sections-and-filter/filter-cleared.png
Sleep 200ms

# ? opens the help popup over the list.
Type "?"
Wait+Screen /any key closes/
Sleep 2s
Screenshot media/15-just-panel-sections-and-filter/help.png
Sleep 200ms

# Any key closes it. Esc does too, and does not quit the panel.
Escape
Sleep 1.5s

# q quits: the alternate screen goes, and the shell is back as it was.
Type "q"
Wait
Sleep 1.5s

# --- Teardown (hidden). If a key went missing and the panel is still open,
# Ctrl+C quits it (in raw mode it is a key press); at the prompt it is harmless.
Hide
Ctrl+C
Sleep 300ms
