# just-panel milestone notes: JP0 to JP8

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Notes on the worked examples for the Rust capstone: for each milestone, the lesson that builds it, the files it
changes, why, the traps met while building it, and the check results. The lessons print the code from these
folders byte for byte. How to use the examples is in [../README.md](../README.md).

- **Layout**: `JP0/` … `JP8/`. Each is a complete mini Cargo workspace: `JPn/Cargo.toml` mirrors
  `rust/Cargo.toml` (same `[workspace.package]`, resolver 2, only the `[workspace.dependencies]` the crate
  uses, in the same groups as the real file), the crate lives in `JPn/just-panel/`, and `JPn/Cargo.lock` is
  what cargo generated for that workspace.
- **Tools**: `check.sh` (the four checks), `smoke.py` and `smoke-all.sh` (runs on a real pseudo-terminal).
- **Built with**: rustc/cargo 1.92.0 (rustup), just 1.46.0 and Python 3.12.3 on Ubuntu, on 27/09/2026.
  Checked again with laptop-intel's own versions from the flake's pinned nixpkgs (`20b1ddd`), fetched with
  Nix: rustc/cargo 1.98.1, clippy 0.1.98, rustfmt 1.9.0 and just 1.58.0.
- **Resolved versions (JP8 lock)**: ratatui 0.30.2, crossterm 0.29.0 (through `ratatui::crossterm`),
  signal-hook 0.3.18, insta 1.48.0, clap 4.6.7 (the real `rust/Cargo.lock` keeps 4.5.54), serde 1.0.229,
  serde_json 1.0.151, anyhow 1.0.104.

## Contents

