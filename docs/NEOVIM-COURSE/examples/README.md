# Worked examples

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

The finished code of every capstone milestone: **JP0 to JP8** for just-panel (Rust, ratatui) and **SB0 to
SB8** for session-browser (Python, Textual). `SBn/`, and the crate folder `JPn/just-panel/`, hold exactly
what your `python/session-browser` or `rust/just-panel` should hold at the end of that milestone's lesson.
The lessons print the same code, file by file. Every milestone here builds, passes its tests and is lint-
and format-clean, and the check scripts below prove it on your machine.

> **Spoiler:** these are the answers. Do the lesson first, in Neovim, and come here only when you are
> stuck or when you want to compare. Typing the code yourself, meeting the compiler's complaints, reading
> hover docs with `K`: that is the lesson. Copying the folder skips it.

## Contents

- [What is here](#what-is-here)
- [Compare your work](#compare-your-work)
- [Run the checks](#run-the-checks)
- [What differs from what you generate](#what-differs-from-what-you-generate)
- [The capstone tapes record these examples](#the-capstone-tapes-record-these-examples)

## What is here

```text
examples/
├── README.md                 this file
├── .gitignore                build output, caches and virtualenvs, should any appear here
├── just-panel/
│   ├── MILESTONES.md         what each milestone adds and why, traps, verified facts, check results
│   ├── check.sh              build, test, clippy and fmt for one milestone or all
│   ├── smoke.py              drives the TUI on a real pseudo-terminal and checks the screen
│   ├── smoke-all.sh          runs smoke.py's scenarios on JP5 to JP8
│   └── JP0/ … JP8/           one mini Cargo workspace per milestone
│       ├── Cargo.toml        a cut-down copy of rust/Cargo.toml
│       ├── Cargo.lock
│       └── just-panel/       the crate: what goes in rust/just-panel
└── session-browser/
    ├── MILESTONES.md
    ├── check.sh              uv sync, pytest, ruff and pyright for one milestone or all
    └── SB0/ … SB8/           one uv project per milestone: what goes in python/session-browser
```

**just-panel.** Each `JPn/` is a small Cargo workspace, because the real crate lives inside the `rust/`
workspace and inherits from it. `JPn/Cargo.toml` has the same `[workspace.package]` as `rust/Cargo.toml`
(the `authors` line is copied from it) and only the `[workspace.dependencies]` the crate uses, in the same
groups as the real file. The crate itself is `JPn/just-panel/`.

| Milestone | Lesson | What it adds |
|---|---|---|
| [JP0](just-panel/JP0/) | [06 Terminal](../lessons/06-TERMINAL.md) | `cargo new`: a crate that prints `Hello, world!` |
| [JP1](just-panel/JP1/) | [07 Tree](../lessons/07-TREE.md) | The module files, created from the tree, and `[[bin]]` |
| [JP2](just-panel/JP2/) | [08 File Pane](../lessons/08-FILE-PANE.md) | The plain data types: `Recipe`, `Parameter`, `Dependency` |
| [JP3](just-panel/JP3/) | [10 LSP](../lessons/10-LSP.md) | serde parsing of `just --dump`, helpers, 8 tests |
| [JP4](just-panel/JP4/) | [11 Completion, formatting and diagnostics](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | The section-banner parser, 12 tests in all |
| [JP5](just-panel/JP5/) | [14 TUI skeleton](../lessons/14-JUST-PANEL-TUI-SKELETON.md) | The ratatui app: list, detail pane, `j` `k` `g` `G` `q` |
| [JP6](just-panel/JP6/) | [15 Sections and filter](../lessons/15-JUST-PANEL-SECTIONS-AND-FILTER.md) | Section headers, the `/` filter, the `?` help popup |
| [JP7](just-panel/JP7/) | [16 Running recipes](../lessons/16-JUST-PANEL-RUNNING-RECIPES.md) | Parameter prompt, confirmations, running recipes in the real terminal |
| [JP8](just-panel/JP8/) | [17 Testing and shipping](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md) | 36 tests with `TestBackend` and an insta snapshot, README |

**session-browser.** Each `SBn/` is the whole uv project: `pyproject.toml`, `uv.lock`, `README.md`,
`.gitignore`, `src/session_browser/` and, from SB1, `tests/`.

| Milestone | Lesson | What it adds |
|---|---|---|
| [SB0](session-browser/SB0/) | [06 Terminal](../lessons/06-TERMINAL.md) | `uv init`, textual and the dev tools, a minimal app |
| [SB1](session-browser/SB1/) | [07 Tree](../lessons/07-TREE.md) | The package layout, created from the tree; an import test |
| [SB2](session-browser/SB2/) | [08 File Pane](../lessons/08-FILE-PANE.md) | `models.py`: `Source`, `Session`, `Message` |
| [SB3](session-browser/SB3/) | [10 LSP](../lessons/10-LSP.md) | The Claude Code source, fixtures, `[tool.pyright]` |
| [SB4](session-browser/SB4/) | [11 Completion, formatting and diagnostics](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | The Codex and Kitty sources |
| [SB5](session-browser/SB5/) | [18 TUI skeleton](../lessons/18-SESSION-BROWSER-TUI-SKELETON.md) | The Textual app: a worker, the DataTable, a safe preview |
| [SB6](session-browser/SB6/) | [19 Filter and search](../lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md) | Source tabs, search, `j` `k` `g` `G` `h` `l` `/` and Esc |
| [SB7](session-browser/SB7/) | [20 Actions](../lessons/20-SESSION-BROWSER-ACTIONS.md) | Resume a session with Enter, copy its command with `c` |
| [SB8](session-browser/SB8/) | [21 Testing and shipping](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) | Pilot tests, a snapshot test, README |

Lessons 09, 12 and 13 have no milestone of their own. Lesson 09 is investigation, lesson 12 commits JP0 to
JP4 and SB0 to SB4, and lesson 13's additions stay yours (see
[What differs](#what-differs-from-what-you-generate)).

The per-milestone notes are in [just-panel/MILESTONES.md](just-panel/MILESTONES.md) and
[session-browser/MILESTONES.md](session-browser/MILESTONES.md): the files each milestone changes, the
reasons, the traps met while building it, and the check results.

## Compare your work

Compare the crate folder for just-panel, and the whole project folder for session-browser. `diff -ru`
prints the example's lines with `-` and yours with `+`:

```bash
# in ~/Repos/personal/nix-config
diff -ru docs/NEOVIM-COURSE/examples/just-panel/JP5/just-panel rust/just-panel
git diff --no-index docs/NEOVIM-COURSE/examples/just-panel/JP5/just-panel rust/just-panel
```

`git diff --no-index` shows the same in colour, in a pager. It does not honour `.gitignore`, so for
session-browser, where your folder also holds `.venv` and caches, use `diff` and leave them out:

```bash
# in ~/Repos/personal/nix-config
diff -ru -x .venv -x __pycache__ -x .pytest_cache -x .ruff_cache -x .python-version -x uv.lock \
  docs/NEOVIM-COURSE/examples/session-browser/SB4 python/session-browser
```

To go through one file in Neovim, open both side by side in diff mode, then jump between changes with
`]c` and `[c` (Neovim defaults):

```bash
# in ~/Repos/personal/nix-config
nvim -d rust/just-panel/src/app.rs docs/NEOVIM-COURSE/examples/just-panel/JP5/just-panel/src/app.rs
```

Only the crate compares file for file. `JPn/Cargo.toml` is a cut-down workspace file: check that the
`[workspace.dependencies]` lines it has are also in your `rust/Cargo.toml`, rather than diffing the two.

## Run the checks

Nothing here needs installing beyond what the capstones already use: cargo, just and uv (and ruff and
pyright, which laptop-intel has system-wide; elsewhere the script fetches them with `uvx`). The scripts
never write build output, virtualenvs or caches into the course folder.

**just-panel**: `check.sh` runs `cargo build`, `cargo test`, `cargo clippy --all-targets -- -D warnings`
and `cargo fmt --check` inside `JPn/`, with `--locked` so the example's `Cargo.lock` is never rewritten.
Build output goes to `$CARGO_TARGET_DIR`, by default `${TMPDIR:-/tmp}/just-panel-examples-target`.

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE/examples/just-panel
./check.sh JP5          # one milestone
./check.sh all          # JP0 to JP8
```

Each check prints `PASS` or `FAIL`, and a `warning` line counts as a failure. The script touches
`JPn/just-panel/src/main.rs` before building. Every milestone's crate has the same path inside its
workspace, so in a shared target folder cargo would otherwise take an older milestone for up to date and
reuse the previous one's build. [just-panel/MILESTONES.md](just-panel/MILESTONES.md#how-the-checks-run)
explains the trap.

**just-panel on a real terminal**: `smoke-all.sh` builds JP5 to JP8 and runs `smoke.py`'s scenarios
against the course's demo justfile, whose recipes only echo, sleep or print the time. `smoke.py` needs
pyte, a terminal emulator library; uv fetches it into its cache and installs nothing here.

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE/examples/just-panel
./smoke-all.sh                  # JP5 to JP8, every scenario
./smoke-all.sh JP7              # one milestone
# one scenario against any just-panel binary, your own build included:
uv run --no-project --with pyte python smoke.py ~/Repos/personal/nix-config/rust/target/debug/just-panel navigate
```

The scenarios are `navigate`, `ctrl-c`, `ctrl-keys` (JP5 on), `filter-help` (JP6 on), and `run`,
`typeahead` and `symlink` (JP7 on). Each prints `PASS` or `FAIL` per check and a count such as
`== run: 33/33 checks passed`.

**session-browser**: `check.sh` copies the milestone with `cp -r` to
`${TMPDIR:-/tmp}/session-browser-examples/SBn` (fresh file times, like a checkout) and runs
`uv sync --locked`, `uv run pytest -q`, `ruff check`, `ruff format --check` and `pyright` in the copy.
It works on a copy because `uv sync` puts `.venv` inside the project (where `[tool.pyright]` looks for it)
and pytest and ruff write caches next to the code: the copy keeps all of that out of the course folder.

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE/examples/session-browser
./check.sh SB4          # one milestone
./check.sh all          # SB0 to SB8
```

The pytest count depends on the Python that uv picks. On laptop-intel that is 3.14 and every test runs.
On 3.12 the two zstd tests (SB4 on) are skipped: SB4 reports `41 passed` on 3.14 and
`39 passed, 2 skipped` on 3.12, and SB8 reports `70 passed` or `68 passed, 2 skipped`. SB0 has no tests
yet, so pytest's "no tests ran" counts as a pass there. SB0 to SB2 predate `[tool.pyright]`, so the script
gives pyright the venv's Python with `--pythonpath`.

## What differs from what you generate

- **Lock files.** `JPn/Cargo.lock` locks only the mini workspace. Your `rust/Cargo.lock` locks every tool
  in `rust/`, and cargo may resolve newer patch versions on the day you add a crate (the real lock also
  keeps clap at 4.5.54 where JP8's has 4.6.7). The same goes for `uv.lock`: `uv add` resolves the newest
  versions that fit, so yours may differ from the examples' (textual 8.2.8, pytest 8.4.2, syrupy 4.8.0).
  Compare code, not locks.
- **`.python-version` is left out on purpose.** `uv init` writes the Python it found on your machine
  (3.14 on laptop-intel, 3.12 on the Ubuntu machine that built the examples). It is machine-specific:
  keep and commit yours, as the lessons say.
- **The `uv_build` lower bound.** `uv init` writes its own version into `[build-system]`. The examples say
  `uv_build>=0.12.5,<0.13.0`; laptop-intel's uv 0.12.16 writes `uv_build>=0.12.16,<0.13.0`. Leave yours as
  uv wrote it.
- **`dump.json`'s `source` field.** `just-panel/tests/fixtures/dump.json` (JP3 on) is a copy of
  `fixtures/just/dump.json`, the unedited output of `just --dump`. Its `source` field records the absolute
  path of the justfile on the machine that generated it. Nothing reads that field; a dump you generate
  yourself names your path there.
- **Your additions from lesson 13.** The examples hold no `AGENTS.md` or `CLAUDE.md`, and no tests Claude
  drafted with you. From JP5 and SB5 on, expect those in the diff, and add the tests you kept to the
  counts (`12 passed` for JP5 to JP7 becomes 16 if you kept all four).
- **JP0's workspace line.** `cargo new` squeezes `"just-panel",` onto the `dev-layout` line of your
  `rust/Cargo.toml`. Lesson 06 has you move it to its own line; the mini workspace shows only that result.

## The capstone tapes record these examples

The capstone tapes (09, 10 and 14 to 21) record these worked examples, never your own capstones. Each
hidden setup copies the milestone it shows, `examples/just-panel/JPn` or `examples/session-browser/SBn`,
to `/tmp/nvim-course/<slug>/` and builds or runs it there. So if you change an example, re-record the tapes
that copy it (each tape's header names its example). Before recording anything, make sure VHS is 0.12.1:
[Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121) explains why and how to
check.
