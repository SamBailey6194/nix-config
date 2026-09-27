# Lesson 13 — Claude Code and Codex

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Both capstones are about to grow fast, and two coding agents are one keystroke away: Claude Code in a split on
the right, wired into Neovim so that every edit it proposes arrives as a diff you accept, trim or reject, and
Codex in a hidden terminal at the bottom. This lesson makes that safe. You fix the setting that would let Claude
edit with no diff at all, learn the terminal-mode rules that decide where your keys go, give each capstone the
instructions both tools read, and then use them for real: Claude drafts parser tests you review in place,
Codex reviews the Python sources, and git remains the one undo that covers both.

**Part**: 5 — Git and AI · **Time**: ~120 min · **Previous**: [Lesson 12 — Git](12-GIT.md) · **Next**: [Lesson 14 — just-panel: TUI skeleton](14-JUST-PANEL-TUI-SKELETON.md)

## Objectives

- Check Claude's permission mode before it edits anything, and switch it to Manual from the keyboard.
- Move in and out of the Claude and Codex terminals, and know why `<Esc>` must never be mapped there.
- Give Claude context (buffer, selection, files) and review each proposed edit in a Neovim diff.
- Run Codex in its hidden terminal: permissions, review, reloading buffers after it edits, resuming after it exits.
- Write an `AGENTS.md` and a `CLAUDE.md` that imports it for each capstone, and start each tool where it reads them.
- Work with both tools at once without losing work, using git as the shared undo.

## Before you start

- You have finished [Lesson 12](12-GIT.md): JP0–JP4 and SB0–SB4 are committed and tagged `course/jp4` and
  `course/sb4`, and `git status --short` in `~/Repos/personal/nix-config` shows nothing under `rust/just-panel/`
  or `python/session-browser/`.
- Both CLIs work and are signed in. On laptop-intel (full config) `claude --version` reports 2.1.278 and
  `codex --version` 0.155.1. Codex signs in with `codex login` (or an `OPENAI_API_KEY`).
- You know from [Lesson 06](06-TERMINAL.md) that `<C-\><C-n>` leaves a terminal, and from [Lesson 12](12-GIT.md)
  how to stage and commit in Neogit.
- Every prompt you send is a real request against your plan. The walkthrough's prompts are deliberately tiny.
- The walkthrough uses a throwaway practice repo. Create it from a Kitty terminal
  (`SUPER + RETURN`, then `SUPER + 0`: new windows open on workspace 10):

  ```bash
  # in ~/Repos/personal/nix-config
  C=$PWD/docs/NEOVIM-COURSE/fixtures/13-claude-code-and-codex
  L=/tmp/nvim-course/13-practice
  rm -rf "$L" && mkdir -p "$L" && cp -r "$C/." "$L" && cd "$L"
  git init -q -b main
  git config user.name "Course Demo"
  git config user.email "demo@example.invalid"
  git add . && git commit -q -m "docs: review notes"
  nvim panel.md
  ```

## Keys in this lesson

`<leader>` is Space. "t" in the Mode column is Terminal mode.

