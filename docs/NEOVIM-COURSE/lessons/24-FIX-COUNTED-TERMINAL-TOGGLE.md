# Lesson 24 — Fix: a counted terminal toggle

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Since [lesson 06](06-TERMINAL.md) you have typed `:2ToggleTerm` for a second terminal, because `2<leader>t`
throws its count away and closes the dock instead. This lesson follows the count from your fingers to
toggleterm, finds the one place it is lost, and changes one `rhs` so that `2<leader>t` opens terminal 2 while a
bare `<leader>t` keeps its smart toggle. On the way you write a Vimscript expression inside a Nix string that
becomes a Lua string, and see exactly what each layer does to the quotes. You also learn the one surprise the
new key brings: the hidden Codex terminal has a number too.

**Part**: 8 — Making the config yours · **Time**: ~45 min · **Previous**: [Lesson 23 — Fix: jump forward again](23-FIX-JUMP-FORWARD.md) · **Next**: [Lesson 25 — Fix: pyright's diagnostic mode](25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md)

## Objectives

By the end of this lesson you can:

- show that `2<leader>t` loses its count, and explain where and why;
- choose a right-hand side that passes the count on, and rule out the ones that look right but are not;
- write that rhs in the `keymaps` list, with the Nix escaping it needs, and predict the Lua `luaStr` renders;
- pick a description that keeps the which-key popup readable;
- verify the fix with `:verbose nmap`, the keys themselves and `:TermSelect`;
- predict when `N<leader>t` opens the hidden Codex terminal instead of a shell.

## Before you start

- **Lessons 22 and 23 are done.** You have run the change loop once. This lesson runs it again with less
  hand-holding.
- **A clean tree** on your config branch: `git status` in `~/Repos/personal/nix-config` says
  `nothing to commit, working tree clean`.
- **A practice copy.** One Markdown file to come back to from the terminals:

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  rm -rf /tmp/nvim-course/24-fix-counted-terminal-toggle && mkdir -p /tmp/nvim-course/24-fix-counted-terminal-toggle
  cp -r fixtures/24-fix-counted-terminal-toggle/. /tmp/nvim-course/24-fix-counted-terminal-toggle
  ```

- **Codex is optional.** Step 6 opens the hidden Codex terminal with `<leader>co` to show how its number
  interacts with the new key. If you would rather not start Codex, read that part without doing it.

## Keys in this lesson

`<leader>` is Space.

| Keys | Mode | Action | Where it comes from |
|---|---|---|---|
| `<leader>t` | n | Smart toggle of the terminal dock: close every open terminal, or bring them back | config (neovim.nix:27) |
| `N<leader>t` | n | Toggle terminal N, creating it if needed. Only after step 4; before, the same as `<leader>t` | config (neovim.nix:27) |
| `:[N]ToggleTerm` | command | Toggle terminal N; with no N, the smart toggle | toggleterm default |
| `:TermSelect` / `:TermSelect!` | command | Pick a terminal from a numbered list; `!` also lists hidden ones, such as Codex | toggleterm default |
| `:TermNew` | command | Open a terminal with the next free number | toggleterm default |
| `<leader>co` | n | Toggle the hidden Codex terminal | config (neovim.nix:43) |
| `<C-\><C-n>` | t | Leave Terminal mode | Neovim default |
| `<C-k>` | n | Window up | config (neovim.nix:70) |
| `:verbose nmap {lhs}` | command | Show a Normal-mode map, its description and where it was set | Neovim default |
| `:noautocmd w` | command | Save without format-on-save | Neovim default |

## Walkthrough

The recording is made after the fix. It shows step 6: the which-key popup with a count pending, `2` Space t
opening terminal 2 beside terminal 1, `:TermSelect` listing both, the smart toggle, and the new map.

![After the fix: 2 then Space t opens terminal 2 beside terminal 1; :TermSelect lists both; Space t hides both](../media/24-fix-counted-terminal-toggle/24-fix-counted-terminal-toggle.gif)

[MP4](../media/24-fix-counted-terminal-toggle/24-fix-counted-terminal-toggle.mp4)

### 1. See the problem

**Try it.**

```bash
# in /tmp/nvim-course/24-fix-counted-terminal-toggle
nvim notes.md
```

1. Space t: terminal 1 opens across the bottom, in Terminal mode.
2. `<C-\><C-n>`: Normal mode, with the cursor still in terminal 1.
3. `2`, then Space t. You want terminal 2 beside terminal 1.

**What you see instead:** terminal 1 closes, nothing else opens, and the cursor is back in `notes.md`.
`:TermSelect` lists terminal 1 only (press `<CR>` on its empty prompt to cancel). The `2` was ignored and you got
the plain smart toggle, which closes whatever is open. `:2ToggleTerm` does what you wanted.

```vim
:verbose nmap <leader>t
```

```text
n  <Space>t    * <Cmd>ToggleTerm<CR>
                 Toggle terminal (bottom)
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

### 2. Why it happens

Follow the count from the keyboard to toggleterm.

**which-key passes it on.** Space is a which-key trigger: which-key maps `<Space>` itself in each buffer, with
the description `which-key-trigger`. It reads the `t` itself, then replays the keys with `feedkeys` and puts the
pending count in front (which-key.nvim `lua/which-key/state.lua:230-231`):

```lua
    if vim.v.count > 0 and state.mode.mode ~= "i" and state.mode.mode ~= "c" then
      keystr = vim.v.count .. keystr
```

So `2` Space t reaches the `<leader>t` map with its count intact. `:help count-variable` (runtime/doc/vvars.txt:88-91)
describes the variable that holds it: `v:count` is "The count given for the last Normal mode command. Can be
used to get the count before a mapping."

**The `<cmd>` map drops it.** neovim.nix:27:

```nix
    { group = "Panels"; lhs = "<leader>t";  rhs = "<cmd>ToggleTerm<CR>";       desc = "Toggle terminal (bottom)"; }
```

`:help <Cmd>` (runtime/doc/map.txt:357-358) says of these maps: "Command-line mode is never entered". A count
typed before a `:` map turns into a line range when Command-line mode starts. A `<Cmd>` map never starts it, so nothing
carries the `2` into the command, and `:ToggleTerm` runs with no count at all.

**toggleterm treats "no count" as the smart toggle.** It defines `:ToggleTerm` with `count = true`
(toggleterm.nvim `lua/toggleterm.lua:450-454`), so an unset count arrives as 0, and `M.toggle`
(`lua/toggleterm.lua:314-320`) only picks a terminal for a count of 1 or more:

```lua
function M.toggle(count, size, dir, direction, name)
  if count and count >= 1 then
    toggle_nth_term(count, size, dir, direction, name)
  else
    smart_toggle(size, dir, direction, name)
  end
end
```

The fix follows: put `v:count` into the command yourself. toggleterm does exactly that for its own
`open_mapping` (`lua/toggleterm.lua:36-42`), which this config leaves unset (neovim.nix:770-773) so every key
stays in the `keymaps` list:

```lua
    utils.key_map("n", mapping, '<Cmd>execute v:count . "ToggleTerm"<CR>', {
```

### 3. Decide

Four right-hand sides you might try, each checked on the real config:

| rhs | `2<leader>t` | bare `<leader>t` | Verdict |
|---|---|---|---|
| `<cmd>ToggleTerm<CR>` (today) | smart toggle: closes the dock | smart toggle | the trap |
| `<cmd>execute v:count . "ToggleTerm"<CR>` | `:2ToggleTerm`: terminal 2 | `:0ToggleTerm`: count 0, so still the smart toggle | **take** |
| `<cmd>execute v:count1 . "ToggleTerm"<CR>` | `:2ToggleTerm` | `:1ToggleTerm`: always terminal 1 | loses the smart toggle: with two terminals open, a bare `<leader>t` hides only terminal 1 |
| `:ToggleTerm<CR>` (a colon map) | the `2` becomes the range `.,.+1`, and the command's count is the range's last line: terminal 4 when the cursor is on line 3 | smart toggle | right only on line 1, by accident |

`v:count1` is "Just like `v:count`, but defaults to one when no count is used" (vvars.txt:100-103). That default
is what breaks it here.

Or leave the map alone and keep typing `:2ToggleTerm`. That works, but the key you use a dozen times a day
should do the obvious thing.

**Recommendation:** `<cmd>execute v:count . "ToggleTerm"<CR>`, toggleterm's own form, written with the lower-case
`<cmd>` the rest of the list uses.

**The description.** It should say that the key takes a count, and it should stay short. which-key sizes every
column of its popup to the longest entry, so a long description collapses the Space popup from three columns into
one tall column. "Toggle terminal (bottom; a count picks the terminal)" did exactly that when recorded at the
course's tape size. `Toggle terminal [count]` uses `[count]`, the way Neovim's own help writes an optional count,
and at 23 characters it is shorter than its neighbour "Toggle buffer list (left)", so the popup keeps its shape.

### 4. Make the change

Open `home/modules/neovim.nix` (Space f f, `neovim.nix`, select `home/modules/neovim.nix`, `<CR>`), go to line 27
with `:27` `<CR>`, and edit the `rhs` and `desc`. The diff is against the file as it is today:

```diff
--- a/home/modules/neovim.nix
+++ b/home/modules/neovim.nix
@@ -24,7 +24,7 @@
     { group = "Panels"; lhs = "<leader>e";  rhs = "<cmd>Neotree toggle filesystem left<CR>"; desc = "Toggle file tree (left)"; }
     { group = "Panels"; lhs = "<leader>b";  rhs = "<cmd>Neotree toggle buffers left<CR>";    desc = "Toggle buffer list (left)"; }
     { group = "Panels"; lhs = "<leader>o";  rhs = "<cmd>AerialToggle<CR>";     desc = "Toggle outline (left)"; }
-    { group = "Panels"; lhs = "<leader>t";  rhs = "<cmd>ToggleTerm<CR>";       desc = "Toggle terminal (bottom)"; }
+    { group = "Panels"; lhs = "<leader>t";  rhs = "<cmd>execute v:count . \"ToggleTerm\"<CR>"; desc = "Toggle terminal [count]"; }
 
     { group = "Find";   lhs = "<leader>ff"; rhs = "<cmd>Telescope find_files<CR>"; desc = "Find files"; }
     { group = "Find";   lhs = "<leader>fg"; rhs = "<cmd>Telescope live_grep<CR>";  desc = "Live grep"; }
```

Line 27 is untouched by [lesson 23](23-FIX-JUMP-FORWARD.md)'s edit, which added a line further down, so this diff
applies whether or not you made that one.

**Follow the quotes through the three layers.**

1. **Nix.** The rhs contains double quotes, and inside a Nix double-quoted string a `"` must be written `\"`.
   Nix reads `\"` as `"`, so the string's value is `<cmd>execute v:count . "ToggleTerm"<CR>`.
2. **Lua.** `luaStr` (neovim.nix:76) wraps that value in single quotes and escapes only backslashes and single
   quotes. There are neither, so the double quotes pass straight through. The generated line of `init.lua` is:

   ```lua
   vim.keymap.set('n', '<leader>t', '<cmd>execute v:count . "ToggleTerm"<CR>', { desc = 'Toggle terminal [count]', noremap = true, silent = true })
   ```

3. **Vimscript.** When you press the key, `:execute` joins the number in `v:count` and the string `"ToggleTerm"`
   with `.` and runs the result: `2ToggleTerm` for `2<leader>t`, `0ToggleTerm` for a bare `<leader>t`.

**Save with `:noautocmd w`**, not `<C-s>`: format-on-save hands Nix files to `nil`, which reformats the whole file
([lesson 23](23-FIX-JUMP-FORWARD.md), step 4). Then:

```bash
# in ~/Repos/personal/nix-config
git diff --stat     # expect: 1 file changed, 1 insertion(+), 1 deletion(-)
```

The Panels table of `KEYBINDS.md` will read:

```markdown
| `<leader>t` | Toggle terminal [count] |
```

### 5. Check and rebuild

```bash
# in ~/Repos/personal/nix-config
nix-instantiate --parse home/modules/neovim.nix > /dev/null && echo OK
just rebuild
```

A forgotten `\` shows up here, not after a rebuild. Leave out both and each bare `"` ends or starts a Nix string,
so `ToggleTerm` becomes a bare Nix name and `nix-instantiate` stops with `error: undefined variable 'ToggleTerm'`
at line 27. Leave out only one and the quotes pair up wrongly, so you get
`error: syntax error, unexpected invalid token, expecting ';'`, sometimes reported on a later line than the one you
edited. Either way, compare your line with the diff above. After `just rebuild`, restart Neovim.

### 6. Verify

```bash
# in /tmp/nvim-course/24-fix-counted-terminal-toggle
nvim notes.md
```

**The map.** `:verbose nmap <leader>t`:

```text
n  <Space>t    * <Cmd>execute v:count . "ToggleTerm"<CR>
                 Toggle terminal [count]
	Last set from ~/.config/nvim/init.lua (run Nvim with -V1 for more details)
```

Neovim prints `<cmd>` as `<Cmd>`; they are the same key.

![:verbose nmap <leader>t showing <Cmd>execute v:count . "ToggleTerm"<CR> and "Toggle terminal [count]"](../media/24-fix-counted-terminal-toggle/verbose-leader-t.png)

**The keys.** Press `<CR>` to leave the listing, then:

1. Space t: terminal 1, as before. `<C-\><C-n>`: Normal mode, cursor still in terminal 1.
2. `2`, then Space, and pause: the which-key popup lists `t` as "Toggle terminal [count]". The pause is only
   there to show you the popup; which-key replays the count either way.
3. `t`: terminal 2 opens **beside** terminal 1, splitting the dock in two, in Terminal mode.
4. `<C-\><C-n>`, then `:TermSelect`: both terminals are listed, each with your shell's path as its name.
   `<CR>` on the empty prompt cancels.
5. Space t: both terminals hide. Space t again: both come back. The smart toggle is intact.
6. `1`, Space t: only terminal 1 hides. `3`, Space t: a new terminal 3 opens; numbers need not be consecutive.

> **Gotcha:** start from the editor instead (`<C-k>` up to `notes.md`, then `2` Space t) while terminal 1 sits in
> Normal mode, and terminal 2 opens in **Normal** mode: the status line says `NORMAL`, so press `i` before you
> type. That is toggleterm, not the new map: `:2ToggleTerm` from the same place does the same. To put terminal 2
> beside terminal 1, toggleterm first makes terminal 1's window current (toggleterm.nvim
> `lua/toggleterm/ui.lua:314-319`). Entering it restores the mode terminal 1 was left in (`persist_mode`,
> `lua/toggleterm.lua:107-108`) with a scheduled `stopinsert` (`lua/toggleterm/terminal.lua:265-266`), and that
> `stopinsert` lands on the new terminal 2. From inside terminal 1 nothing is re-entered, so terminal 2 keeps
> Terminal mode.

