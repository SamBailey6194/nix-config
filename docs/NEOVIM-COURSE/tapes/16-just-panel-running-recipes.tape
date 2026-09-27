Source tapes/_shared/settings.tape
Output media/16-just-panel-running-recipes/16-just-panel-running-recipes.gif
Output media/16-just-panel-running-recipes/16-just-panel-running-recipes.mp4
Require cargo
Require just
# One target directory for every capstone tape: the dependencies are built
# once, and each tape rebuilds only just-panel itself.
Env CARGO_TARGET_DIR "/tmp/nvim-course/cargo-target"
# No Neovim runs here, so claudecode.nvim cannot write an IDE lock file; the
# redirect only matters if someone adds a Neovim step later.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/16-just-panel-running-recipes.claude"

# tapes/16-just-panel-running-recipes.tape - Lesson 16: just-panel runs
# recipes. The fuzz prompt (a typed value, a changed default), the hand-over
# to the real terminal and back, Ctrl+C during a recipe (just exits 130, the
# panel survives), the sudo confirmation for rebuild --boot, and a [confirm]
# recipe that just no longer asks about because the panel passes --yes.
#
# Records examples/just-panel/JP7 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/16-just-panel-running-recipes.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/16-just-panel-running-recipes/ really holds the GIF, the MP4 and
# the six PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/just-panel/JP7 (a mini Cargo workspace:
# Cargo.toml, Cargo.lock and just-panel/) to
# /tmp/nvim-course/16-just-panel-running-recipes/rust and the demo justfile to
# docs/NEOVIM-COURSE/fixtures/just/ beside it, the repo's own layout, so the
# recorded command is the lesson's own. It builds there with --locked into the
# shared CARGO_TARGET_DIR above; cp gives every copied file a fresh time
# stamp, so cargo never mistakes another milestone's build in that directory
# for this one (examples/just-panel/MILESTONES.md has the trap). JP8 (tests
# only) would record the same frames. The first build in an empty target
# directory can take a minute or two; if it fails, the Wait after it times
# out and VHS prints the cargo error.
#
# No Neovim here: the panel gets the whole window (the prompt and dialogs want
# the room), and it is the panel's behaviour that the lesson's steps point at.
#
# Deterministic, harmless and private:
# - Every recipe runs in the demo justfile's copy under
#   /tmp/nvim-course/16-just-panel-running-recipes. Every demo recipe only
#   echoes or sleeps; the "sudo" in rebuild is inside an echo, so no password
#   prompt can appear.
# - Nothing on screen comes from your real justfile, shell history or prompt:
#   VHS starts its own bash with no rc files.
#
# Anchors. Each run's output stays on the terminal's normal screen, so the
# waits for a hand-over match that run's own last output line together with
# the pause line below it; a bare /Press Enter/ would match an earlier run.
# "Tab next field" and "Run this?" exist only while the prompt or the
# confirmation is open. "Lesson 16 - " is printed by printf from
# "Lesson %s - ", so the typed command never matches it.

# --- Setup (hidden: Hide is the first non-Set command, so nothing is recorded).
Hide
Type `L=/tmp/nvim-course/16-just-panel-running-recipes && rm -rf "$L" "$L.claude" && mkdir -p "$L/docs/NEOVIM-COURSE/fixtures" && cp -r fixtures/just "$L/docs/NEOVIM-COURSE/fixtures/" && cp -r examples/just-panel/JP7/. "$L/rust" && cd "$L/rust"`
Enter
Wait
# Build first, quietly, so the recorded start shows no compiler output. The
# caption stays at the top of the normal screen, so it shows during every
# hand-over.
Type `cargo build --locked -q -p just-panel && clear && printf 'Lesson %s - Enter runs a recipe: prompt, hand-over, Ctrl+C, confirmations\n' 16`
Enter
Wait+Screen@300s /Lesson 16 - /
Type "cargo run -q -p just-panel -- -f ../docs/NEOVIM-COURSE/fixtures/just/justfile"
Enter
# The panel's hint line (the caption also says "Enter run", so not that).
Wait+Screen /help . q quit/
Sleep 1s
Show