| Keys | Mode | Action | Where it comes from |
|---|---|---|---|
| `<leader>cc` | n | Toggle the Claude split; start `claude` if none is running | config (neovim.nix:40) |
| `<leader>cb` | n | Send the whole buffer to Claude (`:ClaudeCodeAdd %`) | config (neovim.nix:41) |
| `<leader>cs` | v | Send the selection; in the file tree, the selected files | config (neovim.nix:42) |
| `<leader>co` | n | Toggle the hidden Codex terminal (`:CodexToggle`) | config (neovim.nix:43, :788-797) |
| `<C-\><C-n>` | t | Leave Terminal mode (Normal mode in the terminal buffer) | Neovim default |
| `<C-\><C-o>` | t | Run one Normal-mode command, then return to Terminal mode | Neovim default |
| `i` | n (terminal buffer) | Back into Terminal mode | Neovim default |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | n | Move between windows; in Terminal mode they go to the program instead | config (neovim.nix:68-71) |
| `]c` / `[c` | n (diff) | Next / previous change | Neovim default |
| `do` | n (proposed buffer) | Take the original text back for this hunk | Neovim default |
| `<C-s>` | n (proposed buffer) | `:w`, which accepts the proposal | config (neovim.nix:64) |
| `<C-q>` | n (proposed buffer) | `:q`, which rejects the proposal | config (neovim.nix:65) |
| `:ClaudeCode [args]`, `:ClaudeCodeFocus`, `:ClaudeCodeAdd`, `:ClaudeCodeTreeAdd`, `:ClaudeCodeStatus`, `:ClaudeCodeDiffAccept`, `:ClaudeCodeDiffDeny` | Command | Start, focus, send, report, accept, reject | claudecode.nvim default |
| `:checktime` | Command | Reload buffers whose files changed on disk | Neovim default |
| `Shift+Tab` | Claude prompt | Cycle permission modes | Claude Code default |
| `Esc` / `Esc Esc` | Claude prompt | Interrupt / clear the draft, or open the rewind menu when empty | Claude Code default |
| `@`, `/`, `!`, `\` then `Enter` | Claude prompt | Mention a file, commands, shell mode, new line | Claude Code default |
| `/permissions`, `/review`, `/diff`, `/resume`, `/quit` | Codex composer | Permissions preset, review, diff, resume, quit | Codex default |
| `Esc`, `@`, `Ctrl+O` | Codex composer | Interrupt, file search, copy the latest output | Codex default |

![Lesson 13 recording: the Claude split, Manual mode, sending a buffer, and the hidden Codex terminal](../media/13-claude-code-and-codex/13-claude-code-and-codex.gif)

[MP4](../media/13-claude-code-and-codex/13-claude-code-and-codex.mp4)

## Walkthrough

### 1. Open Claude, then check its permission mode first

`<leader>cc` (Space, then `cc`) runs `:ClaudeCode` (neovim.nix:40). The first time, it starts `claude` in a
full-height split on the right, 30% of the width, and puts you in Terminal mode in it. Later presses hide and
show the same process. In a folder Claude has not seen before it may first ask whether you trust the folder:
accept it.

Before you type anything, read the **mode line** under Claude's input box:

| Mode line | What Claude does with an edit |
|---|---|
| `⏸ manual mode on` | Asks first, and in Neovim that question **is** a diff you accept or reject. This is the mode for this course. |
| `⏵⏵ accept edits on` | Writes files without asking: no diff. |
| `⏸ plan mode on` | Reads and plans, edits nothing until you approve the plan. |
| `⏵⏵ auto mode on` | Writes files and runs commands after its own safety check: **no diff**. |

> **Gotcha:** on this config Claude will very likely start in **auto** mode. `home/modules/claude.nix` sets no
> `permissions.defaultMode`, and Claude's built-in default in a terminal is auto on Pro, Max and Team plans
> (from 2.1.283 for everyone). `skipAutoPermissionPrompt = true` also hides the one-time notice that would have
> told you. In auto mode the diff review in step 4 never happens: files change on disk behind your back.

Fix it for this session in one of two ways:

- **`Shift+Tab`** in Claude's prompt cycles the modes. From auto, the first press goes to Manual; after that
  the cycle is Manual → accept edits → plan → (auto, if available) → Manual. Watch the mode line.
- **Start it in Manual:** `:ClaudeCode --permission-mode manual`. Arguments count only when no Claude process
  is running, so type `/exit` in Claude first (it closes the split), then run the command.

The permanent, machine-wide fix is `permissions.defaultMode = "default"` in `claude.nix`, which
[lesson 27](27-FIX-CLAUDE-DIFF-REVIEW.md) walks through. Do not edit `~/.claude/settings.json` by hand: it is a
read-only link into the Nix store.

**Try it:** `<leader>cc`, read the mode line, then press `Shift+Tab` until it says `⏸ manual mode on`.

**You should see** the split on the right with Claude's input box, and the mode line change with each press.

![First launch: the mode line shows the mode Claude started in](../media/13-claude-code-and-codex/claude-first-launch.png)

![After relaunching with --permission-mode manual](../media/13-claude-code-and-codex/claude-manual.png)

### 2. Terminal mode: where your keys go

Claude's split and Codex's pane are terminal buffers. In **Terminal mode every key except `<C-\>` goes to the
program**, and none of your mappings exist there: the config defines no terminal-mode maps (neovim.nix:80-85
renders every entry in Normal mode unless it says otherwise).

- `<leader>cc` typed in Terminal mode puts " cc" into Claude's prompt. `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` go
  to Claude too, where `Ctrl+J` is a new line, `Ctrl+K` deletes to the end of the line and `Ctrl+L` redraws.
- **Leave** with `<C-\><C-n>`. You are now in Normal mode in the terminal buffer: scroll, search and yank as
  in any buffer, or press `<C-h>` to go back to your code.
- **Return** with `<C-l>` from the code. You land in Normal mode (the plugin only enters Terminal mode when it
  moves the cursor itself), so press `i`. `:ClaudeCodeFocus` does both in one go.
- `<C-\><C-o>` runs a single Normal-mode command and drops you straight back into Terminal mode.

> **Gotcha:** never add the popular `tnoremap <Esc> <C-\><C-n>`. `Esc` is how you interrupt Claude or Codex
> mid-answer, `Esc Esc` in Claude clears the draft or opens the rewind menu, and in Codex it edits your previous
> message. An `<Esc>` map in Terminal mode would swallow all of them. [Lesson 28](28-GOING-FURTHER.md) shows
> window keys for Terminal mode that leave `Esc` alone.

**Try it:** in Claude's prompt press `<C-\><C-n>`, then `<C-h>`; you are back in `panel.md`. Now `<C-l>`,
`i`, and you can type into Claude again. Leave again with `<C-\><C-n>` `<C-h>`.

### 3. Give Claude context

| How | What Claude receives |
|---|---|
| `<leader>cb` | The whole current file as an @-mention (`:ClaudeCodeAdd %`, neovim.nix:41) |
| `V`…, then `<leader>cs` | The selected lines, with their line range (neovim.nix:42, Visual mode only) |
| `<leader>e`, `V` over files, `<leader>cs` | Those files, from the neo-tree file tree |
| `:ClaudeCodeTreeAdd` in the `<leader>e` tree | The file or folder under the cursor |
| `:ClaudeCodeAdd src/sections.rs 20 60` | Lines 20 to 60 of that file |
| `@` in Claude's prompt | A file path, with completion |

The mention appears in Claude's input and **your cursor stays in the editor**, so you can collect several
before switching over. On top of that, `track_selection = true` (neovim.nix:830-833) tells Claude which file
you are in and what you have selected every time you prompt, so select only what you mean to share.

**Try it:** in `panel.md` press `<leader>cb`, then `<C-l>`, `i`.

**You should see** a mention of `panel.md` waiting in Claude's input. Nothing has been sent yet.

![A buffer sent with <leader>cb waits in Claude's input](../media/13-claude-code-and-codex/send-buffer.png)

> **Gotcha:** tree sending reads only neo-tree's **filesystem** source (`<leader>e`). From the buffers panel
> (`<leader>b`) or the git_status panel (`<leader>gs`) it does not work.

### 4. Review a proposed edit in a diff

In Manual mode, when Claude wants to edit a file it opens a diff in Neovim: **your file on the left**, the
proposed version on the right in a buffer whose name ends in `(proposed)`, and the cursor moves into the
proposed side. Claude waits until you decide.

| In the proposed buffer | Effect |
|---|---|
| `]c` / `[c` | Next / previous change |
| `do` | Take the original text back for the change under the cursor: that change is dropped |
| Any edit | Allowed. What you save is what Claude writes |
| `<C-s>` or `:w` | **Accept** |
| `<C-q>` or `:q` | **Reject** (also `:ClaudeCodeDiffDeny`) |

`:ClaudeCodeDiffAccept` and `:ClaudeCodeDiffDeny` do the same from the command line, but only while the cursor
is in the proposed buffer.

**Try it:** with the mention from step 3 still in the input, type the prompt below and press `Enter`:

```text
Add one more bullet to the list in panel.md: a recipe line that starts with spaces. Change nothing else.
```

**You should see** the diff open with focus on the proposed side. Walk it with `]c`, then accept with
`<C-s>`. Your `panel.md` reloads with the new bullet and gitsigns marks it with `+`. The exact way Claude's own
pane reports the pending question differs between versions: answering in Neovim is enough (verify on
laptop-intel that the two stay in step).

Three rules come with this:

- **Save first.** If your buffer has unsaved changes, Claude cannot open a diff and says "Cannot create diff:
  file has unsaved changes. Please save (:w) or discard (:e!)". Press `<C-s>` (or `:e!`) and ask again.
- **Leave Insert mode before `<C-s>`.** The config's `<C-s>` is a Normal-mode map (neovim.nix:64); in Insert
  mode `<C-s>` is Neovim's signature help and accepts nothing.
- **Accepted text is not formatted.** Saving a proposal goes through the plugin's own write handler instead of
  a normal write, so conform's format-on-save (neovim.nix:974-977) does not run. Press `<C-s>` in the real
  buffer afterwards, or run `cargo fmt` / `uvx ruff format`.

> **Zed habit:** Zed's agent panel "Accept" and "Reject" buttons are `<C-s>` and `<C-q>` in the proposed
> buffer. There is no "accept all": you look at each diff.

### 5. Undo: Claude's checkpoints and git

- Claude keeps a **checkpoint** before every prompt. `Esc Esc` on an empty prompt (or `/rewind`) opens the
  rewind menu to restore the code, the conversation or both. Checkpoints do **not** cover changes made by
  Bash commands, by Codex, by you, or most sub-agent edits.
- **git sees everything.** `git diff`, gitsigns (`:Gitsigns reset_hunk`, lesson 12), Neogit `x` and
  `git restore <file>` undo any tool's work. `/diff` in Claude shows the working-tree changes too.
- **Resume later:** `/resume` in Claude picks an old conversation; `:ClaudeCode --continue` (only when no
  Claude is running) continues the latest one in this folder.

**Try it:** undo the accepted bullet with git: `:Gitsigns nav_hunk first`, `:Gitsigns reset_hunk`, `<C-s>`.

### 6. Status, health and Claude outside Neovim

- `:ClaudeCodeStatus` reports whether the plugin's server is running and on which port;
  `:checkhealth claudecode` checks the CLI, the server and the connection.
- The server starts with every Neovim (`auto_start = true`, neovim.nix:831). A `claude` started elsewhere,
  for example in the dev layout's free shell, can join it with `/ide` or by starting as `claude --ide`; its
  diffs then open in this Neovim.
- `/memory` in Claude lists the `CLAUDE.md` files it has loaded (step 11).
- `Ctrl+G` in Claude opens the prompt in `$EDITOR`, which is Zed here (home/stages/dev.nix:75).

### 7. Codex in its hidden terminal

`<leader>co` runs `:CodexToggle` (neovim.nix:43), which toggles a toggleterm terminal defined at
neovim.nix:788-793 with `cmd = 'codex'`, `hidden = true` and `close_on_exit = false`. It opens at the bottom,
15 rows high, in Terminal mode. `codex` starts on the first toggle, in Neovim's current directory; after that
`<leader>co` hides and shows the same session.

- **Hidden** means only `<leader>co` touches it. `<leader>t` and `:ToggleTerm` ignore it, and
  `:TermSelect!` (with the `!`) is the only picker that lists it. Its terminal number depends on what you
  opened first, so never rely on `:2ToggleTerm`.
- With **only** Codex open, `<leader>t` does nothing at all. Hide Codex with `<leader>co` first, then
  `<leader>t` works again.
- The terminal-mode rules of step 2 apply. toggleterm also remembers the mode you left a terminal in: leave
  Codex in Normal mode and it comes back in Normal mode, so press `i`.
- The first run in a folder asks whether to trust it.

**Try it:** `<leader>co`, wait for Codex's header box, then `<C-\><C-n>`, `<C-k>` back to the code, and
`<leader>co` to hide it.

![Codex at the bottom, Claude on the right, the code in the middle](../media/13-claude-code-and-codex/codex.png)

**You should see** the pane close while Codex keeps running. `<leader>cc` from the code hides Claude the same
way, and the next `<leader>cc` or `<leader>co` brings back the same session.

![Both panes hidden with <leader>co and <leader>cc; both processes are still running](../media/13-claude-code-and-codex/both-hidden.png)

### 8. What Codex may do, and the commands you need

In a git repo Codex starts in its **Auto** preset: it edits files and runs commands inside the folder without
asking, and asks before touching anything outside it or using the network. Its sandbox keeps `.git` read-only,
so Codex cannot commit (you do, in Neogit), and it has no network, so `cargo` downloading crates or `uv sync`
will stop and ask.

| Command | What it does |
|---|---|
| `/permissions` | Choose a preset: **Read Only** for a reviewer, Auto for an author |
| `/review` | Review mode: uncommitted changes, a base branch, or other targets it offers |
| `/diff` | `git diff`, untracked files included |
| `/status` | This session's configuration and token use |
| `@` / `/mention` | Find a file and mention it |
| `!cmd` | Run a shell command under the sandbox |
| `Esc` | Interrupt the running turn |
| `/quit` | Leave Codex |

From the shell (`<leader>t`) the same review runs non-interactively and cannot edit anything:
`codex review --uncommitted`, `codex review --commit <sha>` or `codex review "custom instructions"`.

Codex has no Neovim plugin, so it **writes files directly**: no diff appears in Neovim.

### 9. After Codex edits: `:checktime`

Neovim looks for changes made on disk only at certain moments, such as regaining focus or running a `:!`
command, and Codex writing from inside one of Neovim's own terminals is not one of them. After Codex edits a
file you have open, run `:checktime`: unmodified buffers reload, and a buffer with unsaved changes makes Neovim
ask what to do. If a buffer ever reloads by itself first, `:checktime` is simply harmless.

**Try it:** `<leader>co` (press `i` if Codex comes back in Normal mode, step 7) and ask Codex:

```text
Append the line "- a ruler of dashes only" to the list in panel.md. Do nothing else.
```

When it has finished: `<C-\><C-n>`, `<C-k>`, and look at `panel.md`, which still shows the old text. Now
`:checktime`.

**You should see** the new line appear with a `+` in the gutter. Review it like any change (`<leader>gd`, or
`:Gitsigns preview_hunk`), and undo it with `:Gitsigns reset_hunk` and `<C-s>`.

### 10. When Codex exits, and getting the session back

`close_on_exit = false` keeps the pane open after `/quit`, showing `[Process exited]`. The next key you press in
Terminal mode wipes that buffer, and the next `<leader>co` starts a **new** Codex session. The old one is
saved: `/resume` in the new Codex opens a picker of this folder's sessions, and `codex resume --last` in
`<leader>t` reopens the most recent one directly.

**Try it:** `/quit` in Codex, press a key, `<leader>co`, then `/resume` and pick the session from step 9.

### 11. Instructions both tools read: AGENTS.md and CLAUDE.md

- **Codex** reads `AGENTS.md` files from the git root **down to its working directory**, at most one per
  folder, closer ones last (so they win), up to 32 KiB in all. nix-config has none at the root, so Codex only
  sees `rust/just-panel/AGENTS.md` when it runs in `rust/just-panel`.
- **Claude** loads every `CLAUDE.md` from its working directory upwards when it starts, and those in
  subfolders when it reads files there. It reads an `AGENTS.md` itself only when there is no `CLAUDE.md` in the
  folder or above, and nix-config has `.claude/CLAUDE.md` at its root, so it never would here. The fix is a
  one-line `CLAUDE.md` next to each `AGENTS.md` that imports it with `@AGENTS.md`.
- Both tools take their working directory from Neovim's, so **start Neovim in the capstone folder** when you
  want them to use its instructions.

`/init` in either tool would generate such a file for you. You write your own in the milestone instead: shorter,
and every command in it is one you have run.

### 12. A safe way to use both

| Step | How |
|---|---|
| Start clean | `git status` shows nothing unexpected; commit or stash first |
| One writer at a time | Claude writes (Manual mode, diffs), Codex reviews (Read Only), or the other way round, never both at once on the same files |
| Review every change | Claude: in the diff. Codex: `:checktime`, then `<leader>gd` or gitsigns |
| Check | `<C-s>` in the real buffer (format), `<leader>xx` (diagnostics), the tests in `<leader>t` |
| Commit | Neogit, after each accepted change that passes |
| Undo | git. Claude's rewind covers only Claude's own edits |

## Gotchas in this config

- **Auto mode means no diffs.** No `permissions.defaultMode` in claude.nix, so Claude probably starts in auto.
  Check the mode line every session; `Shift+Tab` to `⏸ manual mode on`, or start with
  `:ClaudeCode --permission-mode manual`. Accept-edits mode also skips the diff.
- **Terminal mode swallows your keys.** `<leader>cc`, `<leader>co`, `<leader>t` and `<C-h/j/k/l>` only work in
  Normal mode: `<C-\><C-n>` first.
- **Never map `<Esc>` in Terminal mode**: it would break interrupting and rewinding in both tools.
- **Arguments are ignored while Claude runs.** `:ClaudeCode --anything` only takes effect when no Claude process
  exists (`/exit` first), and there is one Claude per Neovim.
- **`<Tab>` / `<S-Tab>` in Claude's window** (Normal mode) run `:bnext`/`:bprevious` there and replace Claude's
  view with another buffer; the process keeps running and `<C-^>` should bring it back (verify on laptop-intel).
  Leave the window with `<C-h>` before switching buffers.
- **A modified buffer blocks the diff**: save or `:e!` first.
- **Accepted proposals skip format-on-save**: `<C-s>` in the real buffer afterwards.
- **Diffview borrows `<leader>co` and `<leader>cb`** while its tab is open (lesson 12).
- **Codex's `[Process exited]` pane**: one key wipes it and the next `<leader>co` starts afresh; `/resume` or
  `codex resume --last` brings the conversation back.
- **Stale buffers after Codex**: `:checktime`.
- **Codex's sandbox** has no network and a read-only `.git`: expect approval questions for downloads, and commit
  yourself.
- **`Ctrl+G` in Claude opens Zed** (`EDITOR = zeditor --wait`).
- **The `claude` shell alias does not apply inside Neovim.** zsh's alias sets `TMPDIR=$HOME/.claude/tmp`
  (home/modules/shell.nix:60); the plugin starts the bare `claude` binary, so Claude inside Neovim uses the
  normal temporary folder. Harmless.
- **The right edge is shared**: the git_status panel (`<leader>gs`, 40 columns) and Claude's 30% split both
  dock on the right inside a Neovim the dev layout already limits to 75% of the screen. Close one of them.
- **Without `@AGENTS.md`** Claude sees only the NixOS-centred root `.claude/CLAUDE.md`; without starting in the
  capstone folder Codex sees no AGENTS.md at all.

## Drills

1. You press `<leader>cc` to hide Claude and " cc" appears in its prompt. Why, and what do you press instead?
   <details><summary>Answer</summary>

   You were in Terminal mode, where every key goes to Claude. While you are still in its prompt, clear the
   stray text with Claude's own `Esc Esc` (or `Ctrl+C`), then press `<C-\><C-n>` and `<leader>cc`.
   </details>

2. You asked Claude for a change, no diff appeared, and the file has already changed. What happened, and how
   do you undo it and stop it happening again?
   <details><summary>Answer</summary>

   Claude was in auto (or accept-edits) mode. Undo with git (`:Gitsigns reset_hunk`, Neogit `x` or
   `git restore <file>`) or Claude's `/rewind`. Then `Shift+Tab` until `⏸ manual mode on`.
   </details>

3. Claude answers "Cannot create diff: file has unsaved changes". Fix it.
   <details><summary>Answer</summary>

   Save the buffer with `<C-s>` (or throw your changes away with `:e!`) and ask again.
   </details>

4. A proposal has three changes and you want only the first and the third. Keys?
   <details><summary>Answer</summary>

   In the proposed buffer: `]c` to the second change, `do` to take the original back, then `<C-s>` to accept
   the rest.
   </details>

5. You accepted a Rust proposal and the file is not formatted the way rustfmt would. Why, and what now?
   <details><summary>Answer</summary>

   Accepting writes through the plugin's own handler, so format-on-save does not run. Press `<C-s>` in the
   real buffer (or run `cargo fmt`).
   </details>

6. Codex changed `models.py`, which is open in a window, but the window still shows the old code. One command?
   <details><summary>Answer</summary>

   `:checktime`.
   </details>

7. You ran `/quit` in Codex and then pressed a key in its pane. How do you get the conversation back?
   <details><summary>Answer</summary>

   `<leader>co` starts a new Codex; type `/resume` and pick the session. Or run `codex resume --last` in
   `<leader>t`.
   </details>

8. You want Codex to follow `python/session-browser/AGENTS.md`. Where must Neovim be started, and why?
   <details><summary>Answer</summary>

   In `python/session-browser` (or a folder inside it). Codex reads AGENTS.md files from the git root down to
   its working directory, and Codex's working directory is Neovim's.
   </details>

## Milestone JP4 + SB4: agent instructions, Claude-drafted tests, a Codex review

**Goal:** both capstones carry an `AGENTS.md` and a `CLAUDE.md` that imports it; Claude has added four
edge-case tests to `src/sections.rs`, each reviewed in a diff before it touched the disk; Codex has reviewed
the session sources without changing them; everything is committed. The capstone code is otherwise still
JP4 and SB4, which is what lessons 14 and 18 build on.

### Step 1: just-panel instructions

Start Neovim in the crate so that both tools work there:

```bash
# in a Kitty terminal
cd ~/Repos/personal/nix-config/rust/just-panel && nvim src/sections.rs
```

Create the file with `:e AGENTS.md` (the path is relative to Neovim's working directory, `rust/just-panel`)
and put this in it.

> **Tip:** paste the blocks in this milestone rather than typing them. Copy a block from the rendered page
> (the four file contents are not indented, so `V` over the lines inside a fence and `y` in this file's source
> work too), then press `p` in Normal mode in the new buffer:
> `clipboard=unnamedplus` (neovim.nix:257) makes the system clipboard the default register. Typing long
> Markdown in Insert mode invites the completion menu's `<CR>` trap from lesson 11.

```markdown
# just-panel

