# Lesson 25 — Fix: pyright's diagnostic mode

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

The config asks pyright to check the whole project, and pyright has never done it: the setting is spelt
`diagnosticsMode`, and pyright only reads `diagnosticMode`. [Lesson 10](10-LSP.md) showed you the two keys side by
side. This lesson proves, from Neovim's merged settings and from pyright's own code, which one wins and why nothing
ever complained. Then it asks the real question, whether you want workspace-wide diagnostics at all, with the costs
measured on this repository, fixes the key, and verifies the result on a two-file project where one file is never
opened. The same checks will tell you, in the session-browser capstone, whether a change broke a file you are not
looking at.

**Part**: 8 — Making the config yours · **Time**: ~50 min · **Previous**: [Lesson 24 — Fix: a counted terminal toggle](24-FIX-COUNTED-TERMINAL-TOGGLE.md) · **Next**: [Lesson 26 — Fix: a close-buffer key that does not wait](26-FIX-CLOSE-BUFFER-KEY.md)

## Objectives

By the end of this lesson you can:

- show which settings Neovim sends pyright, without opening a Python file;
- explain where today's `openFilesOnly` comes from, and why a misspelt key fails silently;
- weigh workspace mode against open-files mode: what Trouble gains, and what it costs in CPU and noise,
  including the case where pyright's root is the whole repository;
- edit Lua that lives inside a Nix string, in Lua syntax;
- verify the fix by observation: the settings, Trouble listing a file you never opened, `:ls!`, and the
  `pyright` command line agreeing with the editor.

## Before you start

- **Lessons 10, 11 and 22 are done.** You know `:checkhealth vim.lsp` and the pyright settings (lesson 10, step
  12), Trouble (lesson 11), and the change loop (lesson 22).
- **A clean tree** on your config branch: `git status` in `~/Repos/personal/nix-config` says
  `nothing to commit, working tree clean`.
