# Lesson 23 — Fix: jump forward again

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Since [lesson 02](02-MOTIONS.md) you have walked back through the jumplist with `<C-o>` and never forward,
because `<C-i>` switches buffers instead. This lesson finds out why a map on `<Tab>` also answers for `<C-i>`,
adds one line to the `keymaps` list that gives `<C-i>` its own job, and proves it: in Kitty, `<C-i>` jumps
forward again while `<Tab>` still cycles buffers. It is the first full pass through the change loop from
[lesson 22](22-MAKING-THE-CONFIG-YOURS.md), on the smallest possible edit, so the loop itself is what you learn.

**Part**: 8 — Making the config yours · **Time**: ~40 min · **Previous**: [Lesson 22 — Making the config yours](22-MAKING-THE-CONFIG-YOURS.md) · **Next**: [Lesson 24 — Fix: a counted terminal toggle](24-FIX-COUNTED-TERMINAL-TOGGLE.md)

## Objectives

By the end of this lesson you can:

- show the problem in two keys and explain it from Neovim's own rule for `<Tab>` and `<C-i>`;
- choose between mapping `<C-i>` explicitly and giving `<Tab>` back, knowing what each costs;
- write a `keymaps` entry that must be generated, not `docOnly`, and say why;
- save a change to `neovim.nix` without Neovim reformatting the whole file;
- verify the fix with `:verbose nmap`, the keys themselves, `KEYBINDS.md` and which-key, and explain the one
  place which-key gets it wrong;
- test a Kitty-only key where the terminal cannot send it, with `nvim_input`.

## Before you start

- **Lesson 22 is done.** You know the change loop: edit, check the syntax, `just rebuild`, restart Neovim,
  verify, commit. This lesson runs it once, slowly.
- **A clean tree** on the branch you use for config changes (lesson 22):

  ```bash
  # in ~/Repos/personal/nix-config
  git status          # expect: nothing to commit, working tree clean
  ```

- **Kitty on laptop-intel.** The fix only shows in a terminal that can tell `Tab` from `Ctrl+I`. Kitty can;
  tmux cannot (step 2 explains). Work in Kitty directly, not inside tmux.
- **A practice copy.** Two small Markdown files, so no language server gets in the way:

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  rm -rf /tmp/nvim-course/23-fix-jump-forward && mkdir -p /tmp/nvim-course/23-fix-jump-forward
  cp -r fixtures/23-fix-jump-forward/. /tmp/nvim-course/23-fix-jump-forward
  ```

  `jumps.md` is 80 lines long, so its first and last lines never share a screen. `other.md` is the second
  buffer that `<Tab>` switches to.

## Keys in this lesson

| Keys | Mode | Action | Where it comes from |
|---|---|---|---|
| `G` | n | Last line; a jump, so it is recorded in the jumplist | Neovim default |
| `<C-o>` | n | Back to the previous jumplist position | Neovim default |
| `<C-i>` | n | Forward in the jumplist. Before this lesson it runs `:bnext` | Neovim default; after step 4 also config (neovim.nix:63) |
| `<Tab>` / `<S-Tab>` | n | Next / previous buffer | config (neovim.nix:61, :62) |
| `:verbose nmap {lhs}` | command | Show a Normal-mode map, its description and where it was set | Neovim default |
| `:lua vim.api.nvim_input('<C-i>')` | command | Send `<C-i>` exactly as Neovim's terminal UI does when Kitty reports `Ctrl+I` | Neovim default (API) |
| `:WhichKey n` | command | which-key's list of every Normal-mode key | which-key default |
| `:noautocmd w` | command | Save without running autocommands, so format-on-save stays out | Neovim default |
| `:exe "normal! 1\<C-i>"` | command | Lesson 02's workaround: jump forward without the key | Neovim default |

## Walkthrough

The recording is made after the fix. It shows step 6: the new map, `<C-i>` jumping forward, `<Tab>` still
switching buffers, and the new `KEYBINDS.md` row.

![After the fix: :verbose nmap <C-i>, a jump forward, <Tab> still next buffer, and the KEYBINDS.md row](../media/23-fix-jump-forward/23-fix-jump-forward.gif)

[MP4](../media/23-fix-jump-forward/23-fix-jump-forward.mp4)

### 1. See the problem

**Try it.** In Kitty:

```bash
# in /tmp/nvim-course/23-fix-jump-forward
nvim jumps.md other.md
```

1. `G`: the cursor lands on line 80, "This is the bottom of the file."
2. `<C-o>`: back to line 1, "# Jumplist practice". The jump is remembered, so there is a forward step.
3. `<C-i>`: in stock Neovim you would be back on line 80.

**What you see instead:** `other.md` opens ("# The other buffer") and the bufferline highlights it. `<C-i>` ran
`:bnext`. Press `<S-Tab>` to return to `jumps.md`.

Now ask Neovim about the two keys:

```vim
:verbose nmap <C-i>
```

```text
No mapping found
```

```vim
:verbose nmap <Tab>
```

```text
n  <Tab>       * <Cmd>bnext<CR>
                 Next buffer
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