Sleep 1.5s

# --- 1. The prompt. / filters, Enter keeps the filter, Enter again begins
# the run. fuzz has parameters, so the prompt opens with TIME pre-filled.
Type "/fuzz"
Sleep 800ms
Enter
Sleep 800ms
Enter
Wait+Screen /Tab next field/
Sleep 1.5s
Type "demo"
Sleep 800ms
# Tab moves to TIME; Backspace deletes the default 5.
Tab
Sleep 800ms
Backspace
Sleep 400ms
Type "3"
Sleep 1s
Screenshot media/16-just-panel-running-recipes/prompt.png
Sleep 200ms

# --- 2. The hand-over. Enter runs `just fuzz demo 3` on the normal screen,
# then the panel prints the exit status and waits.
Enter
Wait+Screen /second 3 of 3\s+\[just-panel\] exit status: 0\s+Press Enter to return to just-panel/
Sleep 1.5s
Screenshot media/16-just-panel-running-recipes/handover.png
Sleep 200ms
Enter
Wait+Screen /fuzz: exit 0/
Sleep 1.5s
Screenshot media/16-just-panel-running-recipes/back.png
Sleep 200ms

# --- 3. Ctrl+C during a recipe. Same recipe, 10 seconds this time.
Enter
Wait+Screen /Tab next field/
Sleep 800ms
Type "demo"
Sleep 400ms
Tab
Sleep 400ms
Backspace
Type "10"
Sleep 800ms
Enter
Wait+Screen /fuzzing demo, second 2 of 10/
Sleep 300ms
# Cooked mode now: Ctrl+C is SIGINT for the recipe, just AND the panel. The
# panel's do-nothing handler keeps it alive; just reports 130.
Ctrl+C
Wait+Screen /exit status: 130\s+Press Enter to return to just-panel/
Sleep 1.5s
Screenshot media/16-just-panel-running-recipes/ctrl-c.png
Sleep 200ms
Enter
Wait+Screen /fuzz: exit 130/
Sleep 1.5s

# --- 4. The sudo confirmation. Esc clears the kept filter (it does not quit
# while a filter is set); then rebuild, with --boot for its *ARGS.
Escape
Sleep 800ms
Type "/rebuild"
Sleep 800ms
Enter
Sleep 800ms
Enter
Wait+Screen /Tab next field/
Sleep 800ms
Type "--boot"
Sleep 800ms
Enter
Wait+Screen /Run this\?/
Sleep 2s
Screenshot media/16-just-panel-running-recipes/confirm-sudo.png
Sleep 200ms
# Enter would do nothing here: only y runs.
Type "y"
Wait+Screen /demo: done\s+\[just-panel\] exit status: 0\s+Press Enter to return to just-panel/
Sleep 1.5s
Enter
Wait+Screen /rebuild: exit 0/
Sleep 1s

# --- 5. A [confirm] recipe. The panel shows the justfile's own question, and
# y runs `just --yes update`, so just does not ask a second time.
Escape
Sleep 800ms
Type "/update"
Sleep 800ms
Enter
Sleep 800ms
Enter
Wait+Screen /Run this\?/
Sleep 2s
Screenshot media/16-just-panel-running-recipes/confirm-attribute.png
Sleep 200ms
Type "y"
Wait+Screen /would run: nix flake update\s+\[just-panel\] exit status: 0\s+Press Enter to return to just-panel/
Sleep 2s
Enter
Wait+Screen /update: exit 0/
Sleep 2s

# --- Teardown (hidden). Esc clears the filter, q quits the panel and puts
# the terminal back.
Hide
Escape
Sleep 500ms
Type "q"
Sleep 1s
