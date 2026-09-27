# Course tapes

**Last Updated**: 27/09/2026
**Version**: 1.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

The [VHS](https://github.com/charmbracelet/vhs) scripts that record the course's GIFs, MP4s and
screenshots. Each lesson has one tape, `NN-slug.tape`. The slug is the lesson's filename in lower case
without `.md`, and output goes to `../media/NN-slug/`. The full guide, covering conventions, privacy,
the live tape, a checklist and troubleshooting, is
[Appendix B — Recording with VHS](../appendices/B-RECORDING-WITH-VHS.md).

## First: make sure VHS is 0.12.1

The config builds VHS **0.12.1** (commit `47cd1bc`, `home/stages/dev.nix:51-62`). The pinned nixpkgs
ships 0.12.0, which cancels its own render step (charmbracelet/vhs#787): it plays the tape, prints
`Creating …gif...`, exits with status 0 and writes **no** GIF, MP4 or PNG. `vhs validate` only parses,
so it is unaffected. Before the first render:

```bash
# anywhere on laptop-intel
vhs --version        # must print: vhs version 0.12.1
```

If it prints 0.12.0, the rebuild with the override has not happened yet: `just rebuild` in
`~/Repos/personal/nix-config`, then check again.
[Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121) has the details, and
[lesson 28](../lessons/28-GOING-FURTHER.md) explains the override and when to drop it. Whatever the
version, a render only counts once `ls -l media/NN-slug/` shows the files.

## Quick start (on laptop-intel)

VHS's Nix wrapper brings ttyd, ffmpeg and Chromium with it. **Always run from `docs/NEOVIM-COURSE/`**:
every path in every tape is relative to that directory.

```bash
cd ~/Repos/personal/nix-config/docs/NEOVIM-COURSE

vhs validate tapes/_shared/settings.tape tapes/*.tape   # parse only; silent when all is well
vhs tapes/07-tree.tape                                  # render one lesson (VHS 0.12.1)
ls -l media/07-tree/                                    # the GIF, the MP4 and the PNGs must be there
```

With the recipes from [lesson 28](../lessons/28-GOING-FURTHER.md), these become `just vhs-validate`
and `just vhs-record 07-tree`, and they work from any directory. To render every tape except the live
ones, use the loop in [Appendix B](../appendices/B-RECORDING-WITH-VHS.md#3-render-them-all).

## Capstone tapes and the worked examples

The capstone tapes (09, 10 and 14 to 21) record the [worked examples](../examples/README.md), never
your own capstones. Each one copies the milestone it shows, `examples/just-panel/JPn` or
`examples/session-browser/SBn`, to `/tmp/nvim-course/<slug>/` and builds or runs it there: the
just-panel tapes share `CARGO_TARGET_DIR=/tmp/nvim-course/cargo-target`, and the session-browser tapes
run `uv sync --frozen` in their copy. Tape 09 also reads the repository's `justfile`, read-only. So
they record the same at any point in the course, and no tape needs a git tag. The `course/*` tags the
lessons have you create are for diffing against, and returning to, your own milestones.
[Appendix B](../appendices/B-RECORDING-WITH-VHS.md#capstone-tapes-record-the-worked-examples) has more.

## Record in this order

Record tapes 00, 05 and 22 **before** you apply lessons 24 and 26 (tape 22 also before lesson 23, and
tape 05 before lesson 28's gitsigns keys), and tape 13 **before** lesson 27: they show the config as the
earlier lessons teach it. Record tapes 23 to 28 **after** their own lesson's change. Every other tape is
unaffected.
[Appendix B](../appendices/B-RECORDING-WITH-VHS.md#record-in-this-order) says why.

## Privacy guards

- **Registers:** which-key lists every register, your clipboard (`"+`) and primary selection (`"*`)
  included, the moment `"` (Normal/Visual) or `<C-r>` (Insert/Command-line) is pressed, and so does
  `:reg`. A tape that uses them first runs `printf 'nvim-course' | wl-copy && printf 'nvim-course' |
  wl-copy --primary` in its hidden setup (tape 04). Tapes 03 and 04 change your clipboard.
- **Shell history:** a tape that types into your zsh must set
  `Env ZSH_AUTOSUGGEST_HISTORY_IGNORE "*"`, or `Env SHELL "/bin/sh"` so Neovim's terminal runs a plain
  `sh`.
- **Claude's lock file:** every tape that starts Neovim, except the live tapes 13 and 27, should set
  `Env CLAUDE_CONFIG_DIR` to a throwaway folder, such as `/tmp/nvim-course/NN-slug.claude`, so
  claudecode.nvim never writes to `~/.claude/ide`. The live tapes must not, or Claude starts logged out.
  [Appendix B](../appendices/B-RECORDING-WITH-VHS.md#privacy-guards) has a `grep` that audits both
  guards.
- **Data:** session-browser tapes read only copies of `fixtures/sessions/` (synthetic). Tapes 13 and 27
  are **LIVE**: they use your real, signed-in Claude Code (and, in 13, Codex), and tape 27 submits one
  short prompt. Record both by hand
  ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#the-live-tape-lesson-13)).

## Writing or editing a tape

- The first command (a header comment may come before it) is `Source tapes/_shared/settings.tape`.
  That file holds `Set` lines only: do not add anything else to it.
- Next come `Output media/NN-slug/NN-slug.gif`, `Output media/NN-slug/NN-slug.mp4`, `Require nvim`
  (a capstone tape that never starts Neovim may leave it out), then any `Env` lines.
- A header comment says what the tape shows, that it needs VHS 0.12.1, and, for a capstone tape, the
  worked example it records.
- A hidden setup copies `fixtures/NN-slug/.` (or a worked example) to `/tmp/nvim-course/NN-slug` and
  starts `nvim -i NONE <file>`.
- Use `Wait+Screen /regex/` before `Show`.
- Screenshots go in `media/NN-slug/`, with `Sleep 300ms` or more before each one.
- The recording ends with a hidden `:qa!`. Tape 00 is the exception: it quits on camera, because
  quitting is what it teaches.
- Check each change with `vhs validate tapes/NN-slug.tape`, and embed media in the lesson with
  exactly the paths on the tape's `Output`/`Screenshot` lines.

## Tapes

Every tape writes `media/<slug>/<slug>.gif` and `.mp4`, plus the screenshots listed (each
`<name>.png`, in the same folder). All tapes except 14 to 16 also `Require nvim`. "Fixture copy" means the
tape touches nothing but a copy of its fixture under `/tmp/nvim-course/`, and "Worked example JPn"
or "SBn" a copy of `examples/just-panel/JPn` or `examples/session-browser/SBn`. The appendices have no
tapes. Each tape's header comment is the authority if it and this table ever disagree.

| Tape | Lesson | Screenshots | Records | Needs |
|---|---|---|---|---|
| `00-setup-and-orientation` | [00](../lessons/00-SETUP-AND-ORIENTATION.md) | `dock-layout`, `which-key` | Fixture copy; bare `nvim` (dock layout), your zsh in the bottom pane; record before lessons 24 and 26 | – |
| `01-modes-and-survival` | [01](../lessons/01-MODES-AND-SURVIVAL.md) | `start`, `insert-mode`, `dot-repeat`, `open-lines`, `undo`, `saved`, `persistent-undo`, `help-window`, `e37` | Fixture copy | – |
| `02-motions` | [02](../lessons/02-MOTIONS.md) | `relative-numbers`, `w-and-W`, `percent`, `marks-popup`, `jumps` | Fixture copy | – |
| `03-operators-and-text-objects` | [03](../lessons/03-OPERATORS-AND-TEXT-OBJECTS.md) | `ciw-ci-quote`, `tags`, `di-brace`, `block-insert`, `block-append`, `gcip`, `autopairs` | Fixture copy; changes your clipboard | – |
| `04-search-registers-macros` | [04](../lessons/04-SEARCH-REGISTERS-MACROS.md) | `search`, `star`, `substitute`, `cgn`, `recording`, `macro-vec`, `reg-a`, `macro-caution` | Fixture copy; overwrites clipboard and primary selection | `wl-copy` |
| `05-your-keybindings` | [05](../lessons/05-YOUR-KEYBINDINGS.md) | `leader`, `leader-f`, `leader-g`, `leader-c`, `leader-x`, `verbose-x` | Fixture copy; record before lessons 24, 26 and 28 | – |
| `06-terminal` | [06](../lessons/06-TERMINAL.md) | `terminal-open`, `normal-scrollback`, `window-up`, `two-terminals`, `termselect` | Fixture copy; types into your zsh | – |
| `07-tree` | [07](../lessons/07-TREE.md) | `tree`, `add-prompt`, `added`, `delete-confirm`, `hidden-toggled`, `fuzzy-filter`, `help` | Fixture copy, made a git repository | `git` |
| `08-file-pane` | [08](../lessons/08-FILE-PANE.md) | `bufferline`, `ls`, `vsplit`, `three-windows`, `buffers-panel`, `buffer-deleted` | Fixture copy | – |
| `09-project-pane` | [09](../lessons/09-PROJECT-PANE.md) | `find-files`, `live-grep`, `quickfix`, `cnext`, `aerial` | Worked example SB2's `models.py` plus a read-only copy of the repo `justfile` | – |
| `10-lsp` | [10](../lessons/10-LSP.md) | `checkhealth`, `hover`, `definition`, `references`, `sign`, `diagnostic-float` | Worked example JP3; rust-analyzer builds under `/tmp` | `cargo`, `rust-analyzer`; crates cached or network |
| `11-completion-formatting-diagnostics` | [11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | `start`, `completion`, `formatted`, `trouble` | Fixture copy | `ruff` |
| `12-git` | [12](../lessons/12-GIT.md) | `signs`, `preview-hunk`, `staged-sign`, `git-status-panel`, `neogit-status`, `neogit-staged`, `commit-popup`, `commit-editor`, `diffview` | Throwaway repository from the fixture, demo identity | `git` |
| `13-claude-code-and-codex` | [13](../lessons/13-CLAUDE-CODE-AND-CODEX.md) | `claude-first-launch`, `claude-manual`, `send-buffer`, `codex`, `both-hidden` | **LIVE**: real, signed-in Claude Code and Codex. Record by hand, before lesson 27; the render-all loop skips it. See [Appendix B](../appendices/B-RECORDING-WITH-VHS.md#the-live-tape-lesson-13) | `claude`, `codex`, network, one manual trust step |
| `14-just-panel-tui-skeleton` | [14](../lessons/14-JUST-PANEL-TUI-SKELETON.md) | `start`, `rebuild`, `last` | Worked example JP5; no Neovim | `cargo`, `just`; crates cached or network |
| `15-just-panel-sections-and-filter` | [15](../lessons/15-JUST-PANEL-SECTIONS-AND-FILTER.md) | `headers`, `filter-typing`, `filter-kept`, `filter-cleared`, `help` | Worked example JP6; no Neovim | As 14 |
| `16-just-panel-running-recipes` | [16](../lessons/16-JUST-PANEL-RUNNING-RECIPES.md) | `prompt`, `handover`, `back`, `ctrl-c`, `confirm-sudo`, `confirm-attribute` | Worked example JP7; no Neovim | As 14 |
| `17-just-panel-testing-and-shipping` | [17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md) | `snapshot`, `cargo-test`, `clippy` | Worked example JP8; types into your zsh | `cargo`; crates cached or network |
| `18-session-browser-tui-skeleton` | [18](../lessons/18-SESSION-BROWSER-TUI-SKELETON.md) | `split`, `hover`, `termexec`, `list`, `preview`, `markup` | Worked example SB5; synthetic sessions | `uv`; uv cache or network |
| `19-session-browser-filter-and-search` | [19](../lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md) | `datatable-bindings`, `all`, `claude-tab`, `search`, `filtered-list` | Worked example SB6; synthetic sessions | As 18 |
| `20-session-browser-actions` | [20](../lessons/20-SESSION-BROWSER-ACTIONS.md) | `build-launch`, `run`, `browser`, `suspended`, `copied`, `behind`, `launches` | Worked example SB7; synthetic sessions, stand-in `claude`/`codex`/`kitty` | As 18 |
| `21-session-browser-testing-and-shipping` | [21](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) | `pilot-test`, `pytest`, `checks`, `termexec` | Worked example SB8 | `uv`, `ruff`, `pyright` |
| `22-making-the-config-yours` | [22](../lessons/22-MAKING-THE-CONFIG-YOURS.md) | `attrset`, `keybinds-split`, `verbose-tab`, `verbose-c-i`, `which-key` | Fixture copy; record before lessons 23, 24 and 26 | – |
| `23-fix-jump-forward` | [23](../lessons/23-FIX-JUMP-FORWARD.md) | `verbose-c-i`, `jump-forward`, `tab-next-buffer`, `keybinds` | Fixture copy, plus your `KEYBINDS.md` read-only; record after lesson 23 | – |
| `24-fix-counted-terminal-toggle` | [24](../lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md) | `verbose-leader-t`, `count-popup`, `two-terminals`, `termselect` | Fixture copy; types into your zsh; record after lesson 24 | – |
| `25-fix-pyright-diagnostic-mode` | [25](../lessons/25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md) | `settings`, `trouble`, `ls` | Fixture copy; record after lesson 25 | – |
| `26-fix-close-buffer-key` | [26](../lessons/26-FIX-CLOSE-BUFFER-KEY.md) | `verbose-q`, `verbose-x`, `which-key`, `group-waits`, `closed` | Fixture copy; record after lesson 26 | – |
| `27-fix-claude-diff-review` | [27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md) | `settings`, `claude-manual`, `diff`, `accepted` | **LIVE**: real, signed-in Claude Code, one short prompt. Record by hand, after lesson 27 | `claude`, `jq`, network, one manual trust step |
| `28-going-further` | [28](../lessons/28-GOING-FURTHER.md) | `signs`, `preview`, `staged`, `leader-g`, `verbose` | Throwaway repository from the fixture, demo identity; record after lesson 28's gitsigns keys | `git` |

The exact output and PNG paths for each lesson are on its tape's `Output` and `Screenshot` lines, and
in the lesson's own **Recording** section.
