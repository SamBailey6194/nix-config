# Lesson 28 — Going further

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Lessons 23 to 27 removed traps. This last lesson adds what the course left out and tidies what it left
behind. You give gitsigns the keys it never had (`]h`/`[h` to jump between hunks, Space g p/a/r/b to
preview, stage, reset and blame), add Terminal-mode keys that move between windows without taking `<Esc>`
from Claude or Codex, and read the VHS override the config already carries: what it does, how you would
have found the bug, and when to remove it. Then you add two tape recipes to the justfile and watch
just-panel pick them up with no code change, and replace the stale `docs/NEOVIM-SETUP.md` with a short
guide that cannot drift. Every change goes round lesson 22's loop and ends in its own commit.

**Part**: 8 — Making the config yours · **Time**: ~150 min · **Previous**: [Lesson 27 — Fix: review Claude's edits in Neovim](27-FIX-CLAUDE-DIFF-REVIEW.md) · **Next**: [Appendix A — Cheat sheet](../appendices/A-CHEATSHEET.md)

## Objectives

By the end of this lesson you can:

- jump between, preview, stage (whole hunks or selected lines), reset and blame git hunks with keys you
  chose, and say why they are `]h` and `<leader>g…` rather than the gitsigns README's suggestions;
- leave a terminal window with `Alt+h/j/k/l` and come back in Terminal mode, and explain why `<Esc>` and
  `<C-h/j/k/l>` are the wrong keys for it;
- explain how `vhs.overrideAttrs` in `home/stages/dev.nix` replaces one pinned package, how the VHS
  0.12.0 bug would have been diagnosed, how to check the fix is in effect, and when and how to drop it;
- add justfile recipes and find them in just-panel;
- replace a hand-kept reference with one that points at the generated one;
- pick your next steps.

## Before you start

- **Lesson 22's loop.** Branch, edit, `:noautocmd w`, `nix-instantiate --parse`, `just rebuild`, restart
  Neovim, verify, commit. Lessons 23 to 27 are independent of this one: do them first or not at all.
- **Machine:** NixOS `laptop-intel`, full configuration. Section 4 also needs just-panel from
  [lesson 17](17-JUST-PANEL-TESTING-AND-SHIPPING.md): `command -v just-panel` prints a path.
- **A clean tree and one branch per section:**

  ```bash
  # in ~/Repos/personal/nix-config
  git status                         # expect: nothing to commit, working tree clean
  git switch -c config/gitsigns-keys # section 1; later config/terminal-alt-keys, config/vhs-recipes, docs/neovim-setup
  ```

- **Record tapes 05 and 09 first** if you want the course's recordings. Section 1 adds four keys to tape
  05's `+git` popup, and section 4 moves the justfile line numbers that tape 09 shows
  ([lesson 22](22-MAKING-THE-CONFIG-YOURS.md), step 10). Tape 28 is the other way round: record it
  after section 1.
- **The finished files** are in `fixtures/28-going-further/` for comparing: the four diffs of this lesson
  under `patches/`, and the new `NEOVIM-SETUP.md`. Its `README.md` shows how to check your edit against
  them.

## Keys in this lesson

The rows marked "section 1" or "section 2" only exist once you have made that change.

| Keys | Mode | Action | Where it comes from |
|---|---|---|---|
| `]h` / `[h` | n | Next / previous hunk; `]h` lands on the hunk's first line, `[h` on its last | config (neovim.nix:39-40, section 1) |
| `<leader>gp` (Space g p) | n | Preview the hunk in a float | config (neovim.nix:41, section 1) |
| `<leader>ga` | n | Stage the hunk; on a staged hunk, unstage it | config (neovim.nix:42, section 1) |
| `<leader>ga` | x | Stage only the selected lines | config (neovim.nix:43, section 1) |
| `<leader>gr` | n | Reset the hunk: discard the change in the buffer | config (neovim.nix:44, section 1) |
| `<leader>gb` | n | Blame the line in a float | config (neovim.nix:45, section 1) |
| `<A-h>` `<A-j>` `<A-k>` `<A-l>` | t | Window left / down / up / right, staying in Terminal mode | config (neovim.nix:72-75, section 2) |
| `<C-\><C-n>` | t | Leave Terminal mode | Neovim default |
| `:Gitsigns nav_hunk next` | command | What `]h` runs (and `prev`, `preview_hunk`, `stage_hunk`, `reset_hunk`, `blame_line`) | gitsigns default |
| `:verbose tmap {lhs}` / `:verbose xmap {lhs}` | command | Show a Terminal-mode / Visual-mode map and where it was set | Neovim default |
| `/`, `<CR>`, `<Esc>` | just-panel | Filter, run the selected recipe, clear the filter | just-panel (app.rs) |

Section 2's lines are 79-82 if section 1 is already in; lessons 23 to 27 move them a little further.

## Walkthrough

![Jumping between hunks with the new keys, previewing one with Space g p, staging one with Space g a, and the +git popup](../media/28-going-further/28-going-further.gif)

[MP4](../media/28-going-further/28-going-further.mp4)

### 1. Give gitsigns some keys

#### See the problem

gitsigns draws the signs you met in [lesson 12](12-GIT.md), but every action is a command: you have typed
`:Gitsigns nav_hunk next`, `:Gitsigns preview_hunk` and `:Gitsigns stage_hunk` in full. The obvious key
does nothing:

```vim
:verbose nmap ]h
```

**What you should see:** `No mapping found`. Pressing `]h` in a changed file moves nothing.

#### Why it happens

The config calls `require('gitsigns').setup` with only a `signs` table (neovim.nix:736-744). gitsigns
itself sets no keys; its README suggests binding them in an `on_attach` function, and the config has
none. Every other global key lives in the `keymaps` list, so that is where these go too.

#### Decide

The gitsigns README suggests `]c`/`[c` and `<leader>h…`. Run them and the alternatives through lesson 22's
key checklist:

| Candidate | Collides with | Verdict |
|---|---|---|
| `]c` / `[c` | Neovim's diff-mode "next/previous change", which you use when reviewing Claude's diffs ([lesson 13](13-CLAUDE-CODE-AND-CODEX.md)), in `:Gvdiffsplit` and in Diffview | avoid |
| `]h` / `[h` | Nothing. Pause after `]` and which-key lists every `]` key there is: `]a`, `]b`, `]d`, `]l`, `]m`, `]q`, `]t` and their capitals, `]s`, `]%`, `](`, `]<`, `]{`, `]<Space>` and three Ctrl ones. No `h` | **take** |
| `<leader>hs`, `<leader>hp`, … | `<leader>h` clears the search highlight (neovim.nix:66). `<leader>h…` would make it a prefix with an action, the `<leader>x` trap again | avoid |
| `<leader>gp`, `<leader>ga`, `<leader>gr`, `<leader>gb` | `<leader>g` is a pure group ("git", neovim.nix:846) with no action of its own. `gs gg gd gq gh` are taken; `p a r b` are free | **take** |

Three more decisions:

- **Strings, not closures.** The list can only hold strings, because every `rhs` goes through `luaStr`.
  `<cmd>Gitsigns …<CR>` covers every action here. Something that needs a Lua function, such as
  `require('gitsigns').blame_line({ full = true })`, follows the `<leader>cf` pattern instead: a
  `docOnly` entry plus a hand-written `vim.keymap.set` next to neovim.nix:987-989.
- **Staging a selection needs `:`, not `<Cmd>`.** A `<Cmd>` map never passes the selected range. A
  classic `:` map does: from Visual mode, Neovim types `'<,'>` after the `:` for you, and
  `:'<,'>Gitsigns stage_hunk` stages just those lines.
- **Mode `x`, not `v`.** `v` also covers Select mode, which snippet placeholders use, and there a typed
  Space should be text rather than the start of a map. `x` is Visual mode only.

> **Why:** these are global maps, while the README binds them per buffer in `on_attach`. The keys
> therefore also exist in buffers outside a git repository. There they do nothing and print nothing
> (checked on the real config, in a file outside any repository).

#### Make the change

Seven lines after the last Git entry (neovim.nix:38). The diff is against the file as it is at the start
of this lesson; after lessons 23 to 27 the line numbers differ, so find the place by its text.

```diff
--- a/home/modules/neovim.nix
+++ b/home/modules/neovim.nix
@@ -36,6 +36,13 @@
     { group = "Git";    lhs = "<leader>gd"; rhs = "<cmd>DiffviewOpen<CR>";          desc = "Diff view"; }
     { group = "Git";    lhs = "<leader>gq"; rhs = "<cmd>DiffviewClose<CR>";         desc = "Close diff view"; }
     { group = "Git";    lhs = "<leader>gh"; rhs = "<cmd>DiffviewFileHistory %<CR>"; desc = "History of this file"; }
+    { group = "Git";    lhs = "]h";         rhs = "<cmd>Gitsigns nav_hunk next<CR>"; desc = "Next hunk"; }
+    { group = "Git";    lhs = "[h";         rhs = "<cmd>Gitsigns nav_hunk prev<CR>"; desc = "Previous hunk"; }
+    { group = "Git";    lhs = "<leader>gp"; rhs = "<cmd>Gitsigns preview_hunk<CR>";  desc = "Preview hunk"; }
+    { group = "Git";    lhs = "<leader>ga"; rhs = "<cmd>Gitsigns stage_hunk<CR>";    desc = "Stage / unstage hunk"; }
+    { group = "Git";    lhs = "<leader>ga"; rhs = ":Gitsigns stage_hunk<CR>";        desc = "Stage selected lines (visual)"; mode = "x"; }
+    { group = "Git";    lhs = "<leader>gr"; rhs = "<cmd>Gitsigns reset_hunk<CR>";    desc = "Reset hunk (discard changes)"; }
+    { group = "Git";    lhs = "<leader>gb"; rhs = "<cmd>Gitsigns blame_line<CR>";    desc = "Blame this line"; }
 
     { group = "AI";     lhs = "<leader>cc"; rhs = "<cmd>ClaudeCode<CR>";           desc = "Toggle Claude Code"; }
     { group = "AI";     lhs = "<leader>cb"; rhs = "<cmd>ClaudeCodeAdd %<CR>";      desc = "Send buffer to Claude"; }
```

In Neovim: `:38` `<CR>`, `yy` then `p` gives you a Git line to change, and `.` repeats the paste until
you have seven. Or type them fresh with `o`.

#### Check and rebuild

```bash
# in ~/Repos/personal/nix-config (after :noautocmd w in Neovim)
nix-instantiate --parse home/modules/neovim.nix > /dev/null && echo OK
git diff --stat                    # 1 file changed, 7 insertions(+)
just rebuild
```

Then restart Neovim, as lesson 22 step 7 describes.

#### Verify

The maps first:

```text
:verbose nmap ]h
n  ]h          * <Cmd>Gitsigns nav_hunk next<CR>
                 Next hunk
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)

:verbose xmap <leader>ga
x  <Space>ga   * :Gitsigns stage_hunk<CR>
                 Stage selected lines (visual)
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

![:verbose nmap for the next-hunk key: the new map, its description and where it was set](../media/28-going-further/verbose.png)

Then the keys, on a throwaway repository with three known hunks. It is the one tape 28 records: the
course's demo justfile, committed, with a changed comment, a deleted recipe and two added recipes on
top.

```bash
# in the layout's bottom-right shell
C=~/Repos/personal/nix-config/docs/NEOVIM-COURSE/fixtures/28-going-further
L=/tmp/nvim-course/28-going-further
rm -rf "$L" && mkdir -p "$L" && cp -r "$C"/v1/. "$L" && cd "$L"
git init -q -b main && git config user.name "Course Demo" && git config user.email "demo@example.invalid"
git add . && git commit -q -m "chore: demo justfile" && cp -r "$C"/v2/. .
nvim justfile
```

The repository-local identity keeps your own name out of it; your personal identity only applies under
`~/Repos/personal/`.

**What you should see:** `~` beside line 11, `_` beside line 14 (the deleted `lint-rust` recipe was
below it) and `+` beside lines 19-26.

![The demo justfile with three hunks: ~ on line 11, _ on line 14, + on lines 19-26](../media/28-going-further/signs.png)

**Try it:**

1. `]h` three times: the cursor lands on lines 11, 14 and 19, the first line of each hunk. The command
   line shows `Hunk 1 of 3` and so on as you go.
2. `[h` twice: back to 14, then 11. From the bottom of the file (`G`), `[h` lands on line 26, the
   **last** line of the added hunk. That is gitsigns' rule for going backwards.
3. `gg`, then `2]h`: straight to line 14. A count works, because gitsigns reads it from `v:count1`.
4. On line 11, Space g p (`<leader>gp`): a float titled `Hunk 1 of 3` shows `-# Test the Rust tools`
   and `+# Test every Rust crate in the workspace`, with the changed words highlighted. Move the
   cursor to close it.

   ![The preview float for hunk 1: the old and new comment lines](../media/28-going-further/preview.png)

5. `]h` twice to line 19, then Space g a (`<leader>ga`): the eight `+` signs turn into gitsigns' staged
   bar, `┃`. In the shell, `git diff --cached --stat` reports `1 file changed, 8 insertions(+)`.
   Space g a again on the same hunk unstages it: gitsigns 2.1.0 toggles.

   ![The added hunk staged: its + signs replaced by the staged bar](../media/28-going-further/staged.png)

6. Stage part of a hunk: `19G`, `V`, `jj` (lines 19-21), Space g a. `git diff --cached` shows only the
   `vhs-validate` recipe, three lines.
7. On line 11, Space g r (`<leader>gr`): the comment goes back to `# Test the Rust tools`. It is an edit
   to the buffer, so `u` brings your change back, and nothing reaches the file until you save.
8. Space g b (`<leader>gb`) on line 7: a float with the commit's short hash, `Course Demo`, the date and
   `chore: demo justfile`. On line 11 it says `Not Committed Yet`.
9. Space g, then a pause: the `+git` popup lists `a`, `b`, `p` and `r` beside the old five.

   ![The +git popup with Stage / unstage hunk, Blame this line, Preview hunk and Reset hunk](../media/28-going-further/leader-g.png)

   `]` and a pause shows `h ➜ Next hunk` among the `]` keys.

Quit with `:qa!` (nothing here is worth saving).

#### What else changes

- `KEYBINDS.md`'s Git table gains seven rows, `<leader>ga` twice; the descriptions tell the two apart.
- Tape 05's `leader-g.png` would now show the longer popup: record it before this change.
- [Lesson 12](12-GIT.md) still teaches the `:Gitsigns` commands. They keep working; the keys are a
  shortcut to them.
- Inside the neo-tree git panel, `ga`, `gr` and `gp` are that panel's own keys (stage, revert, push).
  They are different keys from Space g a/r/p and do not clash.

#### Commit

`feat(nvim): gitsigns hunk keys (]h [h, <leader>gp/ga/gr/gb)`

### 2. Leave a terminal window without `<Esc>`

#### See the problem

Every map in the list is Normal mode unless it says otherwise, and none says `"t"`. Open the bottom
terminal with Space t and, while it is in Terminal mode, press `<C-k>`: zsh deletes to the end of the
line instead of moving you up. Leaving takes three keys, `<C-\><C-n>` and then `<C-k>`, and the terminal
is then in Normal mode when you come back, so you press `i` as well.

```vim
:verbose tmap
```

**What you should see:** `No mapping found`. The config has no Terminal-mode maps at all.

#### Why it happens

`renderKeymap` passes `k.mode or "n"` to `vim.keymap.set` (neovim.nix:82-84), so every entry without a
`mode` is Normal mode, `<C-h/j/k/l>` (neovim.nix:68-71) included. In Terminal mode every key except
`<C-\>` goes to the program in the terminal.

#### Decide

Many Neovim guides, toggleterm's README among them, suggest mapping `<Esc>` to `<C-\><C-n>` in Terminal
mode. **Do not.**

- In Claude, `Esc` interrupts a turn, and `Esc Esc` on an empty prompt opens the rewind menu.
- In Codex, `Esc` interrupts, and `Esc Esc` on an empty composer edits your previous message.
- Any full-screen program you run in a terminal (`less`, `btop`, another `nvim`) needs `Esc`.

`<C-h/j/k/l>` in Terminal mode are no better. In Claude, `Ctrl+J` inserts a newline, `Ctrl+K` deletes to
the end of the line and `Ctrl+L` redraws. Codex 0.155.1 binds `Ctrl+J` (newline), `Ctrl+K` (delete to the
end of the line), `Ctrl+L` (clear) and `Ctrl+H` (delete backwards) by default. In zsh, `Ctrl+L` clears the
screen.

`Alt+h/j/k/l` is a set nobody here relies on:

| Program | Uses Alt+h/j/k/l? |
|---|---|
| Claude Code | No. Its Alt keys are `Alt+P`, `Alt+T` and `Alt+O` |
| Codex 0.155.1 | No. Its default Alt keys are `Alt+B`, `Alt+F`, `Alt+D`, `Alt+R`, `Alt+,`, `Alt+.`, `Alt+Enter`, `Alt+Backspace`, `Alt+Delete` and the arrows (read from its `codex-rs/tui/src/keymap.rs` at `rust-v0.155.1`). `Ctrl+Alt+H` is a different chord |
| Kitty | No. Its own shortcuts use `Ctrl+Shift`, and the config adds only font-size keys (home/stages/desktop.nix:82-90) |
| Hyprland | No. It only uses `SUPER + ALT` |
| zsh (emacs keymap) | `Alt+h` is `run-help` and `Alt+l` is `down-case-word`; `Alt+j` and `Alt+k` are unbound. Inside Neovim's terminals you lose the first two |

The rhs is `<Cmd>wincmd h<CR>`, not `<C-\><C-n><C-w>h`. It moves without leaving Terminal mode first,
which is the form toggleterm's README recommends with `persist_mode`: the terminal is still in Terminal
mode when you come back to it.

#### Make the change

`KEYBINDS.md` does not show modes, so the `desc` says it:

```diff
--- a/home/modules/neovim.nix
+++ b/home/modules/neovim.nix
@@ -69,6 +69,10 @@
     { group = "Windows"; lhs = "<C-j>"; rhs = "<C-w>j"; desc = "Window down"; }
     { group = "Windows"; lhs = "<C-k>"; rhs = "<C-w>k"; desc = "Window up"; }
     { group = "Windows"; lhs = "<C-l>"; rhs = "<C-w>l"; desc = "Window right"; }
+    { group = "Windows"; lhs = "<A-h>"; rhs = "<Cmd>wincmd h<CR>"; desc = "Window left (terminal mode)";  mode = "t"; }
+    { group = "Windows"; lhs = "<A-j>"; rhs = "<Cmd>wincmd j<CR>"; desc = "Window down (terminal mode)";  mode = "t"; }
+    { group = "Windows"; lhs = "<A-k>"; rhs = "<Cmd>wincmd k<CR>"; desc = "Window up (terminal mode)";    mode = "t"; }
+    { group = "Windows"; lhs = "<A-l>"; rhs = "<Cmd>wincmd l<CR>"; desc = "Window right (terminal mode)"; mode = "t"; }
   ];
 
   # Lua single-quoted string literal. Backslash first, or it would double the
```

After section 1 the hunk starts at line 76 instead of 69; the context lines are the same.

#### Check and rebuild

```bash
# in ~/Repos/personal/nix-config (after :noautocmd w in Neovim)
nix-instantiate --parse home/modules/neovim.nix > /dev/null && echo OK
git diff --stat                    # 1 file changed, 4 insertions(+)
just rebuild
```

Restart Neovim.

#### Verify

```text
:verbose tmap <A-h>
t  <M-h>       * <Cmd>wincmd h<CR>
                 Window left (terminal mode)
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

Neovim writes Alt as `<M-…>` (Meta). `:tmap` with no argument lists all four.

**Try it** (all checked on the real config):

1. Space t opens the terminal in Terminal mode. Press `Alt+k`: the cursor is in the window above, in
   Normal mode, and the shell keeps running.
2. `<C-j>` takes you back down, and the terminal is in Terminal mode again: type and the shell gets it.
   toggleterm's `persist_mode` remembered the mode you left in.
3. For comparison, `<C-\><C-n>` then `<C-k>`, and `<C-j>` back: now the terminal is in Normal mode and
   needs `i`.
4. Claude's split works too: Space c c, then `Alt+h` to the file. Coming back with `<C-l>` leaves you in
   the split's Normal mode, because claudecode.nvim only enters Terminal mode when it opens or focuses the
   split itself. Press `i`.
5. In Normal mode the maps do not exist, and Neovim reads an Alt key that is not mapped as `<Esc>`
   followed by the key (`:help vim-differences`: "ALT may behave like <Esc> if not mapped"). So in a
   file, `Alt+j` just moves the cursor down like `j`, and never changes window. Keep using
   `<C-h/j/k/l>` there.

which-key never pops up in Terminal mode (its triggers cover Normal, Visual, Select and Operator-pending
mode only), so `KEYBINDS.md` is where you look these up.

#### What else changes

- `KEYBINDS.md`'s Windows table gains four rows ending in "(terminal mode)".
- [Lesson 06](06-TERMINAL.md) and [lesson 13](13-CLAUDE-CODE-AND-CODEX.md) teach `<C-\><C-n>` first. It
  still works and is still the way into Normal mode to scroll or yank terminal output.
- No tape presses `Alt`, so no recording changes.

#### Commit

`feat(nvim): Alt+h/j/k/l leave a terminal window without Esc`

### 3. The VHS override, explained

This change is already in the config. Commit `47cd1bc` (`fix(dev): build vhs 0.12.1 so tapes actually
render`) replaced one line of `home/stages/dev.nix`. There is nothing to edit here; the section reads it,
shows how the bug would have been found, how to check the fix, and when to take it out.

#### What it does

`home/stages/dev.nix:50-62` today:

```nix
    # Terminal recording
    # Scripted terminal recordings (.tape -> GIF/MP4); wraps its own ttyd + ffmpeg.
    # 0.12.1, not nixpkgs' 0.12.0: 0.12.0 cancels its own render context, so it
    # plays a tape, exits 0 and writes no GIF, MP4 or PNG (charmbracelet/vhs#787,
    # fixed by #788). go.mod is unchanged, so the vendorHash carries over. Drop
    # the override once the pinned nixpkgs has 0.12.1.
    (vhs.overrideAttrs (old: {
      version = "0.12.1";
      src = old.src.override {
        tag = "v0.12.1";
        hash = "sha256-9O9f/3B42BhhJ5LWNyHrQtaOKwVnAZR309Dvbpx3d4g=";
      };
    }))
```

Read it from the inside out:

- `old.src.override { … }` reuses the package's own `fetchFromGitHub` call, so the owner and repository
  stay, with a new `tag` and the hash of the 0.12.1 source.
- `vhs.overrideAttrs (old: { … })` returns a copy of the package with `version` and `src` replaced and
  everything else kept: the Go build, the tests, and the wrapper that puts the pinned Chromium, ffmpeg
  and ttyd on VHS's `PATH`.
- nixpkgs builds VHS with `-X=main.Version=${finalAttrs.version}`, so the new `version` is also what
  `vhs --version` reports.
- `vendorHash`, the hash of the Go dependencies, is left alone on purpose: `go.mod` and `go.sum` are
  identical in both releases.
- The outer parentheses matter. In a Nix list, elements are separated by spaces, so without them
  `vhs.overrideAttrs` and `(old: { … })` would be two elements, both functions, and the rebuild would fail
  because neither is a package.

Nothing in any binary cache matches this derivation, so Nix builds VHS on your machine once: a short Go
build with its tests.

#### How you would have diagnosed it

The symptom is quiet. A render plays the whole tape, prints `Creating …gif...`, exits with status 0,
and the media folder stays empty. Here is the path from that to the override.

1. **Rule out the tape.** `vhs validate` passes (it only parses), so try the smallest tape that can
   render:

   ```bash
   # in a scratch folder, e.g. mkdir -p /tmp/vhs-smoke/out && cd /tmp/vhs-smoke
   cat > smoke.tape <<'EOF'
   Output out/smoke.gif
   Set Shell "bash"
   Type "echo hello"
   Enter
   Sleep 500ms
   Screenshot out/smoke.png
   Sleep 500ms
   EOF
   vhs smoke.tape; echo "exit status: $?"; ls out
   ```

   Keep the last `Sleep`: a `Screenshot` that is the tape's very last command can be lost even on a
   working VHS, which is why every course tape sleeps after each screenshot. With 0.12.0 you get
   `exit status: 0` and an empty `out`, so the problem is VHS, not the tape.
   You can still see it today with nixpkgs' own package, which the override does not touch:

   ```bash
   # in /tmp/vhs-smoke
   nix shell ~/Repos/personal/nix-config#nixosConfigurations.laptop-intel.pkgs.vhs --command vhs --version
   # vhs version 0.12.0
   nix shell ~/Repos/personal/nix-config#nixosConfigurations.laptop-intel.pkgs.vhs --command vhs smoke.tape
   ```

2. **Which version, and what does upstream say?**

   ```bash
   # in ~/Repos/personal/nix-config
   nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.vhs.version          # 0.12.0
   nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.vhs.meta.changelog   # the v0.12.0 release page
   ```

   The releases page lists 0.12.1, which fixes charmbracelet/vhs#787 (the fix is #788). The fix itself
   is three lines, plus a new test. 0.12.0 created a cancellable context under the same name as the one
   it later hands to ffmpeg and the screenshot step, cancelled it when recording stopped, and logged,
   rather than returned, the failure that followed:

   ```diff
   -	ctx, cancel := context.WithCancel(ctx)
   -	ch := v.Record(ctx)
   +	recordCtx, cancel := context.WithCancel(ctx)
   +	ch := v.Record(recordCtx)
   ```

   ```diff
    		out, err := cmd.CombinedOutput()
    		if err != nil {
    			log.Println(string(out))
   +			return fmt.Errorf("render failed: %w", err)
    		}
   ```

3. **Read the recipe you want to change.** `meta.position` names the file and line:

   ```bash
   # in ~/Repos/personal/nix-config
   nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.vhs.meta.position
   # /nix/store/…-source/pkgs/by-name/vh/vhs/package.nix:58
   ```

   Open it read-only (`nvim -R` with that path, without the `:58`). The parts that matter: `src` is a
   `fetchFromGitHub` with `tag = "v${finalAttrs.version}"` and a `hash`, there is a `vendorHash`, and
   `ldflags` passes the version to `main.Version`.

4. **Get the new source hash.**

   ```bash
   # anywhere
   nix flake prefetch github:charmbracelet/vhs/v0.12.1
   # … (hash 'sha256-9O9f/3B42BhhJ5LWNyHrQtaOKwVnAZR309Dvbpx3d4g=')
   ```

   `vendorHash` only changes when the Go dependencies do. Prefetch `v0.12.0` the same way and `diff` the
   two store paths' `go.mod` and `go.sum`: they are identical, so the old `vendorHash` holds. Had they
   differed, the build would have stopped with a hash mismatch and printed the right value after `got:`.

5. **Choose the remedy.**

   | Option | For | Against |
   |---|---|---|
   | A one-off `nix shell` of a newer nixpkgs' `vhs` per recording | No config change | You type it every time, and `just vhs-record` (section 4) would still run 0.12.0 |
   | `just update` | One command | Moves Neovim, every plugin and Claude Code away from the versions this course was written against |
   | Override just `vhs` | One package changes; everything else stays pinned | You must remember to remove it later |

   The config took the third.

#### Check that it is in effect

Before a rebuild, ask what the config would install. This reads `home.packages`, so it includes the
override:

```bash
# in ~/Repos/personal/nix-config
nix eval --raw .#nixosConfigurations.laptop-intel.config.home-manager.users.sam-laptop.home.packages \
  --apply 'ps: builtins.concatStringsSep " " (map (p: p.name) (builtins.filter (p: (p.pname or "") == "vhs") ps))'
# vhs-0.12.1
```

After `just rebuild`, ask the command itself:

```bash
# anywhere
vhs --version                     # vhs version 0.12.1
readlink -f "$(command -v vhs)"   # /nix/store/…-vhs-0.12.1/bin/vhs
```

If it prints `vhs version 0.12.0`, the rebuild with the override has not happened yet, or another `vhs`
comes first on `PATH` ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)).
The final proof is a render that writes files:

```bash
# in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
vhs tapes/07-tree.tape && ls -l media/07-tree/   # the GIF, the MP4 and the PNGs, none of them empty
```

#### When and how to drop it

**When:** as soon as the pinned nixpkgs carries 0.12.1 or later. After a `just update` (or before one,
with `just preview-update`), ask nixpkgs' own package, which the override never changes:

```bash
# in ~/Repos/personal/nix-config
nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.vhs.version
```

While it prints 0.12.0, keep the override: removing it brings back the VHS that renders nothing (checked:
without it, the config installs `vhs-0.12.0`). Once it prints 0.12.1 or later, remove it, or it will hold
you on 0.12.1 while nixpkgs moves on, and keep costing you a local build.

**How:** revert the commit that added it. `git revert` restores the original line exactly, and
`--no-edit` keeps git's `Revert "…"` message instead of opening Zed for it:

```bash
# in ~/Repos/personal/nix-config
git revert --no-edit 47cd1bc
```

The change it makes (also `fixtures/28-going-further/patches/drop-vhs-override.diff`):

```diff
--- a/home/stages/dev.nix
+++ b/home/stages/dev.nix
@@ -48,18 +48,7 @@
     curl
 
     # Terminal recording
-    # Scripted terminal recordings (.tape -> GIF/MP4); wraps its own ttyd + ffmpeg.
-    # 0.12.1, not nixpkgs' 0.12.0: 0.12.0 cancels its own render context, so it
-    # plays a tape, exits 0 and writes no GIF, MP4 or PNG (charmbracelet/vhs#787,
-    # fixed by #788). go.mod is unchanged, so the vendorHash carries over. Drop
-    # the override once the pinned nixpkgs has 0.12.1.
-    (vhs.overrideAttrs (old: {
-      version = "0.12.1";
-      src = old.src.override {
-        tag = "v0.12.1";
-        hash = "sha256-9O9f/3B42BhhJ5LWNyHrQtaOKwVnAZR309Dvbpx3d4g=";
-      };
-    }))
+    vhs       # Scripted terminal recordings (.tape -> GIF/MP4); wraps its own ttyd + ffmpeg
 
     # Security / cloud / infra CLIs
     cosign      # Sigstore container/artifact signing & verification
```

If the lines around it have changed since, `git revert` stops with a conflict; make the edit by hand from
the diff instead. Then `nix-instantiate --parse home/stages/dev.nix`, `just rebuild`, and `vhs --version`
shows nixpkgs' version. Commit message, if you edit by hand:
`chore(dev): drop the vhs override now that nixpkgs ships 0.12.1`.

> **Tip:** an override can also retire itself. Wrap it in a version check, and it becomes plain `vhs` as
> soon as nixpkgs reaches 0.12.1. Today it evaluates to exactly the same derivation as the override
> above (checked); the cost is a slightly harder block to read.
>
> ```nix
>     (if pkgs.lib.versionOlder vhs.version "0.12.1" then
>       vhs.overrideAttrs (old: {
>         version = "0.12.1";
>         src = old.src.override {
>           tag = "v0.12.1";
>           hash = "sha256-9O9f/3B42BhhJ5LWNyHrQtaOKwVnAZR309Dvbpx3d4g=";
>         };
>       })
>     else
>       vhs)
> ```
>
> `dev.nix` receives `pkgs` but not `lib`, hence `pkgs.lib`.

### 4. Tape recipes in the justfile, seen in just-panel

#### See the problem

Nothing is broken; something is missing. Recording the course means typing
`cd docs/NEOVIM-COURSE && vhs …` every time ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md)), and
the command you use most, validation, needs the right list of files too.

#### Decide

- **Where:** they are development tools, so at the end of the `Development` section, after
  `check-playwright` and before the `Fuzzing` banner (justfile:349).
- **Names:** `vhs-validate` and `vhs-record`, so that `/vhs` in just-panel finds both.
- **One parameter:** `vhs-record TAPE` takes the tape's name without folder or extension, `07-tree`.

Three details of `just` matter:

- Each recipe line runs in its own shell, so the `cd` and the `vhs` share one line.
- The comment right above a recipe is its description; `just --list` and just-panel show exactly that line.
- Recipes run in the justfile's directory (the repository root), which is why `cd docs/NEOVIM-COURSE` is
  relative.

#### Make the change

```diff
--- a/justfile
+++ b/justfile
@@ -346,6 +346,14 @@
     echo "  [tool.uv]"
     echo "  constraint-dependencies = [\"playwright==$wheel\"]"
 
+# Validate every Neovim course tape (parse only: no browser, nothing rendered)
+vhs-validate:
+    cd docs/NEOVIM-COURSE && vhs validate tapes/_shared/settings.tape tapes/*.tape
+
+# Render one Neovim course tape into docs/NEOVIM-COURSE/media (e.g. 07-tree)
+vhs-record TAPE:
+    cd docs/NEOVIM-COURSE && vhs tapes/{{TAPE}}.tape
+
 # ============================================================================
 # Fuzzing (Security Testing)
 # ============================================================================
```

Recipe bodies are indented with four spaces, like the rest of the file. Saving the justfile with `<C-s>` is
safe: no formatter or language server handles it, so it is written as typed.

#### Check

No rebuild. `just` reads the justfile every time it runs, and just-panel reads it when it starts.

```bash
# anywhere: JUST_JUSTFILE points every `just` at the nix-config justfile
just --list --unsorted | grep vhs
```

```text
    vhs-validate                        # Validate every Neovim course tape (parse only: no browser, nothing rendered)
    vhs-record TAPE                     # Render one Neovim course tape into docs/NEOVIM-COURSE/media (e.g. 07-tree)
```

```bash
# anywhere
just -n vhs-record 07-tree           # prints the command without running it
just vhs-validate && echo "all tapes parse"
```

`just -n` prints `cd docs/NEOVIM-COURSE && vhs tapes/07-tree.tape`. `just vhs-record` without a name
stops with ``error: recipe `vhs-record` got 0 positional arguments but takes 1``. `just vhs-validate` echoes its
command line; `vhs validate` prints nothing when every tape parses, so the last line is
`all tapes parse`.

#### See them in just-panel

Start `just-panel` in the layout's bottom-right shell. It finds the justfile through `$JUST_JUSTFILE`.
These steps were checked with the JP8 worked example against this justfile:

1. Scroll to the **Development** header: `vhs-validate` and `vhs-record` sit after `check-playwright`,
   just above the **Fuzzing (Security Testing)** header. The banner parser from JP4 put them there
   with no code change.
2. `/`, type `vhs`, `<CR>`: the list title reads `Recipes (filter: vhs)` and only the two remain, under
   their header. The right-hand pane shows each one's description, section and command.
3. On `vhs-validate`, `<CR>`. The panel hands the terminal to `just`: `$ just vhs-validate`, the recipe
   line that `just` echoes, then `[just-panel] exit status: 0` and `Press Enter to return to just-panel`.
   Back in the panel, the status line reads `vhs-validate: exit 0`.
4. On `vhs-record`, `<CR>`: a prompt titled ` just vhs-record ` asks for `TAPE`, marked `required`.
   Type `07-tree` and `<CR>` to render it in the real terminal (it takes a while), or `<Esc>` to cancel.
   After a render, `ls -l docs/NEOVIM-COURSE/media/07-tree/` must list the files, none of them empty.
5. `<Esc>` clears the filter, a second `<Esc>` (or `q`) quits.

Neither recipe uses `sudo` or matches the panel's caution list, so neither asks for confirmation.

#### What else changes

- `just --list` and just-panel list two more recipes. Nothing needs a rebuild.
- Everything below line 349 of the justfile moves down eight lines. [Lesson 09](09-PROJECT-PANE.md)
  quotes line numbers from its live_grep investigation of this file (the sub-section rulers at 706,
  769 and 808, for example): on your machine they are now eight higher. The banners and the method are
  unchanged.
- Tape 09 greps a copy of the repository's justfile. Its anchors match any line number, so it still
  records, but its frames now show the new numbers rather than the ones lesson 09 quotes. Record it
  before this section if you want the two to agree.

#### Commit

`feat(dev): vhs-validate and vhs-record recipes for the Neovim course tapes`. Commit rendered media
separately, if you keep them.

### 5. Bring `docs/NEOVIM-SETUP.md` up to date

#### See the problem

The repo's own Neovim guide predates most of this course. Nothing links to it, but it is the first thing
you would find in `docs/`. What is stale, checked line by line against today's files:

| docs/NEOVIM-SETUP.md | Reality |
|---|---|
| :3-14 two metadata blocks | One block, as in every other doc |
| :30 "Zed remains the default editor (`EDITOR=zed`)" | `EDITOR` and `VISUAL` are `zeditor --wait` (home/stages/dev.nix:75-76) |
| :44-45 stylua and nixfmt as formatters | conform lists neither (neovim.nix:939-957). Lua falls back to its language server; Nix falls back to `nil`, which does run nixfmt ([lesson 22](22-MAKING-THE-CONFIG-YOURS.md), step 7) |
| :48 "exact same binaries" for every server | True for most, but rust-analyzer comes from rustup (neovim.nix:426), and conform's prettier and ruff from `PATH` (:959-964) |
| :59 format on save for six languages | Every filetype: a conform formatter if one is listed, else the language server, 3000 ms (neovim.nix:974-977) |
| :63, :93 `<leader>e` toggles nvim-tree | neo-tree; nvim-tree is not installed (neovim.nix:24, :144) |
| :67-68 git is gitsigns and fugitive | Also Neogit, Diffview and the neo-tree git panel (neovim.nix:34-38, :176-177) |
| :105 `<C-k>` signature help | `<leader>k`; `<C-k>` is window up (neovim.nix:350, :70) |
| :108 `<leader>f` format | `<leader>cf` (neovim.nix:987) |
| :111 `<leader>e` diagnostic float | `<leader>ld` (neovim.nix:358) |
| :137 `` <C-`> `` floating terminal | `<leader>t`, a bottom split; no float and no `open_mapping` (neovim.nix:27, :774-780) |
| :188 "Want AI assistance (Claude integration)" as a reason to use Zed | Claude Code and Codex run inside Neovim too (neovim.nix:40-43, :830-833) |
| :196 `git config core.editor nvim` | `core.editor` is `zeditor --wait` (home/modules/git.nix:21) |
| :217, :227 `:LspInfo`, `:LspRestart` | Neither exists on the pinned Neovim and nvim-lspconfig. Use `:checkhealth vim.lsp` and `:lsp restart` |
| :222 `vim.lsp.get_log_path()` | Deprecated in Neovim 0.12; `vim.lsp.log.get_filename()` replaces it |
| :241 `extraLuaConfig` with `lspconfig.<server>.setup()` | The option is `initLua` (neovim.nix:202), and `setup{}` is deprecated. Servers use the local `lsp(name, opts)` helper (neovim.nix:386-394) |
| :245 a hand-written `vim.keymap.set` | Add to the `keymaps` list so `KEYBINDS.md` stays in sync (neovim.nix:10-22) |
| :338 `QUICK-START.md` | Does not exist |
| missing | The dock layout, `KEYBINDS.md`, the dev layouts (`SUPER + SHIFT/CTRL/ALT + RETURN`), aerial, Neogit, Diffview, toggleterm, Claude Code and Codex, and the keys `<leader>b/o/t/gs/gg/gd/gq/gh/cc/cb/cs/co/ld` |

#### Decide

- **Fix the tables:** 18 rows of corrections, and the same drift the next time a key moves.
- **Shrink it to a guide** that says where the config lives, how to change a binding, and that
  `~/.config/nvim/KEYBINDS.md` is the key reference. It cannot drift again, because the generated file
  does the job the hand-kept tables failed at. The config says the same about the hand-kept Hyprland
  cheat sheet (neovim.nix:14-17).

The second is recommended, and it is what follows.

#### Make the change

Replace the whole file with this (the date is the day you do it):

````markdown
# Neovim Configuration

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Neovim runs alongside Zed. Both editors use the same language servers and
formatters, and Zed stays the default editor: `EDITOR`, `VISUAL` and git's
`core.editor` are all `zeditor --wait`.

This guide says where the configuration lives and how to change it. It keeps no
key tables: `~/.config/nvim/KEYBINDS.md` is generated from the configuration on
every rebuild, so it cannot drift. To learn the editor itself, work through the
[keyboard-first Neovim course](NEOVIM-COURSE/README.md).

## Where things live

| What                                      | Where                                                      |
| ----------------------------------------- | ---------------------------------------------------------- |
| The Neovim configuration                  | `home/modules/neovim.nix`                                  |
| Every global key binding                  | the `keymaps` list at the top of `home/modules/neovim.nix` |
| The key reference                         | `~/.config/nvim/KEYBINDS.md`, generated from that list     |
| Language servers and formatters on `PATH` | `modules/software/development.nix`                         |
| Zed's settings                            | `home/modules/editor.nix`                                  |

## Start Neovim

| How                      | What you get                                                              |
| ------------------------ | ------------------------------------------------------------------------- |
| `nvim <file>`            | Neovim on that file                                                       |
| `nvim`                   | The dock layout: the file tree on the left, a terminal along the bottom   |
| `SUPER + SHIFT + RETURN` | The nix-config layout on workspace 2: Neovim, `KEYBINDS.md` and a shell   |
| `SUPER + CTRL + RETURN`  | Pick a repository, then the same layout on a free workspace from 3 to 5   |
| `SUPER + ALT + RETURN`   | Neovim with the dock layout in a new Kitty window, in your home directory |

`vi`, `vim` and `vimdiff` start Neovim too. On laptop-intel, a new Kitty window
opens on workspace 10 (`SUPER + 0`) unless a layout places it.

## Keys

Leader is Space. Press it and wait: which-key lists every key that can follow,
with its description. `~/.config/nvim/KEYBINDS.md` lists every global key,
grouped as in the configuration, and the dev layout shows it in its top-right
pane. The keys that only exist where a language server is attached, such as
`gd`, `K` and `<leader>ca`, are listed there too.

## Change a key binding

1. Edit the `keymaps` list in `home/modules/neovim.nix`. Each entry has a
   `group`, an `lhs`, an `rhs` and a `desc`, and optionally a `mode` (`"n"`
   when left out).
2. Save with `:noautocmd w`. A plain `:w` lets the Nix language server reformat
   the whole file with nixfmt.
3. Check the syntax: `nix-instantiate --parse home/modules/neovim.nix`.
4. Run `just rebuild`, then restart Neovim.
5. Check the result with `:verbose nmap <lhs>`, the which-key popup and
   `KEYBINDS.md`.

A binding that needs a Lua function is written by hand next to `<leader>cf` at
the end of `initLua`, and gets a `docOnly = true` entry in the list so the
reference still shows it. The language-server keys are set in the `LspAttach`
callback and have `docOnly` entries too.

## Add a language server

Add the package to `modules/software/development.nix`, so Zed finds it as well,
then enable it in `initLua` with the local `lsp(name, opts)` helper, which calls
`vim.lsp.config` and `vim.lsp.enable`. The Nix server's line is an example:

```lua
lsp('nil_ls', { cmd = { '${pkgs.nil}/bin/nil' } })
```

nvim-lspconfig supplies each server's defaults, and the options you pass are
merged over them.

## When a language server misbehaves

| Command                                         | What it does                                                   |
| ----------------------------------------------- | -------------------------------------------------------------- |
| `:checkhealth vim.lsp`                          | The enabled configurations, the attached clients, the log path |
| `:lsp restart`                                  | Restarts the servers attached to the current buffer            |
| `:lua vim.cmd.edit(vim.lsp.log.get_filename())` | Opens the LSP log                                              |
| `:ConformInfo`                                  | Shows which formatter runs on save for the current buffer      |

## Learn it

- The [keyboard-first Neovim course](NEOVIM-COURSE/README.md) teaches this
  configuration key by key.
- `:Tutor` inside Neovim is the built-in tutorial.
````

The tables are already aligned the way prettier aligns them, so format-on-save (conform runs prettier on
Markdown) leaves the file exactly as it is. Every command in it was checked on the real config:
`:LspInfo` and `:LspRestart` do not exist there, `:lsp restart` and `vim.lsp.log.get_filename()` do.

**Do it in Neovim.** Two ways, both keyboard only:

- **Type it**, as a last Insert-mode workout: `:e docs/NEOVIM-SETUP.md`, `ggdG` to empty the buffer, then
  write it section by section. Tables need not be aligned as you type: saving with `:w` runs prettier,
  which aligns them for you.
- **Read in the finished copy**: `:e docs/NEOVIM-SETUP.md`, `:%d`, then
  `:0r docs/NEOVIM-COURSE/fixtures/28-going-further/NEOVIM-SETUP.md` and `:$d` (the empty line `:%d`
  left behind). Then read it through before you save, and change what you disagree with.

#### Check

```bash
# in ~/Repos/personal/nix-config (after :w)
git diff --stat                    # 1 file changed, 80 insertions(+), 324 deletions(-)
diff docs/NEOVIM-SETUP.md docs/NEOVIM-COURSE/fixtures/28-going-further/NEOVIM-SETUP.md && echo same
ls docs/NEOVIM-COURSE/README.md    # the link target exists
```

The `diff` prints nothing (and `same`) when your file matches the finished copy; differences you made on
purpose show up there. Save a second time with `:w`: `git diff --stat` must not change, which proves
prettier has nothing left to do.

#### Commit

`docs(nvim): replace the stale NEOVIM-SETUP.md with a short guide that cannot drift`

## Gotchas in this config

- **`[h` lands on the last line of the hunk.** gitsigns moves backwards to a hunk's end, forwards to its
  start. On a long hunk that looks like a skip; it is not.
- **Space g r discards without asking.** It edits the buffer, so `u` brings the change back until you
  save; after a save, only git can.
- **New files have no signs.** gitsigns' `attach_to_untracked` defaults to false, so `]h` finds nothing in
  a file git does not track yet. `git add` it first.
- **The Visual stage map is `x` mode.** `:verbose vmap <leader>ga` finds it, but `:verbose smap` does not,
  on purpose. Use `V`, not a snippet's Select mode, to pick lines.
- **Alt keys are Terminal mode only.** In Normal mode an unmapped `Alt+j` acts like `<Esc>` then `j`, so it
  moves the cursor, not the window; `<C-h/j/k/l>` still move between windows there.
- **Never map `<Esc>` in Terminal mode.** Claude and Codex need it to interrupt, rewind and edit, and
  full-screen programs need it too.
- **The VHS override is not forever.** Drop it once `nix eval --raw
  .#nixosConfigurations.laptop-intel.pkgs.vhs.version` prints 0.12.1 or later, and not before.
- **A Screenshot as a tape's last command can be lost.** End every tape with a `Sleep` after its last
  `Screenshot`, as the course's tapes do.
- **Save Nix files with `:noautocmd w`.** Markdown and the justfile can be saved normally: prettier
  leaves the new guide alone, and nothing formats a justfile.

## Drills

1. Why `]h` rather than the gitsigns README's `]c`?
   <details><summary>Answer</summary>

   `]c` and `[c` are Neovim's diff-mode "next/previous change", used in Claude's diff review, in
   `:Gvdiffsplit` and in Diffview. `]h` is free: which-key's `]` popup lists no `h`.
   </details>

2. Why is the Visual-mode stage map `":Gitsigns stage_hunk<CR>"` and not `"<cmd>Gitsigns stage_hunk<CR>"`?
   <details><summary>Answer</summary>

   A `<Cmd>` map never enters Command-line mode, so the selection's range is not passed. With `:`, Neovim
   inserts `'<,'>` for you and gitsigns stages only the selected lines.
   </details>

3. You pressed Space g r on the wrong hunk. What now?
   <details><summary>Answer</summary>

   `u`. Resetting a hunk edits the buffer like any other change. If you had already saved, the change is
   gone from the file too; only an earlier commit or stash would still have it.
   </details>

4. Why is the Terminal-mode rhs `<Cmd>wincmd k<CR>` and not `<C-\><C-n><C-w>k`?
   <details><summary>Answer</summary>

   `<Cmd>wincmd k<CR>` moves without leaving Terminal mode first, so toggleterm's `persist_mode` brings
   the terminal back in Terminal mode. The `<C-\><C-n>` form leaves it in Normal mode.
   </details>

5. After a `just update`, `vhs --version` still says 0.12.1. Has nixpkgs caught up?
   <details><summary>Answer</summary>

   You cannot tell from `vhs --version`: the override pins 0.12.1 whatever nixpkgs has. Ask nixpkgs'
   own package with `nix eval --raw .#nixosConfigurations.laptop-intel.pkgs.vhs.version`. If it prints
   0.12.1 or later, drop the override.
   </details>

6. Why does the override leave `vendorHash` alone, and what would you see if that were wrong?
   <details><summary>Answer</summary>

   `vendorHash` covers the Go dependencies, and `go.mod`/`go.sum` are identical in 0.12.0 and 0.12.1. If
   they had changed, the build would stop with a hash mismatch and print the correct hash after `got:`.
   </details>

7. You added `vhs-validate` but just-panel does not list it. Name two likely reasons.
   <details><summary>Answer</summary>

   just-panel only reads the justfile when it starts, so restart it. Or the recipe is malformed, for
   example a body line indented with a tab among lines indented with spaces, and `just` rejects the
   whole file (`error: recipe line has inconsistent leading whitespace`): run `just --list` in the
   shell and read the error.
   </details>

8. Why replace the key tables in `NEOVIM-SETUP.md` with a pointer to `KEYBINDS.md`?
   <details><summary>Answer</summary>

   A hand-kept table drifts every time a key changes, which is how the old guide ended up describing
   nvim-tree and `<C-k>`. `KEYBINDS.md` is generated from the same list that defines the keys, so it is
   always right.
   </details>

## Recap

- gitsigns keys: `]h`/`[h` between hunks, Space g p/a/r/b to preview, stage (or unstage), reset and
  blame, and Space g a in Visual mode for part of a hunk. `]h` because `]c` is diff mode's, `<leader>g…`
  because `<leader>h` is already an action.
- Terminal-mode window keys: `Alt+h/j/k/l` with `<Cmd>wincmd`, because `<Esc>` and `<C-h/j/k/l>` belong to
  the programs inside, and `wincmd` keeps Terminal mode for when you come back.
- The VHS override: `overrideAttrs` with a new `version` and `src`, the old `vendorHash`, found by a
  smoke tape, `vhs --version`, the upstream release and `meta.position`. Check it with `vhs --version`,
  drop it with `git revert 47cd1bc` once nixpkgs' own `vhs.version` reaches 0.12.1.
- Justfile recipes appear in `just --list` and just-panel with no rebuild and no code change; the comment
  above a recipe is its description.
- A generated reference beats a hand-kept one: `NEOVIM-SETUP.md` now points at `KEYBINDS.md`.

### Where to go next

- **Keep the references open.** [Appendix A](../appendices/A-CHEATSHEET.md) for every binding,
  [Appendix C](../appendices/C-TROUBLESHOOTING.md) when something misbehaves, and
  [Appendix B](../appendices/B-RECORDING-WITH-VHS.md) to record the course's media.
- **Read Neovim's own manual.** `:help user-manual`, then the pages behind this course's traps:
  `:help map-precedence`, `:help map-ambiguous`, `:help CTRL-I`, `:help terminal-input`,
  `:help lsp-defaults`.
- **More changes in the same spirit**, each one a turn of lesson 22's loop:
  - Add list entries for the Claude commands that have no key: `:ClaudeCodeDiffAccept`,
    `:ClaudeCodeDiffDeny`, `:ClaudeCodeTreeAdd`. `<leader>cy`, `<leader>cn` and `<leader>ct` are free in
    the `+code / AI` group. Diffview takes `<leader>ct` inside its own tab, so run the key checklist before
    you choose.
  - Decide whether Nix files should format on save at all. Today `nil` runs nixfmt over the whole file,
    which is why Part 8 saves with `:noautocmd w`.
  - Make `[d`/`]d` honour a count again. The `LspAttach` maps at neovim.nix:353-354 hard-code
    `count = ±1` and pass `float = true`, which Neovim 0.12 deprecates in favour of `on_jump`.
  - If you skipped the optional Hyprland keys in lessons [17](17-JUST-PANEL-TESTING-AND-SHIPPING.md)
    (`SUPER + X` for just-panel) and [21](21-SESSION-BROWSER-TESTING-AND-SHIPPING.md) (`SUPER + A` for
    session-browser), add them now. On the unmodified config, `SUPER` plus `A`, `G`, `I`, `N`, `O`, `U`,
    `X` or `Y` is free (config/hypr/60-keybinds.lua).
  - The hand-kept `config/hypr/KEYBINDS.md` has drifted too. Either bring it up to date, or generate it
    the way `neovim.nix` generates Neovim's.

## Recording

- **Tape:** `tapes/28-going-further.tape`, section 1 only. Run it from `docs/NEOVIM-COURSE` with
  `vhs tapes/28-going-further.tape` (or `just vhs-record 28-going-further` after section 4).
- **Record it after section 1**: the gitsigns keys in the list, `just rebuild` done, and vhs started from
  a fresh shell. On the config without them, `]h` and Space g p do nothing and the first `Wait+Screen`
  after them times out. Record tape 05 **before** section 1 ([lesson 22](22-MAKING-THE-CONFIG-YOURS.md),
  step 10).
- **VHS version:** `vhs --version` must print 0.12.1
  ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)).
- **Repository:** not read or written. The hidden setup builds a throwaway repository in
  `/tmp/nvim-course/28-going-further` from `fixtures/28-going-further/v1` (committed with the demo
  identity `Course Demo <demo@example.invalid>`) and `v2` (copied over it). It has no remote. The tape
  points `CLAUDE_CONFIG_DIR` at a throwaway folder, opens no terminal and shows no register, so nothing
  private can appear. Sections 2 to 5 are not recorded: Alt keys, a rebuild, the VHS diagnosis and
  just-panel runs are described in text.
- **Outputs**, all in `media/28-going-further/`:
  - `28-going-further.gif` and `.mp4`: the whole run.
  - `signs.png`: the three hunks' signs, `~`, `_` and `+`.
  - `preview.png`: Space g p's float for hunk 1.
  - `staged.png`: the added hunk after Space g a, its signs turned into the staged bar.
  - `leader-g.png`: the `+git` popup with `a`, `b`, `p` and `r`.
  - `verbose.png`: `:verbose nmap ]h` at its hit-enter prompt.
- **Manual steps:** none.
- **Check after rendering:**
  1. `ls -l media/28-going-further/` lists the GIF, the MP4 and all five PNGs, none of them empty.
  2. `preview.png` shows `Hunk 1 of 3` with the old and new comment lines.
  3. In `staged.png` the added lines carry a thin bar instead of `+`.
  4. The rest of [Appendix B's checklist](../appendices/B-RECORDING-WITH-VHS.md#checklist-for-every-recording).
