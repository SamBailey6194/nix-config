# Keyboard-first Neovim course

**Last Updated**: 27/09/2026
**Version**: 1.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

A hands-on course that takes you from your first `nvim` to building two real terminal apps without leaving
the keyboard. Every lesson teaches **your** Neovim: the config in `home/modules/neovim.nix`, as it runs on
NixOS `laptop-intel`, including the traps that config sets. Each step asks you to try something, then tells
you what you should see. Each lesson ends with drills, and the answers are folded away.

## Contents

- [Who it is for](#who-it-is-for)
- [What you will build](#what-you-will-build)
- [Worked examples](#worked-examples)
- [Pane terminology](#pane-terminology)
- [Lessons](#lessons)
- [Appendices and project specs](#appendices-and-project-specs)
- [How to use a lesson](#how-to-use-a-lesson)
- [Notation](#notation)
- [Platform: written on Ubuntu, followed on laptop-intel](#platform-written-on-ubuntu-followed-on-laptop-intel)
- [Media, tapes and fixtures](#media-tapes-and-fixtures)
- [Course layout](#course-layout)
- [Progress checklist](#progress-checklist)

## Who it is for

This course is for an experienced developer who is new to Neovim and to modal editing: someone who already
writes Rust and Python, reads Nix, lives in Hyprland and knows Zed well. It assumes nothing about Vim. It
does assume you want to work from the keyboard: there are no mouse instructions, and every binding is named
with where it comes from.

**Zed habit** callouts map what your fingers already do in Zed onto the Neovim way.

## What you will build

Two capstones, built step by step inside Neovim from lesson 06 onwards. Both live in this repository.

**just-panel** (Rust, ratatui 0.30). A control panel for the repository's justfile:

- it lists every recipe under the justfile's own `# ====` section banners and shows what the selected
  recipe does;
- it runs the recipe in the real terminal, with a prompt for parameters and a confirmation step for recipes
  that use `sudo` or end your session;
- it lives in `rust/just-panel` as a member of the Rust workspace, is packaged by Nix through
  `rust/nix/default.nix`, and ends up on your `PATH` after `just rebuild`.

Milestones JP0 to JP8. Spec: [projects/JUST-PANEL-SPEC.md](projects/JUST-PANEL-SPEC.md).

**session-browser** (Python 3.14, Textual 8). One searchable list of your Claude Code, Codex and Kitty
sessions:

- it previews the session you select;
- Enter resumes it: `claude --resume`, `codex resume` or `kitty --session`;
- it lives in `python/session-browser` as a uv project with a `src` layout, and installs with
  `uv tool install`.

Milestones SB0 to SB8. Spec: [projects/SESSION-BROWSER-SPEC.md](projects/SESSION-BROWSER-SPEC.md).

Every capstone code block in the lessons was built, tested and linted at its milestone before it was
written down. You type it, not invent it. The skill being trained is editing.

## Worked examples

[`examples/`](examples/README.md) holds the finished code for every milestone: `examples/just-panel/JP0`
to `JP8`, each a small Cargo workspace, and `examples/session-browser/SB0` to `SB8`, each a uv project.
Every one builds, passes its tests and is lint-clean. Each milestone section that writes capstone code
ends with a **Stuck? Compare with …** line that points at the right one, and the capstone recordings are
made from them.

**Spoiler warning.** The examples give every milestone away. Type each one yourself first, and open
its example only to compare, or when you are stuck: copying it across skips the editing practice the
course is for. [examples/README.md](examples/README.md) shows how to compare your work with a milestone
and how to run the checks.

## Pane terminology

The course uses three names for the areas of the editor. This is how they map onto your config:

| Name | What it means in this config |
|---|---|
| **File Pane** | The editing area: buffers, windows, splits, the bufferline, and the neo-tree *buffers* panel (`<leader>b`). |
| **Tree** | The neo-tree *filesystem* explorer (`<leader>e`) and every file operation you do from it. |
| **Project Pane** | The whole-project view: the dock layout (tree and outline on the left, git panel on the right, terminal at the bottom), the dev-layout windows that Hyprland opens, Telescope project search, the Aerial outline, and quickfix. |

Lessons 07, 08 and 09 teach the Tree, the File Pane and the Project Pane in that order.

## Lessons

Milestone codes: **JP** = just-panel, **SB** = session-browser. A dash means the lesson has no capstone
milestone.

| # | Lesson | Part | Time | What you learn | Milestone |
|---|---|---|---|---|---|
| 00 | [Setup and orientation](lessons/00-SETUP-AND-ORIENTATION.md) | 0 — Orientation | ~45 min (plus ~30 for `:Tutor` chapter 1) | How the course runs; where the config lives and how KEYBINDS.md is generated; the launch keys; the dock layout; which-key, `:checkhealth`, `:Tutor`, `:qa` | – |
| 01 | [Modes and survival](lessons/01-MODES-AND-SURVIVAL.md) | 1 — Neovim basics | ~45 min | Modes; inserting; saving and quitting; `<C-s>` and `<C-q>`; undo, redo and persistent undo; `:help`; `.` | – |
| 02 | [Motions](lessons/02-MOTIONS.md) | 1 — Neovim basics | ~60 min | Word, line, file and screen motions; counts with relative numbers; marks; the jumplist and the `<Tab>` versus `<C-i>` trap | – |
| 03 | [Operators and text objects](lessons/03-OPERATORS-AND-TEXT-OBJECTS.md) | 1 — Neovim basics | ~75 min | The operator grammar; text objects; Visual modes; indenting; commenting with Comment.nvim; autopairs; `.` repeat | – |
| 04 | [Search, registers and macros](lessons/04-SEARCH-REGISTERS-MACROS.md) | 1 — Neovim basics | ~75 min | Search and substitute; `cgn`; `:g`; registers and the system clipboard; macros | – |
| 05 | [Your keybindings](lessons/05-YOUR-KEYBINDINGS.md) | 2 — Your keybindings | ~60 min | The leader and which-key; every global binding by group; LSP maps; Neovim 0.12 defaults; how bindings are generated; conflicts and shadowing; inspecting maps | – |
| 06 | [Terminal](lessons/06-TERMINAL.md) | 3 — Workspace | ~90 min | toggleterm and Terminal mode; numbered terminals; the hidden Codex terminal; environment traps (direnv, `JUST_*`, `EDITOR`) | JP0, SB0 |
| 07 | [Tree](lessons/07-TREE.md) | 3 — Workspace | ~75 min | neo-tree: navigating, filtering, and creating, renaming, moving and deleting files; what the config changes | JP1, SB1 |
| 08 | [File Pane](lessons/08-FILE-PANE.md) | 3 — Workspace | ~100 min | Buffers, windows and tabs; the bufferline; splits and resizing; the `<leader>x` wait trap | JP2, SB2 |
| 09 | [Project Pane](lessons/09-PROJECT-PANE.md) | 3 — Workspace | ~90 min | The dock layout and dev layouts; Telescope; Aerial; quickfix | investigation (designs JP4, explores SB3 and SB4) |
| 10 | [LSP](lessons/10-LSP.md) | 4 — Code intelligence | ~150 min | rust-analyzer, pyright and ruff; navigation and hover; reading diagnostics with virtual text off; the uv venv and the two Rust toolchains | JP3, SB3 |
| 11 | [Completion, formatting and diagnostics](lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) | 4 — Code intelligence | ~150 min | nvim-cmp and snippets; format on save with conform; Trouble; clippy fixes | JP4, SB4 |
| 12 | [Git](lessons/12-GIT.md) | 5 — Git and AI | ~100 min | gitsigns commands; the git status panel; Neogit; Diffview; fugitive; commit style | commit and tag JP0–JP4, SB0–SB4 |
| 13 | [Claude Code and Codex](lessons/13-CLAUDE-CODE-AND-CODEX.md) | 5 — Git and AI | ~120 min | claudecode.nvim and in-place diff review; the permission-mode trap; Codex in its terminal; AGENTS.md and CLAUDE.md; a safe two-tool workflow | AGENTS.md and CLAUDE.md for both, Claude-drafted tests, a Codex review |
| 14 | [just-panel: TUI skeleton](lessons/14-JUST-PANEL-TUI-SKELETON.md) | 6 — Build just-panel | ~120 min | The ratatui app loop, state, list and detail layout, vim-style keys, loading the real justfile | JP5 |
| 15 | [just-panel: sections and filter](lessons/15-JUST-PANEL-SECTIONS-AND-FILTER.md) | 6 — Build just-panel | ~100 min | Section headers, `/` filter mode, the `?` help popup | JP6 |
| 16 | [just-panel: running recipes](lessons/16-JUST-PANEL-RUNNING-RECIPES.md) | 6 — Build just-panel | ~120 min | Parameter prompt, confirmations, handing the terminal to `just`, exit status | JP7 |
| 17 | [just-panel: testing and shipping](lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md) | 6 — Build just-panel | ~120 min | TestBackend and snapshot tests, clippy, README, Nix packaging, `just rebuild` | JP8 |
| 18 | [session-browser: TUI skeleton](lessons/18-SESSION-BROWSER-TUI-SKELETON.md) | 7 — Build session-browser | ~150 min | Textual App, DataTable of sessions, a markup-safe preview, loading in a worker | SB5 |
| 19 | [session-browser: filter and search](lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md) | 7 — Build session-browser | ~110 min | Source tabs, search input, key bindings, footer | SB6 |
| 20 | [session-browser: actions](lessons/20-SESSION-BROWSER-ACTIONS.md) | 7 — Build session-browser | ~100 min | Resuming Claude and Codex sessions, opening Kitty sessions, copying the command, `App.suspend()` | SB7 |
| 21 | [session-browser: testing and shipping](lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) | 7 — Build session-browser | ~120 min | Pilot and snapshot tests, ruff and pyright clean, `uv tool install` | SB8 |
| 22 | [Making the config yours](lessons/22-MAKING-THE-CONFIG-YOURS.md) | 8 — Making the config yours | ~75 min | The change loop: branch, edit, check, `just rebuild`, verify, commit, and how to go back; choosing keys; recording order; the road map for lessons 23 to 28 | – |
| 23 | [Fix: jump forward again](lessons/23-FIX-JUMP-FORWARD.md) | 8 — Making the config yours | ~40 min | Why `<Tab>` also takes `<C-i>`, and an explicit `<C-i>` map that gives jump-forward back in Kitty | – |
| 24 | [Fix: a counted terminal toggle](lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md) | 8 — Making the config yours | ~45 min | Why `2<leader>t` ignores its count, and a `<leader>t` that passes the count on | – |
| 25 | [Fix: pyright's diagnostic mode](lessons/25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md) | 8 — Making the config yours | ~50 min | The silently ignored `diagnosticsMode` key, and pyright reporting on the whole workspace | – |
| 26 | [Fix: a close-buffer key that does not wait](lessons/26-FIX-CLOSE-BUFFER-KEY.md) | 8 — Making the config yours | ~40 min | Moving close-buffer off the `<leader>x` prefix to `<leader>q` | – |
| 27 | [Fix: review Claude's edits in Neovim](lessons/27-FIX-CLAUDE-DIFF-REVIEW.md) | 8 — Making the config yours | ~35 min | Claude's `permissions.defaultMode`, so its edits arrive as diffs you accept or reject | – |
| 28 | [Going further](lessons/28-GOING-FURTHER.md) | 8 — Making the config yours | ~150 min | gitsigns hunk keys; Terminal-mode window keys without `<Esc>`; the VHS override; `vhs-validate` and `vhs-record` in just-panel; updating `docs/NEOVIM-SETUP.md` | – |

Total: about 2,610 minutes (43 h 30 min), plus ~30 minutes for `:Tutor` chapter 1 in lesson 00.

## Appendices and project specs

| File | What it is |
|---|---|
| [appendices/A-CHEATSHEET.md](appendices/A-CHEATSHEET.md) | Every binding in one place, with the lesson that teaches it and the traps it carries. |
| [appendices/B-RECORDING-WITH-VHS.md](appendices/B-RECORDING-WITH-VHS.md) | Rendering the tapes on laptop-intel, conventions, privacy, and checking each recording. |
| [appendices/C-TROUBLESHOOTING.md](appendices/C-TROUBLESHOOTING.md) | Language server not attaching, the venv invisible to pyright, toolchain mismatches, Claude's auto mode, Codex edits not reloading, `<leader>x` closing buffers, and more. |
| [projects/JUST-PANEL-SPEC.md](projects/JUST-PANEL-SPEC.md) | just-panel: goals, architecture, module map, keymap, milestones, acceptance criteria, tests, packaging. |
| [projects/SESSION-BROWSER-SPEC.md](projects/SESSION-BROWSER-SPEC.md) | session-browser: the same for the Python capstone. |
| [practice/README.md](practice/README.md) | The kata files for lessons 01 to 04, and how to practise on a copy in `/tmp`. |
| [examples/README.md](examples/README.md) | The worked examples: the finished code for every milestone, JP0 to JP8 and SB0 to SB8. Spoilers. |

## How to use a lesson

Every lesson follows the same template:

1. **Header.** The metadata block, then one paragraph on what you will be able to do and why it matters for
   the capstones.
2. **Navigation line.** Part, Time, Previous and Next.
3. **Objectives.**
4. **Before you start.** Prerequisites, what to open, and which milestone you should have reached.
5. **Keys in this lesson.** A table of Keys, Mode, Action and "Where it comes from":
   - `config (neovim.nix:NN)` is a line of your config;
   - `config (LSP buffer-local)` exists only where a language server is attached;
   - `Neovim default`, `Neovim 0.12 default` and `<plugin> default` are not in your config at all.
6. **Walkthrough.** Numbered steps. Each explains an idea, gives you a **Try it**, then says **What you
   should see**.
7. **Gotchas in this config.** The traps your config sets for that topic, each with a fix or a way round.
8. **Drills.** Three to eight short exercises. Each answer is folded inside a
   `<details><summary>Answer</summary>` block, so try first.
9. **Milestone.** Lessons with a capstone step only. The goal, the steps, full code blocks and "check it"
   commands.
10. **Recap.**
11. **Recording.** The tape that produced the lesson's pictures, what each screenshot shows, and how to
    re-record it.

Other rules the lessons follow:

- **Where to read.** Keep the lesson beside Neovim, never in the window you type in: in a browser (GitHub
  renders these files once the course is pushed), in Zed's Markdown preview, or as plain text in a second
  Kitty window with `nvim -R docs/NEOVIM-COURSE/lessons/<file>.md`, where `<leader>o` outlines the headings
  ([lesson 09](lessons/09-PROJECT-PANE.md)). When a lesson says "copy a block from the rendered page", any of
  these will do; in the plain text, a block inside a numbered list carries the list's indentation, which
  [lesson 12](lessons/12-GIT.md)'s milestone tip shows how to strip.
- **Order.** Work through the lessons in order. Each one assumes the milestones before it.
- **Git.** No capstone work is committed until lesson 12. From then on, each milestone ends with a
  suggested commit in the repository's style, such as `feat(just-panel): …`. Lesson 12 and lessons 14 to
  21 then tag it (`course/jp4` … `course/jp8`, `course/sb4` … `course/sb8`), so you can diff against and
  return to each milestone later. The tags are local, and the course never asks you to push.
- **Callouts.** Four kinds: **Gotcha** (a trap in this config), **Tip**, **Zed habit** and **Why**.
- **Unverified claims.** Anything the author could not check from Ubuntu is labelled
  **verify on laptop-intel**.

## Notation

| Written | Means |
|---|---|
| `<leader>` | The Space bar. Each lesson spells it "Space" the first time. |
| `<C-w>` | Ctrl+w. `<C-\><C-n>` is Ctrl+\ then Ctrl+n. |
| `<S-Tab>` | Shift+Tab |
| `<M-q>` | Alt+q |
| `<CR>` / `<Esc>` / `<BS>` | Enter / Escape / Backspace |
| `<leader>ff` | Space, then `f`, then `f`, typed briskly. Pause after a prefix and which-key shows what can follow. |
| `:qa` | Type `:qa` and press Enter. |
| `SUPER + SHIFT + RETURN` | A Hyprland chord: hold SUPER and Shift, press Return. |
| n, i, v, x, o, c, t | Modes: Normal, Insert, Visual (`v` covers all Visual modes, `x` is Visual only), Operator-pending, Command-line, Terminal |
| `neovim.nix:24` | `home/modules/neovim.nix`, line 24. Other files are named in full or relative to the repository root. |

Shell commands always say where they run:

```bash
# in ~/Repos/personal/nix-config
just --justfile docs/NEOVIM-COURSE/fixtures/just/justfile --list
```

## Platform: written on Ubuntu, followed on laptop-intel

The course was **written** on an Ubuntu machine and is **followed and recorded** on NixOS `laptop-intel`,
running the full `laptop-intel` configuration.

- **Ubuntu cannot run Neovim.** `/usr/local/bin/nvim` there is a 9-byte file containing `Not Found`, the
  remains of a failed download, and there is no `~/.config/nvim`. Do not try to follow along on Ubuntu.
- **Pinned versions.** Facts are pinned to what the flake installs: nixpkgs `20b1ddd` (19/09/2026), with
  Neovim 0.12.5, neo-tree 3.42.0, aerial v4.0.0, gitsigns 2.1.0, claude-code 2.1.278, codex 0.155.1,
  just 1.58.0, Rust 1.98 (nixpkgs) plus the rustup toolchain, Python 3.14.7, uv 0.12.16 and kitty 0.48.2.
  VHS is 0.12.1: the config overrides nixpkgs' 0.12.0, which renders nothing. The capstones use
  ratatui 0.30.2 and Textual 8.2.8.
- **Unverified claims.** Anything that could not be checked from Ubuntu is labelled
  **verify on laptop-intel**. If one turns out wrong, the lesson is the thing to fix.
- **Line numbers.** References such as `neovim.nix:61` or `justfile:434-436` match the repository at commit
  `47cd1bc` (27/09/2026). If a file has changed since, lessons 23 to 28 included, search for the quoted text
  instead of trusting the number.
- **Stale guide.** `docs/NEOVIM-SETUP.md` predates this config. It still describes nvim-tree and bindings
  that have moved. Use this course and `~/.config/nvim/KEYBINDS.md` instead;
  [lesson 28](lessons/28-GOING-FURTHER.md) brings the old guide up to date.

## Media, tapes and fixtures

The lessons' GIFs, MP4s and screenshots are recorded with [VHS](https://github.com/charmbracelet/vhs) from
scripted `.tape` files.

- **Rendering.** The tapes are rendered on laptop-intel, where `vhs` comes from the `dev` home stage. Until
  then, the image links in the lessons point at files that do not exist yet. That is expected: every
  instruction is in the text, and the media only illustrate it.
- **VHS version.** The config builds VHS 0.12.1, because 0.12.0 exits 0 and writes nothing: after
  `just rebuild`, `vhs --version` must print 0.12.1
  ([Appendix B](appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)).
- **Where things live.** Each lesson has a tape, `tapes/NN-slug.tape`, whose slug is the lesson file name in
  lower case (for example `tapes/07-tree.tape`). It writes to `media/NN-slug/`.
- **Running a tape.** Run tapes from this folder: `vhs tapes/NN-slug.tape`. Paths in tapes are relative to
  it, and `tapes/_shared/settings.tape` holds the settings that every tape shares.
- **Fixtures.** Tapes never edit the files in your repositories. Most copy a synthetic fixture from
  `fixtures/` into `/tmp/nvim-course/NN-slug` and work there. `fixtures/just/` holds a harmless sample
  justfile; `fixtures/sessions/` holds synthetic Claude, Codex and Kitty sessions, which the session-browser
  tapes use instead of your real ones. The capstone tapes (09, 10 and 14 to 21) record the
  [worked examples](#worked-examples), copied to `/tmp`, never your own capstones, so no tape needs your
  work to be at a particular milestone. Each tape's header names the example it copies. The tapes for
  lessons 13 and 27 are the exceptions to the synthetic data: they are marked **LIVE** and run your real,
  signed-in Claude Code (and, in lesson 13, Codex).
- **Recording order.** Lessons 23 to 28 change the config, so a few tapes must be recorded before them
  and the fix lessons' own tapes after:
  [Appendix B](appendices/B-RECORDING-WITH-VHS.md#record-in-this-order) has the list.
- **More detail.** Conventions, privacy rules, re-recording and a checklist for each recording are in
  [Appendix B](appendices/B-RECORDING-WITH-VHS.md).

## Course layout

```text
docs/NEOVIM-COURSE/
├── README.md             this page
├── lessons/              00-SETUP-AND-ORIENTATION.md … 28-GOING-FURTHER.md
├── appendices/           A-CHEATSHEET.md, B-RECORDING-WITH-VHS.md, C-TROUBLESHOOTING.md
├── projects/             JUST-PANEL-SPEC.md, SESSION-BROWSER-SPEC.md
├── examples/             worked examples: just-panel/JP0…JP8, session-browser/SB0…SB8 (spoilers)
├── practice/             kata files for lessons 01–04
├── fixtures/             synthetic data the tapes copy to /tmp/nvim-course/
├── tapes/                one VHS tape per lesson, plus _shared/settings.tape
└── media/                rendered GIF/MP4/PNG, one folder per lesson
```

## Progress checklist

Tick each lesson as you finish its drills and milestone.

- [ ] 00 — [Setup and orientation](lessons/00-SETUP-AND-ORIENTATION.md)
- [ ] 01 — [Modes and survival](lessons/01-MODES-AND-SURVIVAL.md)
- [ ] 02 — [Motions](lessons/02-MOTIONS.md)
- [ ] 03 — [Operators and text objects](lessons/03-OPERATORS-AND-TEXT-OBJECTS.md)
- [ ] 04 — [Search, registers and macros](lessons/04-SEARCH-REGISTERS-MACROS.md)
- [ ] 05 — [Your keybindings](lessons/05-YOUR-KEYBINDINGS.md)
- [ ] 06 — [Terminal](lessons/06-TERMINAL.md) (JP0, SB0)
- [ ] 07 — [Tree](lessons/07-TREE.md) (JP1, SB1)
- [ ] 08 — [File Pane](lessons/08-FILE-PANE.md) (JP2, SB2)
- [ ] 09 — [Project Pane](lessons/09-PROJECT-PANE.md) (investigation for JP4, SB3 and SB4)
- [ ] 10 — [LSP](lessons/10-LSP.md) (JP3, SB3)
- [ ] 11 — [Completion, formatting and diagnostics](lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md) (JP4, SB4)
- [ ] 12 — [Git](lessons/12-GIT.md) (first commits)
- [ ] 13 — [Claude Code and Codex](lessons/13-CLAUDE-CODE-AND-CODEX.md) (AGENTS.md, CLAUDE.md, tests, review)
- [ ] 14 — [just-panel: TUI skeleton](lessons/14-JUST-PANEL-TUI-SKELETON.md) (JP5)
- [ ] 15 — [just-panel: sections and filter](lessons/15-JUST-PANEL-SECTIONS-AND-FILTER.md) (JP6)
- [ ] 16 — [just-panel: running recipes](lessons/16-JUST-PANEL-RUNNING-RECIPES.md) (JP7)
- [ ] 17 — [just-panel: testing and shipping](lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md) (JP8)
- [ ] 18 — [session-browser: TUI skeleton](lessons/18-SESSION-BROWSER-TUI-SKELETON.md) (SB5)
- [ ] 19 — [session-browser: filter and search](lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md) (SB6)
- [ ] 20 — [session-browser: actions](lessons/20-SESSION-BROWSER-ACTIONS.md) (SB7)
- [ ] 21 — [session-browser: testing and shipping](lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) (SB8)
- [ ] 22 — [Making the config yours](lessons/22-MAKING-THE-CONFIG-YOURS.md)
- [ ] 23 — [Fix: jump forward again](lessons/23-FIX-JUMP-FORWARD.md)
- [ ] 24 — [Fix: a counted terminal toggle](lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md)
- [ ] 25 — [Fix: pyright's diagnostic mode](lessons/25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md)
- [ ] 26 — [Fix: a close-buffer key that does not wait](lessons/26-FIX-CLOSE-BUFFER-KEY.md)
- [ ] 27 — [Fix: review Claude's edits in Neovim](lessons/27-FIX-CLAUDE-DIFF-REVIEW.md)
- [ ] 28 — [Going further](lessons/28-GOING-FURTHER.md)