A terminal control panel for the nix-config justfile, written in Rust with ratatui. This crate is the `just-panel` member of the Cargo workspace in `rust/` (see `../Cargo.toml`).

## Commands

Run them from this directory; cargo finds the workspace on its own.

- Build: `cargo build -p just-panel`
- Test: `cargo test -p just-panel`
- Lint: `cargo clippy -p just-panel --all-targets -- -D warnings`
- Format check: `cargo fmt -p just-panel --check`

A change is finished when all four pass with no warnings.

## Rules

- Tests never run `just`, never need a terminal, the network or `$HOME`, and never read files at run time: test data is compiled in with `include_str!` from `tests/fixtures/`.
- `tests/fixtures/justfile` and `tests/fixtures/dump.json` are exact copies of `docs/NEOVIM-COURSE/fixtures/just/` at the repo root. Do not edit them here.
- Never run a bare `just`: the shell exports `JUST_JUSTFILE` and `JUST_WORKING_DIRECTORY` for the real nix-config justfile. Pass `--justfile` and `--working-directory` explicitly.
- New dependencies go in `[workspace.dependencies]` in `../Cargo.toml` and are used here as `{ workspace = true }`. Nix builds offline from `../Cargo.lock`, so say when the lockfile changes.
- Use crossterm through `ratatui::crossterm`, not as a dependency of its own.
- Fix clippy warnings; do not silence them with new `#[allow(...)]` attributes.
- Keep changes small and focused, and do not commit: the maintainer reviews every diff and commits.
- Comments and docs are in British English.
```

`<C-s>` saves it (prettier formats Markdown on save; this text is already in its style). Then
`:e CLAUDE.md`:

```markdown
# just-panel