So `<C-i>` has no map of its own, and yet it runs the `<Tab>` map. Step 2 explains how both are true.

> **Tip:** not in Kitty, or inside tmux? `:lua vim.api.nvim_input('<C-i>')` sends `<C-i>` the way Neovim's own
> terminal UI does when Kitty reports `Ctrl+I`: the UI hands every key to the editor through `nvim_input`, with
> modified keys written as `<C-…>` (src/nvim/tui/input.c:207 in Neovim 0.12.5). Run it after `G` and `<C-o>`:
> today it opens `other.md`, exactly like the key in Kitty. Pressing `Ctrl+I` in tmux proves nothing, because
> tmux sends a plain Tab.

### 2. Why it happens

Three facts, in order.

**The config maps only `<Tab>`.** neovim.nix:61:

```nix
    { group = "Buffers"; lhs = "<Tab>";      rhs = "<cmd>bnext<CR>";     desc = "Next buffer"; }
```

`renderKeymap` (neovim.nix:80-85) turns it into this line of the generated `init.lua`:

```lua
vim.keymap.set('n', '<Tab>', '<cmd>bnext<CR>', { desc = 'Next buffer', noremap = true, silent = true })
```

**Old terminals send one byte for both keys.** `Tab` and `Ctrl+I` are both byte 9 in the traditional
encoding. At start-up Neovim asks the terminal whether it supports a richer one, the kitty keyboard protocol
("CSI u"), and switches it on if it does (`:help tui-csiu`). Kitty does, so in Kitty `Ctrl+I` reaches Neovim
as its own key, `<C-I>`, and `Tab` as `<Tab>`.

**Neovim only keeps them apart if both are mapped.** `:help CTRL-I` (runtime/doc/motion.txt:1068-1072):

```text
NOTE: In the GUI and in a terminal supporting
|tui-modifyOtherKeys| or |tui-csiu|, CTRL-I can be
mapped separately from <Tab>, on the condition that
both keys are mapped, otherwise the mapping applies to
both. Except in tmux: https://github.com/tmux/tmux/issues/2705
```

Only `<Tab>` is mapped, so the map applies to both, and `<C-i>` runs `:bnext` even though Kitty delivered it
as a separate key. `:verbose nmap` lists maps by the name they were created with, which is why it finds
nothing under `<C-i>`.

The fix follows from the rule: map `<C-i>` too. One more fact tells you what that fix cannot do. Neovim's
`:help vim-differences` (runtime/doc/vim_diff.txt:652-653) says "Creating a mapping for a simplifiable key
(e.g. `<C-I>`) doesn't replace an existing mapping for its simplified form (e.g. `<Tab>`)". A terminal that
sends byte 9 for both keys, like tmux or the VHS recorder, keeps getting `:bnext` for both, fix or no fix.

### 3. Decide

| Option | What you get | What it costs |
|---|---|---|
| **A. Map `<C-i>` explicitly** (the edit below) | `<Tab>` stays "next buffer", and `<C-i>` jumps forward in Kitty | Nothing changes in tmux or in recordings, where both keys are byte 9 |
| B. Give `<Tab>` back | Delete the `<Tab>` and `<S-Tab>` entries (neovim.nix:61-62) and cycle buffers with `]b` / `[b`, Neovim's own defaults since 0.11. Then `<Tab>` and `<C-i>` both jump forward, in every terminal | Two keys instead of one to change buffer, and every lesson from [08](08-FILE-PANE.md) on uses `<Tab>` |
| C. Leave it | Nothing to do | Keep using lesson 02's `:exe "normal! 1\<C-i>"`, or jump again instead of forward |