![The popup after 2 and Space: t is "Toggle terminal [count]"](../media/24-fix-counted-terminal-toggle/count-popup.png)

![Terminal 2 beside terminal 1 after 2 Space t](../media/24-fix-counted-terminal-toggle/two-terminals.png)

![:TermSelect listing terminals 1 and 2](../media/24-fix-counted-terminal-toggle/termselect.png)

**Codex has a number too.** The Codex terminal is created at start-up (`Terminal:new{ cmd = 'codex', hidden = true,
… }`, neovim.nix:788-793) and takes the lowest free number the first time you open it with `<leader>co`
(toggleterm.nvim `lua/toggleterm/terminal.lua:109-115`, `:230-234`). So:

- open the shell first (Space t), then Codex: the shell is 1 and Codex is **2**;
- open Codex first (`<leader>co` straight after `nvim notes.md`), then Space t: Codex is **1** and the shell is 2.

Now `N<leader>t` with Codex's number toggles **Codex**, not a shell. toggleterm looks the number up, skips
hidden terminals, and then asks for a new terminal with that number, which hands back the existing Codex terminal
(`lua/toggleterm/terminal.lua:540-546`, `:198-203`). Before the fix you could only do this with `:2ToggleTerm`; now
two keys do it. The rest of Codex's behaviour does not change: a bare `<leader>t` never touches it, and if Codex
is the only terminal open, a bare `<leader>t` does nothing at all (hide Codex with `<leader>co` first).