The instructions for every coding agent live in AGENTS.md:

@AGENTS.md
```

### Step 2: session-browser instructions

In the same Neovim, `:e ~/Repos/personal/nix-config/python/session-browser/AGENTS.md` and write:

```markdown
# session-browser

A Textual app that lists Claude Code, Codex and Kitty sessions in one table and resumes them. A uv project with a src layout: the package is `session_browser`, the command `session-browser`.

## Commands

Run them from this directory.

- Environment: `uv sync`
- Test: `uv run pytest -q`
- Lint: `uvx ruff check`
- Format check: `uvx ruff format --check`
- Types: `uvx pyright`

A change is finished when all of them pass.

## Rules

- Tests never read real session stores. `tests/conftest.py` points `HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `SESSION_BROWSER_KITTY_DIR` at temporary or fixture folders; keep it that way.
- Never open, list or quote files under `~/.claude`, `~/.codex` or `~/.local/share/kitty`: they hold real conversations. Use `tests/fixtures/` instead.
- `tests/fixtures/` is an exact copy of `docs/NEOVIM-COURSE/fixtures/sessions/` at the repo root. Do not edit it here.
- Session files are internal formats that change between tool versions: parse defensively and skip lines that do not parse.
- Code must work on Python 3.12 (`requires-python = ">=3.12"`); gate anything newer on `sys.version_info`.
- Add dependencies with `uv add` or `uv add --dev`; never edit `uv.lock` by hand.
- Keep changes small and focused, and do not commit: the maintainer reviews every diff and commits.
- Comments and docs are in British English.
```