**Recommendation: A.** You use Kitty every day, and `<Tab>` for buffers is in your fingers by now.

Every field of the new entry is a decision too:

- **`lhs = "<C-i>"`**, the key you are separating from `<Tab>`.
- **`rhs = "<C-i>"`**, a key mapped to itself. That looks circular, but `renderKeymap` always adds
  `noremap = true` (neovim.nix:85). A non-recursive map does not look its right-hand side up in the map table
  again, so the rhs runs Neovim's built-in `CTRL-I`: jump forward.
- **No `mode`.** `mode` defaults to `"n"` (neovim.nix:82), and that is right: `<Tab>` is only mapped in Normal
  mode, so Visual and Operator-pending mode never lost `<C-i>`.
- **Not `docOnly`.** A `docOnly` entry is filtered out before any Lua is written (neovim.nix:78) and only
  documents a key defined elsewhere. Here the map itself is the fix, because Neovim separates the two keys only
  when both are mapped. A `docOnly` row would list "Jump forward" in `KEYBINDS.md` for a key that still ran
  `:bnext`.
- **`group = "Buffers"`, right after `<S-Tab>`.** `KEYBINDS.md` prints one table per group, in the order the
  groups first appear, with the rows in list order (neovim.nix:89-97). Next to `<Tab>` the row explains itself.
  A new group such as "Jumps" would give a table with one row.
- **`desc = "Jump forward (jumplist)"`**, short, and it names the list so nobody reads it as a buffer key.

### 4. Make the change

Open the file in the dev layout's Neovim (`SUPER + SHIFT + RETURN`): Space f f (`<leader>ff`), type
`neovim.nix`, move to `home/modules/neovim.nix` with `<C-n>` if it is not already selected, and `<CR>`. Then
`:62` and `<CR>` puts you on the `<S-Tab>` entry. Press `yyp` to copy it below itself and edit the
copy until it reads like the added line here. The diff is against the file as it is today:

```diff
--- a/home/modules/neovim.nix
+++ b/home/modules/neovim.nix
@@ -60,6 +60,7 @@
 
     { group = "Buffers"; lhs = "<Tab>";      rhs = "<cmd>bnext<CR>";     desc = "Next buffer"; }
     { group = "Buffers"; lhs = "<S-Tab>";    rhs = "<cmd>bprevious<CR>"; desc = "Previous buffer"; }
+    { group = "Buffers"; lhs = "<C-i>";      rhs = "<C-i>";              desc = "Jump forward (jumplist)"; }
     { group = "Buffers"; lhs = "<leader>x";  rhs = "<cmd>bdelete<CR>";   desc = "Close buffer"; }
     { group = "Buffers"; lhs = "<C-s>";      rhs = "<cmd>w<CR>";         desc = "Save"; }
     { group = "Buffers"; lhs = "<C-q>";      rhs = "<cmd>q<CR>";         desc = "Quit"; }
```

**Save with `:noautocmd w`**, not `<C-s>`. `<C-s>` and `:w` run conform's format-on-save, conform falls back to
the Nix language server for Nix files, and the pinned `nil` formats with nixfmt: it rewrites the whole file,
1003 lines becoming 1217, and the `keymaps` list loses its columns. `:noautocmd w` skips the autocommand that
runs the formatter. Check that only your line changed:

```bash
# in ~/Repos/personal/nix-config
git diff --stat     # expect: 1 file changed, 1 insertion(+)
```

If you already saved with `<C-s>`, press `u` once in Neovim (it undoes the formatting and keeps your edit),
then `:noautocmd w`.

The new entry renders to this line of `init.lua`, placed right after the `<S-Tab>` map:

```lua
vim.keymap.set('n', '<C-i>', '<C-i>', { desc = 'Jump forward (jumplist)', noremap = true, silent = true })
```

and to one new row in the Buffers table of `KEYBINDS.md`:

```markdown
| `<C-i>` | Jump forward (jumplist) |
```

### 5. Check and rebuild

```bash
# in ~/Repos/personal/nix-config
nix-instantiate --parse home/modules/neovim.nix > /dev/null && echo OK
just rebuild
```

