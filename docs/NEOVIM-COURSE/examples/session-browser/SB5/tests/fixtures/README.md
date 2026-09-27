# Session fixtures

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Synthetic Claude Code, Codex and Kitty sessions for the session-browser capstone
(lessons 09–11 and 18–21) and its VHS tapes. **Everything here is invented.** The
line shapes (entry types, keys and nesting) mirror the real stores as observed
with Claude Code 2.1.283 and codex-cli 0.154.0; the text, ids, paths and times do
not come from any real session.

`python/session-browser/tests/fixtures/` is a copy of this directory:

```bash
# from the nix-config repository root
cp -r docs/NEOVIM-COURSE/fixtures/sessions/. python/session-browser/tests/fixtures/
```

## Layout

```text
sessions/
├── claude/                                   # use as CLAUDE_CONFIG_DIR
│   └── projects/
│       ├── -tmp-nvim-course-nix-config/<id>.jsonl
│       ├── -tmp-nvim-course-nix-config-python-session-browser/<id>.jsonl
│       ├── -tmp-nvim-course-nix-config-rust-just-panel/<id>.jsonl
│       │   └── <id>/subagents/agent-a7c3e91f5d2b.jsonl (+ .meta.json)
│       └── -tmp-nvim-course-scratch-textual-prototype/<id>.jsonl
├── codex/                                    # use as CODEX_HOME
│   ├── session_index.jsonl
│   └── sessions/2026/09/{24,25,26}/rollout-<local time>-<id>.jsonl
└── kitty/                                    # use as the kitty sessions dir
    ├── just-panel.kitty-session
    └── session-browser.kitty-session
```

Claude project directories are the session's first working directory with every
non-alphanumeric character replaced by `-`. That encoding is lossy, so the
browser reads `cwd` from the entries and never decodes the directory name.

## What the browser should list

Nine rows, newest first. Times are UTC; the app shows them in local time.

| Source | Title | Project | Updated (UTC) |
|---|---|---|---|
| Claude | Add a justfile recipe for the session-browser tests | nix-config | 2026-09-26 20:05 |
| Codex | Explain what ~/.codex/session_index.jsonl is for. | nix-config | 2026-09-26 07:06 |
| Codex | Suggest clippy fixes for just-panel | just-panel | 2026-09-25 15:44 |
| Claude | How do I read a Claude Code transcript without parsing the whole file? | session-browser | 2026-09-25 13:41 |
| Codex | Review the Codex source parser | session-browser | 2026-09-24 10:31 |
| Claude | Parse just's JSON dump with serde | just-panel | 2026-09-24 09:47 |
| Claude | Why [/bold] crashes Static: markup in untrusted text | textual-prototype | 2026-09-12 10:22 |
| Kitty | just-panel | just-panel | file modification time |
| Kitty | session-browser | session-browser | file modification time |

The two Kitty rows take their time from the file, so their place depends on it. A fresh copy or checkout
dates them now and sorts them first. After lesson 18's `touch -d '2026-09-20 12:00:00 UTC'` they sit between
the serde session (2026-09-24 09:47) and the textual-prototype one (2026-09-12 10:22).

## Deliberate traps

Each fixture exercises one thing a parser gets wrong:

| File | Trap | Expected behaviour |
|---|---|---|
| `rust-just-panel/4b1f6c2e….jsonl` | Two `ai-title` entries | The last one wins |
| `rust-just-panel/4b1f6c2e….jsonl` | `<command-name>`, `isMeta` and `<local-command-stdout>` user entries before the first prompt | Never used as a title or shown as something you typed |
| `rust-just-panel/4b1f6c2e…/subagents/agent-….jsonl` | Sub-agent transcript (`isSidechain: true`, same `sessionId`) | Not listed |
| `python-session-browser/9e7d2a41….jsonl` | No `ai-title`; `<task-notification>` and `<pasted_content>` entries first; the real prompt uses list content | Title is the first prompt you typed |
| `nix-config/c2a8e5f0….jsonl` | Line 5 is cut off mid-JSON | Skipped; the rest of the session still loads |
| `nix-config/c2a8e5f0….jsonl` | `cwd` changes mid-session | The first `cwd` is the project |
| `scratch-textual-prototype/e5b3d7a9….jsonl` | The working directory does not exist | Resuming warns and starts in `$HOME` |
| `scratch-textual-prototype/e5b3d7a9….jsonl` | Title and messages contain `[/bold]` and `[session titles]` | Shown literally, never parsed as Textual markup |
| `codex/sessions/2026/09/24/rollout-…-019a2b3c-9e8f-….jsonl` | Sub-agent rollout (`thread_source: "subagent"`) | Not listed |
| `codex/sessions/2026/09/26/rollout-….jsonl` | Not in `session_index.jsonl`; an injected `<environment_context>` message comes first | Title is the first `UserMessage` |
| `codex/session_index.jsonl` | `updated_at` records when the thread was named, not the last activity | `Updated` comes from the rollout's last timestamp |

## Pointing the browser at the fixtures

```bash
# from python/session-browser
CLAUDE_CONFIG_DIR=$PWD/tests/fixtures/claude \
CODEX_HOME=$PWD/tests/fixtures/codex \
uv run session-browser --kitty-sessions-dir tests/fixtures/kitty
```

`SESSION_BROWSER_KITTY_DIR` works in place of `--kitty-sessions-dir`.

> **Gotcha:** resuming a fixture session starts the real `claude` or `codex` with
> the same `CLAUDE_CONFIG_DIR` / `CODEX_HOME`. They find no such conversation (or
> ask you to log in) and may write their own files next to the fixtures. Work on
> a copy under `/tmp/nvim-course/`, as the tapes do, never on this directory.

## Editing

Keep every line a single JSON object (apart from the deliberate cut-off line) and
keep the content invented. After a change, re-copy the directory into
`tests/fixtures/` and update the table above and the tests that count rows.
