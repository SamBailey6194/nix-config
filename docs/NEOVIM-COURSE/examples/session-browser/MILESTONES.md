# session-browser milestone notes: SB0 to SB8

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Notes on the worked examples for the Python capstone: for each milestone, the lesson that builds it, the files
it adds or changes, why, the traps met while building it, and the check results. Each `SBn/` folder is a
complete uv project (src layout, package `session_browser`, console script `session-browser`), and the
lessons print its code byte for byte. The folders hold no virtualenv or caches: `check.sh` works on a copy.
How to use the examples is in [../README.md](../README.md).

| Milestone | Lesson | What it adds |
|---|---|---|
| SB0 | [06 Terminal](../../lessons/06-TERMINAL.md) | `uv init` scaffold, textual, dev tools, a minimal app |
| SB1 | [07 Tree](../../lessons/07-TREE.md) | Module files created from the tree; the app moves to `app.py` |
| SB2 | [08 File Pane](../../lessons/08-FILE-PANE.md) | `models.py`: `Source`, `Session`, `Message` |
| SB3 | [10 LSP](../../lessons/10-LSP.md) | Claude Code source, shared JSON Lines helpers, fixtures, `[tool.pyright]` |
| SB4 | [11 Completion, formatting and diagnostics](../../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | Codex and Kitty sources |
| SB5 | [18 TUI skeleton](../../lessons/18-SESSION-BROWSER-TUI-SKELETON.md) | Textual app: worker, DataTable, markup- and escape-safe text, `app.tcss` |
| SB6 | [19 Filter and search](../../lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md) | Source tabs, search, `j/k/g/G`, `h/l`, `/`, Esc |
| SB7 | [20 Actions](../../lessons/20-SESSION-BROWSER-ACTIONS.md) | `actions.py`: Launch, Enter resumes, `c` copies, injectable launcher |
| SB8 | [21 Testing and shipping](../../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) | Pilot tests, snapshot SVG, README, packaging |

**Built with** uv 0.12.5 and Python 3.12.3 on Ubuntu, on 27/09/2026, with every milestone from SB3 on also
tested on Python 3.14.6. Locked: textual 8.2.8, rich 15.0.0, pytest 8.4.2, pytest-asyncio 1.4.0,
pytest-textual-snapshot 1.1.0, syrupy 4.8.0, textual-dev 1.8.0. Checked with `uvx ruff` 0.16.9 and
`uvx pyright` 1.1.414, and SB8 also with ruff 0.14.11 and a Node-installed pyright 1.1.408, all clean.
SB0, SB4 and SB8 were checked again with laptop-intel's own versions from the flake's pinned nixpkgs
(`20b1ddd`), fetched with Nix: uv 0.12.16, Python 3.14.7, ruff 0.16.7 and pyright 1.1.414, all clean.

## Contents

- [Scaffold (lesson 06): the exact commands](#scaffold-lesson-06-the-exact-commands)
- [Per-milestone notes](#per-milestone-notes)
- [How the checks run](#how-the-checks-run)
- [Traps found while building](#traps-found-while-building)
- [Packaging notes (lesson 21)](#packaging-notes-lesson-21)
- [The session fixtures](#the-session-fixtures)
- [Fixes found in testing](#fixes-found-in-testing)
- [Stretch goals (not implemented)](#stretch-goals-not-implemented)

---

## Scaffold (lesson 06): the exact commands

```bash
# in ~/Repos/personal/nix-config (python/ does not exist yet)
mkdir -p python && cd python
uv init --python '>=3.12' --vcs none --author-from none \
  --description "Browse and resume Claude Code, Codex and Kitty sessions" session-browser
cd session-browser
uv add textual
uv add --dev pytest pytest-asyncio 'pytest-textual-snapshot>=1.1' textual-dev
uv run session-browser
```

- `--python '>=3.12'` must be quoted in zsh (`>` is a redirect). uv writes it straight into
  `requires-python = ">=3.12"`, so no edit is needed. It pins `.python-version` to the first interpreter it
  finds: **3.12 on Ubuntu, 3.14 on NixOS**. Checked with a PATH holding only python3.14: `.python-version`
  was `3.14` and `requires-python` stayed `>=3.12`. `.python-version` is machine-specific, so the examples
  leave it out on purpose; keep and commit yours.
- `--author-from none` leaves `authors` out. Otherwise uv copies your git identity into `pyproject.toml`.
- `--vcs none` plus being inside a git repo means **uv creates neither `.git` nor `.gitignore`**. It does
  create `pyproject.toml`, `.python-version`, an **empty** `README.md` and `src/session_browser/__init__.py`
  (the hello-world `main()`). The `[build-system]` it writes is `uv_build>=0.12.5,<0.13.0`: the lower bound
  is the version of the uv that ran `uv init`. laptop-intel's uv is 0.12.16 (nixpkgs `20b1ddd`, the flake's
  root `nixpkgs` input) and writes `uv_build>=0.12.16,<0.13.0` (checked by running that uv). Like
  `.python-version`, this line is machine-specific: leave yours as uv wrote it.
- `uv add textual` writes `textual>=8.2.8`.
- The dev line writes `pytest>=8.4.2`, `pytest-asyncio>=1.4.0`, `pytest-textual-snapshot>=1.1` and
  `textual-dev>=1.8.0`.

Manual edits to the uv output in SB0:

1. Replace `src/session_browser/__init__.py` with the minimal Textual app. `main()` stays where
   `[project.scripts]` expects it (`session_browser:main`).
2. Create `.gitignore`: uv's usual template, plus `.pytest_cache/` and `.ruff_cache/`. The repository's own
   `.gitignore` has no Python entries.
3. Append `[tool.ruff.lint] select = ["E", "W", "F", "I", "UP", "B", "SIM"]` to `pyproject.toml`.

### The syrupy/pytest pin conflict: how it was resolved

- pytest-textual-snapshot 1.1.0 (the latest) pins `syrupy==4.8.0`, which needs `pytest<9`. With the plugin
  unpinned, uv picks the older plugin 1.0.0 with syrupy 6.1.1 and pytest 9.1.1.
- That combination is broken in a way you can see. The plugin names its snapshot files through
  `_file_extension = "svg"`. syrupy 5 and later ignore that attribute (it is now `file_extension`), so the
  baselines are written as `.raw`. Checked in the source of syrupy 4.8.0, 5.5.3 and 6.1.1.
- **Decision:** `uv add --dev … 'pytest-textual-snapshot>=1.1' …`. This resolves to pytest 8.4.2 and
  syrupy 4.8.0, which is the combination the plugin's authors pinned. The baseline is a real `.svg` that
  doubles as a lesson image. pytest-asyncio 1.4.0 accepts pytest ≥ 8.4, so nothing else moves.

---

## Per-milestone notes

For each milestone: files added (A) or changed (M) compared with the previous one, why, and the check
results. [How the checks run](#how-the-checks-run) has the commands.

### SB0 (lesson 06): scaffold and a minimal app

- A: the uv output (`pyproject.toml`, `README.md` (empty), `uv.lock`, `src/session_browser/__init__.py`;
  `.python-version` left out, see above) and `.gitignore`.
- Why: `uv run session-browser` shows Header ("Session browser") and Footer (`q Quit`), and `q` quits. The
  app sits in `__init__.py` so that uv's own entry point works with no `pyproject` edit in lesson 06.
- The pytest config was held back to SB1. With `testpaths` set and no `tests/` directory, pytest prints a
  confusing "No files were found in testpaths" warning.
- Checks: `uv sync` ok; `uv run pytest` **exit 5, "no tests ran"** (expected: there are no tests until
  SB1); ruff check ok; ruff format --check ok; pyright (with `--pythonpath .venv/bin/python`) 0 errors. pty:
  `q` gives exit 0.

### SB1 (lesson 07): package layout from the tree

- A: `app.py` (the SB0 app, moved), `models.py`, `actions.py`, `sources/__init__.py`, `sources/claude.py`,
  `sources/codex.py`, `sources/kitty.py`, `tests/conftest.py`. Each new file is a one-line docstring, except
  `app.py`.
- A: `tests/test_imports.py`, a parametrised import of every module. This proves "the stubs import cleanly"
  and gives pytest something to run.
- M: `__init__.py` is now just the docstring. `pyproject.toml`: the script becomes
  `session_browser.app:main`, and `[tool.pytest.ini_options]` gains `asyncio_mode = "auto"` and
  `testpaths = ["tests"]`.
- Checks: 8 passed; ruff and format clean; pyright (with `--pythonpath .venv/bin/python`) 0 errors. pty:
  exit 0.

### SB2 (lesson 08): the plain data types

- M: `models.py` gains:
  - `Source(StrEnum)`: claude, codex, kitty.
  - A frozen, slotted dataclass `Session(source, id, title, cwd: Path | None, updated: datetime, path,
    detail="")`.
  - `Session.__post_init__`, which rejects a naive `updated`. Sessions from all three tools are sorted
    together, and a naive/aware comparison raises TypeError.
  - The properties `key` (`"claude:<id>"`, unique DataTable row keys) and `project` (the cwd basename).
  - `Message(role: Literal["user", "assistant"], text)`.
  Attribute docstrings are used on purpose: pyright shows them on hover (`K`).
- A: `tests/test_models.py` (5 tests). One uses `# pyright: ignore[reportAttributeAccessIssue]` for the
  deliberate assignment to a frozen field.
- Checks: 13 passed; ruff clean. `pyright --pythonpath .venv/bin/python` gives 0 errors. **Plain `pyright`
  gives 4 errors** ("Import "textual"/"pytest" could not be resolved"). That is the lesson-10 teaching
  moment, fixed in SB3.

### SB3 (lesson 10): Claude Code source

- A: `tests/fixtures/`, a copy of the course's `fixtures/sessions/`.
- M: `sources/__init__.py`, the shared helpers:
  - `type Entry = dict[str, Any]`.
  - `read_entries(file)`: the first `HEAD_LINES = 30` lines plus the last `TAIL_BYTES = 256 KiB`. There is
    no overlap. When the read lands mid-file, the first tail fragment is dropped (if the jump lands exactly
    on a line boundary, that is one whole line from the middle of the file, which never matters; the
    comment says so).
  - `parse_line` skips malformed and non-object lines.
  - `parse_timestamp` treats an offset-less time as UTC.
  - `modified(path)` and `one_line(text, 80)`.
- M: `sources/claude.py`:
  - `config_dir()`: `CLAUDE_CONFIG_DIR`, else `~/.claude`.
  - `load_sessions()` globs `projects/*/*.jsonl`. The glob's depth is what skips `<id>/subagents/…`.
  - In `read_session()`: `cwd` is the first entry that has one; the title is the last `ai-title`, else the
    first prompt you typed, else "(untitled)"; `updated` is the newest timestamp, else mtime; `detail` is
    `git branch X`.
  - `user_text` filters `isMeta` and `<command-…>`, `<local-command-…>`, `<task-notification>` and
    `<pasted_content>`, and accepts str or list content.
  - `recent_messages(path, limit=6)`. It lives here rather than in SB5 so that the SB5 diff stays about
    Textual.
- M: `tests/conftest.py` gains an autouse `synthetic_stores` fixture: HOME becomes tmp_path and
  `CLAUDE_CONFIG_DIR` points at the fixtures. **No test can read real sessions.**
- A: `tests/test_claude.py` (11 tests). They cover the sub-agent skip, the last ai-title winning, the prompt
  fallback, the first cwd, the malformed line, the branch, recent messages and the limit. A 5,000-line
  (> 2×256 KiB) synthetic file proves the two-ends read. Also covered: a missing store and the default dir.
- M: `pyproject.toml` gains `[tool.pyright] venvPath = "."`, `venv = ".venv"`.
- Checks: 24 passed; ruff clean; pyright 0 errors. On 3.14: 24 passed.

### SB4 (lesson 11): Codex and Kitty sources

- M: `sources/codex.py`:
  - `codex_home()`: `CODEX_HOME`, else `~/.codex`.
  - `read_index()`: id → `thread_name`, a later line wins.
  - Globs `sessions/*/*/*/rollout-*`, keeping the suffixes `.jsonl`, plus `.jsonl.zst` when zstd is
    available.
  - `session_meta` must be the first line. `thread_source == "subagent"` is skipped.
  - The title is the index name, else the first `UserMessage`.
  - `updated` is the rollout's newest timestamp, **not** the index's `updated_at`. A structural scan of a
    real index showed it lags the last message by 1–52 minutes: it records naming.
  - Messages come only from `event_msg`/`item_completed` `UserMessage` and `AgentMessage` items (block keys
    checked structurally: `text`), never from `response_item`, which carries `<environment_context>`.
  - The zstd import is `if sys.version_info >= (3, 14): try: from compression import zstd except
    ImportError: zstd = None`. The version gate keeps pyright (analysing for 3.12) quiet, and the try covers
    a CPython built without libzstd. pyright is clean at both `--pythonversion 3.12` and `3.14`.
  - `open_rollout()` decompresses a `.zst` rollout in one go (`BytesIO(zstd.decompress(...))`) and turns
    `zstd.ZstdError` into `OSError(errno.EIO, "damaged zstd file (...)")`. Reading a damaged or truncated
    archive through `zstd.open` raised `ZstdError` or `EOFError`, neither an OSError, so on 3.14 (the NixOS
    Python) one bad file crashed the loading worker and the preview. `zstd.decompress` raises only
    `ZstdError` (checked: truncated, garbage, empty; multi-frame input decompresses fine).
- M: `sources/kitty.py`:
  - `sessions_dir()`: `SESSION_BROWSER_KITTY_DIR`, else `~/.local/share/kitty/sessions`.
  - Accepts `.kitty-session`, `.kitty_session` and `.session`, kitty's own list for directory scans.
  - The title is the file stem. `cwd` is the first `cd`, with `~` and `$VARS` expanded and a relative path
    taken from the session file's folder, as kitty does.
  - Lines are split the way kitty v0.48.2's `parse_session` splits them, `line.split(maxsplit=1)`, so a tab
    after the keyword works (`partition(" ")` missed `cd<Tab>/path`). `~` goes through
    `os.path.expanduser`, which is what kitty uses: it leaves an unknown `~user` as it is, where
    `Path.expanduser` raises `RuntimeError` and crashed the loading worker on a session file copied from
    another machine. The directory argument gets the same treatment.
  - `updated` is the mtime. `detail` reads "2 tabs, 4 windows": a `launch` before any `new_tab` opens the
    first tab, and `new_os_window` starts a fresh one.
- M: `conftest.py` also sets `CODEX_HOME` and `SESSION_BROWSER_KITTY_DIR`.
- A: `tests/test_codex.py` (10 tests). The two zstd ones (a compressed rollout, and a truncated plus a
  garbage `.zst` that must be skipped) use `pytest.importorskip("compression.zstd")`, so they are skipped on
  3.12 and run on 3.14. A: `tests/test_kitty.py` (7 tests; one covers the tab separator and the unknown
  `~user`). `test_updated_is_the_file_modification_time` compares `session.updated` with
  `datetime.fromtimestamp(st_mtime, tz=UTC)`, datetime with datetime (see
  [Fixes found in testing](#fixes-found-in-testing) for why).
- Checks: 39 passed, 2 skipped (3.12); **41 passed on 3.14**; ruff clean; pyright 0 errors.
- Live `kitten @ ls` is out of scope, because remote control is off in this config. It is a stretch goal,
  noted in the SB8 README.

### SB5 (lesson 18): the Textual app skeleton

- M: `app.py`:
  - `SessionBrowser(App[None])` with `CSS_PATH = "app.tcss"`. The layout is Header, then
    `Horizontal(DataTable(id="sessions", cursor_type="row"), VerticalScroll(Static(id="preview",
    markup=False)))`, then Footer.
  - The loader is `@work(thread=True, exclusive=True) load_sessions`, which uses
    `call_from_thread(self.show_sessions, …)`. `table.loading = True/False` shows the loading indicator.
  - **`table.focus()` after loading.** While it was loading, the table could not take focus, so Textual
    focused the preview's VerticalScroll and arrow keys scrolled the preview. Observed with Pilot.
  - Columns: Source 6, Title 30, Project 15, Updated 16 (`%Y-%m-%d %H:%M` local). These fit ~116-column
    tapes (1440 px at FontSize 20) even when a vertical scrollbar appears.
  - The preview is plain text, rebuilt on `RowHighlighted`, reading synchronously (at most 30 lines +
    256 KiB, 3.6 ms worst case on real data): title, Source (+detail), Updated, Folder, File, then the last
    6 messages, each cut at 600 characters. Paths under HOME are shown as `~/…` (`tilde()`), which also
    makes the SB8 snapshot machine-independent.
  - `main()` uses argparse for `--kitty-sessions-dir DIR`, then `sys.exit(app.return_code)`. `App.run()`
    returns normally even after a crash (the traceback is printed, `return_code` is 1), so without it the
    console script exited 0 after a crash. Verified on a pty: a crash now exits 1.
  - `printable(text)` replaces control characters (C0 bar tab and newline, DEL, C1) with U+FFFD. It is
    applied to the Title and Project cells and to the whole preview text. See trap 1: neither `Content` nor
    `markup=False` stops an escape sequence in session text reaching the terminal.
  - `on_data_table_row_highlighted` returns early when `event.row_key is None`. Up or Page Down in an empty
    table moves the cursor to row -1, and DataTable posts `RowHighlighted(cursor_row=-1, row_key=None)`
    although the attribute is typed `RowKey`: the handler crashed on `None.value` (see trap 11).
- A: `app.tcss` (table 2fr, preview 1fr with a left border).
- **Markup traps (verified in the Textual 8.2.8 source):**
  - `DataTable` passes **str cells through `Text.from_markup`**, so a title such as "Why [/bold] crashes…"
    raises `MarkupError`. Cells from session data are wrapped in `textual.content.Content(...)`, which is
    plain and renderable, with no rich import needed.
  - `Static` defaults to `markup=True`, hence `markup=False` for the preview.
- Checks: 39 passed, 2 skipped; ruff clean; pyright 0 errors. pty: arrows move the cursor, the preview shows
  the Claude session and its branch, the `[/bold]` title renders literally, exit 0. Up/`k`/Page Down on an
  empty store: no crash.

### SB6 (lesson 19): filter and search

- M: `app.py`:
  - `SessionTable(DataTable)` adds `j`/`k` (`cursor_down`/`cursor_up`) and `g`/`G`
    (`scroll_top`/`scroll_bottom`, which move the row cursor), with `key_display="j/k"` so the footer stays
    short.
  - App bindings: `slash` → search, `l`/`h` → next/previous tab (footer shows `h/l`), and **`escape` → focus
    table, on the App**, because Input has no Escape binding and the key bubbles up. `q` quits.
  - A filter row holds `Tabs(Tab("All", id="all"), *(Tab(s.name.title(), id=s.value) for s in Source))` and
    `Input(compact=True)`.
  - `refresh_table()` reads the state straight from the widgets (`Tabs.active`, `Input.value`), so there is
    a single source of truth. The pure function `matches(session, source, search)` does a casefold
    substring match on title or folder.
  - `on_input_submitted` returns focus to the list.
- M: `app.tcss` puts the filter row in the same 2fr/1fr columns.
- Verified with Pilot and in a real terminal:
  - In the search box, `q` and `h` are typed rather than acted on.
  - Esc returns to the table.
  - Tabs wrap (`_move_tab` uses modulo).
  - With the search box focused, Textual's footer hides bindings on printable keys.
- Checks: 39 passed, 2 skipped; ruff clean; pyright 0 errors. pty: tab and search counts "9 of 9 / 4 of 9 /
  2 of 9 / 3 of 9 sessions" all seen. `q` pressed after Esc exits 0, which proves Esc left the Input. A
  search that matches nothing, then Esc, `k`, Up, `G`: no crash ("0 of 9 sessions"), and clearing the search
  brings the rows back.
- The preview follows filtering: `refresh_table()` clears the table, and DataTable's `add_row` posts
  `RowHighlighted` for row 0 when the first row arrives (checked in the 8.2.8 source and with Pilot), so the
  preview always shows the highlighted row.

### SB7 (lesson 20): actions

- M: `actions.py`:
  - `Launch(argv: tuple[str, ...], cwd: Path, env: dict[str, str] = field(default_factory=dict),
    detach: bool = False)`, a frozen, slotted dataclass. `shell_command()` gives
    `cd <cwd> && K=V … <shlex.join(argv)>`.
  - `type Launcher = Callable[[Launch], None]`.
  - `build_launch(session)` does `match` on the source:
    - Claude: `("claude", "--resume", id)` with `env={"TMPDIR": ~/.claude/tmp}`. `claude_tmpdir()` creates
      the directory, and its docstring explains the shell.nix alias and why subprocess bypasses it.
    - Codex: `("codex", "resume", id)`, run in the session cwd so that Codex does not ask about the resume
      cwd.
    - Kitty: `("kitty", "--session", <resolved path>)`, `detach=True`.
    - A missing cwd becomes `Path.home()`.
  - `run(launch) -> int | None`. Detached: `Popen(start_new_session=True, DEVNULL×3)`, plus
    `threading.Thread(target=process.wait, daemon=True)` so no zombie lingers, and it returns None. Without
    the thread, `-W error` shows `ResourceWarning: subprocess … is still running`. Blocking:
    `subprocess.run` under a do-nothing SIGINT handler (see the traps below), returning the exit status.
- M: `app.py`:
  - `SessionBrowser(kitty_dir=None, launcher=None)`: the launcher defaults to `self.run_in_terminal`.
  - `on_data_table_row_selected` builds the Launch, warns (`severity="warning"`, `markup=False`, text
    through `printable`) when the folder has gone, calls the launcher, and turns `FileNotFoundError` into
    "Could not find 'claude'. Is it installed and on PATH?" and any other `OSError` into "Could not start
    'claude': <strerror>." (for example Permission denied, Exec format error).
  - `run_in_terminal`: detached commands run straight away. Otherwise it runs `actions.run(launch)` inside
    `with self.suspend():`, **catching `OSError` inside the block** and raising it again after the block,
    once the app has its terminal back (trap 3). A positive exit status becomes a warning: "claude exited
    with status 1. Quit the browser to read what it printed." (whatever the program printed went to the
    normal screen behind the app; without the warning, a program that failed straight away just made the
    screen flicker). A `shutil.which` pre-check is not needed: it only covered a missing program, and the
    catch covers every start-up error.
  - `c` → `action_copy_command` → `copy_to_clipboard` (OSC 52) and a notification (text through
    `printable`).
  - The table's `enter` binding is re-declared only to label it "Resume" in the footer.
- A: `tests/test_actions.py` (12 tests):
  - argv, cwd and env for each source; TMPDIR created under HOME; the home fallback; shell quoting.
  - `run` passes cwd and env; returns the exit status (None when detached); detached returns in < 1 s; a
    missing program raises FileNotFoundError.
  - Two signal tests: a child doing `kill -INT $PPID` must not interrupt pytest, and a child doing
    `kill -INT $$; touch survived` must die, which proves it did not inherit SIG_IGN. Both were shown to fail
    against the naive versions.
- Checks: 51 passed, 2 skipped (3.14: 53 passed); ruff clean; pyright 0 errors.
- pty, with fake `claude`/`codex`/`kitty` scripts first on PATH that log argv|cwd|TMPDIR, and HOME in a
  throwaway folder:
  - Enter on Claude: the fake claude printed and read a line from the TTY (it had the terminal).
  - The final "full" run logged
    `claude|--resume 4b1f6c2e-8d3a-4f7b-9c1e-2a5d7e9f0b13|<HOME>|<HOME>/.claude/tmp`,
    `codex|resume 019a3c4d-5e6f-7a81-9b2c-3d4e5f6a7b82|<HOME>|` and
    `kitty|--session <fixtures>/kitty/just-panel.kitty-session|<HOME>|` (detached). The fixture folders do
    not exist on the test machine, hence HOME and the warning.
  - `c` emitted `ESC]52;c;` and "Copied".
  - PATH with only `uv`: "Could not find 'claude'. Is it installed and on PATH?", and the app stayed usable.
    The terminal flickers once, because the error comes from inside `suspend()`, where it is caught.
  - A session folder that exists but cannot be entered (mode 000): "Could not start 'claude': Permission
    denied.", app usable.
  - A fake claude that prints "No conversation found…" and exits 1: the warning notification appears.
  - Ctrl+Z during the resumed program (from an interactive bash): both stop, `fg` brings back the program
    and then the app, which reads keys again. Textual's own SIGTSTP/SIGCONT handlers, disabled for
    automatic restart inside `suspend()`, make this work.
  - Ctrl+C during a 6 s foreground fake claude: the program stopped, the app came back, and `l` changed the
    tab ("4 of 9 sessions") before `q`. Exit 0 in every case.

### SB8 (lesson 21): testing and shipping

- M: `tests/conftest.py` gains a `pinned_stores` fixture. It copies the fixtures into HOME (tmp_path), sets
  the Kitty files' mtimes to 2026-09-20 12:00 UTC (a checkout stamps clone time), and sets TZ=UTC with
  `time.tzset()`, which is undone on teardown.
- A: `tests/test_app.py`, 16 Pilot tests via `run_test` and `pilot.press`:
  - ordering; `h`/`l` counts [4, 3, 2, 9, 2]; search is case-insensitive ("PANEL" → 3).
  - Esc leaves search, and `q` typed in search does not quit.
  - Enter in search goes to the list without launching; `j`/`k`/`G`/`g` cursor moves.
  - Enter on Claude: argv, `TMPDIR` and cwd=HOME, plus one warning.
  - Enter on Codex (argv/env/detach) and on Kitty (argv, detached).
  - Missing program → an error notification. Notifications are recorded by
    `monkeypatch.setattr(app, "notify", …)`.
  - `c` → `app.clipboard`.
  - The preview shows `[/bold]` literally.
  - Escape sequences in a title (an OSC 52 clipboard write) are shown as `�` in the cell and the preview.
    The test builds its own one-session Claude store in tmp_path rather than writing into the
    `pinned_stores` copy, whose files keep the read-only modes of a read-only checkout.
  - Up, `k`, `G`, Page Down, Enter and `c` in an empty (filtered-out) list: no crash, no launch.
  - With `app.suspend` swapped for a recorder that, like Textual's, only resumes when its block ends
    normally: a `claude` that the kernel cannot run gives ["suspend", "resume"] and "Could not start
    'claude': Exec format error."; a `claude` that exits 3 gives the exit-status warning. The fake `claude`
    is the **only** program on PATH: CPython's `_posixsubprocess` goes on down PATH after ENOEXEC, and with
    the fake merely first on PATH the real `claude` ran during the test.
  - cwd-sensitive assertions use only the session whose folder the fixture README documents as absent, so a
    tape that creates `/tmp/nvim-course/nix-config` cannot break them.
  - Fake launcher: `launches: list[Launch] = []; SessionBrowser(launcher=launches.append)`.
- A: `tests/test_snapshots.py`: one `snap_compare(SessionBrowser(), terminal_size=(116, 34),
  run_before=wait_for_sessions, press=["G"])`. `run_before` waits for the loading worker.
- A: `tests/__snapshots__/test_snapshots/test_oldest_session_selected.svg`, the committed baseline, created
  with `uv run pytest --snapshot-update`. It is stable over 5 runs, under `TZ=America/New_York` and on
  Python 3.14.
- M: `.gitignore` gains `snapshot_report.html`, written by the plugin on failure.
- M: `README.md` (it was uv's empty file) covers run, keys, sources and overrides, what Enter runs
  (including what happens when a program cannot start or fails, and that session text is shown as plain
  text), trying it on the fixtures, develop, install, layout and the stretch goals.
- Checks: **68 passed, 2 skipped** (3.14: 70 passed); ruff check clean; ruff format --check clean (ruff 0.16
  also scans Markdown code blocks: the READMEs have none); pyright 0 errors. pty: the full flow, missing
  program and Ctrl+C cases all pass (see the tables below).

---

## How the checks run

`check.sh` copies the milestone with `cp -r` (fresh file times, as a checkout gives) to
`${TMPDIR:-/tmp}/session-browser-examples/SBn` and runs, in the copy:

```bash
# in docs/NEOVIM-COURSE/examples/session-browser
./check.sh SB4        # or: ./check.sh all
# which runs, in the copy of SB4:
uv sync --locked
uv run --locked pytest -q
ruff check                # from PATH if there, else uvx ruff
ruff format --check
pyright                   # SB0–SB2: pyright --pythonpath .venv/bin/python
```

The copy keeps `.venv`, `__pycache__` and the pytest and ruff caches out of the course folder, while
`.venv` still sits inside the project, where `[tool.pyright]` expects it. `--locked` makes uv stop rather
than rewrite the example's `uv.lock`. SB0's pytest exit 5 ("no tests ran") counts as a pass. Results with
Python 3.12 and 3.14 (the 3.14 runs used `uv run --python 3.14 --isolated pytest -q`):

| | uv sync | pytest (3.12) | pytest (3.14) | ruff check | format --check | pyright |
|---|---|---|---|---|---|---|
| SB0 | ok | exit 5, no tests (expected) | – | ok | ok (2 files) | 0 errors with `--pythonpath` |
| SB1 | ok | 8 passed | – | ok | ok (11) | 0 errors with `--pythonpath` |
| SB2 | ok | 13 passed | – | ok | ok (12) | 0 errors with `--pythonpath`; 4 errors without (teaching point) |
| SB3 | ok | 24 passed | 24 passed | ok | ok (14) | 0 errors |
| SB4 | ok | 39 passed, 2 skipped | 41 passed | ok | ok (16) | 0 (also `--pythonversion 3.14`: 0) |
| SB5 | ok | 39 passed, 2 skipped | 41 passed | ok | ok (16) | 0 (also 3.14: 0) |
| SB6 | ok | 39 passed, 2 skipped | 41 passed | ok | ok (16) | 0 (also 3.14: 0) |
| SB7 | ok | 51 passed, 2 skipped | 53 passed | ok | ok (17) | 0 (also 3.14: 0) |
| SB8 | ok | 68 passed, 2 skipped | 70 passed | ok | ok (19) | 0 (also 3.14: 0) |

The two skipped tests are the zstd ones, which need Python 3.14. `uv lock --check` passes in every
milestone.

**Last run of the script** (27/09/2026, from a fresh `cp -r` of `examples/session-browser`):
`./check.sh all` PASS for SB0–SB8 with uv 0.12.5, Python 3.12.3, ruff 0.14.11 and pyright 1.1.408 (the
3.12 column above), and again with laptop-intel's uv 0.12.16, Python 3.14.7, ruff 0.16.7 and pyright
1.1.414 (the 3.14 column; SB0–SB2 on 3.14 too). SB2 also passes with ruff and pyright fetched by `uvx`
(0.16.9 and 1.1.414).

SB8 was also run the way a Nix build runs it: an empty environment with a nonexistent HOME, `LANG=C`, a PATH
holding only `sh`, `touch`, `sleep`, `cat` and `env`, no controlling TTY (`setsid`, stdin closed), source and
tests read-only, no bytecode, and separately with no network (`unshare -rn`): 68 passed, 2 skipped both
times.

### Real-terminal runs

A small pty script ran the app at 120×35 with `TERM=xterm-256color`, with `CLAUDE_CONFIG_DIR`,
`CODEX_HOME` and `SESSION_BROWSER_KITTY_DIR` pointed at a copy of the fixtures (Kitty mtimes pinned) and
HOME in a throwaway folder. A case passes when the app exits 0, has left the alternate screen, printed no
traceback, and every expected string appeared.

| Milestone | Keys | Result |
|---|---|---|
| SB0–SB4 | `q` | exit 0, clean, 2/2 expected |
| SB5 | ↓ ↓ ↓ `q` | exit 0, 4/4 ("9 sessions", Claude branch line, the Claude title, "Why [/bold]") |
| SB6 | `j G g l / b r o w Esc j h q` | exit 0, 4/4 (9, 4, 2 and 3 "of 9 sessions") |
| SB7, SB8 full | `j G g / panel Esc j Enter Enter(to fake claude) l l Enter l Enter c q` | exit 0, 4/4; launch log as described in SB7 |
| SB7, SB8 missing | PATH=uv only; `Enter j q` | exit 0, error notification seen, app still usable |
| SB7, SB8 Ctrl+C | `Enter`, Ctrl+C during a 6 s fake claude, `l q` | exit 0, "4 of 9 sessions" seen after the Ctrl+C |

A second script emulates the screen (pyte) and starts the app from an interactive `bash -i` (job control,
as in real use), recording `stty -g` before and after. A case passes when the app exits 0, no traceback
appears, `stty -g` is identical afterwards and the expected text is on screen. Every case below passed on
the milestones listed.

| Case | Milestones | What it does | Seen |
|---|---|---|---|
| quit | SB5–SB8 | `q` | clean exit, terminal restored |
| filter | SB6–SB8 | `j G g l / brow Esc j h q` | "4 of 9", "2 of 9" |
| empty-search | SB6–SB8 | `/zzzz Esc k Up G`, clear the search, `q` | "0 of 9 sessions", no crash |
| empty-store | SB5–SB8 | all three stores missing; Up, `k`, Page Down, Enter, `c`, `q` | "0 sessions" / "0 of 0 sessions", no crash |
| resume | SB7, SB8 | Enter on Claude (fake reads a line), Codex, Kitty; `c` | launch log as in SB7, OSC 52 written |
| missing | SB7, SB8 | PATH holding only `uv`; Enter, `j`, `q` | "Could not find 'claude'…" |
| ctrl-c | SB7, SB8 | Ctrl+C during a 6 s fake claude, then `l` | "4 of 9 sessions" |
| ctrl-z | SB7, SB8 | Ctrl+Z during the fake claude, `fg`, then `l`, `q` | app back, "4 of 9 sessions", exit 0 |
| fail | SB7, SB8 | a fake claude that exits 1 | "claude exited with status 1…" |
| denied-cwd | SB7, SB8 | a session folder with mode 000 | "Could not start 'claude': Permission denied." |

A hostile synthetic store (escape sequences in titles and messages, a 450-character CJK and emoji title, a
Unicode folder, an empty file, garbage lines, invalid UTF-8, non-object JSON, a `.jsonl` directory, a
tab-separated and a Latin-1 kitty file, a kitty directory and a broken symlink with session suffixes) was
loaded while counting escape sequences in the raw output. Before the escape fix, `ESC]0;` (window title)
appeared 6 times, `ESC]52;c;` (clipboard write) twice, and `ESC[2J` and `ESC[?1049l` from the session text
broke the screen. After: none on SB5–SB8, only Textual's own final `ESC[?1049l`.

### Read-only runs against real stores (counts and timings only)

SB4 and SB8 were run once, read-only and with no overrides, against the build machine's own stores, printing
only counts and timings:

| Source | Files on disk | Sessions | Load | With cwd | "(untitled)" | Preview: total / worst | Errors |
|---|---|---|---|---|---|---|---|
| Claude | 168 main transcripts | 168 | 0.35 s | 168 | 14 | 0.35 s / 3.6 ms | 0 |
| Codex | 30 rollouts (23 sub-agent) | 7 | 0.05 s | 7 | 0 | 0.014 s / 3.4 ms | 0 |
| Kitty | folder absent on Ubuntu | 0 | 0.0 s | – | – | – | 0 |

- The 14 untitled Claude sessions were checked structurally (entry types only). They hold nothing but a
  slash command, `<local-command-…>` output and `isMeta` entries, so "(untitled)" is correct.
- A full parse of every line of the 168 transcripts takes 1.50 s, against 0.35 s for the two-ends read
  (quoted in the `read_entries` docstring).
- The app ran on the real stores in a pty: navigation, search, Esc, the four tabs and `q`, never Enter or
  `c`. Exit 0, no traceback.

---

## Traps found while building

1. **DataTable str cells are markup** (`default_cell_formatter` → `Text.from_markup`). Wrap untrusted text
   in `Content(...)`. `Static` also defaults to `markup=True`. `notify` defaults to `markup=True`, so pass
   `markup=False` for paths and commands. **Plain text is not terminal-safe text.** Textual and Rich strip
   only BEL, BS, VT, FF and CR (`_STRIP_CONTROL_CODES` in `textual/content.py`), not ESC, so an escape
   sequence inside a title, folder or message is written to the terminal and obeyed: it can retitle the
   window, clear the screen, leave the alternate screen or, in kitty (whose default `clipboard_control`
   allows writes), set the clipboard through OSC 52. `printable()` (SB5) shows every control character as
   `�`.
2. **Focus during loading**: a `loading=True` table cannot take focus, so Textual focuses the next focusable
   widget (the preview's VerticalScroll). Call `table.focus()` when loading ends.
3. **`App.suspend()` in Textual 8.2.8 is not exception-safe**: the resume step comes after a bare `yield`
   (`app.py` l.4754–4763, no try/finally). Any exception escaping the `with` leaves the app without its
   terminal: frozen and reading no keys, or, when the exception reaches Textual, a crash with a traceback.
   Both were reproduced on a pty. Checking `shutil.which` first covers only a missing program; a folder
   that cannot be entered, or a file that is not a runnable program, still raises inside the block. The
   fix (SB7) is to catch `OSError` inside the block, keep it, and raise it after the block has ended and
   the app has its terminal back.
4. **Ctrl+C in a resumed program quits the browser**: Textual runs under `asyncio.run`, whose SIGINT
   handler cancels the main task (`asyncio/runners.py` `_on_sigint`), so the app exits as soon as the
   program does. This was reproduced on a pty. The fix is a do-nothing Python handler around
   `subprocess.run`. It must not be `SIG_IGN`, which the child would inherit. A handled signal is reset to
   its default by exec.
5. **Detached Popen**: the child must be reaped (a daemon thread `process.wait`), otherwise it becomes a
   zombie and a ResourceWarning.
6. **`pytest-textual-snapshot` vs syrupy ≥ 5**: files are named `.raw`, not `.svg` (see the pin decision
   above).
7. **pyright + uv**: `[tool.pyright] venvPath/venv` is required. For code that is only valid on 3.14, gate
   it on `sys.version_info` so pyright analysing for 3.12 does not report a missing import.
8. **Codex `session_index.jsonl` `updated_at`** records naming, not activity.
9. The `claude` alias's `TMPDIR` must be recreated in code, and `~/.claude/tmp` created. Nothing in the
   repository creates it.
10. Snapshot determinism needs pinned mtimes, a pinned TZ, and paths shown relative to HOME.
11. **`DataTable.RowHighlighted.row_key` can be None** although it is typed `RowKey`. Up, `k`, `G` or Page
    Down in an empty table sets the cursor to row -1 (the clamp in `_clamp_cursor_coordinate` has max <
    min), and `_highlight_row(-1)` posts the event with `get_key(-1) == None`. Guard with
    `if event.row_key is None: return`. `RowSelected` is safe: `_post_selected_message` returns early on an
    empty table.
12. **`App.run()` does not raise or exit non-zero when the app crashes.** It prints the traceback and
    returns; `app.return_code` is 1. `main()` must end with `sys.exit(app.return_code)` (the idiom from
    the `return_code` docstring).
13. **`compression.zstd` errors are not OSError**: a damaged archive raises `ZstdError`, a truncated one
    read through `zstd.open` raises `EOFError`. Convert them where the file is opened (SB4 `open_rollout`).
14. **`Path.expanduser()` raises `RuntimeError`** for `~user` when that user does not exist;
    `os.path.expanduser()` returns the path unchanged, as kitty relies on.
15. **Test isolation from real programs**: `subprocess` (CPython `_posixsubprocess`) tries the next PATH
    entry after ENOEXEC or EACCES, so a fake program that cannot run falls through to the real one further
    down PATH. A test that fakes `claude` must make the fake directory the whole PATH.
16. **A program that fails at once is invisible**: its output goes to the normal screen, and `suspend()`
    returns straight to the alternate screen. Report a non-zero exit status (SB7).
17. **File times have nanoseconds, `datetime` has microseconds.** Comparing `datetime.timestamp()` with the
    float `st_mtime` fails about 3 runs in 4 on a fresh copy; compare datetimes (SB4's kitty test).

---

## Packaging notes (lesson 21)

Nothing in nix-config was changed for these notes.

### `uv tool install`

```bash
# in ~/Repos/personal/nix-config/python/session-browser
uv tool install --editable .
```

- Verified with `UV_TOOL_DIR`/`UV_TOOL_BIN_DIR` pointed into a throwaway folder. It installed 1 executable,
  and `session-browser --help` shows the argparse help.
- By default the shim lands in `~/.local/bin`, which `home/modules/shell.nix` puts on PATH.
- `--editable` means source edits take effect without reinstalling.
- On NixOS the `uv-manylinux` wrapper's `UV_CONSTRAINT` is read by `uv tool install`. It pins only
  playwright/patchright, so it has no effect here.
- `uv build` produces a wheel that contains `session_browser/app.tcss` next to `app.py` (checked with
  `zipfile -l`).

### Nix derivation sketch (built in the Nix sandbox at nixpkgs `20b1ddd`; not through the flake)

The flake's root `nixpkgs` input is `nixpkgs_4`, locked at `20b1ddd1aa` (the `ac6b2166` node in
`flake.lock` is the nixpkgs of affinity-nix's `git-hooks` input, not the system's). Evaluated there with
`nix eval`: python3 3.14.7, uv 0.12.16, **uv-build 0.11.28**, textual 8.2.8, rich 15.0.0, pytest 9.1.1,
pytest-asyncio 1.4.0, pytest-textual-snapshot 1.1.0 (relaxed onto syrupy 5.5.3), kitty 0.48.2. uv-build
0.11.28 is older than the `uv_build>=0.12.x,<0.13.0` that `uv init` writes (0.12.5 in the examples, 0.12.16
on laptop-intel), and nixpkgs' `pypaBuildHook` runs `pyproject-build --no-isolation` without
`--skip-dependency-check`: without a fix the build stops at `ERROR Unmet dependencies …
uv_build<0.13.0,>=0.12.5 … found: 0.11.28`. The fix is that flag, through `pypaBuildFlags`. It does not
depend on which uv wrote the pin.

```nix
# e.g. pkgs/session-browser.nix, called with pkgs.callPackage
{ lib, python3Packages }:

python3Packages.buildPythonApplication {
  pname = "session-browser";
  version = "0.1.0";
  pyproject = true;
  src = ../python/session-browser;   # flake sources hold only git-tracked files, so no .venv

  # uv init pins the build backend to the uv that ran it; nixpkgs ships an
  # older uv-build, which builds this project fine. Skip the pin check.
  pypaBuildFlags = [ "--skip-dependency-check" ];

  build-system = [ python3Packages.uv-build ];
  dependencies = [ python3Packages.textual ];

  nativeCheckInputs = with python3Packages; [ pytestCheckHook pytest-asyncio ];
  # nixpkgs puts pytest-textual-snapshot on syrupy 5, which looks for .raw
  # baselines instead of the committed .svg.
  disabledTestPaths = [ "tests/test_snapshots.py" ];

  pythonImportsCheck = [ "session_browser" ];
  meta.mainProgram = "session-browser";
}
```

- The tests suit the sandbox: they need no TTY and no network, and they set HOME to tmp_path themselves.
  The `sh`/`touch`/`sleep` used by `test_actions.py` come from stdenv (`kill` is a shell builtin), and the
  two `test_app.py` tests with a fake `claude` need only `/bin/sh`, which the Nix sandbox provides.
- **Real Nix build (27/09/2026).** The sketch above, with only `src` pointed at a clean copy of SB8, was
  built with `nix-build` against nixpkgs `20b1ddd` in the Nix sandbox: wheel built with
  `--skip-dependency-check`, **69 passed** on Python 3.14.7 with pytest 9.1.1 (the zstd tests run; only the
  snapshot test is left out), `pythonImportsCheck` ok, and `bin/session-browser --help` runs; `app.tcss` is
  installed next to `app.py`. The same build with SB8's pyproject changed to `uv_build>=0.12.16,<0.13.0`
  (what laptop-intel's uv writes) gives the same result. With `pytest-textual-snapshot` added to
  `nativeCheckInputs` and the test not disabled, it fails exactly as the comment says: "1 snapshot failed.
  1 snapshot unused" (syrupy 5.5.3 looks for a `.raw`, so the committed `.svg` is unused). Not yet done: a
  build through the flake (`pkgs/session-browser.nix` wired in, `git add`ed) on laptop-intel.
- `git add python/session-browser` before `nix build`.
- Optional Hyprland bind (lesson 21): `kitty --class session-browser -e session-browser`.

---

## The session fixtures

The course's `fixtures/sessions/` holds a README.md with the layout, expected listing, traps and usage.
Everything is invented: cwd paths are under `/tmp/nvim-course/…` (the folder the tapes work in) and the
texts are about building just-panel and session-browser.

- `claude/projects/…`: four sessions and one sub-agent transcript (+ `.meta.json`), with one cut-off line
  (line 5 of `c2a8e5f0-….jsonl`).
- `codex/session_index.jsonl`, three user rollouts and one sub-agent rollout.
- `kitty/just-panel.kitty-session`, `kitty/session-browser.kitty-session`.

The files were generated once by a small script (not part of the course) in the shapes of the real stores
(compact JSON); edit them by hand if needed. Every `SBn/tests/fixtures` from SB3 on is a byte-identical copy
of `fixtures/sessions/`: re-copy it into each (`cp -r fixtures/sessions/. examples/session-browser/SBn/tests/fixtures/`
from the course folder) if the course fixtures change.

## Fixes found in testing

Driving every milestone on a real pty, with hostile data and failing programs, found the bugs below. Each
fix enters at the milestone shown and is carried unchanged into every later milestone, so the lessons' code
already includes it. The fixtures and the snapshot SVG did not change.

| Fix | Enters | Files |
|---|---|---|
| `read_entries` comment made accurate (a jump onto a line boundary drops one whole line) | SB3 | `sources/__init__.py` |
| Damaged or truncated `.jsonl.zst` rollouts are skipped instead of crashing the loader and the preview (3.14) | SB4 | `sources/codex.py`, `tests/test_codex.py` |
| Kitty lines split on spaces or tabs, like kitty; unknown `~user` no longer crashes the loader | SB4 | `sources/kitty.py`, `tests/test_kitty.py` |
| `test_updated_is_the_file_modification_time` compares two datetimes instead of `session.updated.timestamp()` with the float `st_mtime` | SB4 (identical in SB5–SB8) | `tests/test_kitty.py` |
| Up/`k`/`G`/Page Down in an empty table no longer crash the app | SB5 | `app.py` |
| Escape sequences in session text are shown as `�`, never sent to the terminal | SB5 (cells, preview), SB7 (notifications) | `app.py` |
| The console script exits 1 when the app crashed (it exited 0) | SB5 | `app.py` |
| No exception can escape `suspend()`; every start-up `OSError` is reported and the app stays usable (`shutil.which` pre-check removed) | SB7 | `app.py` |
| A non-zero exit of the resumed program is reported; `actions.run` returns the exit status | SB7 | `actions.py`, `app.py`, `tests/test_actions.py` |
| Pilot regression tests for all of the above; README paragraph | SB8 | `tests/test_app.py`, `README.md` |

Before these fixes: an empty search followed by Up crashed the app, as did an empty store; a session folder
with mode 000 crashed it with a traceback whose locals printed environment values, and the process still
exited 0; a program that failed at once was silent. All four new Pilot tests in SB8 were shown to fail
against the earlier code.

- **The flaky test.** The code was right: `modified()` turns `st_mtime` into a `datetime`, which keeps
  whole microseconds, and that is all the app needs. The test was wrong: it turned the `datetime` back into
  a float and compared that with the float of a nanosecond file time. Reproduced on a copy of SB4 with the
  Kitty fixtures at a nanosecond time (`os.utime(path, ns=…)`): `assert 1790508755.148187 ==
  1790508755.1481867`. Over 100,000 random nanosecond times the float round trip differs 76 % of the time.
  Before the fix, 25 of 30 runs failed (a new random nanosecond mtime before each run), and 24 of 30 on
  Python 3.14. After it: 0 of 30 in each of SB4, SB5, SB6, SB7 and SB8 on 3.12, and 0 of 30 for SB4 on
  3.14. The `pinned_stores` fixture still pins the times for the Pilot and snapshot tests.
- **The Nix sketch.** A first version used `substituteInPlace --replace-fail 'uv_build>=0.12.5,<0.13.0'
  'uv_build'`, which fails with "pattern … doesn't match anything" on a project scaffolded by
  laptop-intel's uv 0.12.16. `pypaBuildFlags = [ "--skip-dependency-check" ]` replaced it, and the sketch
  was then built for real (see [Packaging notes](#packaging-notes-lesson-21)).

Found but deliberately not fixed (the lessons may mention them):

- A timestamp of year 1 (or year 9999 east of UTC) makes `format_time`'s `astimezone()` raise
  `OverflowError`, which crashes the app. Only garbage data can do this; both tools write current UTC times.
- `claude_tmpdir()` creates `~/.claude/tmp` from `build_launch`, so `c` (copy) creates it too, and an
  unwritable `~/.claude` would raise outside the error handling.
- Kitty's own counts differ in corner cases: a tab with no `launch` gets a shell window from kitty but
  counts as 0 windows here, and `cd` with no argument (kitty: the session file's folder) is ignored.
- Codex `_session_meta` uses the first line that parses, not strictly the first line.
- `Ctrl+\` (SIGQUIT) during a resumed program kills the browser too: only SIGINT is guarded. A shell would
  give the program its own process group; that is more than the lesson needs.
- A mouse click on the already-highlighted row resumes it (Textual's DataTable selects on a second click).
- While loading, the header reads "0 of 0 sessions" (Tabs posts `TabActivated` on mount, before the worker
  finishes).

## Stretch goals (not implemented)

- Live Kitty windows via `kitten @ ls` over a `listen_on` socket. Remote control is off in this config.
- Nesting Codex sub-agent threads under `parent_thread_id`.
- Reloading the list after a resumed session exits, so it moves to the top.
- Claude's `sessions/<pid>.json` "live" badge and `cost-state` column.
