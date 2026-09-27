# Lesson 26 — Fix: a close-buffer key that does not wait

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Since lesson 05 you have typed Space x x "briskly", because `<leader>x` is two things at once: it
closes the buffer, and it is also the start of `<leader>xx` and `<leader>xw`. Neovim waits 300 ms to
see which one you mean, so a pause at the wrong moment closes the buffer you were working in, and
every window showing it goes too. In this lesson you move close-buffer to `<leader>q`. It then runs
the moment you press it, and `<leader>x` becomes a plain diagnostics group that waits for you. You
also learn the general rule behind the trap and how to check that a key is free before you take it.

**Part**: 8 — Making the config yours · **Time**: ~40 min · **Previous**: [Lesson 25 — Fix: pyright's diagnostic mode](25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md) · **Next**: [Lesson 27 — Fix: review Claude's edits in Neovim](27-FIX-CLAUDE-DIFF-REVIEW.md)

## Objectives

By the end of this lesson you can:

- reproduce the `<leader>x` wait and explain it from Neovim's rule for ambiguous maps and which-key's
  rule for a key that is both a map and a group;
- check a candidate key against the config, Neovim's defaults, the which-key groups and plugin windows
  before you take it;
- move close-buffer to `<leader>q`, check the change before the rebuild, rebuild, and verify it with
  `:verbose nmap`, which-key, `:checkhealth which-key` and `KEYBINDS.md`;
- say why the new key still closes every window that shows the buffer, and why a "keep the window"
  map was rejected;
- name the lessons, cheat-sheet rows and recordings that still show `<leader>x`.

## Before you start

- **The change loop.** You have worked through [lesson 22](22-MAKING-THE-CONFIG-YOURS.md): branch,
  edit `home/modules/neovim.nix`, save with `:noautocmd w`, check it, `just rebuild`, restart Neovim,
  verify, commit, and how to go back. This lesson follows that loop step by step.
- **A clean tree and a branch for this change:**

  ```bash
  # in ~/Repos/personal/nix-config
  git status                          # expect: nothing to commit, working tree clean
  git switch -c config/close-buffer-key
  ```

- **Lessons 23 to 25** can be applied or not; this fix does not depend on them. If you applied
  [lesson 23](23-FIX-JUMP-FORWARD.md), its `<C-i>` line sits just above the one you change here, so
  the line numbers below are one higher. Find the line by its text.