`<C-s>`, then `:e ~/Repos/personal/nix-config/python/session-browser/CLAUDE.md`:

```markdown
# session-browser

The instructions for every coding agent live in AGENTS.md:

@AGENTS.md
```

`<C-s>`, then `:b sections` back to `sections.rs`.

> **Why:** none of the four files uses fenced code blocks. `uvx ruff format --check` also inspects code blocks
> in Markdown files, and plain lists keep prettier and ruff out of each other's way.

### Step 3: check that Claude reads them

`<leader>cc`. Make sure the mode line says `⏸ manual mode on` (`Shift+Tab` if not). Type `/memory` and
`Enter`: the list should include `rust/just-panel/CLAUDE.md` (whether the imported `AGENTS.md` is listed
separately: verify on laptop-intel). `Esc` closes it. For proof that the import worked, ask:

```text
Which commands must pass before a change here is finished?
```

The answer should be the four `cargo … -p just-panel` commands from your `AGENTS.md`.

### Step 4: Claude drafts four tests, and you review them in place

1. `<C-\><C-n>`, `<C-h>` to `sections.rs`. Make sure it is saved (`<C-s>`), then `<leader>cb`.
2. `<C-l>`, `i`, and paste this prompt with Kitty's `ctrl+shift+v` (a pasted newline does not send it), then
   press `Enter`:

   ```text
   Add four unit tests to the `tests` module at the bottom of src/sections.rs and change nothing else:
   1. a `# ====` banner that holds only sub-sections does not become a section of its own;
   2. a `# Title` / `# ----` sub-section above the first `=` banner is titled with its own title only;
   3. a recipe header with parameters and a quoted default, such as `fuzz TARGET TIME="300":`, gives the name `fuzz`;
   4. a ruler of only two `=` signs is not a banner.
   Use small inline sources like the existing `skips_lines_that_are_not_recipe_headers` test.
   ```

3. The diff opens with the cursor in the proposed buffer. Walk it with `]c` and check each test against
   what the parser really does:
   - (1) a source with `# ====` / `# Storage` / `# ====`, then `# Backups` / `# ----` and a recipe, yields
     exactly one section, titled `Storage / Backups`;
   - (2) the sub-section's title is just its own text, because no `=` banner came first;
   - (3) the recipe name is the first word before the `:`;
   - (4) `# ==` is too short to be a ruler (three characters is the minimum), so its recipe stays in the
     untitled section (`title: None`).

   A test you do not want: `do` on its change. A name you would put differently: edit it. Then `<C-s>` to
   accept, or `<C-q>` to reject everything and ask again.