- [How the checks run](#how-the-checks-run)
- [JP0: cargo new (lesson 06)](#jp0-cargo-new-lesson-06)
- [JP1: module files (lesson 07)](#jp1-module-files-lesson-07)
- [JP2: plain data types (lesson 08)](#jp2-plain-data-types-lesson-08)
- [JP3: serde parsing of just --dump (lesson 10)](#jp3-serde-parsing-of-just---dump-lesson-10)
- [JP4: section-banner parser (lesson 11)](#jp4-section-banner-parser-lesson-11)
- [JP5: ratatui skeleton (lesson 14)](#jp5-ratatui-skeleton-lesson-14)
- [JP6: section headers, / filter, ? help (lesson 15)](#jp6-section-headers--filter--help-lesson-15)
- [JP7: running recipes (lesson 16)](#jp7-running-recipes-lesson-16)
- [JP8: tests, snapshot, README, shipping (lesson 17)](#jp8-tests-snapshot-readme-shipping-lesson-17)
- [The demo justfile and its dump](#the-demo-justfile-and-its-dump)
- [Verified facts](#verified-facts)
- [Design decisions](#design-decisions)
- [Known limitations](#known-limitations)
- [Fixes found in testing](#fixes-found-in-testing)

## How the checks run

Every milestone is checked with `check.sh`, which runs these in `JPn/`:

```bash
# in docs/NEOVIM-COURSE/examples/just-panel
./check.sh JP5        # or: ./check.sh all
# which runs, in JP5/, with CARGO_TARGET_DIR=${TMPDIR:-/tmp}/just-panel-examples-target by default:
touch just-panel/src/main.rs          # see "The shared target folder" below
cargo build --locked
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
cargo fmt --check
```

A check counts as PASS only with exit code 0 **and** no `warning` lines (rustc warnings do not fail
`cargo build` by themselves). `--locked` makes cargo stop rather than rewrite the example's `Cargo.lock`.

**The shared target folder, a trap found on the way.** Every milestone's crate sits at the same
workspace-relative path (`just-panel`), and cargo keys fingerprints on that relative path and on file
mtimes. With one shared `CARGO_TARGET_DIR`, a milestone whose files are older than the last build is taken
as up to date and the previous milestone's artefacts are reused (JP4 once reported JP3's 8 tests).
`check.sh` and `smoke-all.sh` therefore touch `src/main.rs` first. As an independent cross-check, every
milestone was also built and tested once in its own empty target folder, with identical results. A fresh
`cp -r` of a milestone avoids the trap too, because the copy's files are newer than any earlier build.

**The NixOS toolchain.** All nine milestones were checked again with the pinned nixpkgs toolchain (rustc
1.98.1, clippy 0.1.98, rustfmt 1.9.0), each in its own target folder, with `--locked --offline` (so every
`Cargo.lock` is exact): all PASS, same test counts. One trap on the way: cargo looks for `cargo-clippy` and
`cargo-fmt` in `$CARGO_HOME/bin` before `PATH`, so with rustup installed, `cargo clippy` silently ran
rustup's clippy 0.1.92 even with the Nix clippy first on `PATH`. That run therefore used a separate
`CARGO_HOME` that shares only the registry. laptop-intel installs rustup too
(`modules/software/development.nix`), and inside nix-config direnv puts the flake's nixpkgs cargo first on
`PATH`, so the same can happen there: `cargo clippy --version` shows which clippy actually runs.

**Real-terminal smoke runs** (JP5 onwards): `smoke-all.sh` builds each milestone and runs

```bash
# in docs/NEOVIM-COURSE/examples/just-panel
uv run --no-project --with pyte python smoke.py "$CARGO_TARGET_DIR/debug/just-panel" <scenario>
```

with the course's demo justfile, `../../fixtures/just/justfile`. `smoke.py` forks the binary onto a new pty
as its controlling terminal (`os.login_tty`, 100×30, `TERM=xterm-256color`, `JUST_*` removed from the
environment), feeds keys, renders the output with pyte, and after exit checks: exit code 0, the pty's
termios identical to before launch (cooked mode, echo and signals restored), the alternate screen left last
(`ESC[?1049l` after the last `ESC[?1049h`) and the cursor visible (`ESC[?25h` after the last `ESC[?25l`). It
answers crossterm's cursor-position query (`ESC[6n`) the way a real terminal does; see verified fact 5.

| Scenario | Keys and checks |
|----------|-----------------|
| `navigate` | Detail pane shows `default`; `j j` → `rekey-secrets`; `G` → `snapshot` (sudo flagged); `g`; `k` at the top stays; `Down`; private `_stamp` hidden; `q`. |
| `ctrl-c` | `Ctrl+C` in the TUI (raw mode) quits cleanly. |
| `filter-help` | Section and sub-section headers; `/lint` shows `/lint` in the status line; `Ctrl+U` types nothing; only matching recipes and headers; `Enter` keeps (`filter: lint` in the title); `j`; `Esc` clears and keeps the selection; `?` popup, with its longest line (`… Esc clears it`) whole; any key closes it; `q`. |
| `ctrl-keys` | `Ctrl+Q` does not quit and `Alt+J` does not move (crossterm reports them as `q`/`j` plus a modifier); `q`. |
| `run` | `check` runs (output, `exit status: 0`, "Press Enter to return"), `Enter` resumes, status `check: exit 0`. `fuzz` prompt (TARGET, `default "5"`), type `demo`, run, `Ctrl+C` after 2 s: recipe terminated, just exits 130, panel survives, status `fuzz: exit 130`. `rebuild` prompt, `--boot`, sudo confirmation, `y`, runs with `--boot`. `update` `[confirm]` dialog: `n` runs nothing; `Enter`, `y` runs with `--yes` (just does not ask again). `edit-secret` with blank SECRET: "SECRET is required"; `Esc` closes the prompt; `q`. |
| `typeahead` | Two `Enter` presses in one write on `check`: it runs once, and after one `Enter` at the pause the list is back with `check: exit 0`. |
| `symlink` | A temporary `link/justfile` symlinked to `real/justfile`, whose recipe runs `pwd`: the recipe prints the `link` directory, as `just` would, and not `real`. |

---

## JP0: `cargo new` (lesson 06)

**Files**: `Cargo.toml` (workspace, member line), `just-panel/Cargo.toml`, `just-panel/src/main.rs`
(`Hello, world!`), all exactly as `cargo new` produces them.

**Rationale and verified facts** (cargo 1.92.0, in a throwaway git repository holding a copy of
`rust/Cargo.toml`):

- Inside a workspace, `cargo new just-panel` writes `version.workspace = true`,
  `edition.workspace = true`, `authors.workspace = true` and `license.workspace = true` itself, and adds
  the member to `rust/Cargo.toml` automatically. It prints `Adding 'just-panel' as member of workspace at …`.
- It mangles the commented members list: `"dev-layout", "just-panel",        # Hyprland dev layout launcher`.
  Lesson 06 has you tidy it into its own line: `    "just-panel",        # TUI control panel for the justfile`.
- Inside an existing git repo it creates no nested `.git` and no `.gitignore` (outside a repo it creates
  both).
- `cargo run -p just-panel` in `rust/` prints `Hello, world!` and adds a `just-panel` entry to
  `rust/Cargo.lock`.

**Checks**: build PASS · test PASS (0 tests) · clippy PASS · fmt PASS.

## JP1: module files (lesson 07)

**Files**: `just-panel/Cargo.toml` gains `[[bin]] name = "just-panel" path = "src/main.rs"` (every crate in
`rust/` declares `[[bin]]`, dev-layout included). New `src/justfile.rs`, `sections.rs`, `app.rs`, `ui.rs`,
`runner.rs`, each only a one-line `//!` module doc. `src/main.rs` gains a crate doc with a module map and the
five `mod` lines (in rustfmt's alphabetical order).

**Rationale**: a module that holds only a doc comment has no items, so nothing can be unused, and JP1
compiles warning-free with no `allow` at all.

**Checks**: build PASS · test PASS (0 tests) · clippy PASS · fmt PASS.

## JP2: plain data types (lesson 08)

**Files**: `src/justfile.rs` gains `Recipe { name, doc, parameters, dependencies, private }`,
`Parameter { name, kind, default: Option<String> }`, `ParameterKind { Singular, Plus, Star }` and
`Dependency { recipe }`. `src/main.rs` gains a crate-level `#![allow(dead_code)]` with a comment explaining
why.

**Rationale**: the types are typed from the spec with no serde yet. Nothing calls them until the TUI is
wired up in JP5, and without the `allow` rustc reports every type as unused (11 warnings by JP3, verified by
deleting the line). The only alternative is throwaway callers in `main`, so the `allow` is the lesser evil.
It is scoped to that one lint, carries a comment, and JP5 deletes it.

**Checks**: build PASS · test PASS (0 tests) · clippy PASS · fmt PASS.

## JP3: serde parsing of `just --dump` (lesson 10)

**Files**: `Cargo.toml` gains `[workspace.dependencies]` `anyhow`, `serde`, `serde_json` (copied from
`rust/Cargo.toml`). `just-panel/Cargo.toml` gains the three `{ workspace = true }` deps.
`src/justfile.rs` (+330 −6) gains:

- serde derives, with `default` changed to `Option<serde_json::Value>`. The lesson's LSP moment: a real
  dump holds expression arrays there, so `String` was too optimistic. New fields `attributes: Vec<Value>`
  and `body: Value`.
- `Dump { recipes: BTreeMap }`, `parse(&str)`, `load(&Path)` (runs just; never called by tests) and
  `just_command(&Path)`, which builds `just --justfile F --working-directory dir(F)`. Its doc comment says
  the path should be absolute ("`main` makes it so").
- Helpers: `Recipe::signature`, `body_lines`, `needs_sudo` (whole-word `sudo` in the body text), `group`,
  `confirm_prompt`; `Parameter::is_variadic`, `literal_default`; and `Display for Parameter` in
  `just --list` style.
- 8 unit tests.

New `tests/fixtures/dump.json`, a byte-identical copy of the course fixture `fixtures/just/dump.json`.

**Rationale**: lenient by construction. Only the fields used are declared (serde ignores unknown fields),
and shape-varying fields are `Value`. A test feeds a synthetic just 1.58-style dump (`flag`, `min`, `max`,
`multiple`, expression `value` and `default`, top-level `module_path`, `{"confirm": null}`) and passes.
Fixtures are compiled in with `include_str!`, so tests never read files at run time or reach `docs/`. The
command-builder test inspects `Command::get_args()` without running anything.

**Checks**: build PASS · test PASS (8 passed) · clippy PASS · fmt PASS.

## JP4: section-banner parser (lesson 11)

**Files**: `src/sections.rs` (+200) gains `Section { title: Option<String>, recipes }`, `parse`, and
slice-pattern helpers `banner`, `sub_banner`, `comment`, `is_ruler`, `title`, `recipe_name`, plus 4 tests.
New `tests/fixtures/justfile` (a byte-identical copy of `fixtures/just/justfile`).

**Rationale**:

- Banners are `# ===` / `# Title` / `# ===`. Sub-sections are `# Title` over `# ---`, titled
  "Section / Sub". A recipe header is a first-column line whose first word comes before a `:`; indented
  lines and anything with `:=` (assignment, alias, set) are skipped. Sections without recipes are dropped.
- Verified once against the repository's real `justfile` (via `#[path]`, not a crate test): 131/131
  recipes, in exactly the order of `just --summary --unsorted`, with these per-section counts at the time of
  writing: 1, 7, 18, 10, 6, 9, 4, 4, 3, 1, 3, 4, 10, 14, 15, 9, 11, 2.
- Lesson 11 material: the first draft of the loop tripped clippy `manual_map` (an
  `else if let Some(x) = … { Some(…) } else { None }`). The shipped code is clippy's suggestion
  (`sub_banner(…).map(|title| …)`), which is a real "fix it with a code action" example.
- One test checks that the parser and just agree on the recipe set (the parser's names, sorted, against
  the dump fixture).

**Checks**: build PASS · test PASS (12 passed) · clippy PASS · fmt PASS.

## JP5: ratatui skeleton (lesson 14)

**Files**: `Cargo.toml` gains `clap` (the exact `rust/Cargo.toml` line) and `ratatui = "0.30"`.
`just-panel/Cargo.toml` gains `clap = { workspace = true, features = ["env"] }` and
`ratatui = { workspace = true }`. `src/main.rs` (+56 −8) loses `#![allow(dead_code)]` and gains:

- `Cli` (clap derive: `-f/--justfile`, `env = "JUST_JUSTFILE"`, default `justfile`), made absolute with
  `std::path::absolute` so the working directory is never empty. Not `fs::canonicalize`: it also resolves
  symlinks, which moves the recipes of a symlinked justfile (home-manager links files in from the Nix
  store) away from where `just` itself runs them. The source is read before `just --dump` runs, so a wrong
  path fails with `cannot read …` before anything is spawned.
- `ratatui::run(|terminal| event_loop(…))`, and `event_loop`: draw, `event::read()`, act on
  `KeyEventKind::Press` only.

New code in `src/app.rs` (+129): `Entry`, `Action::Quit`, `App { entries, list: ListState }`, `App::new`
(merges dump and sections, hides private recipes, puts unmatched recipes under "Other"), `selected`, and
`handle_key` (Ctrl+C, q, Esc, j/k/Down/Up, g/G, with its own clamped movement). Any other key held with Ctrl
or Alt is ignored: crossterm reports Ctrl+Q as `q` plus CONTROL, so without that check Ctrl+Q quits, and
from JP6 on Ctrl+U would type a `u` into the filter. New code in `src/ui.rs` (+115): `render` (vertical
status split, horizontal 35 % list), detail pane (signature, doc, section, group, dependencies, confirm,
sudo, parameter hints, body), and the key hints line.

**Rationale**:

- crossterm is used only through `ratatui::crossterm`, and the event loop lives in `main.rs` while
  `app.rs` stays pure. Movement is done by hand because `ListState::select_next`/`select_last` only clamp
  at render time.
- The detail pane shows the section title, so `sections.rs` and `Section::title` are genuinely used before
  JP6. With the `allow` gone, the compiler confirms every JP2 to JP4 item is used.
- `runner.rs` is still a doc-only stub.

**Checks**: build PASS · test PASS (12 passed) · clippy PASS · fmt PASS.
**Smoke**: `navigate` 14/14, `ctrl-c` 6/6, `ctrl-keys` 7/7. Verified: in raw mode, Ctrl+C arrives as a key
press, not SIGINT.

## JP6: section headers, `/` filter, `?` help (lesson 15)

**Files**: `src/app.rs` (+125 −8) gains `Row { Header, Recipe(usize) }`, `Mode { Normal, Filter, Help }`,
`rows`, `mode`, `filter`, and `Entry::matches` (name or doc, case-insensitive). It gains `normal_key`,
`filter_key` and `refresh`, which rebuilds rows with a header over each section's first match and keeps the
selected recipe if it still matches. `selectable()` now yields recipe rows only, so j/k/g/G skip headers.
`src/ui.rs` (+69 −11) renders headers (bold cyan) and indented recipes, shows `Recipes (filter: …)` in the
title, puts the status line in filter mode (`/text` plus a real cursor via `set_cursor_position`), and adds
the `KEYS` table, `render_help` (`Clear` + centred `popup()` helper, as wide as its longest line) and
`.scroll_padding(1)` on the list.

**Rationale**:

- In normal mode, Esc clears a kept filter before it quits (a refinement of JP5's "Esc quits").
- `scroll_padding(1)` fixes a real bug found against the 131-recipe justfile: after `G` and then `/vpn`,
  the old scroll offset hid the "VPN Management …" header above the first match. One row of padding keeps
  the header in view. Verified on a pty against the real justfile (read-only: only `just --dump` runs).
- `popup()` and `KEYS` as a slice exist here so that JP7's diff stays additive.
- The help popup measures its lines (`Line::width`) instead of using a fixed width. The first draft
  hard-coded 48 columns, and the `/` row (49 columns inside the border) lost the "it" of "Esc clears it"
  without any test noticing.

**Checks**: build PASS · test PASS (12 passed) · clippy PASS · fmt PASS.
**Smoke**: `navigate` 14/14, `filter-help` 20/20, `ctrl-c` 6/6, `ctrl-keys` 7/7.

## JP7: running recipes (lesson 16)

**Files**: `Cargo.toml` gains `signal-hook = "0.3"` (under `# Process execution`), and
`just-panel/Cargo.toml` gains the matching dep. `src/runner.rs` (+186) gains:

- `CAUTION`, a data table of `(pattern, reason)`, where a trailing `*` is a prefix.
- `cautions(&Recipe)`: the `[confirm]` prompt, then "uses sudo", then table matches.
- `arguments(&[Parameter], &[String])`: required singular must be non-blank, `+` needs at least one word,
  `+`/`*` split on whitespace, trailing blanks are dropped so just applies its defaults, and a blank before
  a filled value is passed as `""`.
- `command(&Path, &Run)`: `--yes` goes before the recipe name.
- `run_in_terminal(&mut DefaultTerminal, &Path, &Run)`: leave the alternate screen, disable raw mode,
  `show_cursor`, print `$ just …`, `Command::status()`, print the `ExitStatus`, pause on "Press Enter to
  return to just-panel", enter the alternate screen, enable raw mode, `terminal.clear()`, then drop every
  event still queued (`while event::poll(Duration::ZERO)? { event::read()?; }`). It never calls
  `ratatui::init` again.
- `survive_ctrl_c()`: `signal_hook::flag::register(SIGINT, …)`.

`src/app.rs` (+154 −1) gains `Mode::Prompt(Prompt)`, `Mode::Confirm(Confirm)` and `#[derive(Default)]`
(Normal). It gains `Run` with `Display` (`just rebuild --boot`), `LastRun`, `Action::Run`, `last_run`,
`finished()`, `begin` (prompt pre-filled with literal defaults), `start` (confirm or run), `prompt_key`
(typing, Backspace, Tab/BackTab/Up/Down, Enter validates, Esc) and `confirm_key` (`y` via `mem::take`;
`n`/Esc). Enter is deliberately **not** yes. `src/main.rs` (+11 −7) installs the SIGINT handler before
`ratatui::run`, passes the justfile to the loop, and handles `Action::Run`. `src/ui.rs` (+99 −8) gains
`render_prompt` (focused label reversed, hints from `describe()`, cursor in the focused field, which shows
the end of a value too long to fit via a small `tail()` helper), `render_confirm` (yellow border, reasons,
`y`/`n`), the `Enter` row in `KEYS`, and the last exit code (green 0, red otherwise) in the status line.

**Rationale, and the Ctrl+C decision**:

- **Why a handler.** In the cooked terminal, Ctrl+C sends SIGINT to the whole foreground process group,
  just-panel included. A do-nothing handler keeps the panel alive, and `exec` resets handled signals to the
  default, so just and the recipe behave as if started from a shell.
- **Why not SIG_IGN.** An ignored disposition survives `exec` into every child. Verified: just 1.46
  installs its own SIGINT handler, so recipes run *through just* would still be interruptible even under
  SIG_IGN, but the panel should not rely on that. So the precise claim is "SIG_IGN would be inherited by
  every child", not "SIG_IGN would make recipes uninterruptible".
- **Why signal-hook.** signal-hook 0.3.18 is already compiled into the binary (crossterm uses it for
  SIGWINCH), so it adds **no** crate. ctrlc 3.5 would add nix 0.30, a second nix next to the workspace's
  0.27. `flag::register` is a safe API. Its flag is never read, as the doc comment says.
- **Exit codes.** Verified with the course fixture (`fuzz demo` on a pty, Ctrl+C after 2 s): just prints
  ``error: recipe `fuzz` was terminated on line 65 by signal 2`` and exits 130. The line is the fixture's
  `fuzz` body line, and the word is `recipe` in just 1.58.0 but `Recipe` in 1.46.0 (in general:
  ``error: recipe `<name>` was terminated on line <n> by signal 2``). The status line shows `fuzz: exit 130`.
- **A bug the pty run caught.** The first draft left `Mode::Prompt` set while the recipe ran, so after
  "Press Enter" the prompt reopened and swallowed keys. `start()` now resets the mode to Normal before
  returning `Action::Run`.
- **Queued keys are dropped after a run.** crossterm reads everything the terminal has sent and queues the
  events. A double-tapped Enter that arrives in one read leaves the second Enter in the queue, and the first
  draft replayed it as soon as the list was back: the recipe ran twice (reproduced on the pty). Draining the
  queue after `terminal.clear()` fixes it.
- **Long prompt values.** The prompt is at most 64 columns wide, and a value that did not fit ran past the
  border: the text being typed and the cursor were out of view (the real justfile's `commit MESSAGE` hits
  this). The focused field now shows the end of its value.
- **Cooked mode really is restored for the child.** A test recipe running `stty -a` saw
  `isig icanon echo`, and `read -p` received typed input, which is what sudo needs. Ctrl+C at the "Press
  Enter" pause is harmless: the handler runs, and `read_line` retries on EINTR.

**Checks**: build PASS · test PASS (12 passed) · clippy PASS · fmt PASS.
**Smoke**: `navigate` 14/14, `filter-help` 20/20, `ctrl-c` 6/6, `ctrl-keys` 7/7, `run` 33/33,
`typeahead` 9/9, `symlink` 7/7. The same seven pass with laptop-intel's just 1.58.0 and cargo 1.98 first on
`PATH`.

## JP8: tests, snapshot, README, shipping (lesson 17)

**Files**: `Cargo.toml` gains `# Testing` / `insta = "1.48"`, and `just-panel/Cargo.toml` gains
`[dev-dependencies] insta = { workspace = true }`. Tests are appended to existing files and no production
code changes:

- `src/app.rs` (+240): `pub mod tests` with the `demo()`, `press()` and `type_keys()` helpers (shared with
  ui tests) and 12 pure-state tests: order and headers, private hidden, header-skipping movement and ends,
  filter keep/clear/selection, description match and empty result, help and quitting from every mode,
  Ctrl/Alt keys are not plain keys (Ctrl+U, Ctrl+Q, Alt+J), run without parameters, prompt defaults and
  typed values, required-field error, sudo waits for `y` (Enter is not yes), `[confirm]` → `yes: true`, and
  `finished()` with `ExitStatus::from_raw(130 << 8)`.
- `src/runner.rs` (+118): 5 tests covering the `arguments()` rules (including a synthetic `+FILES` and a
  blank-before-filled pair), `cautions()` on six recipes, and the command argv via
  `get_program()`/`get_args()`, never run.
- `src/ui.rs` (+105): 7 `TestBackend` tests at 80×24: screen text, the highlight read from the `Cell`
  modifier (`REVERSED` on row 1, not on row 2), filter, help popup (its longest line whole), prompt, a
  103-character value (its end is on screen, the cell left of the cursor holds its last character, and the
  cursor is inside the prompt, read with `Terminal::get_cursor_position`), and the insta snapshot
  `main_screen`.

New `src/snapshots/just_panel__ui__tests__main_screen.snap` (committed) and `README.md` (usage, keys,
running rules, modules, development, snapshot workflow, Nix packaging, limitations).

**Rationale**: tests never run `just`, need a TTY or read `$HOME`. Fixtures are `include_str!`, drawing
uses `TestBackend`, and commands are inspected rather than run. Styles are asserted through `Buffer` cells,
because the snapshot text has no styles.

**Checks**: build PASS · test PASS (36 passed) · clippy PASS (`--all-targets`, so tests too) · fmt PASS.
The snapshot file was created by running once (insta wrote `.snap.new` and failed, as designed) and
accepting with `INSTA_UPDATE=always cargo test`, because cargo-insta was not installed on the build
machine. That run writes the `.snap` but **leaves the `.snap.new` in place**; the next passing `cargo test`
deletes it (verified with insta 1.48.0, both from a missing `.snap` and from a stale one; the `.snap`
written is byte-identical to the committed one). After that, `cargo test` and `CI=true cargo test` both
pass with no `.snap.new`.

**cargo-insta** (1.48.0, nixpkgs `20b1ddd`): `cargo insta review --help` lists `--manifest-path`,
`--workspace-root`, `--workspace`, `--snapshot` and similar, but no `-p`; `-p, --package <PACKAGE>` belongs
to `cargo insta test`, which also has `--review` ("Follow up with review"). `cargo insta review -p
just-panel` prints `error: unexpected argument '-p' found`. On a copy of JP8 with a stale `.snap`, run on a
pty, `cargo insta test -p just-panel --review` ran the 36 tests, opened the review, and `a` wrote a `.snap`
byte-identical to the committed one and removed the `.snap.new`. Plain `cargo insta review` in the
workspace root (the command in `ui.rs`'s doc comment, and `rust/` in the real repo) also works.

**Smoke**: `navigate` 14/14, `filter-help` 20/20, `ctrl-c` 6/6, `ctrl-keys` 7/7, `run` 33/33,
`typeahead` 9/9, `symlink` 7/7. All seven scenarios pass again with the pinned nixpkgs just 1.58.0 first on
`PATH` (96/96 checks), so the panel runs recipes through laptop-intel's just unchanged.

**Nix sandbox build.** JP8 was built by `rustPlatform.buildRustPackage` from the flake's pinned nixpkgs
(`20b1ddd`), with the same arguments as `buildWorkspaceCrate`. Its `cargoCheckHook` ran `cargo test -j 16
--profile release --target x86_64-unknown-linux-gnu --offline --package just-panel` in the sandbox: 36
passed, snapshot found, no `cargo metadata failed`. A second build imported a copy of `rust/nix/default.nix`
with the `just-panel` entry from "Shipping it" below, so the whole real workspace and its lock (468
`[[package]]` entries) went through `buildWorkspaceCrate` itself: 36 passed again. The sandbox has no
controlling terminal, no `$HOME`, no network and no `just`, and insta's run-time `cargo metadata --no-deps`
(which it uses to find the workspace root) still succeeds offline. Not yet run: `nix build .#just-panel`
through the flake, and `just rebuild` on laptop-intel.

**Real-workspace rehearsal**: a copy of `rust/` (the repository itself untouched) with the edits below and
JP8's crate. `cargo build -p just-panel`, `cargo test -p just-panel` (36 passed),
`cargo clippy -p just-panel --all-targets -- -D warnings` and `cargo fmt -p just-panel --check` all passed.
`rust/Cargo.lock` went from 332 to 425 crates (370 to 468 `[[package]]` entries, counting each version
separately): 93 new, none removed, and new versions of 9 existing crates (bitflags 2.10.0 → 2.13.2, time
0.3.46 → 0.3.55, time-core, deranged, num-conv; plus extra versions of base64 0.22, hashbrown 0.17, nix 0.29
and syn 1/3 alongside the old ones). `time` comes from ratatui's calendar widget (default `all-widgets`).
The lock also lists termwiz/ratatui-termwiz, which is never compiled but which Nix still vendors.

### Shipping it: the repository edits (lesson 17)

1. Copy `JP8/just-panel/` to `rust/just-panel/` (or, having built it yourself, it is already there).

2. `rust/Cargo.toml`, exactly as rehearsed:

   ```diff
   @@ members
        "dev-layout",        # Hyprland dev layout launcher
   +    "just-panel",        # TUI control panel for the justfile
        # "security-wrapper",  # Phase 10 - Future security wrapper for OpenBao
   @@ # CLI and terminal
    clap = { version = "4.5", features = ["derive", "cargo"] }
    colored = "2.1"
   +ratatui = "0.30"
   @@ # Process execution
    which = "6.0"
   +signal-hook = "0.3"
   @@ end of [workspace.dependencies]
    notify-rust = "4.10"
   +
   +# Testing
   +insta = "1.48"
   ```

3. `rust/Cargo.lock`: regenerate it by running any cargo command in `rust/` (for example
   `cargo build -p just-panel`), then commit it. The Nix build is offline against this file.

4. `rust/nix/default.nix`: add after the `dev-layout` entry (lines 99–102), before the closing `}`. It
   needs no `nativeBuildInputs` or `buildInputs`, because there is no openssl or pkg-config dependency:

   ```nix
     just-panel = buildWorkspaceCrate {
       pname = "just-panel";
       description = "Terminal control panel for the nix-config justfile";
     };
   ```

   It then appears as `packages.<system>.just-panel`, as `pkgs.just-panel` through the overlay, and on
   `PATH` on full-config hosts (`modules/core/common.nix:97`). At run time it needs `just`, which the full
   config installs (`common.nix:88`), so no wrapper is needed.

5. `git add rust/just-panel rust/Cargo.toml rust/Cargo.lock rust/nix/default.nix`, including
   `rust/just-panel/tests/fixtures/` and `rust/just-panel/src/snapshots/`: flakes only see tracked files.
   Then `nix build .#just-panel` and `just rebuild`.

6. Optional:
   - `cargo-insta` (nixpkgs attr `cargo-insta`, 1.48.0 at the pinned rev) in `home/stages/dev.nix`, next
     to `vhs`.
   - insta's speed tip in `rust/Cargo.toml` (profiles only work at the workspace root):
     `[profile.dev.package] insta.opt-level = 3` and `similar.opt-level = 3`.
   - A `just-panel` entry under "Tools" in `rust/README.md`, and the missing `rust/nix/default.nix` step in
     its "Adding a New Tool" section.
   - A Hyprland bind modelled on `config/hypr/60-keybinds.lua:75` (the `kitty -e btop` bind):
     `hl.bind(mod .. " + <KEY>", hl.dsp.exec_cmd("kitty -e just-panel --justfile <absolute path>"))`. Pass
     `--justfile` explicitly, because zsh-only `JUST_JUSTFILE` is probably not inherited. The key choice,
     and whether `exec_cmd` expands `~`, are not verified.

---

## The demo justfile and its dump

- `fixtures/just/justfile` (in the course folder) has 15 recipes (14 public plus private `_stamp`) and 7
  banner sections, one of them split into the `Backups` and `Snapshots` sub-sections. It also has an
  exported variable, doc comments, singular parameters, defaults (`TIME="5"`, `NAME=""`), a variadic
  `*ARGS`, a shebang recipe (`rebuild`), dependencies (`lint: lint-rust lint-nix`,
  `backup-status: _stamp`), `[group('rust')]`, `[confirm("…")]`, and a free-form paragraph under "Session
  Control" as in the real file. Every recipe only echoes, sleeps or prints the time; each one was run by
  hand to confirm it is harmless.
- **The sudo choice.** `rebuild` and `snapshot` only `echo "demo: would run: sudo …"`. `needs_sudo` is a
  word search over the body text, so they get exactly the confirmation that real sudo recipes get, while
  sudo itself never runs: no password prompt can stall a demo or be recorded. Variable-guarding a real sudo
  call was rejected, because a wrong value would run it for real.
- `fixtures/just/dump.json` is the unedited output of `just --justfile <that justfile> --dump --dump-format
  json` (just 1.46.0, 6262 bytes, one line), with the justfile given by its absolute path. Its `source`
  field records that path on the machine that generated it; nothing reads the field.
- `fixtures/just/README.md` covers what the files are, why every recipe is harmless, the caution table,
  usage (always pass `--justfile`), regeneration, and copying to `rust/just-panel/tests/fixtures/`.
- The copies in `JP3`…`JP8/just-panel/tests/fixtures/` are byte-identical to the course fixtures (checked
  with `cmp`).

## Verified facts

1. `cargo new` in a workspace auto-adds the member but mangles the commented list (JP0).
2. clippy `manual_map` fires on the natural first draft of the banner loop (JP4). Good for lesson 11.
3. The parser reproduces `just --summary --unsorted` for the real justfile (131/131).
4. In raw mode Ctrl+C is `KeyCode::Char('c')` + `CONTROL`, not SIGINT.
5. `Terminal::clear()` (ratatui-core 0.1.2) queries the cursor position (`ESC[6n`, via
   `backend.get_cursor_position()`), so the terminal must answer it, as kitty and VHS's xterm.js do. A test
   script must answer it too, or crossterm times out after about 2 s and the resume fails.
6. Ctrl+C during a recipe: just exits 130, and the panel survives thanks to the handler. just installs its
   own SIGINT handler, so the SIG_IGN argument is about children in general, not about just.
7. `terminal.show_cursor()` before the child matters: without it, password prompts show no cursor.
8. just 1.58.0's real dump of the course fixture (pinned nixpkgs) differs from 1.46's only by a top-level
   `module_path: ""`, parameter fields `flag`, `max`, `min`, `multiple`, and a `star` field on each
   dependency. A synthetic test covers that shape, the model parses the real output, and the panel runs
   recipes through just 1.58 unchanged (`--yes`, exit code 130 on Ctrl+C).
9. A shared `CARGO_TARGET_DIR` across copies of the same crate is unsafe without forcing a recompile (see
   [How the checks run](#how-the-checks-run)).
10. `ListState` scroll offset versus headers: `List::scroll_padding(1)` keeps a section's header visible
    above its first recipe.
11. Snapshot files record `source: just-panel/src/ui.rs`, which is relative to the workspace root and
    identical in the real `rust/` workspace.
12. `fs::canonicalize` resolves symlinks. `just` runs a symlinked justfile's recipes in the link's
    directory; a canonicalised path moves them to the target's directory (on NixOS, possibly into the Nix
    store). `std::path::absolute` (Rust 1.79) is the right tool.
13. crossterm reports Ctrl+letter as that letter plus `KeyModifiers::CONTROL` (and Alt likewise), so a
    `match key.code` that ignores modifiers makes Ctrl+Q quit and Ctrl+U type a `u`.
14. crossterm keeps a queue of parsed events. Events read before the TUI stepped aside are still there when
    it comes back and must be drained, or a double-tapped Enter runs a recipe twice.
15. With rustup installed, `cargo clippy` and `cargo fmt` come from `$CARGO_HOME/bin` even when another
    toolchain is first on `PATH` (see [How the checks run](#how-the-checks-run)).
16. `INSTA_UPDATE=always cargo test` writes the `.snap` but leaves the `.snap.new`; the next passing
    `cargo test` deletes it (JP8).

## Design decisions

1. **JP2–JP4 carry `#![allow(dead_code)]`** in `main.rs`, with a comment. It is needed because nothing
   calls the code before JP5 (11 warnings otherwise), and JP5 removes it. JP1 needs none.
2. **JP1 adds `[[bin]]`** to the crate manifest, matching every other crate in `rust/`. JP0 stays the exact
   `cargo new` output.
3. **JP5's detail pane shows the section title**, so `sections.rs` is really used before JP6 adds header
   rows. Otherwise JP5 would warn about an unused field.
4. **Esc in normal mode clears a kept filter before it quits** (JP6), and **Ctrl+C quits in the TUI**
   (JP5, because raw mode makes it a key). Both refine "q/Esc quit".
5. **The CLI uses clap derive** with the `env` feature (`-f/--justfile`, `JUST_JUSTFILE`, default
   `./justfile`), as the other workspace tools do, rather than hand-rolled parsing. The default is
   `./justfile`, as for `just` itself, not a hard-coded path to nix-config.
6. **Ctrl+C during a recipe uses signal-hook's `flag::register`** instead of the common
   `ctrlc::set_handler`. The effect is the same, it costs no extra crate, and the API is safe.
7. **Suspend order** follows ratatui's spawn-vim recipe (leave the alternate screen, then disable raw
   mode), not the reverse order inside `ratatui::try_restore`. Both work.
8. **`[confirm]` recipes are confirmed in the panel and run with `--yes`**, so just does not ask a second
   time. As a side effect, `--yes` also auto-confirms any `[confirm]` dependency.
9. **JP6 adds `List::scroll_padding(1)`**, a `popup()` helper and `KEYS` as a slice: the first fixes a
   header-visibility bug, and the other two keep JP7's diff additive.
10. **The insta snapshot was accepted with `INSTA_UPDATE=always`**, because cargo-insta was not installed
    on the build machine (then one more `cargo test` to delete the leftover `.snap.new`).
11. **`check.sh` and `smoke-all.sh` touch `src/main.rs`** before building, to defeat cross-milestone
    staleness in their shared `CARGO_TARGET_DIR`.

## Known limitations

- **Not yet run on laptop-intel**: the repository's real justfile under just 1.58 (it has no attributes, so
  nothing new is expected), `nix build .#just-panel` through the flake (needs the crate `git add`ed), and
  `just rebuild`.
- **Typeahead after the hand-over.** A key typed after the panel has left raw mode goes to the recipe or
  answers the "Press Enter to return" pause, so an Enter pressed about 150 ms after the first skips the
  pause (reproduced on the pty). The output stays on the terminal's normal screen. Clearing it would need
  `tcflush`, which means `unsafe` libc code in a teaching crate: not done.
- **A failed spawn ends the panel.** If `just` cannot be started when a recipe runs (for example, it was
  uninstalled after start-up), `run_in_terminal` prints the error and pauses, then returns the
  `io::Error`, and the event loop's `?` quits with it. The terminal is restored. Showing it in the status
  line instead would need `LastRun` to hold an error: not done, because start-up has already proved that
  `just` runs.
- **Only private recipes.** A justfile whose recipes are all private shows "No recipe matches the filter"
  with no filter set. Cosmetic: not changed.
- **Not supported:** `[arg(…)]` option-style parameters (`--name VALUE`; just then fails with
  `Recipe 'x' requires option '--name'`, exit 1), `mod` modules, and sudo detection through dependencies
  (for example `clean-all` → `clean-generations`; `clean-*` still catches it).
- **SIGQUIT.** Only SIGINT is handled. `Ctrl+\` during a recipe would still kill just-panel (with the
  terminal left in cooked mode on the main screen, which is harmless).
- **Terminals that ignore the cursor-position query.** A terminal that never answers `ESC[6n` makes
  `terminal.clear()` fail on resume after about 2 s. kitty and VHS answer it.
- **Truncation.** Long section titles are cut off in the list at 80 columns (for example
  "Storage Management (Phase 8) / …"). Confirmation reasons longer than about 60 characters, and prompt
  fields that are not focused, are cut off rather than wrapped. The focused prompt field shows the end of
  its value.
- **Lockfile churn.** Adding ratatui bumps 9 existing lock entries (bitflags, time and friends), so every
  tool rebuilds on the next `just rebuild`. Running `just test-rust` once after adding the crate is
  advisable. `ratatui` with `default-features = false, features = ["crossterm"]` would drop the calendar
  widget's `time` dependency, but this was not tried.
- **Hyprland bind.** The optional bind is not verified: key choice, and environment and `~` handling in
  `exec_cmd`.

## Fixes found in testing

Every TUI milestone was driven on a real pty: resizes down to 3×10, unicode and very long docs, banners and
names, control characters in the justfile, malformed and missing justfiles, only-private recipes, the real
131-recipe justfile read-only, just 1.58.0, the NixOS toolchain and the Nix sandbox. That found five bugs.
Each fix went identically into every milestone that holds the code, so the lessons' code already includes
it.

| # | Bug (as reproduced) | Fix | Milestones |
|---|---------------------|-----|------------|
| 1 | A symlinked justfile ran its recipes in the target's directory (`pwd` printed `…/real`), where `just` runs them in the link's (`…/link`). | `std::path::absolute` instead of `fs::canonicalize`; read the source before `just --dump`. `just_command`'s doc comment follows. | `main.rs` JP5–JP8; `justfile.rs` comment JP3–JP8 |
| 2 | Ctrl/Alt keys acted as plain letters: `/lint` then Ctrl+U, Ctrl+W gave the filter `lintuw`; Ctrl+Q quit. | `handle_key` ignores any key with CONTROL or ALT after the Ctrl+C check. | `app.rs` JP5–JP8 |
| 3 | The `?` popup was 48 wide and cut "Esc clears it" to "Esc clears". | Width from the longest line plus the border. | `ui.rs` JP6–JP8 |
| 4 | A prompt value longer than the field ran past the border, hiding the typed end and the cursor. | The focused field shows the end of its value (`tail()`); the prompt width is `min(64, frame width)`. | `ui.rs` JP7–JP8 |
| 5 | A double-tapped Enter read in one go ran the recipe twice (the queued Enter replayed on return). | Drain crossterm's queue after `terminal.clear()`. | `runner.rs` JP7–JP8 |
| 6 | JP8's README said `cargo insta review -p just-panel`, which cargo-insta rejects. | It now says `cargo insta test -p just-panel --review` (what lesson 17's `:s/review -p just-panel/test -p just-panel --review/` produces). | `README.md` JP8 |

New checks for fixes 1 to 5: JP8 unit tests `keys_with_ctrl_or_alt_are_not_plain_keys` and
`a_long_value_shows_its_end_and_the_cursor`, plus a stricter `help_lists_the_keys_over_the_list` (34 → 36
tests); smoke scenarios `ctrl-keys` (JP5 on), `typeahead` and `symlink` (JP7 on), and two more checks in
`filter-help` (JP6 on). Each was checked against the code before the fix: reverting the three fixes the new
unit tests cover makes exactly those three tests fail, and the earlier binary fails `ctrl-keys`,
`filter-help`, `typeahead` and `symlink`. The JP8 README describes the new behaviour and the remaining
limitations. After the fixes, every check in this file was run again and passed: `check.sh` for JP0–JP8,
the NixOS-toolchain run for JP0–JP8, `smoke-all.sh` for JP5–JP8, the real-workspace rehearsal (36 tests)
and both Nix sandbox builds (36 tests).

Checked and found sound (no change): the just 1.58 schema (from upstream source and a real 1.58 run); every
ratatui 0.30.2 / ratatui-core 0.1.2 / ratatui-widgets 0.3.2 / crossterm 0.29 call against the registry
source (`Terminal::clear` really does query the cursor position); control characters from a hostile
justfile never reach the terminal (ratatui drops them); malformed or missing justfiles and a missing `just`
fail before the TUI starts, with the terminal untouched; resize during a run redraws at the new size; tiny
terminals do not panic; the terminal is restored after every scenario; the tests need no TTY, `$HOME`,
network or `just`.

**Last run of the scripts** (27/09/2026, from `examples/just-panel`): `./check.sh all` PASS for JP0–JP8
with rustup's cargo 1.92.0 (0, 0, 0, 8, 12, 12, 12, 12 and 36 tests), and JP8 again with laptop-intel's
cargo 1.98 and clippy 0.1.98; `./smoke-all.sh` passes every scenario on JP5–JP8 with just 1.46.0, and
`./smoke-all.sh JP7` again with laptop-intel's just 1.58.0 and cargo 1.98.