- **Recording the course?** Record tapes 00, 05 and 22 **before** this fix: their which-key popups
  and `:verbose nmap` screens show `<leader>x` as the course teaches it
  ([Appendix B, Record in this order](../appendices/B-RECORDING-WITH-VHS.md#record-in-this-order)).
- **A playground.** Three throwaway text files from the course folder, so nothing you care about can
  be closed:

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  L=/tmp/nvim-course/26-fix-close-buffer-key
  rm -rf "$L" && mkdir -p "$L" && cp -r fixtures/26-fix-close-buffer-key/. "$L" && cd "$L"
  nvim -i NONE spec.txt notes.txt todo.txt
  ```

  The bufferline shows `spec.txt`, `notes.txt` and `todo.txt`, and the window shows `spec.txt`. Plain
  text has no language server, so the which-key popup holds only the global maps.

## Keys in this lesson

| Keys | Mode | Action | Where it comes from |
|---|---|---|---|
| `<leader>x` (Space x) | n | Close buffer, 300 ms after you stop typing. Gone after this lesson | config (neovim.nix:63) |
| `<leader>xx` / `<leader>xw` | n | Trouble: all diagnostics / this buffer's diagnostics | config (neovim.nix:55-56) |
| `<leader>q` | n | Close buffer, at once. Added by this lesson | config (neovim.nix:65, once changed) |
| `:bd`, `:bd!` | command | Close the buffer; with `!`, throw its changes away | Neovim default |
| `:e #` | command | Reopen the buffer you just closed (the alternate file) | Neovim default |
| `:noautocmd w` | command | Save without format-on-save, for the Nix file you edit | Neovim default |
| `:verbose nmap {lhs}` | command | List the Normal-mode maps that start with `{lhs}`, with where each was set | Neovim default |
| `:checkhealth which-key` | command | Report keys that are both a map and a prefix ("overlapping keymaps") | which-key default |
| `q{a-z}` | n | Record a macro. Nothing to do with `<leader>q`, which starts with Space | Neovim default |

## Walkthrough

### 1. See the problem

Do this on the config as it is now, in the playground from **Before you start**.

**Try it.** Type Space x in one quick movement, then take your hands off the keyboard.

**What you should see:** after about a third of a second `spec.txt` disappears from the bufferline,
and `notes.txt` fills the window. On the real config, measured from the keys to the buffer being
deleted, that is 302 ms: exactly `timeoutlen`. `:e #` brings `spec.txt` back.

Now the three ways the same two keys behave:

| What you type | What happens |
|---|---|
| Space x, then nothing | `:bdelete` runs after 300 ms |
| Space x x, briskly | Trouble runs. In plain text there are no diagnostics, so you only get the message `No results for **diagnostics**`, and nothing closes |
| Space, wait for the popup, then x | The `+diagnostics` group opens and waits for `x` or `w`. Nothing closes. `<Esc>` leaves it |

Look at the popup while it is open (Space, then wait). It lists `x ➜ +diagnostics`. "Close buffer" is
not in it anywhere, so nothing on screen warns you.

The second half of the trap is what `:bdelete` does to your layout. **Try it:** `:vsplit notes.txt`
(it opens on the right, because `splitright` is on), `<C-h>` back to `spec.txt`, then Space x and
wait. The left window does not go blank: it **closes**, and `notes.txt` fills the screen. Neovim's
`:help :bdelete` says so: "Any windows for this buffer are closed." [Lesson 08](08-FILE-PANE.md)
(step 7) showed the same with `:bd`.

> **Gotcha:** do not try Space q yet. Today it is not mapped, so which-key hands the keys back to
> Neovim: Space moves the cursor one character right and `q` starts recording a macro, waiting for a
> register name. If you did, press `<Esc>`; if the mode line shows `recording @…`, press `q` to stop.

### 2. Why it happens

Four lines of the config meet here:

- `<leader>x` is "Close buffer", `<cmd>bdelete<CR>` (neovim.nix:63);
- `<leader>xx` and `<leader>xw` open Trouble (neovim.nix:55-56);
- which-key labels `<leader>x` as the `diagnostics` group (neovim.nix:848);
- `timeoutlen` is 300 ms (neovim.nix:270).

**Neovim's rule** (`:help map-ambiguous`): "When two mappings start with the same sequence of
characters, they are ambiguous." After Space x Neovim cannot tell whether you meant `<leader>x` or
the start of `<leader>xx`, so it waits up to `timeoutlen` ("time in milliseconds to wait for a mapped
sequence to complete", `:help 'timeoutlen'`) for another key. None comes, so it runs the shorter map.

**which-key's rule.** which-key catches Space first. Its source at the pinned revision
(`lua/which-key/state.lua`, lines 191-192) says: "a node can be both a keymap and a group; when it's
both, we honor timeoutlen and nowait to decide what to do". If `x` arrives within 300 ms of Space,
which-key hands `<Space>x` straight back to Neovim, and Neovim's own 300 ms wait above begins. If `x`
arrives later, which-key goes into the group instead. That is why a brisk Space x closes the buffer
and a slow one does not. The popup takes its label from the group spec before the map, so it shows
`+diagnostics` and never "Close buffer".

which-key knows this is a hazard. `:checkhealth which-key` reports it today:

```text
checking for overlapping keymaps ~
- ⚠️ WARNING In mode `n`, <<Space>x> overlaps with <<Space>xx>, <<Space>xw>:
  - <<Space>x>: diagnostics
  - <<Space>xx>: All diagnostics
  - <<Space>xw>: Buffer diagnostics
```

The same report warns about `gb` and `gc`, Comment.nvim's operators, which are prefixes of `gbc`,
`gcc` and friends by design. Those are information only, and this lesson leaves them alone.

The config even states the rule it breaks. The comment above `<leader>cf` (neovim.nix:983-986) says
that a map "on the prefix itself makes every one of those wait out 'timeoutlen' before firing", which
is why format-buffer is `<leader>cf` and not `<leader>f`. `<leader>x` is the one place the config
forgot its own advice.

The closing windows are a separate matter. They are what `:bdelete` does, whichever key runs it: it
removes the buffer from every window, and a window is only kept, emptied, when the buffer was your
last listed one.

### 3. Decide

Two questions: which key, and which command behind it.

**Which key.** Put each candidate through lesson 22's "is it free?" checks:

| Candidate | Check | Verdict |
|---|---|---|
| `<leader>q` | `:verbose nmap <leader>q` says `No mapping found`. It is not a Neovim default (none of Neovim's defaults start with Space), no pinned plugin defines it, the LSP maps (neovim.nix:350-358) are `<leader>k`, `<leader>rn`, `<leader>ca` and `<leader>ld`, and it is not one of the four which-key groups `f`, `g`, `c`, `x` (neovim.nix:845-848). It is a single key, so it can never wait. "q for quit": `<C-q>` quits the *window*, `<leader>q` the *buffer* | **take** |
| `<leader>bd` | `<leader>b` toggles the buffers panel (neovim.nix:25). `<leader>bd` would make `<leader>b` a map *and* a prefix: the same trap, one key over | reject |
| `<leader>hq` or anything under `<leader>h` | `<leader>h` clears the search highlight (neovim.nix:66): same trap again | reject |
| No key at all | `:bd` always works and never waits | fine if you rarely close buffers |

`<leader>q` is not `q`. The macro key and the `q` that closes plugin windows (Trouble, aerial,
neo-tree, Neogit, `:checkhealth`) are untouched, because every `<leader>` key starts with Space.

**Which command.** [Lesson 08](08-FILE-PANE.md) taught `:bp | bd #` to close a buffer but keep the
window. It is tempting to put that behind the new key as `<cmd>bprevious | bdelete #<CR>`. It was
tried on the real config, and it is not correct as a map:

| Situation | What `bprevious \| bdelete #` did |
|---|---|
| Two buffers, split windows | Fine: the window stays and shows the other buffer |
| The same buffer in two windows | The current window stays, but the other one still closes |
| Your last listed buffer | `:bprevious` stays put, so `#` is some other buffer: `E516: No buffers were deleted`, and nothing closes |
| Unsaved changes | `:bprevious` switches the window away first, then `:bdelete #` refuses with `E89: No write since last change`. The buffer looks closed but is still open, hidden, with your changes |

Plain `:bdelete` fails cleanly on unsaved changes (the buffer stays on screen with `E89`), and it
always closes the buffer you pressed the key in. Keep `<cmd>bdelete<CR>`, and type `:bp | bd #` on the
occasions you want to keep a window.

**Recommendation:** move the existing map, unchanged, from `<leader>x` to `<leader>q`.

### 4. Make the change

One entry in the `keymaps` list moves, and a two-line comment records why, in the same spirit as the
`<leader>cf` comment. Open `home/modules/neovim.nix` (Space f f, type `neovim.nix`), go to line 63
with `:63` (`:64` if lesson 23's `<C-i>` line is in), and edit it to match:

```diff
--- a/home/modules/neovim.nix
+++ b/home/modules/neovim.nix
@@ -60,7 +60,9 @@
 
     { group = "Buffers"; lhs = "<Tab>";      rhs = "<cmd>bnext<CR>";     desc = "Next buffer"; }
     { group = "Buffers"; lhs = "<S-Tab>";    rhs = "<cmd>bprevious<CR>"; desc = "Previous buffer"; }
-    { group = "Buffers"; lhs = "<leader>x";  rhs = "<cmd>bdelete<CR>";   desc = "Close buffer"; }
+    # <leader>q, not <leader>x: <leader>x is the prefix of <leader>xx/<leader>xw,
+    # so a map on it waits out 'timeoutlen' and closes the buffer on a pause.
+    { group = "Buffers"; lhs = "<leader>q";  rhs = "<cmd>bdelete<CR>";   desc = "Close buffer"; }
     { group = "Buffers"; lhs = "<C-s>";      rhs = "<cmd>w<CR>";         desc = "Save"; }
     { group = "Buffers"; lhs = "<C-q>";      rhs = "<cmd>q<CR>";         desc = "Quit"; }
     { group = "Buffers"; lhs = "<leader>h";  rhs = "<cmd>nohlsearch<CR>"; desc = "Clear search highlight"; }
```

The diff is against the file as it is today. With lesson 23 applied, its `<C-i>` line sits between
`<S-Tab>` and the line you change, so the diff no longer applies as a patch; the edit itself is the
same.

The quickest edit: on that line, `0fx` puts the cursor on the `x` of `<leader>x` (it is the first `x`
on the line) and `rq` replaces it. Then `O` opens a line above, where you type the two comment lines,
and `<Esc>`. Neovim indents them like their neighbours and adds no comment leader of its own, so type
the `#` on both lines.

**Save with `:noautocmd w`**, not `<C-s>`: format-on-save would hand the file to `nil`, which
reformats all of it ([lesson 22](22-MAKING-THE-CONFIG-YOURS.md), step 7). Check that only your lines
changed:

```bash
# in ~/Repos/personal/nix-config
git diff --stat     # expect: 1 file changed, 3 insertions(+), 1 deletion(-)
```

If you saved with `<C-s>` by mistake, press `u` once in Neovim (it undoes the formatting and keeps your
edit), then `:noautocmd w`.

**The which-key group stays as it is.** `{ '<leader>x', group = 'diagnostics' }` at neovim.nix:848
is still true: `<leader>xx` and `<leader>xw` are diagnostics. Until now the label hid "Close buffer";
from now on it describes everything under `x`. `<leader>q` is a single key with its own `desc`, so it
needs no group, and the comment above the `wk.add` call (neovim.nix:839-841, "Group labels only")
needs no change either.

### 5. Check and rebuild

Check the syntax first, so a typo does not cost you a rebuild:

```bash
# in ~/Repos/personal/nix-config
nix-instantiate --parse home/modules/neovim.nix > /dev/null && echo OK
```

`OK` means it parses. Then look at what the change will generate before you install it. This
evaluates the `KEYBINDS.md` that Home Manager would write, straight from your working tree:

```bash
# in ~/Repos/personal/nix-config
nix eval --raw '.#nixosConfigurations.laptop-intel.config.home-manager.users.sam-laptop.xdg.configFile."nvim/KEYBINDS.md".text' | grep 'Close buffer'
```

Before the edit it prints ``| `<leader>x` | Close buffer |``; after it, ``| `<leader>q` | Close buffer |``.
Nix may warn that the Git tree is dirty: that only means your edit is not committed yet.

Now rebuild, and give your sudo password:

```bash
# in ~/Repos/personal/nix-config
just rebuild
```

A running Neovim keeps the maps it started with. Quit every Neovim (`:qa`) and start it again; in the
dev layout, close its windows and reopen it with `SUPER + SHIFT + RETURN` so the `less` pane shows
the new `KEYBINDS.md` too ([lesson 22](22-MAKING-THE-CONFIG-YOURS.md) has the details).

### 6. Verify

Recreate the playground from **Before you start** (the commands delete and copy it afresh) and open
the three files again. The recording shows this whole step:

![Lesson 26: :verbose nmap for <leader>q and <leader>x, the Space popup with q Close buffer, the +diagnostics group waiting, and Space q closing spec.txt at once](../media/26-fix-close-buffer-key/26-fix-close-buffer-key.gif)

[MP4](../media/26-fix-close-buffer-key/26-fix-close-buffer-key.mp4)

**`:verbose nmap <leader>q`** and `<CR>`. You should see the new map, set from the generated
`init.lua`:

```text
n  <Space>q    * <Cmd>bdelete<CR>
                 Close buffer
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

Press `<CR>` to dismiss the "Press ENTER" prompt.

![:verbose nmap <leader>q shows <Space>q, <Cmd>bdelete<CR>, Close buffer](../media/26-fix-close-buffer-key/verbose-q.png)

**`:verbose nmap <leader>x`** and `<CR>`. Before the fix it listed three maps, `<Space>x` first. Now
only the two Trouble maps are left:

```text
n  <Space>xw   * <Cmd>Trouble diagnostics toggle filter.buf=0<CR>
                 Buffer diagnostics
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
n  <Space>xx   * <Cmd>Trouble diagnostics toggle<CR>
                 All diagnostics
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

![:verbose nmap <leader>x lists only <Space>xw and <Space>xx](../media/26-fix-close-buffer-key/verbose-x.png)

> **Tip:** typed as above, the listing holds only your maps. Run the same command from a script or a
> plugin and an extra entry can come first:
> `n  <Space>     *@<Lua …: …/which-key.nvim/lua/which-key/triggers.lua:43>`, described
> `which-key-trigger`. That is which-key's own hook on Space (the `@` means buffer-local), not one of
> your maps.

**Space, then wait.** The popup now has a `q` entry beside the `x` group. Icons left out, and the
columns depend on the window width (with [lesson 24](24-FIX-COUNTED-TERMINAL-TOGGLE.md) applied, `t`
reads `Toggle terminal [count]`):

```text
b ➜ Toggle buffer list (left)   q ➜ Close buffer               g ➜ +git
e ➜ Toggle file tree (left)     t ➜ Toggle terminal (bottom)   x ➜ +diagnostics
h ➜ Clear search highlight      c ➜ +code / AI
o ➜ Toggle outline (left)       f ➜ +find
```

![The which-key Space popup with q Close buffer and x +diagnostics](../media/26-fix-close-buffer-key/which-key.png)

**Then x, as slowly as you like.** The `+diagnostics` group opens with `w ➜ Buffer diagnostics` and
`x ➜ All diagnostics`, and `spec.txt` stays where it is. Press `<Esc>`.

![The +diagnostics group waiting, spec.txt still open](../media/26-fix-close-buffer-key/group-waits.png)

**Space x, briskly, then nothing.** The same `+diagnostics` group opens and waits. Nothing closes,
however long you leave it. `<Esc>` again.

**Space q.** `spec.txt` goes at once and `notes.txt` fills the window. `:e #` brings it back.

![After Space q: notes.txt in the window, two buffers left in the bufferline](../media/26-fix-close-buffer-key/closed.png)

**Space x x, briskly.** Trouble runs, exactly as before (`No results for **diagnostics**` in plain
text; a list in a file with problems).

**`:checkhealth which-key`.** Under "checking for overlapping keymaps" the `<Space>x` warning is
gone; the `gb` and `gc` ones remain. `q` closes the health tab.

**The `KEYBINDS.md` pane** in the dev layout: the Buffers table now has the row
``| `<leader>q` | Close buffer |`` where `<leader>x` was.

On the real config, measured the same way as in step 1, Space q deleted the buffer 0 ms after the
keys: there is nothing left to wait for.

### 7. What else changes

- **Generated files.** `~/.config/nvim/KEYBINDS.md` and the generated line in `init.lua` change
  together; nothing else in them moves.
- **which-key.** The Space popup gains `q ➜ Close buffer`. The `+diagnostics` group is unchanged, and
  `:checkhealth which-key` drops its `<Space>x` warning.
- **The windows rule does not change.** Space q runs the same `:bdelete`, so it still closes every
  window showing the buffer. That is the command, not the key.
- **Inside the neo-tree panels.** Space q, like Space x before it, runs `:bdelete` on the panel's own
  buffer, so the panel closes. `<leader>e` or `<leader>b` brings it back.
- **Earlier lessons describe the config as shipped**, and stay that way:
  [lesson 00](00-SETUP-AND-ORIENTATION.md) (the popup gotcha),
  [lesson 05](05-YOUR-KEYBINDINGS.md) (the timing table),
  [lesson 08](08-FILE-PANE.md) (step 7 and its gotchas),
  [lesson 11](11-COMPLETION-FORMATTING-DIAGNOSTICS.md), and the "type Space x w briskly" tips in the
  capstone lessons. The briskness no longer matters: `<leader>xx` and `<leader>xw` cannot close
  anything now. [Appendix A](../appendices/A-CHEATSHEET.md) still lists `<leader>x` as "Close buffer"
  and [Appendix C](../appendices/C-TROUBLESHOOTING.md) still has "Pausing after Space x closed my
  buffer". When the course and your `KEYBINDS.md` pane disagree, trust the pane: it is generated.
- **Recordings.** Tape 00's `which-key.png`, tape 05's `leader.png` and `verbose-x.png`, and tape 22's
  Space popup show the config before this lesson. Record them first
  ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#record-in-this-order)). Tape 24's
  `count-popup.png` is a Space popup too: recorded after this lesson it simply gains the `q` row. Tape
  11 types Space x x in one go and records the same either way. This lesson's own tape needs the fix
  in place.

### 8. Commit

With Neogit, as in [lesson 12](12-GIT.md): Space g g (`<leader>gg`), move to `neovim.nix` and press
`s`, then `c` `c`, write the message and `<c-c><c-c>`. Or from the shell:

```bash
# in ~/Repos/personal/nix-config
git add home/modules/neovim.nix
git commit -m "fix(nvim): move buffer close to <leader>q so <leader>x is only the diagnostics group"
```

Then fold the branch into the one you rebuild from, as lesson 22 does. The tree is the same after the
merge, so no rebuild is needed:

```bash
# in ~/Repos/personal/nix-config
git switch main && git merge --ff-only config/close-buffer-key
```

To undo it later, `git revert` that commit and `just rebuild`.

## Gotchas in this config

1. **Old Neovims keep the old key.** `just rebuild` changes files, not running processes. In a Neovim
   started before the rebuild, Space x still closes a buffer after 300 ms and Space q still starts a
   macro. Restart every Neovim.
2. **Space q before the fix is not harmless.** It moves the cursor one character right and starts
   macro recording (`q`, then the next key names the register). `<Esc>`, and `q` if the mode line
   says `recording @…`.
3. **`:bdelete` closes windows, whichever key runs it.** Every window showing the buffer closes. With
   only the tree left, neo-tree's `close_if_last_window` (neovim.nix:633) quits Neovim
   ([lesson 08](08-FILE-PANE.md)). Type `:bp | bd #` when you want to keep a window.
4. **A closed buffer is one command away.** `:e #` reopens the buffer you just closed and puts it
   back in the bufferline. For an older one, `:ls!` lists closed buffers too (marked `u`, unlisted),
   and `:e {file}` opens it again.
5. **Unsaved changes stop the key.** `E89: No write since last change … (add ! to override)`. Save
   with `<C-s>`, or throw the changes away with `:bd!`. Do not bind `bdelete!` to a key.
6. **`<C-s>` reformats `neovim.nix`.** Save config edits with `:noautocmd w`, and check
   `git diff --stat` before you rebuild.
7. **The course still says `<leader>x` in places.** Lessons 00-21, the cheat sheet, Appendix C and
   the earlier recordings describe the config as shipped. `KEYBINDS.md` is always right.

## Drills

1. Your friend wants close-buffer on `<leader>bd`. What goes wrong, and what does `:checkhealth
   which-key` say after the rebuild?
   <details><summary>Answer</summary>

   `<leader>b` already toggles the buffers panel (neovim.nix:25), so `<leader>b` becomes a map and a
   prefix. Space b then waits 300 ms before it opens the panel, and a pause after Space b opens the
   panel instead of reaching `<leader>bd`. `:checkhealth which-key` would list `<Space>b` under
   "overlapping keymaps", just as it listed `<Space>x`.
   </details>

2. Which of these keys would recreate the trap: `<leader>fq`, `<leader>hq`, `<leader>q`, `<leader>cq`?
   <details><summary>Answer</summary>

   Only `<leader>hq`, because `<leader>h` is an action (clear the search highlight, neovim.nix:66).
   `<leader>f` and `<leader>c` are groups with no action of their own (neovim.nix:845, :847; the
   `<leader>c` group's keys are all two letters long), and `<leader>q` is a single key that nothing
   else starts with.
   </details>

3. After the fix, you type Space x and walk away. Nothing closes. Which part of the system is waiting
   for you now, Neovim or which-key?
   <details><summary>Answer</summary>

   which-key. `<Space>x` is no longer a map, only a group, so which-key goes into the group and shows
   its popup until you press `x`, `w`, `<BS>` or `<Esc>`. There is no map left for Neovim's
   `timeoutlen` to fire.
   </details>

4. Before the fix, `:verbose nmap <leader>q` said `No mapping found`. Why is that not enough on its
   own to call the key free?
   <details><summary>Answer</summary>

   It checks only the current buffer's maps and the global ones at that moment. Maps set when a
   language server attaches, or inside plugin windows, live in other buffers. Run it again in a Rust
   or Python buffer with a server attached, and read the which-key groups (neovim.nix:845-848) and
   Neovim's defaults (`:help default-mappings`) as well.
   </details>

5. Why was `<cmd>bprevious | bdelete #<CR>` rejected as the rhs?
   <details><summary>Answer</summary>

   It fails in two everyday cases. On your last listed buffer, `:bprevious` goes nowhere, so `#` names
   some other buffer and you get `E516: No buffers were deleted`. With unsaved changes, it switches the
   window away and then stops at `E89`, so the buffer looks closed but is still open and modified. It
   also still closes any other window on the same buffer.
   </details>

6. You rebuilt, restarted Neovim and pressed Space q in a file with unsaved changes. What happens,
   and what are your two ways on?
   <details><summary>Answer</summary>

   Nothing closes, and Neovim prints `E89: No write since last change for buffer N (add ! to
   override)`. Save with `<C-s>` and press Space q again, or run `:bd!` to throw the changes away.
   </details>

7. You plan to record the whole course and to keep this fix. In which order?
   <details><summary>Answer</summary>

   Record tapes 00, 05 and 22 first, because their popups and `:verbose nmap` screens show
   `<leader>x`. Then apply this lesson, rebuild and record tape 26. The other tapes are unaffected.
   </details>

## Recap

- `<leader>x` was a map and a prefix. Neovim waits `timeoutlen` (300 ms) on an ambiguous prefix, and
  which-key hands a brisk Space x straight to that wait, so a pause closed the buffer.
- Before you take a key: is it free (`:verbose nmap`, also in an LSP buffer), is it a prefix or does a
  map start it, is it a which-key group, is it taken in plugin windows?
- The fix moves one list entry: `<leader>q` runs `<cmd>bdelete<CR>` at once, and `<leader>x` is only
  the `+diagnostics` group. The which-key group line stays.
- Save with `:noautocmd w`, check with `git diff --stat`, `nix-instantiate --parse` and a `nix eval`
  of `KEYBINDS.md`, then `just rebuild` and restart Neovim.
- Verify with `:verbose nmap <leader>q` / `<leader>x`, the Space popup, `:checkhealth which-key` and
  the `KEYBINDS.md` pane.
- `:bdelete` still closes every window showing the buffer. `:bp | bd #` keeps a window when you type
  it; as a map it misbehaves on the last buffer and on unsaved changes.

## Recording

- **Tape:** `tapes/26-fix-close-buffer-key.tape`. **Record it after the fix**: apply the change,
  `just rebuild`, then render. It shows step 6, so on the old config its first `Wait+Screen` times out
  and VHS writes nothing.
- **Render** from `docs/NEOVIM-COURSE` with VHS 0.12.1, which the config builds
  ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)):
  `vhs tapes/26-fix-close-buffer-key.tape`.
- **Fixture:** `fixtures/26-fix-close-buffer-key/` (`spec.txt`, `notes.txt`, `todo.txt`), copied to
  `/tmp/nvim-course/26-fix-close-buffer-key`. No repository is read or written.
- **Privacy:** `CLAUDE_CONFIG_DIR` points at a throwaway folder, so claudecode.nvim's lock file never
  lands in `~/.claude`. No terminal is opened and no register is shown.
- **Outputs** in `media/26-fix-close-buffer-key/`:
  - `26-fix-close-buffer-key.gif` and `.mp4`: the whole run;
  - `verbose-q.png`: `:verbose nmap <leader>q` at its "Press ENTER" prompt, with `Close buffer`;
  - `verbose-x.png`: `:verbose nmap <leader>x` listing only `<Space>xw` and `<Space>xx`;
  - `which-key.png`: the Space popup with `q ➜ Close buffer` and `x ➜ +diagnostics`;
  - `group-waits.png`: the `+diagnostics` group, opened well after `timeoutlen`, with `spec.txt`
    still in the window and the bufferline;
  - `closed.png`: straight after Space q, `notes.txt` in the window and two buffers in the bufferline.
- **Manual steps:** none. The rebuild needs sudo and is done before recording.
- **Check after rendering:**
  1. `ls -l media/26-fix-close-buffer-key/` lists the GIF, the MP4 and all five PNGs, none of them
     empty.
  2. `group-waits.png` still shows three buffers in the bufferline and `spec.txt` in the window: the
     pause after Space x closed nothing.
  3. `verbose-x.png` has no `<Space>x` line of its own.
  4. The rest of [Appendix B's checklist](../appendices/B-RECORDING-WITH-VHS.md#checklist-for-every-recording).
