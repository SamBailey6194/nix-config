# Appendix B — Recording with VHS

**Last Updated**: 27/09/2026
**Version**: 1.1.1
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

The course was written on Ubuntu, and its GIFs, MP4s and screenshots are rendered later on
laptop-intel, the machine the course teaches. Every lesson has a script for that, a VHS tape in
`tapes/`. This appendix covers the whole job. It starts with what to settle before the first render:
a VHS that actually writes files, the worked examples the capstone tapes record, the privacy guards,
the order to record in, and what each tape needs. Then come the commands, the conventions every tape
follows, the live AI tapes for lessons 13 and 27, a checklist for each recording, and what to do when
a render fails. For a one-page summary, see [tapes/README.md](../tapes/README.md).

## First: make sure VHS is 0.12.1

The config builds VHS **0.12.1**, because the version the pinned nixpkgs (`20b1ddd`) ships, 0.12.0,
renders nothing. 0.12.0 cancels its own render step (charmbracelet/vhs#787): its evaluator swaps the run's
context for one it cancels during teardown, then hands that dead context to ffmpeg and to the
screenshot step. It plays the whole tape, prints `Creating …gif...`, exits with status **0** and leaves
`media/` **empty**. 0.12.1 (the fix, vhs#788) changes nothing else a tape can see. `vhs validate` only
parses, which is why it never showed the problem.

Commit `47cd1bc` (`fix(dev): build vhs 0.12.1 so tapes actually render`) overrides the package in
`home/stages/dev.nix:51-62`. It changes only the version and the source: `vendorHash` carries over,
because `go.mod` is the same in both releases. [Lesson 28](../lessons/28-GOING-FURTHER.md) walks
through the override and says when to drop it.

Check before the first render:

```bash
# anywhere on laptop-intel
vhs --version        # vhs version 0.12.1
```

If it prints `vhs version 0.12.0`, the rebuild that brings the override has not happened yet:

```bash
# in ~/Repos/personal/nix-config
grep -n 'version = "0.12.1"' home/stages/dev.nix   # the override is in your checkout
just rebuild
vhs --version                                      # vhs version 0.12.1
```

If `grep` prints nothing, your checkout predates `47cd1bc`: pull it in first. If `vhs --version` still
says 0.12.0 after the rebuild, `command -v vhs` shows which `vhs` your shell finds. The config's one is
`/etc/profiles/per-user/<your user>/bin/vhs`; a copy from `nix profile install` or an open `nix shell`
can come first on `PATH`.

Whatever VHS you use, **exit status 0 proves nothing**. After every render, look in the folder:
`ls -l media/NN-slug/` must list the GIF, the MP4 and every PNG the tape names, none of them empty.

## Capstone tapes record the worked examples

The capstone tapes (09, 10 and 14 to 21) never read your capstones. They record the
[worked examples](../examples/README.md) in `examples/`: `examples/just-panel/JP0` to `JP8`, each a
small Cargo workspace (`Cargo.toml` plus `just-panel/`), and `examples/session-browser/SB0` to `SB8`,
each a uv project. A capstone tape's hidden setup copies the milestone it shows to
`/tmp/nvim-course/<slug>/` and builds or runs it there:

- the just-panel tapes share one build folder, `CARGO_TARGET_DIR=/tmp/nvim-course/cargo-target`, so
  crates compile once for all of them;
- the session-browser tapes run `uv sync --frozen` in their copy, which gives it its own `.venv`;
- tape 09 also reads the repository's `justfile`, read-only, and changes nothing.

So a capstone tape records the same thing whatever state your own `rust/just-panel` and
`python/session-browser` are in, and it can be recorded before, during or long after the lessons. Each
tape's header names the example it copies.

No tape needs a git tag. The `course/*` tags that lessons 12 and 14 to 21 have you create are for you:
`git diff course/jp5`, `:DiffviewOpen course/sb6` or a throwaway `git worktree` take you back to a
milestone of **your own** code. They are local; do not push them.

## Privacy guards

VHS records its own headless terminal, never your screen, so notifications and other windows cannot
leak in. What can leak is whatever the tape itself shows. Five guards cover the known leaks:

- **Registers show your clipboard.** which-key's registers plugin lists every register, including
  `"+` and `"*` (your clipboard and your primary selection), the moment `"` is pressed in Normal or
  Visual mode or `<C-r>` in Insert or Command-line mode. `:reg` does the same. A tape that needs any of
  these must first overwrite both selections in its hidden setup, as tape 04 does:

  ```bash
  printf 'nvim-course' | wl-copy && printf 'nvim-course' | wl-copy --primary
  ```

  Tapes 03 and 04 also yank (`clipboard=unnamedplus`), so they leave your clipboard changed.
- **Shell history.** zsh-autosuggestions shows lines from your real history as grey text while a tape
  types. Any tape that types into your zsh (a toggleterm terminal, `:terminal`, or a zsh it starts)
  must set `Env ZSH_AUTOSUGGEST_HISTORY_IGNORE "*"`. The alternative is `Env SHELL "/bin/sh"`, which
  tapes 18 and 21 use: the terminal inside Neovim then runs a plain `sh` with no rc files.
- **Claude's lock file.** claudecode.nvim starts a server in every Neovim and writes
  `~/.claude/ide/<port>.lock`. Every tape that starts Neovim, except the live tapes 13 and 27, should
  point `CLAUDE_CONFIG_DIR` at a throwaway folder (tape 00's pattern:
  `Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/NN-slug.claude"`), so not even an aborted run can leave a
  lock in your real `~/.claude`. The live tapes must not do this, or Claude would start logged out.
- **Neovim's state folder.** `:checkhealth vim.lsp` prints the LSP log path, `$XDG_STATE_HOME/nvim/lsp.log`,
  which by default is under your home directory and so shows your user name. A tape that opens a health
  report sets `Env XDG_STATE_HOME "/tmp/nvim-course/NN-slug/state"` (tape 10 does, and tape 01 for its
  persistent-undo demo), which also keeps the tape's logs and undo files out of `~/.local/state`.
- **Real data stays out.** No tape reads your real `~/.claude`, `~/.codex` or Kitty sessions. The
  session-browser tapes point `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `--kitty-sessions-dir` at copies
  of `fixtures/sessions/`, which are synthetic, and tape 20 also sets a throwaway `HOME` and stand-in
  `claude`, `codex` and `kitty` scripts. The live tapes, 13 and 27, are the exceptions (see
  [The live tape](#the-live-tape-lesson-13)).

Audit the tapes before a full render:

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
# tapes without the lock-file redirect: expect only 13 and 27, the live tapes, which must not have one;
# add the redirect to any other tape listed before you record it
grep -L 'Env CLAUDE_CONFIG_DIR' tapes/[0-9]*.tape
# tapes that type into a Neovim terminal without a history guard (should print nothing)
grep -lE '^Type.*(" t"|ToggleTerm|TermExec|:terminal)' tapes/[0-9]*.tape \
  | xargs grep -L -e 'Env ZSH_AUTOSUGGEST_HISTORY_IGNORE' -e 'Env SHELL'
```

More rules for what appears on screen:

- **Shell prompts.** VHS starts bash without your rc files, so its prompt is a bare `>`. A terminal
  opened *inside* Neovim starts `$SHELL`, which VHS inherits from the shell you run it from: your zsh,
  with your full prompt. Check that it shows nothing you would not publish.
- **Private repositories stay out.** Tapes work on copies of fixtures and worked examples under
  `/tmp/nvim-course/`. Outside the course folder they read only three files, all read-only: the
  repository's `justfile` (tape 09), your generated `~/.config/nvim/KEYBINDS.md`, which holds only key
  descriptions (tape 23), and the `permissions` object of `~/.claude/settings.json` (tape 27, live).
- **Git identities.** A tape that commits sets a demo identity in its throwaway repository only
  (`git config user.name`/`user.email` without `--global`, as tape 12 does), or your address appears in
  Neogit's log.
- **Never put before you yank.** A tape must not press `p` before it has yanked something itself, or
  it pastes whatever you last copied. VHS's own `Copy`/`Paste` use your system clipboard too.

## Record in this order

Lessons 23 to 28 change the config, and a tape always records the config you have installed. Most
tapes never touch what those lessons change, but a few show exactly the behaviour a fix removes, and
the fix tapes show it gone:

| Record | Before or after | Why |
|---|---|---|
| Tape 00 | **before** lessons [24](../lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md) and [26](../lessons/26-FIX-CLOSE-BUFFER-KEY.md) | `which-key.png` shows the Space popup: lesson 24 changes the description of `t`, and lesson 26 adds `q` |
| Tape 05 | **before** lessons 24 and 26, and the gitsigns keys in [lesson 28](../lessons/28-GOING-FURTHER.md) | The Space popups and `:verbose nmap <leader>x`: lesson 24 changes `t`, lesson 26 adds `q` and takes close-buffer off `<leader>x`, and lesson 28 adds `a`, `b`, `p` and `r` to the `+git` popup in `leader-g.png` |
| Tape 22 | **before** lessons [23](../lessons/23-FIX-JUMP-FORWARD.md), 24 and 26 | Its `:verbose nmap` listings and Space popup show the keys as lessons 00 to 21 teach them: after lesson 23 `<C-i>` has a mapping of its own, and lessons 24 and 26 change the popup as above |
| Tape 09 | **before** section 4 of [lesson 28](../lessons/28-GOING-FURTHER.md) | It greps a copy of the repository's justfile, and section 4 adds eight lines above the Fuzzing banner. The tape still records, but its frames would show line numbers eight higher than the ones [lesson 09](../lessons/09-PROJECT-PANE.md) quotes |
| Tape 13 | **before** [lesson 27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md) | Its first screenshot shows the mode Claude starts in, usually auto: the trap lesson 13 teaches. After lesson 27, Claude starts in Manual mode |
| Tapes 23 to 28 | **after** their own lesson's change, rebuilt | Each one demonstrates its fix working, so it needs the new config. Its header says so |

Every other tape records the same with or without lessons 23 to 28. If you have already applied a fix
and need one of the "before" tapes, either rebuild the config from before the fix for the recording
and then rebuild your branch again ([lesson 22](../lessons/22-MAKING-THE-CONFIG-YOURS.md) shows how
to go back safely), or update the tape and its lesson to the new behaviour.

## Every tape at a glance

Every tape writes `media/<slug>/<slug>.gif` and `media/<slug>/<slug>.mp4`, plus the PNG screenshots
listed here (each `<name>.png`, in the same folder). All tapes except 14 to 16 also `Require nvim`. "Fixture
copy" means the tape copies `fixtures/<slug>/` (or a shared fixture) to `/tmp/nvim-course/<slug>` and
touches nothing else. "Worked example JPn" or "SBn" means it copies `examples/just-panel/JPn` or
`examples/session-browser/SBn` there instead ([Capstone tapes](#capstone-tapes-record-the-worked-examples)).

| Tape | Lesson | Screenshots | Records | Needs |
|---|---|---|---|---|
| `00-setup-and-orientation` | [00](../lessons/00-SETUP-AND-ORIENTATION.md) | `dock-layout`, `which-key` | Fixture copy. A bare `nvim` with the dock layout; your zsh in the bottom pane. Record before lessons 24 and 26 ([order](#record-in-this-order)) | – |
| `01-modes-and-survival` | [01](../lessons/01-MODES-AND-SURVIVAL.md) | `start`, `insert-mode`, `dot-repeat`, `open-lines`, `undo`, `saved`, `persistent-undo`, `help-window`, `e37` | Fixture copy | – |
| `02-motions` | [02](../lessons/02-MOTIONS.md) | `relative-numbers`, `w-and-W`, `percent`, `marks-popup`, `jumps` | Fixture copy | – |
| `03-operators-and-text-objects` | [03](../lessons/03-OPERATORS-AND-TEXT-OBJECTS.md) | `ciw-ci-quote`, `tags`, `di-brace`, `block-insert`, `block-append`, `gcip`, `autopairs` | Fixture copy. Changes your clipboard | – |
| `04-search-registers-macros` | [04](../lessons/04-SEARCH-REGISTERS-MACROS.md) | `search`, `star`, `substitute`, `cgn`, `recording`, `macro-vec`, `reg-a`, `macro-caution` | Fixture copy. Overwrites your clipboard and primary selection | `wl-copy` |
| `05-your-keybindings` | [05](../lessons/05-YOUR-KEYBINDINGS.md) | `leader`, `leader-f`, `leader-g`, `leader-c`, `leader-x`, `verbose-x` | Fixture copy. Record before lessons 24 and 26 and lesson 28's gitsigns keys ([order](#record-in-this-order)) | – |
| `06-terminal` | [06](../lessons/06-TERMINAL.md) | `terminal-open`, `normal-scrollback`, `window-up`, `two-terminals`, `termselect` | Fixture copy. Types into your zsh in toggleterm | – |
| `07-tree` | [07](../lessons/07-TREE.md) | `tree`, `add-prompt`, `added`, `delete-confirm`, `hidden-toggled`, `fuzzy-filter`, `help` | Fixture copy, made a git repository | `git` |
| `08-file-pane` | [08](../lessons/08-FILE-PANE.md) | `bufferline`, `ls`, `vsplit`, `three-windows`, `buffers-panel`, `buffer-deleted` | Fixture copy | – |
| `09-project-pane` | [09](../lessons/09-PROJECT-PANE.md) | `find-files`, `live-grep`, `quickfix`, `cnext`, `aerial` | Worked example SB2's `models.py`, plus a copy of the repo's `justfile` (read-only) | – |
| `10-lsp` | [10](../lessons/10-LSP.md) | `checkhealth`, `hover`, `definition`, `references`, `sign`, `diagnostic-float` | Worked example JP3, copied to `/tmp/nvim-course/10-lsp/rust`. rust-analyzer builds into the shared `/tmp/nvim-course/cargo-target` | `cargo`, `rust-analyzer` (rustup's, or the repo's dev shell). Crates from `~/.cargo/registry` or the network; a cold first run takes minutes |
| `11-completion-formatting-diagnostics` | [11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | `start`, `completion`, `formatted`, `trouble` | Fixture copy | `ruff` |
| `12-git` | [12](../lessons/12-GIT.md) | `signs`, `preview-hunk`, `staged-sign`, `git-status-panel`, `neogit-status`, `neogit-staged`, `commit-popup`, `commit-editor`, `diffview` | A throwaway repository built from the fixture, with a demo identity | `git` |
| `13-claude-code-and-codex` | [13](../lessons/13-CLAUDE-CODE-AND-CODEX.md) | `claude-first-launch`, `claude-manual`, `send-buffer`, `codex`, `both-hidden` | **LIVE.** Fixture copy, with your real, signed-in Claude Code and Codex. Record by hand, before lesson 27 | `claude`, `codex`, the network, one manual trust step first |
| `14-just-panel-tui-skeleton` | [14](../lessons/14-JUST-PANEL-TUI-SKELETON.md) | `start`, `rebuild`, `last` | Worked example JP5 and the demo justfile. No Neovim | `cargo`, `just`. Crates cached or the network; the first build takes a minute or two |
| `15-just-panel-sections-and-filter` | [15](../lessons/15-JUST-PANEL-SECTIONS-AND-FILTER.md) | `headers`, `filter-typing`, `filter-kept`, `filter-cleared`, `help` | Worked example JP6 and the demo justfile. No Neovim | As tape 14 |
| `16-just-panel-running-recipes` | [16](../lessons/16-JUST-PANEL-RUNNING-RECIPES.md) | `prompt`, `handover`, `back`, `ctrl-c`, `confirm-sudo`, `confirm-attribute` | Worked example JP7 and the demo justfile. No Neovim | As tape 14 |
| `17-just-panel-testing-and-shipping` | [17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md) | `snapshot`, `cargo-test`, `clippy` | Worked example JP8; Neovim opens its snapshot with `-R`. Types into your zsh in toggleterm | `cargo`. Crates cached or the network |
| `18-session-browser-tui-skeleton` | [18](../lessons/18-SESSION-BROWSER-TUI-SKELETON.md) | `split`, `hover`, `termexec`, `list`, `preview`, `markup` | Worked example SB5; synthetic sessions | `uv`. Packages from uv's cache or the network |
| `19-session-browser-filter-and-search` | [19](../lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md) | `datatable-bindings`, `all`, `claude-tab`, `search`, `filtered-list` | Worked example SB6; synthetic sessions | As tape 18 |
| `20-session-browser-actions` | [20](../lessons/20-SESSION-BROWSER-ACTIONS.md) | `build-launch`, `run`, `browser`, `suspended`, `copied`, `behind`, `launches` | Worked example SB7; synthetic sessions, stand-in `claude`, `codex` and `kitty` | As tape 18 |
| `21-session-browser-testing-and-shipping` | [21](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) | `pilot-test`, `pytest`, `checks`, `termexec` | Worked example SB8; the suite, ruff and pyright pass on it | `uv`, `ruff`, `pyright` |
| `22-making-the-config-yours` | [22](../lessons/22-MAKING-THE-CONFIG-YOURS.md) | `attrset`, `keybinds-split`, `verbose-tab`, `verbose-c-i`, `which-key` | Fixture copy. Record before lessons 23, 24 and 26 ([order](#record-in-this-order)) | – |
| `23-fix-jump-forward` | [23](../lessons/23-FIX-JUMP-FORWARD.md) | `verbose-c-i`, `jump-forward`, `tab-next-buffer`, `keybinds` | Fixture copy, and your generated `~/.config/nvim/KEYBINDS.md`, read-only. Record after lesson 23's change | – |
| `24-fix-counted-terminal-toggle` | [24](../lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md) | `verbose-leader-t`, `count-popup`, `two-terminals`, `termselect` | Fixture copy. Types into your zsh in toggleterm. Record after lesson 24's change | – |
| `25-fix-pyright-diagnostic-mode` | [25](../lessons/25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md) | `settings`, `trouble`, `ls` | Fixture copy, checked by the config's own pyright. Record after lesson 25's change | – |
| `26-fix-close-buffer-key` | [26](../lessons/26-FIX-CLOSE-BUFFER-KEY.md) | `verbose-q`, `verbose-x`, `which-key`, `group-waits`, `closed` | Fixture copy. Record after lesson 26's change | – |
| `27-fix-claude-diff-review` | [27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md) | `settings`, `claude-manual`, `diff`, `accepted` | **LIVE.** Fixture copy, with your real, signed-in Claude Code; submits one short prompt. Record by hand, after lesson 27's change ([live tapes](#tape-27-the-other-live-tape)) | `claude`, `jq`, the network, one manual trust step first |
| `28-going-further` | [28](../lessons/28-GOING-FURTHER.md) | `signs`, `preview`, `staged`, `leader-g`, `verbose` | A throwaway repository built from the fixture, with a demo identity. Record after lesson 28's gitsigns keys | `git` |

Each tape's header comment is the authority: if it and this table ever disagree, the header wins.

## What you need

| Item | Where it comes from | Check |
|---|---|---|
| VHS **0.12.1** | The config's override of nixpkgs' 0.12.0 (`home/stages/dev.nix:51-62`), after `just rebuild`: see [the first section](#first-make-sure-vhs-is-0121) | `vhs --version` |
| ttyd, ffmpeg, Chromium | The nixpkgs `vhs` package wraps the binary and puts all three on its `PATH`. Nothing else to install | – |
| Neovim and the course config | `home/modules/neovim.nix` (dev stage and up) | `nvim --version` shows 0.12.5 |
| JetBrainsMono Nerd Font | `modules/core/fonts.nix:54` | `fc-list \| grep -i jetbrainsmono` |
| The config **as each tape expects it** | Tapes press the course's keys. Tapes 00, 05, 13 and 22 record the config before lessons 23 to 28 change it, and tapes 23 to 28 after: see [Record in this order](#record-in-this-order) | `git log --oneline -- home/modules/neovim.nix home/modules/claude.nix` |
| Programs per tape | See [the table above](#every-tape-at-a-glance) | `command -v <program>` |

A tape that needs another program says so with a `Require` line near its top, and VHS stops at once
if that program is not on `PATH`.

## Run everything from the course directory

```bash
cd ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
```

VHS resolves `Source`, `Output`, `Screenshot` and the fixture copy in each tape's hidden setup against
the directory **you run it from**, not the tape's own directory. Run from anywhere else and nothing
lines up.

### 1. Validate first

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
vhs validate tapes/_shared/settings.tape tapes/*.tape
```

`vhs validate` only parses. It needs no browser, works on 0.12.0 too, prints nothing when every tape
is fine, and exits non-zero with the file and error otherwise. If you added the recipes from
[lesson 28](../lessons/28-GOING-FURTHER.md), `just vhs-validate` runs the same command from anywhere.

Validation does **not** catch four failures that only show up at render time:

- a wrong theme name;
- a `Wait` that never matches;
- a `Screenshot` into a directory that does not exist;
- `LoopOffset` combined with a `Screenshot`.

It also lets a misplaced `Set` through, which only prints a warning. The
[troubleshooting section](#troubleshooting) covers all five.

### 2. Render one tape

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
vhs tapes/07-tree.tape
ls -l media/07-tree/
```

With VHS 0.12.1, it writes `media/07-tree/07-tree.gif`, `media/07-tree/07-tree.mp4` and the PNGs
named on the tape's `Screenshot` lines, all into `media/07-tree/`. With lesson 28's recipes:
`just vhs-record 07-tree`.

### 3. Render them all

Tapes run one after another, and a full pass takes a while. The loop skips the live tapes (13 and 27),
keeps going when one tape fails, and counts a tape as failed unless it wrote a fresh GIF. It works in
zsh and bash.

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
mkdir -p /tmp/nvim-course && : > /tmp/nvim-course/failed-tapes.txt
for tape in tapes/[0-9]*.tape; do
  case "$tape" in
    tapes/13-*|tapes/27-*) echo "skip (LIVE, record by hand): $tape"; continue ;;
  esac
  slug=$(basename "$tape" .tape)
  echo "== $tape"
  touch /tmp/nvim-course/render-start
  vhs "$tape" && [ "media/$slug/$slug.gif" -nt /tmp/nvim-course/render-start ] \
    || echo "$tape" >> /tmp/nvim-course/failed-tapes.txt
done
echo "failed:"; cat /tmp/nvim-course/failed-tapes.txt
```

The loop records every tape against the config you have now, so mind
[the recording order](#record-in-this-order). Before lessons 23 to 28 are applied, tapes 23 to 26 and
28 stop at a `Wait` and are listed as failed: record them after their lessons. After those lessons,
tapes 00, 05 and 22 no longer show the config the earlier lessons teach: record them first, or leave
them out of the loop by adding their names to the `case` line.

If every tape is listed as failed although VHS reported no error, you rendered with 0.12.0: see
[the first section](#first-make-sure-vhs-is-0121). Then work through the
[checklist](#checklist-for-every-recording) for each lesson's `media/` folder before you commit
anything.

## Tape conventions

The shared settings live in [`tapes/_shared/settings.tape`](../tapes/_shared/settings.tape), which
holds `Set` lines only. The theme is `ayu`, whose colours match ayu-vim's dark palette, and the frame
is 1440 × 900 px, the 75 % of a 1920 px screen that the dev layout gives Neovim. It also sets the
JetBrainsMono Nerd Font with fallbacks, `TypingSpeed 60ms`, 30 fps, no cursor blink and a 20 s
`WaitTimeout`. Every lesson tape follows the same shape:

1. **Header.** The first command is `Source tapes/_shared/settings.tape`. Then come the two outputs,
   `Output media/NN-slug/NN-slug.gif` and `Output media/NN-slug/NN-slug.mp4`, then `Require nvim` and
   any other `Require` lines, then any `Env` lines. VHS ignores any `Set` that comes after a non-`Set`
   command, and that includes `Env`. A header comment says what the tape shows, which VHS it needs,
   and, for a capstone tape, which worked example it records.
2. **Hidden setup.** `Hide`, then one `Type` that copies `fixtures/NN-slug/.` into a fresh
   `/tmp/nvim-course/NN-slug` (`rm -rf` first) and `cd`s there, then `clear`. Fixed paths keep
   re-recordings identical and keep your real files out of shot. Capstone tapes copy a worked example
   here instead (see [Capstone tapes record the worked examples](#capstone-tapes-record-the-worked-examples)).
3. **Launch.** `nvim -i NONE <file>`. The file argument skips the bare-start dock layout, and `-i NONE`
   keeps your ShaDa history out. Only tapes that demonstrate the dock layout start a bare
   `nvim -i NONE`. Capstone demos that need the whole window run the app straight from VHS's shell
   (tapes 14 to 16 never start Neovim at all).
4. **Anchors, not guesses.** `Wait+Screen /regex/` before `Show` and after anything slow. Inside
   Neovim, always use the `+Screen` scope. A plain `Wait` only looks at the cursor's line, which is
   only reliable at the shell prompt.
5. **Caption.** While still hidden, ``Type@10ms ":echo 'Lesson NN - …'"`` and `Enter`, then `Show`.
   Only the message appears in the recording. Do not put arrow characters (`←↑→↓`) in captions: VHS
   sends them as arrow keys.
6. **Screenshots.** `Sleep` at least `300ms` before each `Screenshot` so Neovim has redrawn, and
   `Sleep 200ms` after it. PNGs go in the same `media/NN-slug/` directory as the outputs, because VHS
   creates that directory and not any other.
7. **Timing around `timeoutlen` (300 ms) and which-key (200 ms).** Type a sequence that shares a
   prefix as one `Type` at the shared 60 ms (`Type " xx"`) so nothing times out mid-sequence. Pause
   1.5–2 s after a prefix only when the which-key popup is the point.
8. **Key syntax.**
   - `Escape` is always followed by `Sleep 300ms`.
   - Write `Ctrl+S`: `Ctrl+s` is a syntax error because `s` is a time unit.
   - Leave Terminal mode with `Ctrl+\` then `Ctrl+n`.
   - Do not use `Ctrl+Shift+…` (it sends nothing) or `Home`/`End` (they do not parse).
   - A bare number is **seconds**: always write the unit.
9. **Hidden teardown.** `Hide`, `Escape`, `Sleep 300ms`, `Type ":qa!"`, `Enter`, `Sleep 300ms`. The
   clean quit lets claudecode.nvim remove its lock file. Tape 00 quits on camera instead, because
   quitting is what it teaches.

> **Why:** VHS records a terminal emulated inside headless Chromium (ttyd and xterm.js), not Kitty.
> It speaks the old keyboard encoding, so `Tab` and `Ctrl+I` are the same key there, and no tape can
> press a Kitty-only key such as the `<C-i>` that [lesson 23](../lessons/23-FIX-JUMP-FORWARD.md) maps.
> Tape 23 sends it with `:lua vim.api.nvim_input('<C-i>')` instead, the route Kitty's `Ctrl+I` takes
> into Neovim.

## The live tape (lesson 13)

Lesson 13's tape runs the real Claude Code and Codex. Its header marks it **LIVE**: non-deterministic
and signed in, and starting the tools makes network calls that count as account activity. It never
submits a prompt, so no model output is recorded, but frames still differ between runs (versions,
notices, the mode Claude starts in). The loop above skips it. Record it by hand:

1. **Log in first.** `claude` must be signed in and `codex login` done. The tape does **not** set
   `CLAUDE_CONFIG_DIR`, because Claude would then start logged out. It sets `IS_DEMO=1` and
   `CLAUDE_CODE_HIDE_CWD=1` to keep your e-mail, organisation and folder out of Claude's header
   (verify on laptop-intel that Claude Code 2.1.278 honours both).
2. **Answer the first-run questions once, by hand.** Both tools remember the answer per folder:

   ```bash
   mkdir -p /tmp/nvim-course/13-claude-code-and-codex
   cd /tmp/nvim-course/13-claude-code-and-codex
   claude     # accept the folder-trust question, then /exit
   codex      # answer the trust question (skip any update offer), then /quit
   ```

   Skip this and a `Wait` times out: VHS stops and writes no GIF.
3. **Permission mode.** The first screenshot shows whatever mode Claude starts in (usually auto on
   this config, which is the lesson's point). The tape then exits Claude and restarts it with
   `:ClaudeCode --permission-mode manual`, and waits for `manual mode on`. Record it before
   [lesson 27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md): once that is applied, the first screenshot
   shows Manual mode instead.
4. **Review every frame.** Step through the GIF before committing. Look for account names or e-mail
   addresses, organisation or plan names, paths outside `/tmp/nvim-course`, and notices you would not
   publish. `/status`, `/usage` and similar screens show account details; the tape never opens them.
5. **Re-record, do not splice.** If one part is wrong, run the whole tape again.
6. **Clean up.** `/exit` any Claude or Codex still running, then check that `ls ~/.claude/ide/` lists
   no lock for a Neovim that has gone.

### Tape 27, the other live tape

[Lesson 27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md)'s tape is live in the same way, with Claude only,
and the same six steps apply, with three differences:

- **It submits one short prompt**, so it uses a little of your plan's allowance and shows a few lines of
  model output. Frames differ between runs more than tape 13's.
- **Record it after lesson 27's change**, rebuilt, with every running Claude `/exit`ed first. It reads
  the `permissions` object of your real `~/.claude/settings.json` and waits for `manual mode on`; on a
  config without the change that wait times out and VHS writes nothing.
- **The first-run question is for its own folder:**

  ```bash
  mkdir -p /tmp/nvim-course/27-fix-claude-diff-review
  cd /tmp/nvim-course/27-fix-claude-diff-review
  claude     # accept the folder-trust question, then /exit
  ```

The tape's header comment has the details; it wins if it and this section ever disagree.

## Re-recording

- **After a config change.** Search the tapes for the key sequences you changed, for example
  `grep -n 'Type " x' tapes/*.tape` after moving `<leader>x`. Update those tapes and re-render them.
  Lessons 23 to 28 are covered in [Record in this order](#record-in-this-order).
- **After `just update`.** New versions of Neovim, plugins or VHS can change what is on screen, or the
  syntax. Run `vhs validate` first, then re-render and compare a few screenshots with the old ones.
  Check whether the VHS override can go: once
  `nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.vhs.version` (in the repository) prints
  0.12.1 or later, nixpkgs has caught up ([lesson 28](../lessons/28-GOING-FURTHER.md)).
- **After a capstone change.** Your own capstones never appear in a tape. If a worked example in
  `examples/` changes, re-record the tapes whose header names it (`grep -l 'examples/just-panel/JP5'
  tapes/*.tape`).
- **Fixtures are part of the tape.** A lesson whose fixture copies a repo file keeps it verbatim on
  purpose. Lesson 22's `neovim-keymaps.nix` is lines 10-105 of `neovim.nix` at commit `6e379a3`. Refresh
  such a copy only when the lesson text changes with it.

## Checklist for every recording

Tick these off for each `media/NN-slug/` folder before `git add`:

- [ ] **The files exist.** `ls -l media/NN-slug/` lists the GIF, the MP4 and every PNG the tape names,
      and none of them is empty. `vhs` exiting 0 is not enough: 0.12.0 exits 0 and writes nothing.
- [ ] The GIF plays from start to finish, and each PNG path matches the one the lesson embeds.
- [ ] **Focus:** at each screenshot the cursor is in the window the lesson is talking about. Tapes that
      start a bare `nvim` (the dock layout) are the most timing-sensitive.
- [ ] **which-key timing:** the popup shows exactly where the tape pauses for it, and nowhere else. No
      buffer disappeared, which is what happens when a pause lands after `<leader>x`.
- [ ] No leftover "Press ENTER" prompt or error message, unless the lesson is about it.
- [ ] Captions are readable, and no typed caption characters are visible.
- [ ] Nerd Font icons render (no empty boxes) and the text is evenly spaced.
- [ ] The frame's padding blends into Neovim's background.
- [ ] **No private data:** prompts, user and host names, paths outside `/tmp/nvim-course`, real
      session titles, shell history, account details, anything from your clipboard.
- [ ] **Lock files cleaned:** `ls ~/.claude/ide/` shows no lock left behind by the tape's Neovim.
- [ ] No `/tmp/vhs…` directories left from failed runs. `/tmp/nvim-course/` can go too.
- [ ] Your clipboard holds what you expect again, if the tape yanked anything (tapes 03 and 04).
- [ ] Sizes are sensible. As a rough guide, a 20-second tape at these settings gave a GIF of about
      200 KB and an MP4 of about 130 KB in testing.
- [ ] `git status` lists only the media you meant to add.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `vhs` prints `Creating …gif...` and exits 0, but `media/NN-slug/` is empty | VHS 0.12.0 cancels its own render step (charmbracelet/vhs#787) | `vhs --version` must print 0.12.1; if not, `just rebuild`: [the first section](#first-make-sure-vhs-is-0121) |
| Icons are empty boxes, or letters look badly spaced | The font family in `settings.tape` does not match the installed name, so a fallback font was used. The exact family name on NixOS is unverified | Run `fc-list \| grep -i jetbrainsmono` and put the family it prints first in the `FontFamily` line of `tapes/_shared/settings.tape` |
| The first `Wait` times out with `last value was: \[\]> \[\]`, on every tape | VHS starts whichever `bash` is first on `PATH`. The repository's `.envrc` loads the dev shell when you `cd` in, and a dev shell without `bashInteractive` puts stdenv's bash first. That bash has no readline, so the prompt prints as `[]> []` and never matches `>$` | `bash -c 'type bind'` must print "bind is a shell builtin". The flake's dev shell includes `bashInteractive`, so run `direnv reload` after pulling it. Outside the dev shell: `PATH=/run/current-system/sw/bin:$PATH vhs tapes/NN-slug.tape` |
| A tape pins `Env TZ "Europe/London"`, but a program still shows UTC | VHS's bash reads no profile, so NixOS's `TZDIR` never reaches the tape, and runtimes not built by Nix (uv's standalone Python, through nix-ld) look for zones only in `/usr/share/zoneinfo`, which NixOS does not have | Add `Env TZDIR "/etc/zoneinfo"` next to `Env TZ`, as tapes 18 to 20 do |
| `browser exited unexpectedly`, or Chromium complains about its sandbox | Headless Chromium could not start its sandbox | `VHS_NO_SANDBOX=1 vhs tapes/NN-slug.tape` |
| The error mentions `Socket path too long` | `TMPDIR` is a very long path, and Chromium's socket path overflows | `TMPDIR=/tmp vhs tapes/NN-slug.tape` |
| VHS starts downloading Chromium into `~/.cache/rod` | This `vhs` is not the Nix-wrapped one, so it cannot find a browser | `command -v vhs`, then remove the other copy from `PATH` |
| `timeout waiting for …`, then `last value was: …`, and no GIF | A `Wait` regex never matched within `WaitTimeout` (20 s). The whole recording is aborted | Read "last value": it is what the screen held. A failed build, a missing worked example or a first-run question shows up here. Otherwise fix the regex or the fixture. For a slow step, give that one line longer: `Wait+Screen@40s /regex/`, with the scope before the `@` |
| `invalid Set Theme "…": did you mean "ayu"` | Theme names are exact and case-sensitive, and are only checked at render time | `vhs themes 2>&1 \| grep -i ayu` (the list goes to stderr) |
| `WARN: 'Set …' has been ignored` | A `Set` after a non-`Set` command, including `Env` | Move it up into the header block. Only `TypingSpeed` may change mid-tape |
| Render fails at the end with an ffmpeg error about a PNG | A `Screenshot` into a directory that does not exist, or `LoopOffset` in a tape that takes screenshots | Keep PNGs next to the outputs in `media/NN-slug/`. Do not use `LoopOffset` with screenshots |
| `vhs validate` rejects `Ctrl+s`, `Home`, `End` or `Output 01-x.gif` | `s` is a time unit, `Home`/`End` do not parse, and a bare path cannot start with a digit | `Ctrl+S`; `0`/`^`/`$` inside Neovim; quote the path or keep the number inside a directory |
| A pause runs for minutes | `Sleep 500` means 500 **seconds** | `Sleep 500ms` |
| A which-key popup appears where it should not | A prefix sequence was split over two `Type` lines, or typed with `@` slower than 200 ms | One `Type` at the shared 60 ms |
| A buffer vanishes halfway through | A pause after Space x ran `<leader>x` (close buffer) | Type `" xx"` in one go |
| A key does something different from Kitty | xterm.js sends the old encodings: `Tab` is `Ctrl+I`, and there is no `Ctrl+Shift` | Do not record Kitty-only distinctions, or send the key with `nvim_input`, as tape 23 does |
| Grey suggestions from your shell history appear in a terminal | The tape types into your zsh without the history guard | Add `Env ZSH_AUTOSUGGEST_HISTORY_IGNORE "*"` (or `Env SHELL "/bin/sh"`) to the tape's header |
| Old `~/.claude/ide/*.lock` files pile up | A render was aborted before the hidden `:qa!`, in a tape without the `CLAUDE_CONFIG_DIR` redirect | Delete the locks whose Neovim is no longer running, and add the redirect to that tape |
| `/tmp/vhs…` directories pile up | Failed renders leave their frame folders behind | Delete them once no render is running |
