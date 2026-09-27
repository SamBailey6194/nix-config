Source tapes/_shared/settings.tape
Output media/14-just-panel-tui-skeleton/14-just-panel-tui-skeleton.gif
Output media/14-just-panel-tui-skeleton/14-just-panel-tui-skeleton.mp4
Require cargo
Require just
# One target directory for every capstone tape: the dependencies are built
# once, and each tape rebuilds only just-panel itself.
Env CARGO_TARGET_DIR "/tmp/nvim-course/cargo-target"
# No Neovim runs here, so claudecode.nvim cannot write an IDE lock file; the
# redirect only matters if someone adds a Neovim step later.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/14-just-panel-tui-skeleton.claude"

# tapes/14-just-panel-tui-skeleton.tape - Lesson 14: just-panel at JP5. The
# panel lists the demo justfile's recipes in source order; j/k and the arrow
# keys move, g/G jump to the first/last recipe, the detail pane follows the
# selection, q quits and gives the shell back.
#
# Records examples/just-panel/JP5 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/14-just-panel-tui-skeleton.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/14-just-panel-tui-skeleton/ really holds the GIF, the MP4 and the
# three PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/just-panel/JP5 (a mini Cargo workspace:
# Cargo.toml, Cargo.lock and just-panel/) to
# /tmp/nvim-course/14-just-panel-tui-skeleton/rust and the demo justfile to
# docs/NEOVIM-COURSE/fixtures/just/ beside it, the repo's own layout, so the
# recorded command is the lesson's own. It builds there with --locked into the
# shared CARGO_TARGET_DIR above. cp gives every copied file a fresh time
# stamp, so cargo never mistakes another milestone's build in that directory
# for this one (examples/just-panel/MILESTONES.md has the trap).
#
# The first build in an empty target directory takes a minute or two. It uses
# the crates already in ~/.cargo/registry and downloads any that are missing.
# If it fails, the Wait after it times out after 5 minutes and VHS prints the
# last screen: the cargo error is there.
#
# Harmless and deterministic: JP5 cannot run recipes at all, and the panel
# reads the demo justfile (fixtures/just/justfile) through `just --dump` only.
# Anchor texts: "Lesson 14 - " is printed by printf from "Lesson %s - ", so
# the typed command never matches it; "first.last" is JP5's key-hint line
# (JP6 replaces it), and the other anchors are recipe descriptions from the
# demo justfile that appear in no caption.

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded).
Hide
Type `L=/tmp/nvim-course/14-just-panel-tui-skeleton && rm -rf "$L" "$L.claude" && mkdir -p "$L/docs/NEOVIM-COURSE/fixtures" && cp -r fixtures/just "$L/docs/NEOVIM-COURSE/fixtures/" && cp -r examples/just-panel/JP5/. "$L/rust" && cd "$L/rust"`
Enter
Wait
# Build first, so the recorded `cargo run` starts the panel at once. `clear`
# then wipes the typed command, and printf leaves only the caption.
Type `cargo build --locked -q -p just-panel && clear && printf 'Lesson %s - just-panel JP5: the recipe list, the detail pane, j k g G q\n' 14`
Enter
Wait+Screen@300s /Lesson 14 - /
Show

Sleep 1s
# The command the lesson runs with :TermExec, from rust/ in the same layout.
Type "cargo run -p just-panel -- -f ../docs/NEOVIM-COURSE/fixtures/just/justfile"
Sleep 500ms
Enter
Wait+Screen /first.last/
Sleep 1.5s
Screenshot media/14-just-panel-tui-skeleton/start.png
Sleep 200ms

# j twice: edit-secret, then rekey-secrets. The detail pane follows.
Type "j"
Sleep 800ms
Type "j"
Wait+Screen /Rekey all secrets/
Sleep 1s

# j: rebuild, a shebang recipe with a *ARGS parameter that mentions sudo.
Type "j"
Wait+Screen /Uses sudo/
Sleep 2s
Screenshot media/14-just-panel-tui-skeleton/rebuild.png
Sleep 200ms

# The arrow keys do the same as j and k.
Down
Sleep 800ms
Down
Sleep 800ms
Up
Sleep 800ms

# G: the last recipe, snapshot (two parameters, sudo again).
Type "G"
Wait+Screen /Create BTRFS snapshot/
Sleep 1.5s
Screenshot media/14-just-panel-tui-skeleton/last.png
Sleep 200ms

# k: backup-status, which runs the private _stamp first. _stamp itself is
# not in the list.
Type "k"
Wait+Screen /Runs first/
Sleep 1.5s

# g: back to the first recipe.
Type "g"
Wait+Screen /Default recipe shows help/
Sleep 1s

# k on the first recipe stays put: the list does not wrap round.
Type "k"
Sleep 1s

# q quits: the alternate screen goes, and the shell is back as it was.
Type "q"
Wait
Sleep 1.5s

# --- Teardown (hidden). If a key went missing and the panel is still open,
# Ctrl+C quits it (in raw mode it is a key press); at the prompt it is harmless.
Hide
Ctrl+C
Sleep 300ms
