Source tapes/_shared/settings.tape
Output media/17-just-panel-testing-and-shipping/17-just-panel-testing-and-shipping.gif
Output media/17-just-panel-testing-and-shipping/17-just-panel-testing-and-shipping.mp4
Require nvim
Require cargo
# One target directory for every capstone tape: the dependencies are built
# once, and each tape rebuilds only just-panel itself.
Env CARGO_TARGET_DIR "/tmp/nvim-course/cargo-target"
# Never write snapshot files: if the main_screen snapshot did not match, insta
# would otherwise leave a .snap.new behind.
Env INSTA_UPDATE "no"
# zsh-autosuggestions would offer lines from your real shell history as grey
# text while the tape types. Ignoring every history entry keeps them off screen.
Env ZSH_AUTOSUGGEST_HISTORY_IGNORE "*"
# claudecode.nvim starts its server with Neovim and writes an IDE lock file
# under $CLAUDE_CONFIG_DIR/ide (default ~/.claude/ide). Point it at a
# throwaway directory so no run, not even an aborted one, leaves a lock there.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/17-just-panel-testing-and-shipping.claude"

# tapes/17-just-panel-testing-and-shipping.tape - Lesson 17: the committed
# insta snapshot open in Neovim (the snapshot IS the screen), then
# `cargo test -p just-panel`, `cargo clippy ... -D warnings` and
# `cargo fmt --check` in the <leader>t terminal.
#
# Records examples/just-panel/JP8 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/17-just-panel-testing-and-shipping.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/17-just-panel-testing-and-shipping/ really holds the GIF, the MP4
# and the three PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/just-panel/JP8 (a mini Cargo workspace:
# Cargo.toml, Cargo.lock and just-panel/, snapshot included) to
# /tmp/nvim-course/17-just-panel-testing-and-shipping/rust and works there:
# - Neovim opens the snapshot with -R and quits with :qa!, so nothing is saved.
# - Every cargo command builds into the shared CARGO_TARGET_DIR above, and the
#   hidden build uses --locked, so Cargo.lock cannot change. cp gives every
#   copied file a fresh time stamp, so cargo never mistakes another
#   milestone's build in that directory for this one.
# - INSTA_UPDATE=no (above): a failing snapshot writes nothing.
#
# The terminal is your real zsh (toggleterm runs $SHELL), started in the
# copied rust/ folder, so its prompt shows a /tmp/nvim-course/... path. The
# hidden build runs in that same zsh, so it uses the same Rust toolchain as
# the recorded commands. It can take minutes if the shared target directory
# is still empty, and seconds after tapes 14 to 16. The terminal is cleared
# afterwards, so neither the build nor any shell start-up message is
# recorded.
#
# Anchors: "Default recipe shows help" is in the snapshot file only.
# READY-17/FAILED-17 are printed with printf, so the typed command (which
# contains READY-%s) cannot match them. "test result: ok. N passed" matches
# any count (the worked example has 36). "Finished `dev` profile" comes from
# clippy only: cargo test prints "Finished `test` profile".

# --- Setup (hidden: Hide is the first non-Set command, so nothing is recorded).
Hide
Type `L=/tmp/nvim-course/17-just-panel-testing-and-shipping && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r examples/just-panel/JP8/. "$L/rust" && cd "$L/rust" && clear`
Enter
Wait
# Neovim starts in rust/, as in lessons 14 to 17, so the terminal and cargo do
# too. A file argument skips the bare-start dock layout; -i NONE keeps ShaDa
# out; -R opens the snapshot read-only.
Type "nvim -i NONE -R just-panel/src/snapshots/just_panel__ui__tests__main_screen.snap"
Enter
Wait+Screen /Default recipe shows help/
Sleep 1s
# <leader>t: the bottom terminal, in Terminal mode (start_in_insert).
Type " t"
Sleep 3s
Type "cargo test -q -p just-panel --locked --no-run && cargo clippy -q -p just-panel --locked --all-targets -- -D warnings && printf 'READY-%s\n' 17 || printf 'FAILED-%s\n' 17"
Enter
Wait+Screen@900s /(READY|FAILED)-17/
Type "clear"
Enter
Sleep 1s
# Back to Normal mode and up to the snapshot window for the caption. The
# terminal remembers that it was left in Normal mode.
Ctrl+\
Ctrl+n
Sleep 300ms
Ctrl+k
Sleep 500ms
Type@10ms ":echo 'Lesson 17 - the snapshot is the screen; cargo test and clippy in <leader>t'"
Enter
Show

Sleep 2s
# The committed snapshot: the first screen of the demo justfile at 80x24.
Screenshot media/17-just-panel-testing-and-shipping/snapshot.png
Sleep 200ms

# <C-j> is window-down. <C-\><C-n> makes sure of Normal mode (a no-op when
# already there), and i enters Terminal mode to type.
Ctrl+j
Sleep 800ms
Ctrl+\
Ctrl+n
Sleep 300ms
Type "i"
Sleep 500ms
Type "cargo test -p just-panel"
Sleep 500ms
Enter
Wait+Screen@180s /test result: ok\. \d+ passed/
Sleep 2s
Screenshot media/17-just-panel-testing-and-shipping/cargo-test.png
Sleep 200ms

Type "cargo clippy -p just-panel --all-targets -- -D warnings"
Sleep 500ms
Enter
Wait+Screen@180s /Finished .dev. profile/
Sleep 2s
Screenshot media/17-just-panel-testing-and-shipping/clippy.png
Sleep 200ms

Type "cargo fmt -p just-panel --check && printf 'fmt: %s\n' clean"
Sleep 500ms
Enter
Wait+Screen@60s /fmt: clean/
Sleep 2.5s

# --- Teardown (hidden). Out of Terminal mode first (Escape would go to zsh),
# then quit, so claudecode.nvim's VimLeavePre handler removes its lock file.
Hide
Ctrl+\
Ctrl+n
Sleep 300ms
Type ":qa!"
Enter
Sleep 500ms