**Try it** (optional, starts Codex): after step 6.1 (terminal 1 open, cursor in it, Normal mode), `<leader>co`
opens Codex; `<C-\><C-n>` and `<leader>co` again hide it. `:TermSelect` lists only terminal 1; `:TermSelect!`
lists `1` and `2: codex`. `2`, Space t now shows Codex. So before `N<leader>t`, look at `:TermSelect!`; for a
fresh shell, use `:TermNew`, which always takes a free number.

Every result in this step, Codex included, was checked on the real laptop-intel Neovim built with this edit
(with a stand-in `codex` command, since only the numbering matters), and the popup with a count pending was
checked in a recording.

### 7. What else changes

- **`KEYBINDS.md`:** the Panels row reads `Toggle terminal [count]`.
- **which-key:** the Space popup shows the new description; its three-column layout is unchanged.
- **Nothing else that toggles the dock.** The start-up dock layout calls `:ToggleTerm` directly
  (neovim.nix:897), not the key, and `:ToggleTerm`, `:2ToggleTerm` and `:TermSelect` behave as before.
- **[Lesson 06](06-TERMINAL.md)** (step 5's count trap and its Try-it item 6, gotcha 3, drill 3) describes the old
  key: there, `2` then Space t closes both terminals. After this lesson it toggles terminal 2, or Codex if Codex
  holds number 2. [Appendix A](../appendices/A-CHEATSHEET.md)'s `<leader>t` row and
  [Appendix C](../appendices/C-TROUBLESHOOTING.md)'s "`2<leader>t` did not open terminal 2" point here.
- **Tapes:** tapes 00 and 05 show the Space popup with the old description, so record them before this lesson
  ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#record-in-this-order)). Tapes 06, 17 and 21 press only a bare
  Space t, which behaves as before.

### 8. Commit

```bash
# in ~/Repos/personal/nix-config
git add home/modules/neovim.nix
git commit -m "feat(nvim): let a count pick the terminal for <leader>t"
```

(Or with Neogit: Space g g, `s`, `c` `c`, the message, `<c-c><c-c>`.)

## Gotchas in this config

- **Codex's number moves.** It depends on whether Codex or a shell was opened first. `N<leader>t` with Codex's
  number opens Codex; check `:TermSelect!` first, and use `:TermNew` for a new shell.
- **`v:count1` looks tidier and is wrong here.** It turns a bare `<leader>t` into `:1ToggleTerm`, which toggles
  terminal 1 only.
- **Escape the quotes for Nix.** `\"` inside the Nix string; `luaStr` handles the Lua side. Missing backslashes
  make `nix-instantiate --parse` fail: `undefined variable 'ToggleTerm'` when both are missing, a syntax error
  (possibly on a later line) when only one is.
- **Save config edits with `:noautocmd w`.** `<C-s>` lets `nil` reformat the whole of `neovim.nix`.
- **Long descriptions reshape the popup.** which-key sizes its columns to the longest entry, so keep a new `desc`
  no longer than its neighbours.
- **Normal mode only.** In Terminal mode, Space goes to the shell; `<C-\><C-n>` first, as in lesson 06.
- **A new terminal can open in Normal mode.** Opened from the editor while another terminal was left in Normal
  mode, it inherits a `stopinsert` meant for that terminal (step 6). Press `i`, or start from inside the terminal.

## Drills

1. `:2ToggleTerm` opens terminal 2, but before the fix `2<leader>t` did not. Where exactly was the `2` lost?
   <details><summary>Answer</summary>

   In the `<cmd>` map. which-key replays the count, and Neovim keeps it in `v:count` while the map runs, but a
   `<Cmd>` map never enters Command-line mode, so nothing puts the count in front of `ToggleTerm`. toggleterm then
   receives count 0 and does the smart toggle.
   </details>

2. What do you write between the Nix quotes to get the Lua string `'<cmd>execute v:count . "ToggleTerm"<CR>'`, and
   why does the Lua need no escaping?
   <details><summary>Answer</summary>

   `rhs = "<cmd>execute v:count . \"ToggleTerm\"<CR>";`. Nix turns `\"` into `"`. `luaStr` wraps the value in
   single quotes and escapes only backslashes and single quotes, so double quotes pass through unchanged.
   </details>

3. Vimscript accepts single-quoted strings too. If you wrote `rhs = "<cmd>execute v:count . 'ToggleTerm'<CR>";`,
   what would `luaStr` render?
   <details><summary>Answer</summary>

   `'<cmd>execute v:count . \'ToggleTerm\'<CR>'`. `luaStr` escapes each single quote as `\'` so the Lua string
   stays valid, and Lua turns `\'` back into `'`, so Neovim gets the same Vimscript. No Nix escaping is needed in
   that form.
   </details>

4. Why is `v:count1` wrong for this map, although toggleterm's README uses it?
   <details><summary>Answer</summary>

   `v:count1` is 1 when you type no count, so a bare `<leader>t` would always run `:1ToggleTerm` and toggle
   terminal 1 only. With `v:count`, a bare press gives `:0ToggleTerm`, and toggleterm treats 0 as "no count": the
   smart toggle that hides or restores every terminal.
   </details>

5. After the fix you start `nvim notes.md`, press `<leader>co` (Codex opens), hide it with `<leader>co`, then press
   Space t. Which number does the shell get, and what does `1<leader>t` do?
   <details><summary>Answer</summary>

   Codex took number 1 when it was first opened, so the shell is terminal 2. `1<leader>t` toggles Codex.
   `:TermSelect!` shows both numbers.
   </details>

6. Only Codex is open. You press Space t (no count) and nothing happens. Why, and what do you press instead?
   <details><summary>Answer</summary>

   The smart toggle sees an open terminal window and decides to close, but it only closes terminals that are not
   hidden, and Codex is hidden. Press `<leader>co` to hide Codex, or give a count for the shell, such as
   `1<leader>t` when the shell is terminal 1.
   </details>

7. Why was `Toggle terminal (bottom; a count picks the terminal)` rejected as the description?
   <details><summary>Answer</summary>

   which-key makes every column as wide as its longest entry. At 52 characters it turned the Space popup into a
   single tall column. `Toggle terminal [count]` says the same in 23 characters and leaves the popup's layout as
   it was.
   </details>

## Recap

- The count survives which-key (it is replayed in front of the keys) and lands in `v:count`, but a `<cmd>` map
  never passes it to the command, so toggleterm got 0 and did the smart toggle.
- `rhs = "<cmd>execute v:count . \"ToggleTerm\"<CR>"`: Nix needs `\"`, `luaStr` needs nothing, and Neovim runs
  `:NToggleTerm`, where 0 still means the smart toggle.
- `v:count1` and a `:` map both look like fixes and are not.
- Keep `desc` short: `Toggle terminal [count]` keeps the which-key popup's shape.
- Codex holds a toggleterm number too: `N<leader>t` with that number opens Codex. `:TermSelect!` shows the
  numbers, and `:TermNew` makes a fresh shell.

## Recording

- **Tape:** `tapes/24-fix-counted-terminal-toggle.tape`. Record it **after** this lesson's fix, rebuilt: it
  demonstrates step 6, and on a config without the fix it stops at its first check, before any terminal opens. Run it from
  `docs/NEOVIM-COURSE/` on laptop-intel (full configuration):

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  vhs tapes/24-fix-counted-terminal-toggle.tape
  ```

- **VHS version:** `vhs --version` must print 0.12.1, which the config builds (0.12.0 exits 0 and writes nothing);
  if it prints 0.12.0, `just rebuild` first ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)).
- **Fixture:** `fixtures/24-fix-counted-terminal-toggle/notes.md`, copied to
  `/tmp/nvim-course/24-fix-counted-terminal-toggle` by the hidden setup. The two terminals run your zsh there; the
  tape types only `printf` commands into them and sets `ZSH_AUTOSUGGEST_HISTORY_IGNORE` so no line of your shell
  history is drawn as a suggestion. It points `CLAUDE_CONFIG_DIR` at a throwaway folder, so claudecode.nvim's lock
  file never lands in your real `~/.claude/ide`. Codex is not started.
- **Outputs:** `media/24-fix-counted-terminal-toggle/24-fix-counted-terminal-toggle.gif` and
  `media/24-fix-counted-terminal-toggle/24-fix-counted-terminal-toggle.mp4`.

| Screenshot | Shows | Used in |
| --- | --- | --- |
| `media/24-fix-counted-terminal-toggle/count-popup.png` | the Space popup with a count of 2 pending: `t` is "Toggle terminal [count]" | step 6 |
| `media/24-fix-counted-terminal-toggle/two-terminals.png` | terminal 1 (`term-one`) and terminal 2 (`term-two`) side by side under `notes.md` | step 6 |
| `media/24-fix-counted-terminal-toggle/termselect.png` | `:TermSelect` listing terminals 1 and 2 | step 6 |
| `media/24-fix-counted-terminal-toggle/verbose-leader-t.png` | `:verbose nmap <leader>t` with the new rhs and description | step 6 |

- **Manual steps:** none. Park the mouse pointer away from the window, and do not type while it runs.
- **Check each recording:**
  - `media/24-fix-counted-terminal-toggle/` actually contains the GIF, the MP4 and all four PNGs. An empty folder
    after a run that exited 0 means VHS 0.12.0 did the rendering.
  - `two-terminals.png` shows two terminals **side by side**. If the tape stopped at `:verbose nmap`, the fix is
    not in the running config: rebuild, restart, record again.
  - The shell prompts show only the fixture path, and no grey history suggestion.
  - The rest of [Appendix B's checklist](../appendices/B-RECORDING-WITH-VHS.md#checklist-for-every-recording).