- **A practice project.** Two Python files and a `pyproject.toml`:

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  rm -rf /tmp/nvim-course/25-fix-pyright-diagnostic-mode && mkdir -p /tmp/nvim-course/25-fix-pyright-diagnostic-mode
  cp -r fixtures/25-fix-pyright-diagnostic-mode/. /tmp/nvim-course/25-fix-pyright-diagnostic-mode
  ```

  `pyproject.toml` makes that folder pyright's root. `opened.py` is clean and is the only file you open.
  `never_opened.py` holds one type error, `retries: int = "three"`. **Do not open it** in this lesson: the whole
  point is a problem in a file you are not looking at. There is no venv and nothing to install.
- **`pyright` on the command line.** laptop-intel installs it system-wide (modules/software/development.nix:106),
  the same pinned 1.1.414 the editor runs.

## Keys in this lesson

`<leader>` is Space.

| Keys | Mode | Action | Where it comes from |
|---|---|---|---|
| `<leader>xx` | n | Trouble: every diagnostic Neovim holds, from every file | config (neovim.nix:55) |
| `<leader>xw` | n | Trouble: this buffer's diagnostics only | config (neovim.nix:56) |
| `]d` / `[d` | n | Next / previous diagnostic in this buffer | config (LSP buffer-local, neovim.nix:353-354) |
| `:lua =vim.lsp.config.pyright.settings` | command | The settings Neovim sends pyright, merged from nvim-lspconfig and your config | Neovim 0.12 default |
| `:checkhealth vim.lsp` | command | Enabled servers and their settings; attached clients and their roots | Neovim default |
| `:ls!` | command | Every buffer, including unlisted ones | Neovim default |
| `:noautocmd w` | command | Save without format-on-save | Neovim default |

## Walkthrough

The recording is made after the fix. It shows step 6: the corrected setting, Trouble listing `never_opened.py`, and
`:ls!` proving the file was never opened.

![After the fix: diagnosticMode = "workspace", Trouble listing never_opened.py, and :ls! showing it unlisted and never loaded](../media/25-fix-pyright-diagnostic-mode/25-fix-pyright-diagnostic-mode.gif)

[MP4](../media/25-fix-pyright-diagnostic-mode/25-fix-pyright-diagnostic-mode.mp4)

### 1. See the problem

**Try it.**

```bash
# in /tmp/nvim-course/25-fix-pyright-diagnostic-mode
nvim opened.py
```

Give pyright a few seconds to start, then Space x x (`<leader>xx`, typed without pausing: a pause after Space x
closes the buffer, [lesson 05](05-YOUR-KEYBINDINGS.md)).

**What you see:** no Trouble window. A warning at the bottom instead, followed by a "Press ENTER" prompt:

```text
No results for **diagnostics**
Buffer: /tmp/nvim-course/25-fix-pyright-diagnostic-mode/opened.py
```

Trouble opens only when it has something to show. Now ask the command line, which always checks every file. Quit
Neovim (`:qa`) or use a spare shell:

```bash
# in /tmp/nvim-course/25-fix-pyright-diagnostic-mode
pyright
```

```text
/tmp/nvim-course/25-fix-pyright-diagnostic-mode/never_opened.py
  /tmp/nvim-course/25-fix-pyright-diagnostic-mode/never_opened.py:3:16 - error: Type "Literal['three']" is not assignable to declared type "int"
    "Literal['three']" is not assignable to "int" (reportAssignmentType)
1 error, 0 warnings, 0 informations
```

The project has a type error, and the editor does not know. Back in Neovim, look at what it sends pyright. This
works in any buffer, before a Python file is even open:

```vim
:lua =vim.lsp.config.pyright.settings
```

```text
{
  pyright = {
    disableTaggedHints = true
  },
  python = {
    analysis = {
      autoSearchPaths = true,
      diagnosticMode = "openFilesOnly",
      diagnosticsMode = "workspace",
      typeCheckingMode = "basic",
      useLibraryCodeForTypes = true
    }
  }
}
```

Two keys, one letter apart, with opposite values.

### 2. Why it happens

**The config writes the wrong key.** neovim.nix:397-407, with the typo on line 402:

```lua
      lsp('pyright', {
        cmd = { '${pkgs.pyright}/bin/pyright-langserver', '--stdio' },
        settings = {
          python = {
            analysis = {
              diagnosticsMode = "workspace",
              typeCheckingMode = "basic",
            }
          }
        }
      })
```

This is Lua inside the `initLua` string, not Nix: `=` and `,`, not `;`.

**nvim-lspconfig supplies the right key.** The `lsp()` helper (neovim.nix:391-394) calls `vim.lsp.config`, which
merges your table onto nvim-lspconfig's defaults for the server (neovim.nix:386-390 says so). The pinned
nvim-lspconfig 2.11.0 ships those defaults in `lsp/pyright.lua`, and line 57 sets:

```lua
        diagnosticMode = 'openFilesOnly',
```

The merge keeps every key from both tables. Your misspelt key does not replace the real one, because to a Lua
table they are simply two different keys. That is the table step 1 printed.

**pyright reads only `diagnosticMode`.** In the pinned pyright 1.1.414, the language server turns the setting into
its `openFilesOnly` flag with `isOpenFilesOnly(e){return"workspace"!==e}`, applied to `diagnosticMode`, and its
built-in default is `openFilesOnly: true`. The string `diagnosticsMode` does not occur anywhere in pyright's code
(`grep -c diagnosticsMode` gives 0 for each of the four `dist/*.js` files of the pinned package). So pyright
checks open files only, and would do so even without nvim-lspconfig's default.

**Nobody complains.** Neovim passes `settings` through without checking them against any schema, and pyright
ignores keys it does not know. A typo in a server setting is silent on both sides. The only way to find one is to
look, as step 1 did.

### 3. Decide

In **workspace** mode pyright analyses every Python file under its root and reports on all of them. The root is the
nearest directory with one of nvim-lspconfig's markers (`lsp/pyright.lua:39-47`): `pyrightconfig.json`,
`pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt`, `Pipfile` or `.git`. Inside it, unless the project
sets an `exclude` of its own, pyright skips its default excludes, `**/node_modules`, `**/__pycache__`, `**/.*` and
`**/__editable__.*`, so `.venv` and `.git` are never scanned.

**What you gain:**

- Trouble (`<leader>xx`) lists problems in files you have not opened. Rename a field in `models.py` and the tests
  that still use the old name show up before you run pytest.
- The editor agrees with `pyright` and `uvx pyright` on the command line, which your capstone's `AGENTS.md` asks for
  ([lesson 13](13-CLAUDE-CODE-AND-CODEX.md)).
- Claude sees them too. claudecode.nvim's diagnostics tool asks for `vim.diagnostic.get(nil)`, every buffer's
  diagnostics, when no file is named (claudecode.nvim `lua/claudecode/tools/get_diagnostics.lua:107-109`), and that
  includes files pyright reported on without your opening them.

**What it costs:**

- **Work.** pyright checks every file when it starts and re-checks the files that depend on one you change. That
  is more CPU and memory, and the first results take longer on a big tree. On the practice project the error in
  `never_opened.py` arrived within two seconds, and the finished session-browser has 17 Python files.
- **A root bigger than you meant.** A Python file with no `pyproject.toml` above it falls back to `.git`, so the
  whole repository becomes the workspace. Measured on a copy of this course with the pinned pyright: opening
  `docs/NEOVIM-COURSE/practice/03-text-objects.py` (the kata file from [lesson 03](03-OPERATORS-AND-TEXT-OBJECTS.md))
  gave 0 diagnostics before the fix and about 130, spread over some 50 files, after it. All but a handful were
  `Import "…" could not be resolved`, from the worked examples in `docs/NEOVIM-COURSE/examples/`, whose imports
  need a venv that the repository root does not have. The rest were real type errors in course files you were not
  looking at, among them `never_opened.py` from this lesson's own fixture.
- **Noise you do not own.** Generated or vendored Python under the root is reported too.

| Option | What you get |
|---|---|
| **A. `diagnosticMode = "workspace"`** (the edit below) | What the config meant all along, with the gains and costs above |
| B. `diagnosticMode = "openFilesOnly"` | What you have had all course, now written down correctly. Run `uvx pyright` for the whole project |
| C. Delete the line | The same as B, through nvim-lspconfig's default, and nothing left to misspell |

**Recommendation: A.** Your Python work happens inside `python/session-browser`, whose `pyproject.toml` keeps the
root small, and seeing a broken test before you run it is worth the CPU. If you often open stray Python files in
this repository, the flood of `Import … could not be resolved` from the worked examples is the price: choose B.

### 4. Make the change

Open `home/modules/neovim.nix` (Space f f, `neovim.nix`, select `home/modules/neovim.nix`, `<CR>`). Then `/sMode`
and `<CR>`: `sMode` occurs only once in the file, so the search puts the cursor on exactly the extra `s`, and `x`
deletes it. (`fs` would not do: it stops at the first `s` of "diagnostics".) Space h (`<leader>h`) clears the
highlight. The diff is against the file as it is today:

```diff
--- a/home/modules/neovim.nix
+++ b/home/modules/neovim.nix
@@ -399,7 +399,7 @@
         settings = {
           python = {
             analysis = {
-              diagnosticsMode = "workspace",
+              diagnosticMode = "workspace",
               typeCheckingMode = "basic",
             }
           }
```

If you made [lesson 23](23-FIX-JUMP-FORWARD.md)'s change, it added a line above this one, so the key is on line 403.
The search finds it either way.

**Save with `:noautocmd w`**, not `<C-s>`: format-on-save hands Nix files to `nil`, which reformats the whole file
([lesson 23](23-FIX-JUMP-FORWARD.md), step 4). Then:

```bash
# in ~/Repos/personal/nix-config
git diff --stat     # expect: 1 file changed, 1 insertion(+), 1 deletion(-)
```

The generated `init.lua` changes in the same single line. There is no key, so `KEYBINDS.md` does not change.

### 5. Check and rebuild

```bash
# in ~/Repos/personal/nix-config
nix-instantiate --parse home/modules/neovim.nix > /dev/null && echo OK
just rebuild
```

`nix-instantiate --parse` checks the Nix around the Lua, not the Lua itself; an edit that only removes a letter
from a key cannot break either. Restart Neovim after the rebuild: pyright receives its settings when it starts, so
a running Neovim keeps sending the old ones.

### 6. Verify

**The settings.** In any buffer:

```vim
:lua =vim.lsp.config.pyright.settings
```

```text
{
  pyright = {
    disableTaggedHints = true
  },
  python = {
    analysis = {
      autoSearchPaths = true,
      diagnosticMode = "workspace",
      typeCheckingMode = "basic",
      useLibraryCodeForTypes = true
    }
  }
}
```

One key now, with the value you asked for. `:checkhealth vim.lsp` shows the same table under
"vim.lsp: Enabled Configurations", `- pyright:`, `settings`. Once a Python file is open,
`:lua =vim.lsp.get_clients({ name = 'pyright' })[1].config.settings` (lesson 10, step 12) shows what the running
client was actually given. All three read the configuration of the Neovim you are in, so if they still show
`diagnosticsMode`, that Neovim was started before `just rebuild`: restart it.

![:lua =vim.lsp.config.pyright.settings.python.analysis with diagnosticMode = "workspace"](../media/25-fix-pyright-diagnostic-mode/settings.png)

The recording prints only the `python.analysis` part, to fit the screen.

**The behaviour.** A setting that reads right proves nothing yet. Watch what pyright does:

```bash
# in /tmp/nvim-course/25-fix-pyright-diagnostic-mode
nvim opened.py
```

After a few seconds, Space x x. Trouble opens at the bottom with one file, the one you never opened:

```text
/tmp/nvim-course/25-fix-pyright-diagnostic-mode/  1
└╴ never_opened.py  1
  └╴E Type "Literal['three']" is not assignable to declared type "int"
      "Literal['three']" is not assignable to "int" Pyright (reportAssignmentType) [3, 16]
```

(Trouble also draws file and folder icons, left out here.)

It is the error `pyright` printed on the command line in step 1: the editor and the CLI now agree.

![Trouble after the fix: never_opened.py with its one error, while opened.py is the only file open](../media/25-fix-pyright-diagnostic-mode/trouble.png)

**Proof you never opened it.** `:ls` lists only `opened.py`. `:ls!` adds unlisted buffers:

```text
  1 %a   "opened.py"                    line 1
  2u     "/tmp/nvim-course/25-fix-pyright-diagnostic-mode/never_opened.py" line 0
```

(plus an unlisted `[Scratch]` buffer that belongs to Trouble). `u` means unlisted, and there is no `a` or `h`:
the buffer was never loaded. Neovim created it only to hang pyright's diagnostic on.

![:ls! showing never_opened.py as buffer 2u, line 0](../media/25-fix-pyright-diagnostic-mode/ls.png)

`<leader>xw` (this buffer only) and `]d` / `[d` (next and previous in this buffer) still see only `opened.py`,
which is clean. Space x x again closes Trouble.

Every output in steps 1 and 6 was taken from the real laptop-intel Neovim, built from this config before and after
the edit, with the pinned pyright 1.1.414 running on this project.

**In your capstone** (optional). With a Python file of `python/session-browser` open, create a file you will not
open, from the terminal (Space t):

```bash
# in ~/Repos/personal/nix-config/python/session-browser
printf 'x: int = "text"\n' > src/session_browser/_probe.py
```

Space x x should list `_probe.py`. If it also lists `Import "textual" could not be resolved` for other files, pyright
cannot see the venv: see [lesson 10](10-LSP.md), step 10. Remove the probe afterwards:

```bash
# in ~/Repos/personal/nix-config/python/session-browser
rm src/session_browser/_probe.py
```

### 7. What else changes

- **Keys, `KEYBINDS.md` and which-key:** nothing. This lesson changes a setting, not a key.
- **Trouble's `<leader>xx`** now includes files you have not opened; `<leader>xw`, `]d` and `[d` do not, because
  they work on the current buffer.
- **[Lesson 10](10-LSP.md), step 12,** prints the two keys side by side. After the fix you see one,
  `diagnosticMode = "workspace"`. Its gotcha and [lesson 11](11-COMPLETION-FORMATTING-DIAGNOSTICS.md)'s ("pyright only
  checks open files") no longer hold, and [Appendix C](../appendices/C-TROUBLESHOOTING.md)'s entry points here.
- **Stray Python files in this repository** bring the worked examples' import errors into Trouble (step 3).
- **Tapes:** none changes. Tape 10's `:checkhealth vim.lsp` screenshot shows rust-analyzer's client, not pyright's
  settings; tape 11's fixture has one Python file, so Trouble lists the same items; tapes 18 to 21 open worked
  example Python files but never Trouble.

### 8. Commit

```bash
# in ~/Repos/personal/nix-config
git add home/modules/neovim.nix
git commit -m "fix(lsp): pyright diagnosticMode key (diagnosticsMode was silently ignored)"
```

(Or with Neogit: Space g g, `s`, `c` `c`, the message, `<c-c><c-c>`.)

## Gotchas in this config

- **Server settings fail silently.** Neither Neovim nor pyright rejects an unknown key. Check
  `:lua =vim.lsp.config.<name>.settings` after every settings change, and then check the behaviour.
- **This edit is Lua, not Nix.** The pyright block lives inside the `initLua` string: `key = value,`.
- **The root decides what "workspace" means.** No `pyproject.toml` above a file means `.git`, the whole repository.
  `:checkhealth vim.lsp` shows the attached client's "Root directory".
- **Restart after the rebuild.** A running pyright keeps the settings it started with.
- **Trouble does not open on an empty list.** It prints `No results for **diagnostics**` instead, which is what
  open-files mode looks like on a clean open file.
- **Save config edits with `:noautocmd w`.** `<C-s>` lets `nil` reformat the whole of `neovim.nix`.

## Drills

1. Before the fix, where did the `openFilesOnly` that pyright used come from? Name both places that would have
   given it.
   <details><summary>Answer</summary>

   nvim-lspconfig's `lsp/pyright.lua:57` sets `diagnosticMode = 'openFilesOnly'`, and `vim.lsp.config` merged your
   settings onto it without replacing it, because `diagnosticsMode` is a different key. Without that default,
   pyright's own default is open-files mode too.
   </details>

2. Why did nothing warn about `diagnosticsMode` for the whole course?
   <details><summary>Answer</summary>

   Neovim passes `settings` to the server as they are, and pyright ignores keys it does not read. A misspelt setting
   is just an extra key in a table.
   </details>

3. Lessons 23 and 24 edited the `keymaps` list with `;` between fields. Why does this edit end in `,`?
   <details><summary>Answer</summary>

   The pyright block is Lua inside the `initLua` string, and Lua table fields are separated by `,`. The `keymaps`
   list is Nix, where attributes end in `;`.
   </details>

4. How do you see the settings Neovim will send pyright without opening a Python file?
   <details><summary>Answer</summary>

   `:lua =vim.lsp.config.pyright.settings`, or `:checkhealth vim.lsp` under "Enabled Configurations". Both show the
   merged table: nvim-lspconfig's defaults plus your overrides.
   </details>

5. After the fix you open `docs/NEOVIM-COURSE/practice/03-text-objects.py` and Trouble fills with
   `Import "…" could not be resolved` from files under `docs/NEOVIM-COURSE/examples/`. Why, and what can you do?
   <details><summary>Answer</summary>

   No `pyproject.toml` sits above the practice file, so pyright's root is the repository (`.git`), and workspace mode
   analyses every Python file in it, including the worked examples, whose imports need a venv. Live with it, open
   such files less, or choose option B (`"openFilesOnly"`).
   </details>

6. In `opened.py`, after the fix, you press `]d`. Does it jump to the error in `never_opened.py`?
   <details><summary>Answer</summary>

   No. `]d` moves between diagnostics in the current buffer, and `opened.py` has none. Trouble (`<leader>xx`) is how
   you reach problems in other files.
   </details>

7. `:lua =vim.lsp.config.pyright.settings` shows `"workspace"`, yet Trouble still finds nothing in the practice
   project. What do you check, in order?
   <details><summary>Answer</summary>

   That pyright is attached at all and rooted at the project: `:checkhealth vim.lsp`, under Active Clients, should
   list `pyright` with the practice folder as its Root directory. Then give it a few seconds, since Trouble only
   shows what has arrived. Finally run `pyright` on the command line in the same folder: if it finds nothing
   either, there is nothing to find.
   </details>

## Recap

- `diagnosticsMode` was never read: pyright only reads `diagnosticMode`, which nvim-lspconfig sets to
  `openFilesOnly`, and pyright defaults to the same. Unknown settings fail silently.
- `:lua =vim.lsp.config.pyright.settings` shows the merged settings without opening a Python file; the running
  client's copy is under `vim.lsp.get_clients()`.
- Workspace mode reports every file under the root: broken tests show up before you run them, and Claude sees
  them too. It costs CPU on big trees, and a file with no `pyproject.toml` above it makes the whole repository the
  root.
- The fix is one letter in Lua inside Nix: `diagnosticMode = "workspace",`.
- Verify by behaviour: Trouble lists a file you never opened, `:ls!` shows it unlisted and unloaded, and the
  `pyright` command line agrees.

## Recording

- **Tape:** `tapes/25-fix-pyright-diagnostic-mode.tape`. Record it **after** this lesson's fix, rebuilt: it
  demonstrates step 6, and on a config without the fix it stops at its first check. Run it from
  `docs/NEOVIM-COURSE/` on laptop-intel (full configuration):

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  vhs tapes/25-fix-pyright-diagnostic-mode.tape
  ```