`OK` means the file parses. `just rebuild` asks for your sudo password and regenerates `init.lua` and
`KEYBINDS.md`. A running Neovim keeps its old maps, so restart it as lesson 22 shows (quit Neovim, close the
dev layout's other two windows, `SUPER + SHIFT + RETURN` again).

### 6. Verify

Reopen the practice files in Kitty:

```bash
# in /tmp/nvim-course/23-fix-jump-forward
nvim jumps.md other.md
```

**The map.** `:verbose nmap <C-i>` and `<CR>`:

```text
n  <C-I>       * <Tab>
                 Jump forward (jumplist)
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

Neovim writes the key as `<C-I>`. It prints the rhs as `<Tab>` because the rhs is stored as byte 9, the byte
`Tab` and `Ctrl+I` share. The `*` is what matters: non-recursive, so that `<Tab>` is the built-in `CTRL-I`, not
your `<Tab>` map. `:verbose nmap <Tab>` still shows `<Cmd>bnext<CR>`, "Next buffer", exactly as in step 1.

![:verbose nmap <C-i> showing the new map: <C-I>, *, <Tab>, "Jump forward (jumplist)"](../media/23-fix-jump-forward/verbose-c-i.png)

**The keys.** Press `<CR>` to leave the listing, then:

1. `G`, `<C-o>`, `<C-i>`: you land on line 80 again, "This is the bottom of the file."
2. `<Tab>`: `other.md`, as before. `<S-Tab>` takes you back.
3. A count works too: `gg`, `40G`, `G`, then `<C-o>` twice (you are on line 1), then `2<C-i>`: two steps
   forward, line 80.

![Back on the last line of jumps.md after G, <C-o> and <C-i>](../media/23-fix-jump-forward/jump-forward.png)

![<Tab> still opens other.md](../media/23-fix-jump-forward/tab-next-buffer.png)

If you are not in Kitty, the step 1 tip still works: `G`, `<C-o>`, then `:lua vim.api.nvim_input('<C-i>')`
now lands on line 80 instead of opening `other.md`. That is also how the recording shows it.

**The reference.** In the dev layout's top-right pane (`KEYBINDS.md` in `less`), or with
`:vsplit ~/.config/nvim/KEYBINDS.md` and `/<C-i>`: the Buffers table has the new row under `<S-Tab>`.

![KEYBINDS.md, Buffers table: the <C-i> row under <Tab> and <S-Tab>](../media/23-fix-jump-forward/keybinds.png)

**which-key.** `<C-i>` is not a prefix, so no popup ever opens for it on its own. `:WhichKey n` lists every
Normal-mode key, and step 7 explains what it shows.

All of step 6 was checked on the real laptop-intel Neovim, built from this config with the edit applied. The
keys were sent with `nvim_input`, the route Kitty's keys take, since a headless check has no Kitty.

### 7. What else changes

- **`KEYBINDS.md`** gains the one row above. Nothing else in it changes.
- **which-key's full list shows `<C-i>` as `<Tab>`.** which-key normalises every key through
  `keytrans(nvim_replace_termcodes(…))` (which-key.nvim `lua/which-key/util.lua:37-42`), and that turns `<C-i>`
  into `<Tab>`. So `:WhichKey n` now has one Tab row that reads "Jump forward (jumplist)", and "Next buffer" is
  no longer in that list. It is display only: `<Tab>` still runs `:bnext`. The popups that open by themselves,
  after Space, `g`, `z`, `[` or `]`, never listed either key. `:checkhealth which-key` reports "No duplicate
  mappings found" before and after.
- **tmux and recordings stay as they were.** Both send byte 9 for both keys, and byte 9 still runs `:bnext`
  (step 2).
- **Earlier lessons describe the old behaviour.** [Lesson 02](02-MOTIONS.md) (step 9, gotcha 1, drill 7) says
  `<C-i>` runs `:bnext`. In Kitty that is now over, and its `:exe "normal! 1\<C-i>"` workaround still works
  anywhere. [Appendix A](../appendices/A-CHEATSHEET.md) and [Appendix C](../appendices/C-TROUBLESHOOTING.md)
  mark the trap and point here.
- **Tapes.** Tape 22 shows `:verbose nmap` listings of the config as the course teaches it, so record it before
  this lesson ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#record-in-this-order)). Tape 02 never presses
  `<C-i>`, and tape 08's `Tab` is byte 9 and still switches buffer: both record the same after the fix.

### 8. Commit

With Neogit ([lesson 12](12-GIT.md)): Space g g (`<leader>gg`), `s` on `home/modules/neovim.nix`, `c` `c`, the
message, `<c-c><c-c>`. Or from the shell:

```bash
# in ~/Repos/personal/nix-config
git add home/modules/neovim.nix
git commit -m "fix(nvim): map <C-i> explicitly so <Tab> no longer eats jumplist-forward"
```

To undo it later: `git revert` the commit and `just rebuild` (lesson 22).

## Gotchas in this config

- **Kitty only.** The fix needs a terminal that reports `Ctrl+I` apart from `Tab`. Kitty does; tmux does not
  (motion.txt:1072), and neither does the VHS recorder. There `<C-i>` stays `:bnext`.
- **`<C-s>` reformats `neovim.nix`.** Format-on-save falls back to `nil`, which formats with nixfmt and rewrites
  the whole file. Save config edits with `:noautocmd w`, and run `git diff --stat` before you commit.
- **`:verbose nmap <Tab>` does not mention `<C-i>`, and before the fix `:verbose nmap <C-i>` finds nothing.**
  Neither listing tells you that one map answers for both keys. Pressing the key does.
- **`docOnly` would not fix anything.** It writes no Lua, so the key stays unmapped and still falls through to
  `<Tab>`.
- **`:WhichKey n` merges the two keys** into one Tab row labelled with the `<C-i>` description. Trust
  `:verbose nmap` and `KEYBINDS.md`.
- **Restart after the rebuild.** A running Neovim keeps the maps it started with.

## Drills

1. Before the fix, `:verbose nmap <C-i>` said `No mapping found`, yet `<C-i>` switched buffers in Kitty. Explain
   both halves.
   <details><summary>Answer</summary>

   Only `<Tab>` was mapped. By `:help CTRL-I`, Neovim keeps the two keys apart only when both are mapped;
   otherwise the `<Tab>` map applies to both. `:verbose nmap` lists maps by the name they were created with, and
   nothing was created under `<C-i>`.
   </details>

2. Why is the new entry not `docOnly = true`?
   <details><summary>Answer</summary>

   `docOnly` entries are filtered out before any Lua is generated (neovim.nix:78), so no `<C-i>` map would exist.
   The map itself is the fix: only when both keys are mapped does `<C-i>` stop running `<Tab>`'s `:bnext`.
   </details>

3. `rhs = "<C-i>"` maps the key to itself. Why does that not loop, and why does it not run `:bnext`?
   <details><summary>Answer</summary>

   `renderKeymap` adds `noremap = true` to every map. A non-recursive rhs is not looked up in the map table
   again, so it runs the built-in `CTRL-I` (jump forward), neither the `<C-i>` map nor the `<Tab>` map.
   </details>

4. After the fix you open Neovim inside tmux and `<C-i>` still switches buffers. Is the fix broken?
   <details><summary>Answer</summary>

   No. tmux sends a plain Tab (byte 9) for `Ctrl+I`, and byte 9 is the `<Tab>` map. A new `<C-I>` map never
   replaces the existing `<Tab>` map for byte 9 (vim_diff.txt:652-653). Check in Kitty, or with
   `:lua vim.api.nvim_input('<C-i>')`.
   </details>

5. You are on line 1 of `jumps.md`, with `40G` and `G` behind you in the jumplist and two `<C-o>` presses just
   made. What does `2<C-i>` do after the fix?
   <details><summary>Answer</summary>

   It goes two steps forward, to line 80. A count typed before a mapped key applies to the rhs, and the rhs is the
   built-in `CTRL-I`, which takes a count.
   </details>

6. After the fix, `:WhichKey n` shows the Tab row as "Jump forward (jumplist)". Does `<Tab>` jump now?
   <details><summary>Answer</summary>

   No. which-key turns `<C-i>` into `<Tab>` when it builds its list, so the two maps share one row. The maps
   themselves are separate: `:verbose nmap <Tab>` still shows `:bnext`, and pressing `<Tab>` still switches
   buffer.
   </details>

7. You saved your edit with `<C-s>` and `git diff --stat` reports hundreds of changed lines. What happened, and
   what now?
   <details><summary>Answer</summary>

   Format-on-save ran `nil`, which reformatted the whole file with nixfmt. Press `u` once to undo the formatting
   (your edit stays), then save with `:noautocmd w`. `git diff --stat` should now show one insertion.
   </details>

## Recap

- A map on `<Tab>` also answers for `<C-i>` unless `<C-i>` is mapped too (`:help CTRL-I`). Terminals that
  report the keys apart (Kitty) then keep them apart; terminals that send byte 9 for both (tmux, VHS) never can.
- The fix is one generated entry: `{ group = "Buffers"; lhs = "<C-i>"; rhs = "<C-i>"; desc = "Jump forward
  (jumplist)"; }`. It must not be `docOnly`, and its non-recursive rhs runs the built-in `CTRL-I`.
- Save config edits with `:noautocmd w`: `<C-s>` lets `nil` reformat the whole file.
- Verify with `:verbose nmap <C-i>` (`<C-I>  * <Tab>`), the keys in Kitty, the new `KEYBINDS.md` row, and
  `:lua vim.api.nvim_input('<C-i>')` anywhere else.
- which-key's `:WhichKey n` merges the two keys into one row. The maps are still separate.

## Recording

- **Tape:** `tapes/23-fix-jump-forward.tape`. Record it **after** this lesson's fix, rebuilt: it demonstrates the
  verification in step 6, and its first `Wait` fails on a config without the `<C-i>` map. Run it from
  `docs/NEOVIM-COURSE/` on laptop-intel (full configuration):

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  vhs tapes/23-fix-jump-forward.tape
  ```

- **VHS version:** `vhs --version` must print 0.12.1, which the config builds (0.12.0 exits 0 and writes nothing);
  if it prints 0.12.0, `just rebuild` first ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)).
- **Fixture:** `fixtures/23-fix-jump-forward/` (`jumps.md`, `other.md`), copied to
  `/tmp/nvim-course/23-fix-jump-forward` by the hidden setup. The tape also opens your generated
  `~/.config/nvim/KEYBINDS.md`, read-only: it holds only key descriptions. It points `CLAUDE_CONFIG_DIR` at a
  throwaway folder, so claudecode.nvim's lock file never lands in your real `~/.claude/ide`. No terminal is
  opened and no register is shown.
- **How it shows `<C-i>`:** VHS sends byte 9 for both `Tab` and `Ctrl+I`, so it cannot press the key. The tape
  types `:lua vim.api.nvim_input('<C-i>')` instead, which is the route Kitty's `Ctrl+I` takes into Neovim.
- **Outputs:** `media/23-fix-jump-forward/23-fix-jump-forward.gif` and
  `media/23-fix-jump-forward/23-fix-jump-forward.mp4`.

| Screenshot | Shows | Used in |
| --- | --- | --- |
| `media/23-fix-jump-forward/verbose-c-i.png` | `:verbose nmap <C-i>`: `<C-I>`, `*`, `<Tab>`, "Jump forward (jumplist)", the "Last set from" line | step 6 |
| `media/23-fix-jump-forward/jump-forward.png` | after `G`, `<C-o>` and `nvim_input('<C-i>')`: the last line of `jumps.md` | step 6 |
| `media/23-fix-jump-forward/tab-next-buffer.png` | `<Tab>` has opened `other.md` | step 6 |
| `media/23-fix-jump-forward/keybinds.png` | `KEYBINDS.md` on the right, its Buffers table with the `<C-i>` row | step 6 |

- **Manual steps:** none. Park the mouse pointer away from the window, and do not type while it runs.
- **Check each recording:**
  - `media/23-fix-jump-forward/` actually contains the GIF, the MP4 and all four PNGs. An empty folder after a
    run that exited 0 means VHS 0.12.0 did the rendering.
  - `verbose-c-i.png` shows the map, not `No mapping found`. If the tape stopped at that point instead, the fix
    is not in the running config: rebuild, then record again.
  - `jump-forward.png` shows "This is the bottom of the file." in `jumps.md`, and `tab-next-buffer.png` shows
    "# The other buffer".
  - The rest of [Appendix B's checklist](../appendices/B-RECORDING-WITH-VHS.md#checklist-for-every-recording).
