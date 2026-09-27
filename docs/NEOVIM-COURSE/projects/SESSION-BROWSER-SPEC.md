# session-browser — project spec

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

session-browser is the Python capstone of the [Neovim course](../README.md): a Textual terminal app that
lists every Claude Code, Codex and Kitty session on the machine in one searchable table, previews the one you
select, and resumes it with Enter. It lives in `python/session-browser` as a uv project with a `src` layout
(package `session_browser`, command `session-browser`) and is built in nine milestones, SB0 to SB8, across
lessons 06 to 21. This page is the reference for what it does, how it is put together, and what "done" means.

## Contents

- [Goals](#goals)
- [Non-goals](#non-goals)
- [Platform and versions](#platform-and-versions)
- [Privacy and security model](#privacy-and-security-model)
- [Architecture](#architecture)
- [Module map](#module-map)
- [Session sources](#session-sources)
- [The TUI](#the-tui)
- [Milestones](#milestones)
- [Acceptance criteria](#acceptance-criteria)
- [Testing](#testing)
- [Packaging](#packaging)
- [Known limitations](#known-limitations)
- [Stretch goals](#stretch-goals)

## Goals

1. **One list.** Every resumable session from Claude Code, Codex and saved Kitty session files, newest first,
   with its title, project (folder name) and last activity.
2. **Find it fast.** Source tabs (All, Claude, Codex, Kitty), a case-insensitive search over titles and
   folders, and Vim-style keys.
3. **Know what it was.** A preview of the selected session: title, source and detail (git branch, or tab and
   window counts), time, folder, file, and the last few messages.
4. **Resume in one key.** Enter runs the right command, in the session's folder, with the environment the
   tool expects; or `c` copies that command as one shell line.
5. **Safe by default.** Session text is treated as untrusted, the stores are never written, and a program
   that cannot start or fails is reported without losing the app.
6. **Teachable.** Each milestone is small, tested, and clean under ruff and pyright, so it can be typed from
   a lesson inside Neovim.

## Non-goals

- **Not a transcript viewer.** The preview shows the last six messages, each cut at 600 characters; the full
  conversation belongs to the tool that wrote it.
- **No changes to sessions.** No renaming, archiving, deleting or forking, even where the tools offer it
  (`codex archive`, `codex delete`, `claude --fork-session`).
- **No live Kitty windows.** Only saved `*.kitty-session` files are listed (see
  [Stretch goals](#stretch-goals)).
- **No sub-agent sessions.** Claude sub-agent transcripts and Codex sub-agent threads are left out: they cannot
  usefully be resumed on their own.
- **No configuration file.** Three environment variables and one command-line option are the whole
  interface.
- **No network access, accounts or costs.** The app reads local files and starts local programs.
- **Linux (and NixOS `laptop-intel`) only.** Nothing is done for macOS or Windows; macOS Terminal would also
  ignore the clipboard sequence.

## Platform and versions

| Item | Version | Notes |
|---|---|---|
| Python | `requires-python = ">=3.12"` | 3.14 on laptop-intel (what uv pins in `.python-version` there); every milestone also passes on 3.12 |
| Textual | 8.2.8 | The only runtime dependency |
| uv | 0.12.16 on laptop-intel (nixpkgs `20b1ddd`) | Project tool; `uv_build` is the build backend. `uv init` writes its own version into the `uv_build` pin, so yours reads `>=0.12.16` where the course's listings show `>=0.12.5` |
| pytest / pytest-asyncio | 8.4.2 / 1.4.0 | `asyncio_mode = "auto"` |
| pytest-textual-snapshot / syrupy | 1.1.0 / 4.8.0 | Pinned by `pytest-textual-snapshot>=1.1`, which holds pytest below 9 |
| textual-dev | 1.8.0 | `textual keys`, `textual console`, `textual run --dev` |
| ruff, pyright | the system packages on NixOS | Not project dependencies; `uvx ruff` / `uvx pyright` elsewhere |
| Claude Code, Codex, Kitty | 2.1.278, 0.155.1, 0.48.2 on laptop-intel | Their file formats are internal (see [Session sources](#session-sources)) |

## Privacy and security model

The stores hold private conversations: prompts, pasted text, tool output and client project paths. The app
is designed around four rules.

### 1. Session text is untrusted

Titles, folders and messages come from files that contain whatever you or a tool pasted into a conversation.

- **Never markup.** `DataTable` parses plain string cells as Textual markup, so a title such as
  `Why [/bold] crashes` would raise `MarkupError`. Untrusted cells are wrapped in `textual.content.Content`,
  the preview is a `Static(markup=False)`, and notifications pass `markup=False`.
- **Never terminal control.** Plain text is not terminal-safe text: Textual strips only a handful of control
  characters, not ESC, so an escape sequence inside a title or message would be obeyed by the terminal. It
  could retitle the window, clear the screen, leave the alternate screen, or, in Kitty (whose default
  `clipboard_control` allows writes), set the clipboard through OSC 52. `printable()` replaces every control
  character except tab and newline (C0, DEL and C1) with `�` in the table cells, the preview and the
  notifications.
- **Never a shell.** Commands are started as argument tuples (`("claude", "--resume", id)`), with no shell, so
  an id or a path cannot inject a command. The copied command line is built with `shlex.quote` and
  `shlex.join`.

### 2. The stores are read-only

The app opens session files for reading only. Its one write is `~/.claude/tmp`, the directory the `claude`
alias uses as `TMPDIR`, created before Claude is started (and, as a side effect, when a Claude command is
copied). Resumed programs, of course, write to their own stores as usual.

### 3. Launching runs your real tools

Enter starts `claude`, `codex` or `kitty` from `PATH` with your environment, in the folder recorded in the
session file (or your home folder when it has gone). Only what the tool itself would do then happens. Resuming
a Claude session by id restores its model and permission mode, so check the mode line before asking for
edits.

### 4. Tests and recordings never touch real data

- An autouse fixture sets `HOME` to a temporary folder and points `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and
  `SESSION_BROWSER_KITTY_DIR` at `tests/fixtures/`, a copy of the course's synthetic stores
  (`docs/NEOVIM-COURSE/fixtures/sessions/`). No test can read your sessions.
- Tests that need a program use a fake one as the **whole** `PATH`, so the real `claude` cannot run even when
  the fake cannot be executed.
- The course's recordings run the app on copies of the synthetic stores. The one that presses Enter (lesson
  20) also gives it a throwaway `HOME` and stand-in `claude`, `codex` and `kitty` scripts as the only programs
  on its `PATH`.

## Architecture

```text
 ~/.claude/projects/*/*.jsonl ──────┐
 ~/.codex/sessions/*/*/*/rollout-* ─┼─► sources/claude.py, codex.py, kitty.py ─► list[Session]
 ~/.local/share/kitty/sessions/* ───┘   (read-only, defensive; in a worker thread)   (models.py)
                                                                                         │
                                                                                         ▼
                                   SessionBrowser (app.py): Tabs + Input │ SessionTable │ preview
                                                                                         │ Enter / c
                                                                                         ▼
                                         actions.build_launch(session) ─► Launch(argv, cwd, env, detach)
                                                                                         │
                               launcher: run_in_terminal ─► App.suspend() + actions.run()  (Claude, Codex)
                                         (injectable)    └► actions.run(), detached        (Kitty)
                                                 c ─► Launch.shell_command() ─► copy_to_clipboard (OSC 52)
```

- **Loading.** `on_mount` adds the columns, marks the table as loading and starts
  `@work(thread=True, exclusive=True) load_sessions`, which reads the three stores, sorts by `updated` (all
  timezone-aware) and hands the list back with `call_from_thread`. The table takes focus when loading ends.
- **One source of truth for the filter.** `refresh_table()` reads the active tab and the search text straight
  from the widgets and refills the table through the pure function `matches()`.
- **Preview on highlight.** `RowHighlighted` rebuilds the preview synchronously: at most 30 lines plus 256 KiB
  of one file.
- **Actions as data.** `build_launch()` decides *what* to run; the launcher decides *how*. Tests replace the
  launcher (or, to exercise the real one, `App.suspend()` itself), because `App.suspend()` raises
  `SuspendNotSupported` under `run_test()`.
- **Exit status.** `main()` ends with `sys.exit(app.return_code)`: `App.run()` returns normally even after a
  crash, with `return_code` 1.

## Module map

Paths are relative to `python/session-browser`. "Since" is the milestone that introduced the current form.

| File | Responsibility | Key names | Since |
|---|---|---|---|
| `pyproject.toml` | uv project: the `session-browser` script, dependencies, pytest, pyright and ruff settings | `[project.scripts]`, `[tool.pytest.ini_options]`, `[tool.pyright]`, `[tool.ruff.lint]` | SB0, SB1, SB3 |
| `src/session_browser/__init__.py` | Package docstring | – | SB1 |
| `src/session_browser/models.py` | Plain data types | `Source` (StrEnum), `Session` (frozen, rejects a naive `updated`; `key`, `project`), `Message` | SB2 |
| `src/session_browser/sources/__init__.py` | Shared JSON Lines helpers | `Entry`, `read_entries` (head and tail), `parse_line`, `parse_timestamp`, `modified`, `one_line` | SB3 |
| `src/session_browser/sources/claude.py` | Claude Code transcripts | `config_dir`, `load_sessions`, `read_session`, `recent_messages`, `user_text`, `assistant_text` | SB3 |
| `src/session_browser/sources/codex.py` | Codex rollouts and the thread-name index | `codex_home`, `load_sessions`, `read_index`, `read_session`, `recent_messages`, `open_rollout` | SB4 |
| `src/session_browser/sources/kitty.py` | Kitty session files | `sessions_dir`, `load_sessions`, `read_session` | SB4 |
| `src/session_browser/app.py` | The Textual app and `main()` | `SessionTable`, `SessionBrowser`, `matches`, `preview_text`, `format_time`, `tilde`, `printable`, `main` | SB5–SB7 |
| `src/session_browser/app.tcss` | Layout: two columns, 2fr and 1fr | – | SB5, SB6 |
| `src/session_browser/actions.py` | The command for a session, and running it | `Launch`, `Launcher`, `build_launch`, `claude_tmpdir`, `run` | SB7 |
| `tests/conftest.py` | Isolation and determinism | `synthetic_stores` (autouse), `pinned_stores` | SB3, SB4, SB8 |
| `tests/test_*.py` | The suite (see [Testing](#testing)) | – | SB1–SB8 |
| `tests/fixtures/` | Copy of `docs/NEOVIM-COURSE/fixtures/sessions/`; never edited here | – | SB3 |
| `tests/__snapshots__/test_snapshots/test_oldest_session_selected.svg` | Snapshot baseline, generated | – | SB8 |
| `.gitignore`, `README.md`, `uv.lock`, `.python-version` | Project files; the repo's own `.gitignore` has no Python entries | – | SB0, SB8 |

## Session sources

### Parse defensively

The Claude Code and Codex files are **internal formats that change between versions**; Anthropic recommends
`/export`, `claude -p --output-format json` or hooks for scripts, and Codex is migrating its storage
(`codex migrate-rollouts`). So every reader follows the same rules:

- A line that is not valid JSON, or not a JSON object, is skipped; the rest of the file still counts.
- Unknown entry types and missing keys are ignored; every value's type is checked before use.
- A file that disappears or cannot be read between listing and reading is skipped.
- Only the two ends of a transcript are read: the first 30 lines (where the working folder is) and the last
  256 KiB (where the latest title and time are). On a real store of 168 transcripts that took 0.35 s against
  1.5 s for every line.
- Times without an offset are read as UTC; every `Session.updated` is timezone-aware.

### Claude Code

| Aspect | Rule |
|---|---|
| Store | `$CLAUDE_CONFIG_DIR` (Claude Code's own override), else `~/.claude` |
| Files | `projects/<encoded folder>/<session id>.jsonl`. The glob `projects/*/*.jsonl` skips sub-agent transcripts, which sit in `<id>/subagents/` |
| Id | The file name without `.jsonl` |
| Folder | The first entry with a `cwd`. The directory name encodes the folder lossily (every non-alphanumeric character becomes `-`), so it is never decoded |
| Title | The last `ai-title` entry's `aiTitle`, else the first prompt you typed, else "(untitled)" |
| Prompts | `user` entries that are not `isMeta` and do not start with `<command-…>`, `<local-command-…>`, `<task-notification>` or `<pasted_content>`; content as a string or a list of `text` blocks |
| Updated | The newest `timestamp`, else the file's modification time |
| Detail | `git branch <gitBranch>` |

### Codex

| Aspect | Rule |
|---|---|
| Store | `$CODEX_HOME` (Codex's own override), else `~/.codex` |
| Files | `sessions/YYYY/MM/DD/rollout-<local time>-<id>.jsonl`; also `.jsonl.zst` on Python 3.14 (`compression.zstd`), where a damaged archive is skipped |
| Metadata | The first line must be `session_meta`; its payload gives `id`, `cwd` and `git.branch`. `thread_source == "subagent"` threads are skipped |
| Title | The thread's name in `session_index.jsonl` (a later line wins), else the first `UserMessage`, else "(untitled)" |
| Updated | The rollout's newest timestamp, **not** the index's `updated_at`, which records when the thread was named |
| Messages | `event_msg` / `item_completed` items of type `UserMessage` and `AgentMessage` only; `response_item` messages also carry injected context such as `<environment_context>` |
| Detail | `git branch <branch>` |

### Kitty

| Aspect | Rule |
|---|---|
| Folder of files | `--kitty-sessions-dir DIR`, else `$SESSION_BROWSER_KITTY_DIR`, else `~/.local/share/kitty/sessions` |
| Files | `*.kitty-session`, `*.kitty_session`, `*.session` (the suffixes Kitty itself scans for) |
| Title | The file name without its suffix |
| Folder | The first `cd`, with `~` and `$VARS` expanded and a relative path taken from the file's own folder, as Kitty does; lines split on the first run of spaces or tabs, as Kitty 0.48.2 does |
| Updated | The file's modification time |
| Detail | "N tabs, M windows": a `launch` before any `new_tab` opens the first tab, and `new_os_window` starts afresh |

## The TUI

### Layout

A header with the title and "N of M sessions"; a filter row (source tabs in the left two thirds, the search
box in the right third); the session table (Source, Title, Project, Updated in local time) beside the
preview; and a footer listing the active keys.

### Keymap

| Key | Where | Action | Since |
|---|---|---|---|
| `j` / `k`, arrows | list | Move down / up | SB6 (arrows SB5) |
| `g` / `G` | list | First / last session | SB6 |
| Page Up / Page Down | list | Move a page (Textual's `DataTable`) | SB5 |
| `Enter` | list | Resume the session (Kitty: open it in a new window) | SB7 |
| `c` | anywhere but the search box | Copy the resume command to the clipboard | SB7 |
| `h` / `l` | anywhere but the search box | Previous / next source tab; wraps round | SB6 |
| `/` | anywhere but the search box | Focus the search box | SB6 |
| `Esc` | anywhere | Back to the list | SB6 |
| `Enter` | search box | Back to the list, keeping the search | SB6 |
| `q` | anywhere but the search box | Quit | SB0 |
| `Ctrl+Q` | anywhere | Quit (Textual's built-in) | SB0 |
| `Ctrl+P` | anywhere | Textual's command palette | SB0 |

### What Enter runs

| Source | Command | Folder | How |
|---|---|---|---|
| Claude Code | `claude --resume <id>`, environment plus `TMPDIR=~/.claude/tmp` | The session's folder, else `~` | In this terminal, inside `App.suspend()` |
| Codex | `codex resume <id>` | The session's folder, else `~` (avoids Codex's "which folder?" question) | In this terminal, inside `App.suspend()` |
| Kitty | `kitty --session <absolute path>` | The file's first `cd`, else `~` | Detached (`start_new_session`, `/dev/null` streams), reaped by a daemon thread |

`TMPDIR` recreates the `claude` alias in `home/modules/shell.nix:60`, which a program started without a shell
never sees. During a blocking run a do-nothing SIGINT handler keeps Ctrl+C from quitting the browser (not
`SIG_IGN`, which the child would inherit).

### What the app tells you

| Situation | Notification |
|---|---|
| The session's folder has gone | warning: "<folder> no longer exists; starting in <home>." |
| The program is not on `PATH` | error: "Could not find 'claude'. Is it installed and on PATH?" |
| It cannot be started | error: "Could not start 'claude': <reason>." (Permission denied, Exec format error, …) |
| It exited with a positive status | warning: "claude exited with status N. Quit the browser to read what it printed." |
| `c` | "Copied", with the command |

## Milestones

| Milestone | Lesson | What it adds | Example |
|---|---|---|---|
| SB0 | [06 — Terminal](../lessons/06-TERMINAL.md) | `uv init` scaffold, Textual and the dev tools, a minimal app (`q` quits) | [SB0](../examples/session-browser/SB0/) |
| SB1 | [07 — Tree](../lessons/07-TREE.md) | The module files, created from the tree; the app moves to `app.py`; import tests | [SB1](../examples/session-browser/SB1/) |
| SB2 | [08 — File Pane](../lessons/08-FILE-PANE.md) | `models.py`: `Source`, `Session`, `Message` | [SB2](../examples/session-browser/SB2/) |
| – | [09 — Project Pane](../lessons/09-PROJECT-PANE.md) | Investigation only: exploring the fixtures for SB3 and SB4 | – |
| SB3 | [10 — LSP](../lessons/10-LSP.md) | Claude Code source, shared JSON Lines helpers, fixtures, `[tool.pyright]` | [SB3](../examples/session-browser/SB3/) |
| SB4 | [11 — Completion, formatting and diagnostics](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | Codex and Kitty sources | [SB4](../examples/session-browser/SB4/) |
| – | [12 — Git](../lessons/12-GIT.md) | SB0–SB4 committed and tagged `course/sb4` | [SB4](../examples/session-browser/SB4/) |
| – | [13 — Claude Code and Codex](../lessons/13-CLAUDE-CODE-AND-CODEX.md) | `AGENTS.md` and `CLAUDE.md`; a Codex review of the sources | – |
| SB5 | [18 — session-browser: TUI skeleton](../lessons/18-SESSION-BROWSER-TUI-SKELETON.md) | The app: loading worker, `DataTable`, markup- and escape-safe preview, `app.tcss` | [SB5](../examples/session-browser/SB5/) |
| SB6 | [19 — session-browser: filter and search](../lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md) | Source tabs, search, `j`/`k`/`g`/`G`, `h`/`l`, `/`, Esc | [SB6](../examples/session-browser/SB6/) |
| SB7 | [20 — session-browser: actions](../lessons/20-SESSION-BROWSER-ACTIONS.md) | `actions.py`: `Launch`; Enter resumes, `c` copies; injectable launcher | [SB7](../examples/session-browser/SB7/) |
| SB8 | [21 — session-browser: testing and shipping](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) | Pilot tests, snapshot SVG, README, `uv tool install` | [SB8](../examples/session-browser/SB8/) |

Tests after each milestone (Python 3.14 / 3.12): SB1 8, SB2 13, SB3 24, SB4–SB6 41 / 39 + 2 skipped,
SB7 53 / 51 + 2 skipped, SB8 70 / 68 + 2 skipped. The two skipped on 3.12 are the zstd tests.

Lesson 12 tags the SB4 commit `course/sb4`, and from SB5 on each milestone ends in a commit tagged `course/sb5`
… `course/sb8` (local tags, never pushed), so you can diff against and return to each milestone later. The next
lesson reviews against the previous tag with `:DiffviewOpen course/sbN`.

The **Example** column links the worked example for each milestone, a complete uv project that passes its
tests, ruff and pyright. They are spoilers, so type the milestone first and compare afterwards
([examples/README.md](../examples/README.md)). The capstone recordings are made from them, not from your
repository, so each shows exactly its milestone.

## Acceptance criteria

The project is done at SB8 when all of these hold on laptop-intel:

- [ ] `uv run pytest -q` passes: `70 passed` on 3.14 (`68 passed, 2 skipped` on 3.12), including
      `1 snapshot passed.`
- [ ] `ruff check`, `ruff format --check` and `pyright` report nothing (the system tools; `uvx ruff` and
      `uvx pyright` agree).
- [ ] With `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `--kitty-sessions-dir` pointed at the fixtures, the browser
      lists the nine sessions newest first, as in lesson 18's table (the Kitty files dated
      2026-09-20 12:00 UTC with lesson 18's `touch -d`), and the tabs show 4, 3 and 2.
- [ ] Every key in the [keymap](#keymap) does what it says, and typing `q`, `h` or `l` in the search box types
      the letter.
- [ ] Enter runs the command in [What Enter runs](#what-enter-runs); the browser comes back after the program
      exits, and after Ctrl+C in the program.
- [ ] A missing program, a folder that cannot be entered, a file that is not a program and a failing program
      each give their notification, and the app stays usable.
- [ ] `[/bold]` in a title or message is shown literally; an escape sequence is shown as `�` and never reaches
      the terminal.
- [ ] Moving, Enter and `c` in an empty (filtered-out) list do nothing and do not crash.
- [ ] The app never writes to a session store.
- [ ] `session-browser` exits 0 after `q`, and 1 if the app crashed.
- [ ] `uv tool install --editable .` puts `session-browser` in `~/.local/bin`, and `session-browser --help`
      prints the usage.
- [ ] SB8 is committed in the repository's style and tagged `course/sb8`.

## Testing

| File | Tests | What it covers |
|---|---|---|
| `test_imports.py` | 8 (one test, parametrised) | Every module imports |
| `test_models.py` | 5 | `key` unique across sources, `project` with and without a folder, immutability, naive times rejected |
| `test_claude.py` | 11 | Sub-agents skipped, last title wins, prompt fallback, first folder, a cut-off line, branch, messages and their limit, a 5,000-line file read from both ends, missing and default stores |
| `test_codex.py` | 10 | Sub-agent threads skipped, titles from the index or the first prompt, last activity rather than the index time, folder and branch from `session_meta`, messages, missing and default stores; two zstd tests, compressed and damaged (3.14 only) |
| `test_kitty.py` | 7 | Listing by name, the first `cd`, tab and window counts, the file time, a relative `cd`, Kitty's line splitting (tab separator, unknown `~user`), the default folder |
| `test_actions.py` | 12 | Each source's `Launch`, `TMPDIR` created under `HOME`, the home fallback, shell quoting, `run()`'s folder, environment and exit status, detached return, a missing program, Ctrl+C reaching the program but not the caller |
| `test_app.py` | 16 | Pilot: ordering, tabs, search, Esc, the Vim keys, what Enter launches for each source, start-up errors and a failing program (with the real launcher and a recording `suspend`), an empty list, `c`, text shown literally, escape sequences replaced |
| `test_snapshots.py` | 1 | The screen at 116 × 34 with the last row selected, against the SVG baseline |

Principles:

- **Isolation.** `synthetic_stores` (autouse) moves `HOME` and all three stores for every test.
- **Determinism.** `pinned_stores` copies the fixtures inside `HOME`, pins the Kitty file times to
  2026-09-20 12:00 UTC and the time zone to UTC. Assertions that depend on a session's folder use only the
  session whose folder is documented as missing.
- **Fakes, not mocks of internals.** A fake launcher (`launches.append`), recorders for `notify` and
  `suspend` swapped in with `monkeypatch`, and fake programs as the whole `PATH`.
- **The Nix sandbox.** The suite needs no terminal, no network and no writable source, and was run that way
  (no controlling terminal, no network, a bare `PATH`, read-only files): 68 passed, 2 skipped. In a real
  `nix-build` of the lesson 21 sketch against nixpkgs `20b1ddd`: 69 passed (Python 3.14.7, pytest 9.1.1; the
  snapshot test is left out).

Commands, from `python/session-browser`: `uv run pytest -q`, `uv run pytest --snapshot-update` (only after a
deliberate change to the screen, then review the SVG), `ruff check`, `ruff format --check`, `pyright`.

## Packaging

- **Supported:** `uv tool install --editable .` from `python/session-browser`. The command lands in
  `~/.local/bin`, already on `PATH` through `home/modules/shell.nix`; source edits apply without reinstalling.
  `uv tool uninstall session-browser` removes it.
- **Optional:** a `buildPythonApplication` derivation (lesson 21, step 8), built with `nix-build` in the Nix
  sandbox against the flake's root nixpkgs (`20b1ddd`) but not yet through the flake (verify on
  laptop-intel). Two known caveats: the `uv_build` requirement written by `uv init` is newer than nixpkgs'
  uv-build 0.11.28, so the sketch passes `--skip-dependency-check`; and nixpkgs' `pytest-textual-snapshot`
  sits on syrupy 5, which would look for `.raw` baselines, so the snapshot test is skipped in the Nix build.
  Flakes only see tracked files: `git add` first.
- **Optional:** a Hyprland key, `kitty --class session-browser -e ~/.local/bin/session-browser` (lesson 21,
  step 9; verify on laptop-intel). On laptop-intel new windows open on workspace 10.

## Known limitations

Found and deliberately left alone; none of them affects the synthetic stores or normal use.

- **Year-1 timestamps crash the app.** A time of year 1 (or year 9999 east of UTC) makes `format_time()`'s
  `astimezone()` raise `OverflowError`. Only garbage data can contain one.
- **`c` creates `~/.claude/tmp`**, because it builds the same `Launch` as Enter; if `~/.claude` is not
  writable, the error is raised outside the app's error handling.
- **Kitty counts differ from Kitty's in corner cases:** a tab with no `launch` gets a shell window from Kitty
  but counts as 0 windows here, and a bare `cd` (Kitty: the session file's folder) is ignored.
- **Codex metadata** is taken from the first line that parses, not strictly the first line of the file.
- **Ctrl+\ (SIGQUIT) during a resumed program ends the browser too.** Only SIGINT is guarded; giving the
  program its own process group, as a shell does, would be the fuller fix.
- **A mouse click on the highlighted row resumes it** (Textual's `DataTable` selects on a second click).
- **While loading, the header reads "0 of 0 sessions"**, because `Tabs` announces its first tab before the
  worker finishes.
- **The list does not refresh** after a resumed session exits, so that session does not move to the top until
  the browser is restarted.
- **Output of a resumed program is behind the app.** A failure is reported, but its text is only visible after
  quitting.
- **Compressed Codex rollouts** (`.jsonl.zst`) are read on Python 3.14 only.
- **Aliases and shell functions are not applied** to the programs the browser starts; only the `claude`
  alias's `TMPDIR` is recreated.

## Stretch goals

- **Live Kitty windows.** Enable `allow_remote_control` (for example `socket-only`) and `listen_on
  unix:/tmp/kitty` in the Kitty settings (`home/stages/desktop.nix`), then list windows with
  `kitten @ --to unix:<socket> ls` from a worker thread. Every Kitty that Hyprland starts is its own process
  with its own socket (the PID is appended to the path), so the browser would have to query each one. With a
  socket, `kitten @ action goto_session <path>` should also open a saved session inside a running Kitty
  instead of a new process (unverified end to end).
- **Sub-agent nesting.** Show Codex sub-agent threads under the thread that started them
  (`parent_thread_id` in `session_meta`), and Claude sub-agent transcripts under their session.
- **Reload after resume.** Re-run the loader when a resumed program exits, so the session moves to the top.
- **Live and cost badges for Claude.** `~/.claude/sessions/<pid>.json` marks a session that is open right now;
  `cost-state` and `pr-link` entries could become columns.
- **More actions.** Fork a session (`claude --resume <id> --fork-session`, `codex fork`), or open its folder in
  a dev layout.
- **A help screen** on `?`, listing the keymap.
