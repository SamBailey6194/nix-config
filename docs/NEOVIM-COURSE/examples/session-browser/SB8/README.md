# Session Browser

**Last Updated**: 27/09/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

A terminal app that lists, searches, previews and resumes your Claude Code,
Codex and Kitty sessions in one place. Built with [Textual](https://textual.textualize.io/)
as the second capstone of the Neovim course.

## Run it

```bash
# from python/session-browser
uv run session-browser
uv run session-browser --kitty-sessions-dir ~/work/kitty-sessions
```

## Keys

| Key | Where | Action |
|---|---|---|
| `j` / `k`, arrows | list | Move down / up |
| `g` / `G` | list | First / last session |
| `Enter` | list | Resume the session (Kitty: open it in a new window) |
| `c` | anywhere but the search box | Copy the resume command to the clipboard |
| `h` / `l` | anywhere but the search box | Previous / next source tab (All, Claude, Codex, Kitty) |
| `/` | anywhere but the search box | Search titles and folders |
| `Esc` | anywhere | Back to the list |
| `Enter` | search box | Back to the list, keeping the search |
| `q`, `Ctrl+Q` | anywhere but the search box (`Ctrl+Q` anywhere) | Quit |

## Where the sessions come from

| Source | Location | Override |
|---|---|---|
| Claude Code | `~/.claude/projects/<folder>/<session id>.jsonl` | `CLAUDE_CONFIG_DIR` (Claude Code's own) |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` and `~/.codex/session_index.jsonl` | `CODEX_HOME` (Codex's own) |
| Kitty | `*.kitty-session` files in `~/.local/share/kitty/sessions` | `--kitty-sessions-dir DIR` or `SESSION_BROWSER_KITTY_DIR` |

Sub-agent transcripts (Claude) and sub-agent threads (Codex) are left out: you
cannot usefully resume them on their own. Compressed Codex rollouts
(`.jsonl.zst`) are read on Python 3.14 and later, and skipped before that.

The app only reads these files. It never changes them.

## What Enter runs

| Source | Command | Where |
|---|---|---|
| Claude Code | `claude --resume <id>`, with `TMPDIR=~/.claude/tmp` | The session's folder, in this terminal |
| Codex | `codex resume <id>` | The session's folder, in this terminal |
| Kitty | `kitty --session <file>` | A new kitty window; the browser keeps running |

Claude and Codex borrow the terminal and hand it back when you quit them. If a
session's folder no longer exists, the command starts in your home directory
and the app tells you so. If the program cannot start, or exits with an error,
the app says that too; what the program printed stays on the terminal behind
the app, so quit the browser to read it. `TMPDIR` is set because the `claude`
alias in `home/modules/shell.nix` sets it, and aliases do not apply to programs
started from another program.

Titles, folders and messages are shown as plain text: `[brackets]` are not
read as Textual markup, and control characters (the start of a terminal escape
sequence, for example) are shown as `�` instead of being sent to your
terminal.

## Try it on the synthetic sessions

```bash
# from python/session-browser
CLAUDE_CONFIG_DIR=$PWD/tests/fixtures/claude \
CODEX_HOME=$PWD/tests/fixtures/codex \
uv run session-browser --kitty-sessions-dir tests/fixtures/kitty
```

See `tests/fixtures/README.md` for what each file is there to test.

## Develop

```bash
uv sync                                   # create .venv with the dev tools
uv run pytest                             # all tests, including the snapshot
uv run pytest --snapshot-update           # accept a deliberate change to the screen
ruff check && ruff format --check         # uvx ruff ... where ruff is not installed
pyright                                   # uses .venv via [tool.pyright]
uv run textual run --dev -c session-browser   # live CSS reload
uv run textual console                    # in a second terminal: logs and print()
```

The tests never read your real sessions: `tests/conftest.py` points
`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, the Kitty folder and `HOME` at the fixtures
and a temporary directory.

## Install

```bash
# from python/session-browser
uv tool install --editable .
```

This puts `session-browser` in `~/.local/bin`. With `--editable`, changes to
the source take effect without reinstalling.

## Layout

```text
src/session_browser/
├── app.py            Textual app: table, preview, tabs, search, key bindings
├── app.tcss          Layout
├── models.py         Session, Source, Message
├── actions.py        Launch: the command for a session, and running it
└── sources/
    ├── __init__.py   JSON Lines helpers shared by the sources
    ├── claude.py     Claude Code transcripts
    ├── codex.py      Codex rollouts
    └── kitty.py      Kitty session files
```

## Not done yet

- Live Kitty windows through `kitten @ ls`. That needs `allow_remote_control`
  and `listen_on` in kitty's settings, which this configuration leaves off.
- Showing Codex sub-agent threads under the thread that started them.
