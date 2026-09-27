# just-panel — project spec

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

just-panel is a terminal control panel for a justfile, written in Rust with ratatui 0.30. It lists the
recipes under the justfile's own `# ====` section banners, shows what the selected recipe does, and runs it
in the real terminal, with a prompt for parameters and a confirmation step for recipes that use `sudo` or end
your session. It is the Rust capstone of the Neovim course: built in `rust/just-panel` from
[lesson 06](../lessons/06-TERMINAL.md) to [lesson 17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md), and
installed on laptop-intel by Nix like every other tool in the workspace.

## Contents

- [Goals](#goals)
- [Non-goals](#non-goals)
- [Environment](#environment)
- [Architecture](#architecture)
- [Data flow](#data-flow)
- [Screen](#screen)
- [Keymap](#keymap)
- [Running recipes and safety rules](#running-recipes-and-safety-rules)
- [Milestones](#milestones)
- [Acceptance criteria](#acceptance-criteria)
- [Testing strategy](#testing-strategy)
- [Packaging](#packaging)
- [Known limitations](#known-limitations)
- [Stretch goals](#stretch-goals)

## Goals

1. **One view of the whole justfile.** Every public recipe, in source order, under the section and
   sub-section banners the file already uses, with private recipes hidden as `just --list` hides them. On the
   repo's justfile that is 131 recipes in exactly the order of `just --summary --unsorted`.
2. **Know before you run.** The selected recipe's signature, description, section, `[group]`, dependencies,
   `[confirm]` question, a sudo warning, a hint per parameter, and its body.
3. **Run from the panel, safely.** `Enter` runs the selected recipe. Parameters are asked for and checked the
   way `just` would check them. Recipes that use `sudo`, carry `[confirm]` or end or destroy something wait for
   an explicit `y`.
4. **The real terminal while a recipe runs.** sudo's password prompt, editors, `fzf`, long output and
   `Ctrl+C` behave exactly as in a shell; the panel comes back afterwards with the exit code.
5. **Keyboard only, vim-flavoured.** `j`/`k`, `g`/`G`, `/` to filter, `?` for help, `q` to quit.
6. **Trustworthy and shippable.** Tests that run anywhere, including the Nix sandbox; clippy clean with
   `-D warnings` over all targets; packaged by `rust/nix/default.nix` and on `PATH` after `just rebuild`.

## Non-goals

- Editing the justfile. The panel reads it; Neovim edits it.
- Replacing `just`. Every run goes through `just` itself, which evaluates defaults, expressions and
  dependencies. The panel never interprets a recipe body.
- Capturing or post-processing recipe output. Output goes to the real terminal.
- Running recipes in the background, in parallel, or on a schedule.
- Mouse support.
- Full coverage of just's newer features: `[arg(…)]` options, `mod` modules and similar (see
  [Known limitations](#known-limitations)).

## Environment

| Item | Value | Where it comes from |
|---|---|---|
| Host | NixOS laptop-intel, **full** configuration | `just` (modules/core/common.nix:88) and the Rust tools (:96-97) are installed there only |
| just | 1.58.0 at the flake's pinned nixpkgs (1.46.0 on the Ubuntu host where the course was written) | The dump model accepts both |
| Rust | nixpkgs `rust_1_98` in `nix develop` and in the Nix build; rustup outside the dev shell | modules/software/development.nix:82-84; flake.nix:394-398 (devShell) |
| Crates | ratatui 0.30 (crossterm 0.29 through `ratatui::crossterm`), clap 4 with `env`, serde, serde_json, anyhow, signal-hook 0.3; insta 1.48 for tests | `rust/Cargo.toml` `[workspace.dependencies]` |
| Terminal | Kitty. The terminal must answer the cursor-position query (`ESC[6n`) that `Terminal::clear` sends; Kitty and VHS's xterm.js do | [Lesson 16](../lessons/16-JUST-PANEL-RUNNING-RECIPES.md) |
| Justfile location | `-f`/`--justfile`, then `$JUST_JUSTFILE` (a zsh session variable, home/modules/shell.nix:79), then `./justfile` | `main.rs` |

## Architecture

A binary crate, `rust/just-panel`, member of the `rust/` Cargo workspace. Six modules:

| Module | Job | Main items |
|---|---|---|
| `main.rs` | Command line, loading, the draw / read key / update loop | `Cli` (clap derive: `-f/--justfile`, env `JUST_JUSTFILE`, default `justfile`), `main`, `event_loop` |
| `justfile.rs` | The recipe model, loaded leniently from `just --dump --dump-format json` | `Recipe`, `Parameter`, `ParameterKind { Singular, Plus, Star }`, `Dependency`; `parse`, `load`, `just_command`; `Recipe::signature`, `body_lines`, `needs_sudo`, `group`, `confirm_prompt`; `Parameter::is_variadic`, `literal_default` |
| `sections.rs` | Which banner each recipe sits under, read from the justfile's source | `Section { title: Option<String>, recipes }`, `parse` |
| `app.rs` | All state and key handling. Pure: no terminal, no I/O | `Entry`, `Row { Header, Recipe }`, `Mode { Normal, Filter, Help, Prompt, Confirm }`, `Prompt`, `Confirm`, `Run`, `LastRun`, `Action { Quit, Run }`, `App` with `new`, `selected`, `handle_key`, `finished` |
| `ui.rs` | Draws the state with ratatui | `render`, and private helpers for the list, detail pane, status line, help, prompt and confirmation popups |
| `runner.rs` | Caution rules, arguments, the `just` command, and handing the terminal over | `CAUTION`, `cautions`, `arguments`, `command`, `run_in_terminal`, `survive_ctrl_c` |

Rules that keep it testable:

- `app.rs` never touches the terminal. `handle_key` changes state and returns what the event loop should do
  (`Action::Quit`, `Action::Run(run)`); `main.rs` does the I/O.
- `ui.rs` only reads the `App`. The one thing drawing changes is the list's scroll offset, which ratatui keeps
  in `ListState`.
- `runner::command` builds a `std::process::Command` that tests inspect with `get_program`/`get_args` and
  never run.
- crossterm is used only through `ratatui::crossterm`, so there is one crossterm version.

## Data flow

```text
                 -f / $JUST_JUSTFILE / ./justfile
                                │  std::path::absolute (not canonicalize: keeps symlinks)
                                ▼
 justfile source ──read──▶ sections::parse ──▶ Vec<Section> ─┐
        │                                                    ├──▶ App::new ──▶ entries (source order,
        └──▶ just --justfile F --working-directory dir(F)    │                 private hidden, rest
             --dump --dump-format json ──▶ justfile::parse ──┘                 under "Other")
                                              Vec<Recipe>
 event loop:  draw(ui::render) ──▶ event::read ──▶ App::handle_key ──▶ None | Quit | Run(run)
                                                                              │
 Run(run) ──▶ runner::run_in_terminal ──▶ just --justfile F --working-directory D [--yes] RECIPE ARGS…
                                      ──▶ ExitStatus ──▶ App::finished ──▶ status line
```

1. **Resolve the justfile.** clap takes `-f`, then `JUST_JUSTFILE`, then `justfile`. `std::path::absolute`
   makes it absolute without resolving symlinks: `just` runs a symlinked justfile's recipes in the link's
   directory, and `canonicalize` would move them to the target's directory (for a file that home-manager links
   in, into the Nix store).
2. **Read the source first.** A wrong path fails with `cannot read <path>` before anything is spawned or the
   terminal is touched.
3. **Ask `just` for the recipes.** `just --justfile F --working-directory dir(F) --dump --dump-format json`.
   Both flags are explicit because zsh exports `JUST_JUSTFILE` and `JUST_WORKING_DIRECTORY` for the nix-config
   repo, and an inherited `JUST_WORKING_DIRECTORY` beats the justfile's own directory. The dump lists recipes
   alphabetically. The model declares only the fields it uses (serde skips the rest) and keeps the fields
   whose shape varies between just releases (defaults, attributes, bodies) as `serde_json::Value`, so dumps
   from just 1.46 and 1.58 both parse.
4. **Read the banners.** A section is `# ====` / `# Title` / `# ====`; a sub-section is `# Title` directly
   above `# ----`, titled "Section / Sub". A recipe header is a first-column line whose first word comes before
   a `:`; indented lines and anything with `:=` are skipped. Sections without recipes are dropped.
5. **Merge.** `App::new` walks the sections in order and takes each recipe from the dump, so the panel shows
   exactly what `just` will run, in the order of the file. Private recipes are dropped. Recipes the banner
   parser did not find (from an `import`, say) go under "Other".
6. **Loop.** Draw, block on `event::read`, act on key presses only, repeat. A resize needs no handling: the
   next draw picks up the new size.
7. **Run.** See [Running recipes and safety rules](#running-recipes-and-safety-rules).

## Screen

- **Left, 35 %:** ` Recipes ` (or ` Recipes (filter: …) `), a bordered list. Section headers in bold cyan,
  recipes indented under them, the selection reversed with a `> ` marker. `scroll_padding(1)` keeps the header
  above a section's first recipe in view.
- **Right:** ` Recipe `, the selected recipe: its signature as `just --list` writes it (bold), its
  description, then `Section`, `Group`, `Runs first` (dependencies), `Confirm` (the `[confirm]` question),
  a yellow `Uses sudo: expect a password prompt`, one hint per parameter (`default "5"`, `has a default`,
  `required`, `optional`, plus `words separated by spaces` for `+`/`*`), and the body, dimmed. It wraps.
  With no match: `No recipe matches the filter`.
- **Bottom line:** the last run (`check: exit 0` in green, anything else in red, or `killed by a signal`),
  then `Enter run · / filter · ? help · q quit`. In filter mode it shows `/text` with a real cursor.
- **Popups**, centred on the screen (over the list and the detail pane) with the cells beneath cleared:
  - ` Keys `: the key table, as wide as its longest line, titled ` any key closes ` at the bottom.
  - ` just <recipe> `: the prompt, at most 64 columns wide. The recipe's description, one field per parameter
    with its hint underneath, the focused field's label reversed and the terminal cursor at the end of its
    value. The focused field shows the **end** of a value too long to fit. The last line is
    `Tab next field · Enter run · Esc cancel`, or the error in red.
  - ` Run this? `: yellow border, 64 columns. The run as you would type it (`just rebuild --boot`), one line
    per reason, then `y run · n or Esc cancel`.

## Keymap

A key held with `Ctrl` or `Alt` never acts as the plain key (crossterm reports `Ctrl+Q` as `q` with the
CONTROL modifier). The one exception is `Ctrl+C`, which quits from any mode: in raw mode it arrives as a key
press, not as a signal.

| Mode | Keys | Action |
|---|---|---|
| List (Normal) | `j` / `Down`, `k` / `Up` | Next / previous recipe; headers are skipped; stops at the ends |
| List | `g` / `G` | First / last recipe |
| List | `Enter` | Run the selected recipe: prompt first if it has parameters, confirmation first if it needs one |
| List | `/` | Start filtering |
| List | `Esc` | Clear a kept filter; with no filter, quit |
| List | `?` | Help popup |
| List | `q`, `Ctrl+C` | Quit |
| Filter | typing, `Backspace` | Edit the filter: recipes whose name or description contains it, in any case, under their headers |
| Filter | `Enter` / `Esc` | Keep the filter and go back to the list / clear it and go back |
| Help | any key | Close the popup |
| Prompt | typing, `Backspace` | Edit the focused field |
| Prompt | `Tab` / `Down`, `Shift+Tab` / `Up` | Next / previous field, wrapping round |
| Prompt | `Enter` | Check the values: run (or confirm first), or show the error and stay |
| Prompt | `Esc` | Cancel |
| Confirmation | `y` | Run |
| Confirmation | `n`, `Esc` | Cancel. `Enter` does nothing, so a double press can never run a sudo recipe |
| During a run | every key | Goes to `just` and the recipe; `Ctrl+C` interrupts the recipe and the panel carries on |
| The pause after a run | `Enter` | Back to the panel. `Ctrl+C` here is caught and does nothing |

## Running recipes and safety rules

**Parameters** (`runner::arguments`):

- The prompt starts with plain-string defaults typed in, so what you see is what runs. Expression defaults
  start blank and are left to `just`.
- A required singular parameter must not be blank (`SECRET is required`).
- `+NAME` needs at least one word (`FILES needs at least one value`); `+NAME` and `*NAME` are split on
  whitespace.
- Values are trimmed. Blank values at the end are left off, so `just` applies its own defaults. A blank before
  a filled value is passed as `""`, because a position cannot be skipped.
- Each value is one argv entry. What the recipe does with it is up to its body: `just` pastes `{{NAME}}` into
  the command text, so quotes in a value can break a recipe's own quoting.

**When the panel asks first** (`runner::cautions`), with every reason listed in the dialog:

1. The recipe has a `[confirm]` attribute: its own question (or `` Run recipe `name`? `` for a bare `[confirm]`).
   After `y` the panel passes `--yes`, so `just` does not ask again.
2. Its body contains the word `sudo`: "uses sudo: you will be asked for your password".
3. Its name matches the `CAUTION` table in `src/runner.rs` (a trailing `*` matches any ending):

   | Pattern | Reason |
   |---|---|
   | `lock` | locks the screen |
   | `sleep` | suspends the machine |
   | `logout` | ends the Hyprland session |
   | `clean-*` | deletes build output or old generations |
   | `fuzz-clean` | deletes fuzzing crashes and corpus |
   | `rekey-*` | re-encrypts every secret |
   | `quarantine-delete` | deletes a quarantined file for good |
   | `restic-prune` | deletes old backup snapshots |
   | `zfs-pool` | creates a ZFS pool on raw disks |
   | `raid-create` | builds a RAID array on raw disks |
   | `raid-fail` | marks a disk in an array as failed |
   | `raid-remove` | removes a disk from an array |
   | `install-nixos` | installs NixOS onto a disk |
   | `gen-hardware` | overwrites hardware-configuration.nix |

   New recipes you would hate to run by accident get a line here.

**The hand-over** (`runner::run_in_terminal`), on the terminal `ratatui::run` lent the event loop, never a
second `ratatui::init()` (which would build another `Terminal` and chain another panic hook):

1. Leave the alternate screen, then raw mode, and show the cursor.
2. Print `$ just <recipe> <args…>` and run `just --justfile F --working-directory D [--yes] <recipe> <args…>`
   with `Command::status()`, which inherits stdin, stdout and stderr and waits.
3. Print `[just-panel] <exit status>` and wait for `Enter` (`Press Enter to return to just-panel`).
4. Enter the alternate screen and raw mode, `terminal.clear()` to force a full repaint, and drop every event
   still queued, so a double-tapped `Enter` runs a recipe once.
5. `App::finished` records the recipe and its exit code for the status line.

**Ctrl+C.** In cooked mode `Ctrl+C` sends SIGINT to the whole foreground process group, the panel included.
Before the TUI starts, `survive_ctrl_c` installs a do-nothing handler with `signal_hook::flag::register`. It is
a handler and not `SIG_IGN`, because an ignored signal stays ignored in every program the panel starts, while
`exec` resets a handled one to its default. `just` reports an interrupted recipe with exit code 130.

## Milestones

Test counts are the course's; lesson 13 adds up to four parser tests of your own on top.

| Code | Lesson | What it adds | Tests | Example |
|---|---|---|---|---|
| JP0 | [06 — Terminal](../lessons/06-TERMINAL.md) | `cargo new just-panel` inside `rust/`: the workspace member, `Hello, world!` | 0 | [JP0](../examples/just-panel/JP0/) |
| JP1 | [07 — Tree](../lessons/07-TREE.md) | `[[bin]]`, a crate doc with the module map, and five one-line modules created from the tree | 0 | [JP1](../examples/just-panel/JP1/) |
| JP2 | [08 — File Pane](../lessons/08-FILE-PANE.md) | The plain data types: `Recipe`, `Parameter`, `ParameterKind`, `Dependency` | 0 | [JP2](../examples/just-panel/JP2/) |
| – | [09 — Project Pane](../lessons/09-PROJECT-PANE.md) | Investigation: the justfile's banners found with live grep and sent to quickfix, which designs JP4 | – | – |
| JP3 | [10 — LSP](../lessons/10-LSP.md) | serde parsing of `just --dump`, lenient; the recipe helpers; `just_command`; `tests/fixtures/dump.json` | 8 | [JP3](../examples/just-panel/JP3/) |
| JP4 | [11 — Completion, formatting and diagnostics](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | The section-banner parser; `tests/fixtures/justfile` | 12 | [JP4](../examples/just-panel/JP4/) |
| – | [12 — Git](../lessons/12-GIT.md) | JP0 to JP4 committed and tagged `course/jp4` | 12 | [JP4](../examples/just-panel/JP4/) |
| – | [13 — Claude Code and Codex](../lessons/13-CLAUDE-CODE-AND-CODEX.md) | `AGENTS.md` and `CLAUDE.md`; up to four Claude-drafted parser tests | 12 (+4) | – |
| JP5 | [14 — just-panel: TUI skeleton](../lessons/14-JUST-PANEL-TUI-SKELETON.md) | clap CLI, loading, `ratatui::run` and the event loop, list and detail layout, `j` `k` `g` `G` `q` | 12 | [JP5](../examples/just-panel/JP5/) |
| JP6 | [15 — just-panel: sections and filter](../lessons/15-JUST-PANEL-SECTIONS-AND-FILTER.md) | Section headers in the list, `/` filter mode, the `?` help popup | 12 | [JP6](../examples/just-panel/JP6/) |
| JP7 | [16 — just-panel: running recipes](../lessons/16-JUST-PANEL-RUNNING-RECIPES.md) | The prompt, the confirmations, the hand-over to the real terminal, the SIGINT handler, the last exit code | 12 | [JP7](../examples/just-panel/JP7/) |
| JP8 | [17 — just-panel: testing and shipping](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md) | State, runner and `TestBackend` tests, an insta snapshot, the README, the Nix package, `just rebuild` | 36 | [JP8](../examples/just-panel/JP8/) |

From lesson 12 on, every milestone ends in a commit in the repository's style (`feat(just-panel): …`).
Lesson 12 tags the JP4 commit `course/jp4`, and lessons 14 to 17 tag their milestone commits `course/jp5` to
`course/jp8`, so you can diff against and return to each milestone later. The tags stay local.

The **Example** column links the worked example for each milestone: a small Cargo workspace whose
`Cargo.toml` mirrors `rust/Cargo.toml`, with the crate in `just-panel/`. Each one builds, passes its tests
and is clippy- and rustfmt-clean. They are spoilers, so type the milestone first and compare afterwards
([examples/README.md](../examples/README.md)). The capstone recordings are made from them, not from your
repository.

## Acceptance criteria

Functional:

1. On the course's demo justfile (`docs/NEOVIM-COURSE/fixtures/just/justfile`) the list shows `default`, then
   the headers and recipes of every section in source order, including the sub-sections
   `Storage Management / Backups` and `Storage Management / Snapshots`; the private `_stamp` is absent.
2. On the repo's justfile it shows all public recipes (131 when this was written) in the order of
   `just --summary --unsorted`.
3. `j`/`k`/`Down`/`Up` skip headers and stop at the ends; `g`/`G` go to the first and last recipe.
4. `/lint` shows only `Development` with `lint`, `lint-rust` and `lint-nix`; `Enter` keeps the filter
   (`filter: lint` in the title); `Esc` clears it and keeps the selection; a second `Esc` quits.
5. `?` shows the key table with its longest line whole; any key closes it.
6. `Ctrl+Q` does not quit, `Ctrl+U` types nothing into the filter, `Alt+J` does not move; `Ctrl+C` quits.
7. `Enter` on `check` runs it at once: the normal screen shows `$ just check`, its output,
   `[just-panel] exit status: 0` and the pause; `Enter` returns with `check: exit 0` in green.
8. `fuzz` opens a prompt with TIME pre-filled `5`; a blank TARGET gives `TARGET is required`; `demo` runs
   `just fuzz demo 5`.
9. `Ctrl+C` during `fuzz demo 10` stops the recipe; `just` exits 130; the panel survives and shows
   `fuzz: exit 130` in red.
10. `rebuild` with `--boot` asks, giving the sudo reason; `Enter` does nothing, `n` runs nothing, `y` runs
    `just rebuild --boot`.
11. `update` shows its `[confirm]` question; `y` runs it with `--yes` and `just` does not ask again.
12. `lock`, `rekey-secrets` and `clean-cache` ask, with the table's reasons.
13. Two `Enter` presses that arrive together on `check` run it once.
14. A justfile reached through a symlink runs its recipes in the link's directory, as `just` does.
15. After quitting, in every case, the terminal is back in cooked mode on the normal screen with the cursor
    visible.
16. A missing justfile, broken JSON or a missing `just` fail before the TUI starts, with a message and the
    terminal untouched.

Quality:

17. `cargo test -p just-panel`: 36 tests pass (plus your lesson 13 tests), with no `.snap.new` left behind.
18. `cargo clippy -p just-panel --all-targets -- -D warnings` and `cargo fmt -p just-panel --check` are clean.
19. No test runs `just`, needs a terminal, reads `$HOME` or reads a file at run time.
20. `nix build .#just-panel` succeeds, running the tests in the sandbox; after `just rebuild`,
    `command -v just-panel` prints `/run/current-system/sw/bin/just-panel`.

## Testing strategy

| Layer | Where | How | Count |
|---|---|---|---|
| Dump model | `justfile.rs` | Parse the compiled-in `dump.json`; signatures, dependencies and attributes, body rendering, whole-word `sudo`, a synthetic just 1.58-style dump, and the `just` argv read back with `get_args` | 8 |
| Banner parser | `sections.rs` | Sections and sub-sections of the compiled-in demo justfile, source order, agreement with the dump on the recipe set, lines that are not recipe headers | 4 (+ lesson 13's) |
| State | `app.rs` | A demo `App` built from both fixtures; keys pressed with `press`/`type_keys`: order and headers, movement, filter, help, quitting, Ctrl/Alt keys, runs, the prompt, required fields, sudo and `[confirm]` confirmations, `finished` with `ExitStatus::from_raw(130 << 8)` | 12 |
| Runner | `runner.rs` | The argument rules (including a synthetic `+FILES` and a blank before a filled value), the reasons for six recipes, the argv with `--yes` before the recipe | 5 |
| Screen | `ui.rs` | `TestBackend` at 80×24: text, the highlight read from a cell's modifier, the filter, the help popup, the prompt, a 103-character value (its end and the cursor inside the popup), and the insta snapshot `main_screen` | 7 |

Principles:

- **Fixtures are compiled in.** `tests/fixtures/justfile` and `tests/fixtures/dump.json` are byte-identical
  copies of `docs/NEOVIM-COURSE/fixtures/just/`, loaded with `include_str!`. The Nix build sees only
  `rust/`, and tests never read files at run time. After changing the demo justfile, regenerate `dump.json`
  and copy both (see `docs/NEOVIM-COURSE/fixtures/just/README.md`).
- **Commands are inspected, never run.** No test starts `just` or any other process.
- **Styles are asserted through cells**, because the snapshot text has none.
- **Snapshots are committed.** A missing or stale `.snap` fails the test, and with it the Nix build. Accept a
  deliberate change with `INSTA_UPDATE=always cargo test -p just-panel` (then run the tests once more to
  remove the `.snap.new`), or with `cargo insta test -p just-panel --review` where `cargo-insta` is
  available.
- **The terminal hand-over is checked by hand**, on a real terminal, with the demo justfile: acceptance
  criteria 7 to 15. Lesson 16's recording exercises most of them.

## Packaging

- **Workspace.** `rust/Cargo.toml` lists `just-panel` in `members` and holds its shared dependencies:
  `ratatui = "0.30"` under `# CLI and terminal`, `signal-hook = "0.3"` under `# Process execution`, and
  `insta = "1.48"` under `# Testing`. The crate uses them as `{ workspace = true }`, with clap's `env`
  feature on top and `insta` as a dev-dependency.
- **Lock.** Nix builds offline from `rust/Cargo.lock`, so it must contain every dependency: any cargo command
  in `rust/` updates it. Adding the capstone grew it from 332 to 425 crates and gave nine crates the other
  tools already use newer versions, so every tool rebuilds once; `just test-rust` checks the whole workspace.
- **Nix.** One entry in `rust/nix/default.nix`, after `dev-layout`:

  ```nix
    just-panel = buildWorkspaceCrate {
      pname = "just-panel";
      description = "Terminal control panel for the nix-config justfile";
    };
  ```

  It needs no `nativeBuildInputs` or `buildInputs` (no openssl). `buildRustPackage` runs
  `cargo test --package just-panel` in release mode in the sandbox. The package appears as
  `packages.x86_64-linux.just-panel` (`nix build .#just-panel`), as `pkgs.just-panel` through the overlay
  (modules/core/base-configuration.nix:22-23), and on `PATH` on full-config hosts
  (modules/core/common.nix:96-97). At run time it needs `just`, which the same configuration installs.
- **Git.** The flake only sees tracked files: `git add` new files (the crate, `tests/fixtures/`,
  `src/snapshots/`) before `nix build` or `just rebuild`.
- **Optional.** `cargo-insta` (nixpkgs attribute `cargo-insta`) in `home/stages/dev.nix`; a Hyprland key that
  runs `kitty -e just-panel --justfile ~/Repos/personal/nix-config/justfile` (lesson 17, unverified on
  laptop-intel).

## Known limitations

- **`[arg(…)]` options** (`--name VALUE`) are passed positionally, so `just` rejects the run
  (`requires option`). Neither the repo's justfile nor the demo one uses them.
- **Modules**: recipes from `mod` modules are not listed. Recipes from `import`ed files appear under "Other".
- **Sudo detection** looks at the recipe's own body only, not at its dependencies (`clean-all` →
  `clean-generations`; the `clean-*` pattern catches that one).
- **`--yes`** also auto-confirms any `[confirm]` recipe that runs as a dependency of a confirmed one.
- **Typeahead after the hand-over**: a key typed once the panel has stepped aside goes to the recipe or
  answers the pause, so an `Enter` pressed just too late skips the pause. The output stays on the normal
  screen. Flushing it would need `tcflush`, which means `unsafe` code.
- **A failed spawn ends the panel**: if `just` cannot be started for a run (uninstalled after start-up), the
  error is printed at the pause and the panel then exits with it. The terminal is restored.
- **Only private recipes**: the panel shows `No recipe matches the filter` with no filter set.
- **SIGQUIT**: only SIGINT is handled; `Ctrl+\` during a recipe also ends the panel (the terminal is then
  already in cooked mode on the normal screen).
- **Terminals that ignore `ESC[6n`** make the resume after a run stall for about two seconds and fail.
- **Truncation**: long section titles are cut off in the list at 80 columns; confirmation reasons longer
  than about 60 characters and unfocused prompt fields are cut rather than wrapped.
- **One read**: the justfile is read at start-up. After editing it, quit and start the panel again.
- **Descriptions**: `just --dump` keeps only the last line of a multi-line comment block above a recipe.
- **Textual interpolation**: `{{NAME}}` is pasted into the recipe text by `just`, so a value with quotes can
  break a recipe such as `commit MESSAGE`.
- **Unverified on laptop-intel**: the real justfile's dump under just 1.58 (it has no attributes, so nothing
  new is expected), and whether a Hyprland-launched panel inherits `JUST_JUSTFILE`. The hand-over inside
  Neovim's own terminal was checked with Neovim 0.12.5 (resume and `Ctrl+C` behave); in `<leader>t` it only
  lacks room.

## Stretch goals

- `r` to reload the justfile without quitting.
- Full descriptions: read the whole comment block above each recipe from the source, as the banner parser
  already reads the file.
- `[arg(…)]` option parameters in the prompt, with `--name VALUE` passed correctly.
- `mod` modules as their own sections.
- Sudo detection through dependencies.
- Show a failed spawn in the status line instead of exiting.
- Handle SIGQUIT like SIGINT.
- A dry run: `just --dry-run` for the selected recipe, shown in the detail pane.
- Group by `[group('…')]` attributes as an alternative to banners.
- Recent runs and their exit codes, and a key to repeat the last run.
- A smaller dependency tree: ratatui with `default-features = false, features = ["crossterm"]` would drop the
  calendar widget's `time` dependency (untried).
- A Kitty window class and a Hyprland window rule for the panel's own window.