- **VHS version:** `vhs --version` must print 0.12.1, which the config builds (0.12.0 exits 0 and writes nothing);
  if it prints 0.12.0, `just rebuild` first ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)).
- **Fixture:** `fixtures/25-fix-pyright-diagnostic-mode/` (`pyproject.toml`, `opened.py`, `never_opened.py`), copied
  to `/tmp/nvim-course/25-fix-pyright-diagnostic-mode` by the hidden setup. Only `opened.py` is opened. The hidden
  setup waits, up to 60 seconds, until pyright has reported. No venv, repository, terminal or register is involved,
  and `CLAUDE_CONFIG_DIR` points at a throwaway folder, so claudecode.nvim's lock file never lands in your real
  `~/.claude/ide`.
- **Needs:** pyright from the config. Nothing else.
- **Outputs:** `media/25-fix-pyright-diagnostic-mode/25-fix-pyright-diagnostic-mode.gif` and
  `media/25-fix-pyright-diagnostic-mode/25-fix-pyright-diagnostic-mode.mp4`.

| Screenshot | Shows | Used in |
| --- | --- | --- |
| `media/25-fix-pyright-diagnostic-mode/settings.png` | `:lua =vim.lsp.config.pyright.settings.python.analysis`: `diagnosticMode = "workspace"`, no `diagnosticsMode` | step 6 |
| `media/25-fix-pyright-diagnostic-mode/trouble.png` | Trouble at the bottom: `never_opened.py`, one error, while `opened.py` is the open file | step 6 |
| `media/25-fix-pyright-diagnostic-mode/ls.png` | `:ls!`: `never_opened.py` as buffer `2u`, `line 0` | step 6 |

- **Manual steps:** none. Park the mouse pointer away from the window, and do not type while it runs.
- **Timing that must not change:** Space x x is typed as one string at 60 ms per key. Slower, and `<leader>x`
  closes the buffer after 300 ms.
- **Check each recording:**
  - `media/25-fix-pyright-diagnostic-mode/` actually contains the GIF, the MP4 and all three PNGs. An empty folder
    after a run that exited 0 means VHS 0.12.0 did the rendering.
  - `trouble.png` lists `never_opened.py` and nothing from `opened.py`. If the tape stopped at its first check
    instead, the running config still has the typo: rebuild, restart, record again.
  - The rest of [Appendix B's checklist](../appendices/B-RECORDING-WITH-VHS.md#checklist-for-every-recording).