4. Claude may now ask to run `cargo test -p just-panel`: approve it in Claude's pane, or decline and run it
   yourself in `<leader>t`.
5. Go to your `sections.rs` window (`<C-h>` if you are in Claude's split) and press `<C-s>`: the accepted text
   was not formatted, and this runs rustfmt through rust-analyzer.

If the file changed with **no** diff, you were not in Manual mode. Throw the change away with
`git restore src/sections.rs` (in `<leader>t`, from `rust/just-panel`), fix the mode and ask again.

Check it:

```bash
# in ~/Repos/personal/nix-config/rust/just-panel
cargo test -p just-panel
cargo clippy -p just-panel --all-targets -- -D warnings
cargo fmt -p just-panel --check
```

Expect `test result: ok. 16 passed` if you kept all four tests (12 before, plus yours), and silence from the
other two. From lesson 14 on, your just-panel test counts are higher than the ones the lessons quote by the
number of tests you kept here. If one of the new tests fails, the test is the suspect: the four behaviours
above are what the parser does. Read it, fix it or drop it.

### Step 5: Codex reviews the session sources

1. Open a second Kitty terminal and start Neovim in the Python project:

   ```bash
   # in a Kitty terminal
   cd ~/Repos/personal/nix-config/python/session-browser && nvim src/session_browser/sources/__init__.py
   ```

2. `<leader>co`. The first time in this repo, Codex asks whether to trust it: trust it (an untrusted project may
   not load `AGENTS.md`; verify on laptop-intel).
3. `/permissions` and choose **Read Only**: a reviewer has no reason to write.
4. `/review`. Codex asks what to review. The sources arrived in lesson 12's
   `feat(session-browser): read Claude Code, Codex and Kitty sessions` commit, so there are no uncommitted
   changes to look at: choose to review that commit, or, if your version offers custom instructions, give it
   this (the exact menu is version-dependent: verify on laptop-intel):

   ```text
   Review src/session_browser/sources/ and src/session_browser/models.py for bugs: truncated or malformed JSON Lines, missing keys, timezones, and paths that do not exist. List each finding with its file and line. Do not change any files.
   ```

   The non-interactive equivalent, from `<leader>t`, needs no menu at all. `git log` shows the sources commit
   at the top, marked `tag: course/sb4`; put its short hash in place of the placeholder:

   ```bash
   # in ~/Repos/personal/nix-config/python/session-browser
   git log --oneline -3
   codex review --commit <sha-of-the-sources-commit>
   ```

5. While it works, `<C-\><C-n>`, `<C-k>` and read the code yourself. Come back with `<C-j>`, `i`.
6. When the review is in, `Ctrl+O` (or `/copy`) copies it. `<C-\><C-n>`, `<C-k>`, `:enew`, `p` puts it in a
   scratch buffer to triage (do not save it into the repo). Whether Codex's copy reaches the Wayland clipboard
   from inside Neovim's terminal: verify on laptop-intel. If it does not, read the review in Codex's pane.

**Triage:** the lessons that follow build on these modules exactly as they are, so change them only for a real
bug, with a test that shows it, in a separate `fix(session-browser): …` commit, keeping function names and
signatures. Everything else is a note for [Lesson 21](21-SESSION-BROWSER-TESTING-AND-SHIPPING.md)'s quality
pass. Whatever you change, check with `uv run pytest -q`, `uvx ruff check` and `uvx pyright`.

### Step 6: commit

In either Neovim, `<leader>gg`. The four instruction files are listed one by one under Untracked files, and
`sections.rs` under Unstaged changes. Make three commits (`s` on the files, `c` `c`, message, `<c-c><c-c>`):

```text
docs(just-panel): AGENTS.md and CLAUDE.md for coding agents
```

```text
docs(session-browser): AGENTS.md and CLAUDE.md for coding agents
```

```text
test(just-panel): four more section-banner parser edge cases

Drafted by Claude Code from src/sections.rs and reviewed as a diff in
Neovim before accepting:

- a banner that holds only sub-sections is not a section;
- a sub-section above the first banner keeps its own title;
- a recipe header with a quoted default still gives the recipe name;
- a two-character ruler is not a banner.

Co-Authored-By: <model name> <noreply@anthropic.com>
```

Replace `<model name>` with the model that drafted the tests, as the repo's other Claude-assisted commits do
(`git log -5` shows the form). Adjust the body to the tests you kept.

### Check it

```bash
# in ~/Repos/personal/nix-config/python/session-browser
uv run pytest -q
uvx ruff check
uvx ruff format --check
# in ~/Repos/personal/nix-config
git log --oneline -6
git status --short
```

pytest still reports `39 passed, 2 skipped` (3.12) or `41 passed` (3.14), and `uvx ruff check` is clean.
`uvx ruff format --check` now reports `18 files already formatted` (ruff 0.16 counts Markdown too: the
milestone's 16 files plus the new `AGENTS.md` and `CLAUDE.md`). Lessons 18 to 20 quote the count with these two
files included. `git log` shows the three new commits (four with a
`fix(session-browser)` commit) on top of lesson 12's three, and `git status --short` shows nothing under the
two capstones. Do not push.

Stuck? This milestone has no worked example of its own: the instructions and the tests you kept are yours.
Everything else still matches [examples/just-panel/JP4](../examples/just-panel/JP4/) and
[examples/session-browser/SB4](../examples/session-browser/SB4/) — see
[examples/README.md](../examples/README.md#what-differs-from-what-you-generate).

## Recap

- Check Claude's mode line first: `⏸ manual mode on` or no diffs. `Shift+Tab`, or
  `:ClaudeCode --permission-mode manual` when no Claude is running.
- In a terminal every key but `<C-\>` goes to the program: `<C-\><C-n>` out, `i` back in, and never map `<Esc>`.
- `<leader>cb`, `<leader>cs` and the tree give Claude context; the diff is yours to trim (`do`), accept
  (`<C-s>`) or reject (`<C-q>`). Save first; format afterwards.
- `<leader>co` is Codex: hidden from `<leader>t`, Auto by default, `/permissions` to Read Only, `/review`,
  `:checktime` after it writes, `/resume` after it exits.
- `AGENTS.md` for both tools, `CLAUDE.md` with `@AGENTS.md` for Claude, Neovim started in the capstone folder.
- One writer at a time, commit between turns, and let git be the undo.

## Recording

- **Tape:** [`tapes/13-claude-code-and-codex.tape`](../tapes/13-claude-code-and-codex.tape). Run it from
  `docs/NEOVIM-COURSE/` on laptop-intel: `vhs tapes/13-claude-code-and-codex.tape`.
- **VHS version:** `vhs --version` must print 0.12.1, which the config builds (0.12.0 exits 0 and writes nothing);
  if it prints 0.12.0, `just rebuild` first ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)).
- **LIVE tape.** It starts the real `claude` and `codex`, which must be signed in; starting them makes network
  calls that count as account activity. It never submits a prompt, so no model output is recorded, but frames
  differ between runs: versions, notices, and the mode Claude starts in.
- **Record it before [lesson 27](27-FIX-CLAUDE-DIFF-REVIEW.md).** After that lesson Claude starts in Manual
  mode, so `claude-first-launch.png` would no longer show the trap this lesson teaches
  ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#record-in-this-order)).
- **Outputs:** `media/13-claude-code-and-codex/13-claude-code-and-codex.gif` and `.mp4`.
- **Screenshots** (all in `media/13-claude-code-and-codex/`):

  | File | Shows | Step |
  |---|---|---|
  | `claude-first-launch.png` | The Claude split after `<leader>cc`, with the mode it started in (usually auto) | 1 |
  | `claude-manual.png` | Claude relaunched with `:ClaudeCode --permission-mode manual`: `⏸ manual mode on` | 1 |
  | `send-buffer.png` | The `panel.md` mention from `<leader>cb` waiting in Claude's input | 3 |
  | `codex.png` | Codex at the bottom, Claude on the right, the code in the middle | 7 |
  | `both-hidden.png` | Both panes hidden again with `<leader>co` and `<leader>cc` | 7 |

- **Manual step, once, before the first recording.** First-run questions cannot be answered safely by the tape,
  so answer them by hand. Both tools remember the answer for this path, and the tape's `rm -rf` does not undo
  that:

  ```bash
  # in a Kitty terminal
  mkdir -p /tmp/nvim-course/13-claude-code-and-codex
  cd /tmp/nvim-course/13-claude-code-and-codex
  claude    # accept the folder-trust question, then /exit
  codex     # answer the trust question; if it offers an update, skip it until the next version; then /quit
  ```

  If you skip it, a `Wait` times out and VHS writes no GIF.
- **Privacy.** The tape sets `IS_DEMO=1` (hides your e-mail and organisation name in Claude's header) and
  `CLAUDE_CODE_HIDE_CWD=1` (hides the folder in Claude's logo). Both are documented Claude Code variables; check
  on laptop-intel that 2.1.278 honours them. Before publishing, step through every frame and look at Claude's
  header and status line (your status line script shows the folder, branch, model and usage) and at Codex's
  header box (model and folder only). Re-record or crop anything that identifies your account.
- **Side effects:** a run may leave short Claude and Codex sessions for
  `/tmp/nvim-course/13-claude-code-and-codex` in your history (whether a session with no prompt is saved depends
  on the version), and those show up in `/resume` pickers and in session-browser.
- **Check after every run:** `media/13-claude-code-and-codex/` actually contains the GIF, the MP4 and all five
  PNGs (an empty folder after a run that exited 0 means VHS 0.12.0 did the rendering), and `ls ~/.claude/ide/`
  lists no lock left behind by the tape's Neovim.
