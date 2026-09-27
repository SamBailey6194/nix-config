# Appendix A — Cheat sheet

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

The bindings the course teaches, in one place. The first eight sections follow the groups of your generated
`~/.config/nvim/KEYBINDS.md`: Panels, Find, Git, AI, Code, Diagnostics, Buffers, Windows. After them come
the language-server maps, completion, the Neovim 0.12 defaults worth knowing, core editing, the keys that
work inside plugin windows, and the Hyprland keys. Each row names the lesson that teaches it and flags the
traps your config sets.

> **Note:** This appendix has no tape and no media. The lesson named in each row shows the key in action
> and has its own recording.

## Contents

- [How to read the tables](#how-to-read-the-tables)
- [The leader map at a glance](#the-leader-map-at-a-glance)
- [Panels](#panels)
- [Find](#find)
- [Git](#git)
- [AI](#ai)
- [Code](#code)
- [Diagnostics](#diagnostics)
- [Buffers](#buffers)
- [Windows](#windows)
- [Language-server maps (buffer-local)](#language-server-maps-buffer-local)
- [Completion (nvim-cmp, Insert mode)](#completion-nvim-cmp-insert-mode)
- [Neovim 0.12 defaults worth knowing](#neovim-012-defaults-worth-knowing)
- [Core editing (lessons 01 to 04)](#core-editing-lessons-01-to-04)
- [Inside plugin windows](#inside-plugin-windows)
- [Hyprland](#hyprland)
- [Traps at a glance](#traps-at-a-glance)

## How to read the tables

- **Keys** use Neovim notation: `<leader>` is Space, `<C-w>` is Ctrl+w, `<S-Tab>` is Shift+Tab, `<M-q>` is
  Alt+q, `<CR>` is Enter. Hyprland keys are written `SUPER + SHIFT + RETURN`.
- **Mode**: `n` Normal, `i` Insert, `v` Visual (all kinds), `x` Visual only, `o` Operator-pending,
  `c` Command-line, `t` Terminal, `s` Select.
- **Lesson** is the lesson that teaches the key. Where two lessons are listed, the first introduces it.
- **Where it comes from**:
  - `config (neovim.nix:NN)` is a line of `home/modules/neovim.nix`;
  - `config (LSP buffer-local, neovim.nix:NN)` exists only in buffers with a language server attached;
  - "listed at :NN" marks a `docOnly` entry: KEYBINDS.md shows it, but it is defined somewhere else;
  - `Neovim default`, `Neovim 0.12 default` and `<plugin> default` are not in your config at all.
- **Trap** marks behaviour that surprises people in this config. The lesson named in the row explains it,
  and where a later lesson changes the config to remove the trap (lessons [23] to [28]), the row says so.
  The tables describe the config as the course teaches it, before those changes.
- A `|` inside a key is written `\|` so the tables render.

## The leader map at a glance

This is what which-key shows after Space (group labels from `neovim.nix:844-849`).

| Prefix | which-key label | Keys that follow |
|---|---|---|
| `<leader>` | – | `e` `b` `o` `t` `h` `x`, plus `k`, `rn` and `ld` in buffers with a language server |
| `<leader>f` | `+find` | `ff` `fg` `fb` `fh` |
| `<leader>g` | `+git` | `gs` `gg` `gd` `gq` `gh` |
| `<leader>c` | `+code / AI` | `cc` `cb` `co` `cf`, `ca` (language-server buffers), `cs` (Visual mode only) |
| `<leader>x` | `+diagnostics` | `xx` `xw`. **Trap:** `<leader>x` on its own is also Close buffer |
| `<leader>r`, `<leader>l` | no label | `rn`, `ld` (language-server buffers only) |

## Panels

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<leader>e` | n | Toggle the file tree (neo-tree filesystem, left, 30 columns). Opening it moves the cursor into it | [00], [07] | config (neovim.nix:24) | Inside a Diffview tab it focuses Diffview's file panel instead. |
| `<leader>b` | n | Toggle the buffer list (neo-tree buffers, left) | [08] | config (neovim.nix:25) | Inside a Diffview tab it toggles Diffview's file panel. Whether it replaces an open file tree or stacks with it: verify on laptop-intel. |
| `<leader>o` | n | Toggle the outline (Aerial, left edge). Opening it moves the cursor into it | [05], [09] | config (neovim.nix:26) | Inside Aerial, `<C-j>` / `<C-k>` scroll instead of moving between windows. |
| `<leader>t` | n | Toggle the terminal (toggleterm, bottom, 15 rows) | [00], [06] | config (neovim.nix:27) | **Trap:** Normal mode only. `2<leader>t` does **not** open terminal 2; use `:2ToggleTerm`. [24] makes `<leader>t` count-aware: `2<leader>t` then opens terminal 2. Does nothing while only the Codex terminal is open. |

## Find

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<leader>ff` | n | Find files (Telescope) | [09] | config (neovim.nix:29) | Hides dotfiles. **Trap:** `file_ignore_patterns` (`neovim.nix:701`) are Lua patterns matched anywhere in the path, so `.git` also hides `.github/` and `home/modules/git.nix`, and `target` hides any path containing "target", such as `rust/fuzz/fuzz_targets/`. |
| `<leader>fg` | n | Live grep across the project | [09] | config (neovim.nix:30) | The prompt is a ripgrep regex, not fzf syntax. `<C-Space>` refines the current results with fuzzy matching. |
| `<leader>fb` | n | Pick an open buffer | [09] | config (neovim.nix:31) | `<M-d>` deletes the buffer under the cursor in the picker. |
| `<leader>fh` | n | Search help tags | [09] | config (neovim.nix:32) | – |

## Git

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<leader>gs` | n | Git status panel (neo-tree git_status, right, 40 columns) | [09], [12] | config (neovim.nix:34) | **Trap:** in this panel `gg` commits **and pushes**, `A` runs `git add -A` with no prompt, and `gr` reverts a file. It shares the right edge with the Claude split. |
| `<leader>gg` | n | Full git UI (Neogit) in its own tab | [12] | config (neovim.nix:35) | In Neogit, `<c-s>` stages everything and `q` closes the tab. |
| `<leader>gd` | n | Open Diffview (working tree against the index) | [12] | config (neovim.nix:36) | **Trap:** inside the Diffview tab, `<leader>e`, `<leader>b`, `<leader>co`, `<leader>cb`, `<leader>ca`, `<Tab>` and `<S-Tab>` belong to Diffview. There is no `q`: close with `<leader>gq`. The language-server `<leader>ca` is deleted from buffers Diffview showed: use `gra`. `:lsp restart` should bring it back (verify on laptop-intel). |
| `<leader>gq` | n | Close Diffview | [12] | config (neovim.nix:37) | – |
| `<leader>gh` | n | History of the current file (`DiffviewFileHistory %`) | [12] | config (neovim.nix:38) | – |

## AI

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<leader>cc` | n | Toggle Claude Code (native split, right, 30 %) | [13] | config (neovim.nix:40) | **Trap:** Claude is likely to start in auto permission mode, which applies edits with no in-editor diff. Press `Shift+Tab` until the status line says "manual mode on". Normal mode only: inside the Claude terminal these keys are typed into Claude. |
| `<leader>cb` | n | Send the whole buffer to Claude (`ClaudeCodeAdd %`) | [13] | config (neovim.nix:41) | Focus stays in the editor. Inside a Diffview tab it chooses BASE instead. |
| `<leader>cs` | v | Send the selection to Claude | [13] | config (neovim.nix:42) | Visual mode only. In the neo-tree file tree it sends the selected files. |
| `<leader>co` | n | Toggle the Codex CLI (a hidden toggleterm) | [06], [13] | config (neovim.nix:43) | Not reachable with `<leader>t` or `:ToggleTerm`; `:TermSelect!` lists it. Codex writes files directly, so run `:checktime` afterwards. Inside a Diffview tab it chooses OURS instead. |

## Code

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<leader>ca` | n | Code action | [10] | config (LSP buffer-local, neovim.nix:352; listed at :45) | Normal mode only: in Visual mode use `gra`. Lost from buffers shown by Diffview. |
| `<leader>cf` | n, v | Format the buffer (conform; language server as the fallback) | [11] | config (neovim.nix:987-989; listed at :46) | Global, so it also works in Markdown. `:w` formats as well, through format-on-save (`:974-977`). |
| `<leader>rn` | n | Rename the symbol | [10] | config (LSP buffer-local, neovim.nix:351; listed at :47) | `grn` does the same. |
| `gd` | n | Go to definition | [10] | config (LSP buffer-local, neovim.nix:340; listed at :48) | Replaces the built-in `gd` in language-server buffers. |
| `gD` | n | Go to declaration | [10] | config (LSP buffer-local, neovim.nix:341; listed at :49) | – |
| `gi` | n | Go to implementation | [10] | config (LSP buffer-local, neovim.nix:342; listed at :50) | Replaces the built-in `gi` (insert where you last left Insert mode) in language-server buffers. `gri` does the same job. |
| `gr` | n | List references | [10] | config (LSP buffer-local, neovim.nix:343; listed at :51) | **Trap:** `gr` is also the start of `grn` `gra` `grr` `gri` `grt` `grx`, so it waits 300 ms (`timeoutlen`) before running. `grr` runs at once. |
| `K` | n | Hover documentation | [10] | config (LSP buffer-local, neovim.nix:344; listed at :52) | – |
| `<leader>k` | n | Signature help | [10] | config (LSP buffer-local, neovim.nix:350; listed at :53) | Only where a server is attached. Moved off `<C-k>`, which is window-up. In Insert mode use `<C-s>`. |

## Diagnostics

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<leader>xx` | n | All diagnostics (Trouble) | [11] | config (neovim.nix:55) | Type `xx` briskly (see `<leader>x`). Trouble opens without taking focus: `<C-j>` goes into it. |
| `<leader>xw` | n | Diagnostics for this buffer (Trouble, `filter.buf=0`) | [11] | config (neovim.nix:56) | As above. |
| `<leader>ld` | n | Diagnostic under the cursor, in a float | [10] | config (LSP buffer-local, neovim.nix:358; listed at :57) | Language-server buffers only. `<C-w>d` does the same everywhere. |
| `[d` | n | Previous diagnostic, with a float | [10] | config (LSP buffer-local, neovim.nix:353; listed at :58) | In language-server buffers this version ignores counts: `3[d` moves one. |
| `]d` | n | Next diagnostic, with a float | [10] | config (LSP buffer-local, neovim.nix:354; listed at :59) | As above. Virtual text is off, so `]d`, `<leader>ld` and Trouble are how you read errors. |

## Buffers

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<Tab>` | n | Next buffer (`:bnext`) | [08] | config (neovim.nix:61) | **Trap:** it also takes over `<C-i>` (jump forward in the jumplist), even in Kitty ([02]). [23] maps `<C-i>` explicitly, which gives jump-forward back in Kitty. Telescope, Neogit, neo-tree, Diffview and the completion menu have their own `<Tab>`, which wins there. `]b` does the same. |
| `<S-Tab>` | n | Previous buffer (`:bprevious`) | [08] | config (neovim.nix:62) | `[b` does the same. |
| `<leader>x` | n | Close the buffer (`:bdelete`) | [05], [08] | config (neovim.nix:63) | **Trap:** it is also the start of `<leader>xx` and `<leader>xw`, and which-key labels it `+diagnostics`. Space and `x` typed together, then a pause, close the buffer 300 ms later; pausing for the popup first opens the group instead. While another listed buffer exists, `:bdelete` also closes every window showing the buffer. `:bd` is the unambiguous form. [26] moves close-buffer to `<leader>q`. |
| `<C-s>` | n | Save (`:w`) | [01] | config (neovim.nix:64) | Normal mode only; in Insert mode `<C-s>` is signature help. neo-tree (quick jump), Neogit (stage everything), Aerial and Trouble (open in a split) all have their own `<C-s>`. In a Claude diff it accepts the change. |
| `<C-q>` | n | `:q`, which closes the current **window** | [01], [08] | config (neovim.nix:65) | **Trap:** it does not quit Neovim while other windows are open; use `:qa`. In Telescope it sends the results to quickfix. In a Claude diff it rejects the change. |
| `<leader>h` | n | Clear search highlighting (`:nohlsearch`) | [04] | config (neovim.nix:66) | Needed because `<C-l>` moves to the right-hand window here. |

## Windows

| Keys | Mode | Action | Lesson | Where it comes from | Traps and notes |
|---|---|---|---|---|---|
| `<C-h>` | n | Move to the window on the left | [00], [08] | config (neovim.nix:68) | **Trap:** Normal mode only. In a terminal, press `<C-\><C-n>` first. |
| `<C-j>` | n | Move to the window below | [00], [08] | config (neovim.nix:69) | Inside Aerial it scrolls; in Neogit status it peeks. |
| `<C-k>` | n | Move to the window above | [00], [08] | config (neovim.nix:70) | As `<C-j>`. From the full-width terminal it goes to whichever window is above the cursor's column, which may be the tree. |
| `<C-l>` | n | Move to the window on the right | [00], [08] | config (neovim.nix:71) | It replaces Neovim's `<C-l>` (redraw and clear highlighting): use `<leader>h`. In Terminal mode it clears the shell's screen. |
| `<C-w>v` / `<C-w>s` | n | Split vertically (new window on the right) / horizontally (below) | [08] | Neovim default (`splitright`, `splitbelow`: neovim.nix:249-261) | – |
| `<C-w>=` / `<C-w>_` / `<C-w>\|` | n | Equalise sizes / maximise height / maximise width | [08] | Neovim default | – |
| `<C-w>o` / `<C-w>c` | n | Close every other window / close this one | [08] | Neovim default | – |
| `gt` / `gT` | n | Next / previous tab page | [08] | Neovim default | Neogit and `:checkhealth` open in tab pages. |

## Language-server maps (buffer-local)

The `LspAttach` autocmd (`neovim.nix:335-360`) sets these for each buffer as a server attaches. They are
all Normal mode. They exist in Rust, Python, Nix, Lua and TOML files, for example, but not in Markdown,
which has no server here. Check what is attached with `:checkhealth vim.lsp` ([10]).

| Keys | Runs | Line | Overlaps with |
|---|---|---|---|
| `gd` / `gD` | definition / declaration | :340 / :341 | the built-in `gd` / `gD` search |
| `gi` | implementation | :342 | the built-in `gi`; the 0.12 default `gri` |
| `gr` | references | :343 | the 0.12 defaults `grn` `gra` `grr` `gri` `grt` `grx` (hence the 300 ms wait) |
| `K` | hover | :344 | Neovim's own language-server `K` (same function) |
| `<leader>k` | signature help | :350 | – |
| `<leader>rn` | rename | :351 | `grn` |
| `<leader>ca` | code action | :352 | `gra` (which also works in Visual mode) |
| `[d` / `]d` | previous / next diagnostic, with a float, count ignored | :353 / :354 | the 0.12 defaults `[d` / `]d` (which honour a count) |
| `<leader>ld` | diagnostic float | :358 | `<C-w>d` |

## Completion (nvim-cmp, Insert mode)

Taught in [11]. The mappings are at `neovim.nix:300-324`; keys marked "preset" come from nvim-cmp's
`preset.insert`.

| Keys | Mode | Action | Where it comes from | Traps and notes |
|---|---|---|---|---|
| `<C-Space>` | i | Open the completion menu | config (neovim.nix:303) | – |
| `<CR>` | i | Confirm, taking the **first** item even if none is selected | config (neovim.nix:305) | **Trap:** with the menu open, Enter at the end of a word inserts a suggestion instead of a new line. Press `<C-e>` first. |
| `<Tab>` / `<S-Tab>` | i, s | Next / previous item. With no menu: expand or jump through a snippet, else a literal Tab | config (neovim.nix:306-323) | – |
| `<C-n>` / `<C-p>` | i | Next / previous item, inserting its text; opens the menu if it is closed | nvim-cmp preset | – |
| `<Down>` / `<Up>` | i | Next / previous item, without inserting | nvim-cmp preset | – |
| `<C-y>` | i | Confirm only an item you selected | nvim-cmp preset | The safe confirm. |
| `<C-e>` | i | Close the menu and restore what you typed | config (neovim.nix:304) | – |
| `<C-b>` / `<C-f>` | i | Scroll the documentation window | config (neovim.nix:301-302) | – |
| `:LuaSnipListAvailable` | c | List the snippets for the current filetype | LuaSnip default | Run it from a `.rs` or `.py` buffer: snippets load per filetype. |

The command line has no nvim-cmp completion (`cmp-cmdline` is installed but not set up). `<Tab>` there is
Neovim's own completion.

## Neovim 0.12 defaults worth knowing

These are built in, not in your config. They coexist with it, apart from the rows marked as replaced.
Lesson [05] tours them all; the Lesson column also names where each one is first met or used in earnest.

| Keys | Mode | Action | Lesson | Traps and notes |
|---|---|---|---|---|
| `grn` | n | Rename (language server) | [05], [10] | Same as `<leader>rn`. |
| `gra` | n, x | Code action | [05], [10] | Works in Visual mode, unlike `<leader>ca`. |
| `grr` | n | References | [05], [10] | Runs at once, unlike the config's `gr`. |
| `gri` | n | Implementation | [05], [10] | – |
| `grt` | n | Type definition | [05], [10] | The only type-definition key in this setup. |
| `grx` | n | Run the code lens | [05], [10] | – |
| `gO` | n | Document symbols into the location list; a table of contents in help, Markdown and `:checkhealth` buffers | [00], [05] | – |
| `<C-s>` | i, s | Signature help | [01], [10] | Normal-mode `<C-s>` is Save. |
| `]d` / `[d` | n | Next / previous diagnostic (honours a count) | [05], [10] | Replaced in language-server buffers by the config's versions. |
| `]D` / `[D` | n | Last / first diagnostic in the buffer | [05], [10] | – |
| `<C-w>d` | n | Diagnostic under the cursor, in a float | [05], [10] | The same as `<leader>ld`, and it works everywhere. |
| `]q` / `[q`, `]Q` / `[Q` | n | Next / previous quickfix entry; last / first | [05], [09] | – |
| `]l` / `[l` | n | Next / previous location-list entry | [05], [09] | – |
| `]b` / `[b`, `]B` / `[B` | n | Next / previous buffer; last / first | [05], [08] | These follow `:bnext` order, not a bufferline order you rearranged. |
| `<C-l>` | n | Redraw, clear search highlighting, update diffs | [04] | **Replaced** by the config's window-right. |

## Core editing (lessons 01 to 04)

All of these are Neovim defaults unless the row says otherwise.

### Modes and survival ([01])

| Keys | Mode | Action |
|---|---|---|
| `i` / `a` | n | Insert before / after the cursor |
| `I` / `A` | n | Insert at the start / end of the line |
| `o` / `O` | n | Open a new line below / above |
| `<Esc>` | i, v | Back to Normal mode |
| `:w` / `:q` / `:wq` / `:q!` / `:qa` | c | Save / close the window / save and close / close without saving / quit everything |
| `ZZ` / `ZQ` | n | Save and close / close without saving |
| `u` / `<C-r>` | n | Undo / redo. Undo history survives restarts (`undofile`, `neovim.nix:266`) |
| `.` | n | Repeat the last change |
| `:help {topic}` | c | Built-in help. `<leader>fh` searches it with Telescope |

### Motions ([02])

| Keys | Mode | Action |
|---|---|---|
| `h` `j` `k` `l` | n | Left, down, up, right. With `relativenumber` on (`neovim.nix:215`), `5j` goes to the line whose relative number is 5 |
| `w` `b` `e` / `W` `B` `E` / `ge` | n | Word start forward, back, end / the same for WORDs / end of the previous word |
| `0` / `^` / `$` | n | Line start / first non-blank / line end |
| `f{c}` `t{c}` `F{c}` `T{c}`, then `;` `,` | n | Find a character on the line, then repeat forwards or backwards |
| `gg` / `G` / `{N}G` | n | First line / last line / line N |
| `{` / `}` / `%` | n | Previous / next paragraph / matching bracket |
| `H` / `M` / `L` | n | Top / middle / bottom of the screen |
| `<C-d>` `<C-u>` / `<C-f>` `<C-b>` | n | Half a page down, up / a full page down, up |
| `zz` / `zt` / `zb` | n | Put the cursor line at the middle / top / bottom of the screen |
| `m{a-z}`, `'{a-z}`, `` `{a-z} `` | n | Set a mark, jump to its line, jump to its exact position |
| `<C-o>` / `<C-i>` | n | Back / forward in the jumplist. **Trap:** `<C-i>` runs `:bnext` here (see `<Tab>`) |

### Operators and text objects ([03])

| Keys | Mode | Action |
|---|---|---|
| `d` `c` `y` + motion | n | Delete / change / yank. The grammar is operator, count, motion or text object |
| `p` / `P` | n | Put after / before. Yanks also go to the system clipboard (`clipboard = unnamedplus`, `neovim.nix:257`) |
| `dd` `cc` `yy` / `D` `C` `Y` | n | The whole line / to the end of the line |
| `x` / `r{c}` / `~` / `J` | n | Delete a character / replace a character / toggle case / join lines |
| `gu` / `gU` + motion | n | Lower-case / upper-case |
| `iw` `aw`, `i"` `a"`, `i(` `a(`, `i{` `a{`, `it` `at`, `ip` | o, x | Text objects: inner or around a word, a quote, brackets, braces, a tag, a paragraph |
| `v` / `V` / `<C-v>` | n | Visual mode by character / by line / by block; in block mode `I` and `A` insert on every line |
| `o` / `gv` | x / n | Jump to the other end of the selection / reselect the last selection |
| `>` / `<` / `=` + motion | n, x | Indent / outdent / re-indent |
| `gcc` / `gc{motion}` / `gc` | n, n, x | Toggle a line comment (Comment.nvim default) |
| `gbc` / `gb{motion}` / `gb` | n, n, x | Toggle a block comment (Comment.nvim default) |
| `gco` / `gcO` / `gcA` | n | New comment line below / above / at the end of the line (Comment.nvim default) |
| `dgc` | n | Delete the comment block under the cursor (`gc` as a text object, Neovim default) |

nvim-autopairs (`neovim.nix:764`) closes brackets and quotes as you type them, and each pair it inserts
starts a new undo step ([03]). It is not wired to nvim-cmp, so it adds nothing when you accept a completion:
after a Python function, type the `(` yourself ([11]).

### Search, registers and macros ([04])

| Keys | Mode | Action |
|---|---|---|
| `/pattern` / `?pattern`, then `n` / `N` | n | Search forwards / backwards, then next / previous. Case is ignored unless you type a capital (`ignorecase`, `smartcase`) |
| `*` / `#` | n | Search for the word under the cursor, forwards / backwards |
| `:s/old/new/` / `:%s/old/new/g` | c | Substitute on this line / in the whole file. Add the flag `c` to confirm each change |
| `\<word\>` | c | Whole-word match inside a pattern |
| `cgn`, then `.` | n | Change the next match, then repeat on the following ones |
| `:g/pattern/cmd` | c | Run a command on every matching line |
| `"a` + operator, `"ap` | n | Use register `a`. `"0` holds the last yank, `"1`–`"9` recent deletes, `"+` the clipboard, `"_` the black hole, `"/` the last search |
| `:reg {name}` | c | Show one register (`:reg a`). A bare `:reg` also shows `"+` and `"*`: your clipboard and primary selection |
| `qa` … `q`, then `@a` / `@@` / `3@a` | n | Record a macro into `a`, then play it / repeat the last one / play it three times |
| `<leader>h` | n | Clear search highlighting (config, `neovim.nix:66`) |

## Inside plugin windows

A plugin's buffer-local keys beat your global ones inside its window. Where that hides one of your
bindings, the row says so.

### neo-tree: the Tree ([07]), buffers panel ([08]) and git_status panel ([12])

| Keys | Action | Traps and notes |
|---|---|---|
| `<CR>` / `<space>` | Open a file, or expand a folder / expand or collapse a folder | Space is mapped here, so which-key's leader popup does not appear. Leader combinations typed within 300 ms should still work (verify on laptop-intel). |
| `<BS>` / `.` | Root up one level / make the folder under the cursor the root | Filesystem panel |
| `H` | Show or hide the filtered (here: git-ignored) entries | Dotfiles always show; git-ignored ones (such as `rust/target/` and `.venv/`) start out shown, dimmed |
| `/` / `D` / `f` / `<C-x>` | Filter as you type / folders only / filter when you press Enter / clear the filter | Filesystem panel |
| `a` / `A` | Add a file (end the name with `/` for a folder) / add a folder | In the git_status panel `A` means something else (below) |
| `r` / `b` | Rename / rename without the extension | – |
| `d` / `T` | Delete / move to the trash (both ask first) | In the buffers panel `d` closes the buffer |
| `c` / `m` | Copy / move, prompting for the destination | – |
| `y` / `x` / `p` | Copy / cut / paste through neo-tree's own clipboard | – |
| `s` / `S` / `t` | Open in a vertical split / horizontal split / new tab | – |
| `P` / `i` / `R` | Toggle a floating preview / file details / rescan the disk | – |
| `C` / `z` | Close this node / collapse everything | – |
| `[g` / `]g` | Previous / next changed file that git already tracks | Untracked and ignored entries are skipped, so new files are never visited |
| `<` / `>` | Previous / next source (filesystem, buffers, git_status) | – |
| `?` / `q` | Help / close the panel | – |
| `<Tab>` / `<C-s>` / `<C-f>` `<C-b>` | Select a node / quick-jump labels / scroll the preview | These hide your `:bnext`, Save and page keys inside the tree |
| `w` | Window picker | Does not work: it needs a plugin that is not installed |
| `ga` / `gu` / `gt` | git_status panel: stage / unstage / toggle staging | – |
| `gr` / `gc` / `gp` | git_status panel: revert the file to HEAD (asks) / commit (prompts for a message) / push | – |
| `gg` | git_status panel: **commit and push** | **Trap:** it does not go to the top here; use `:1` |
| `A` | git_status panel: `git add -A`, with **no prompt** | **Trap** |

### Telescope ([09])

| Keys | Mode | Action |
|---|---|---|
| `<C-n>` / `<C-p>`, `<Down>` / `<Up>` | i | Next / previous result |
| `<CR>` | i, n | Open |
| `<C-x>` / `<C-v>` / `<C-t>` | i, n | Open in a horizontal split / vertical split / tab |
| `<C-u>` / `<C-d>` | i, n | Scroll the preview |
| `<Tab>` / `<S-Tab>` | i, n | Mark for multi-select and move |
| `<C-q>` / `<M-q>` | i, n | Send all results / the marked results to quickfix and open it. This hides your `<C-q>` |
| `<C-/>` / `?` | i / n | Show the picker's keys |
| `<C-c>` | i | Close |
| `<Esc>` | i, n | In the prompt it only switches to Normal mode; a second `<Esc>` closes |
| `j` / `k`, `gg` / `G`, `H` / `M` / `L` | n | Move through the results |
| `<M-d>` | i, n | Buffers picker: delete the buffer |
| `<C-Space>` | i | Live grep: refine the results with fuzzy matching |

Query syntax in find_files, buffers and help_tags: `'exact`, `^prefix`, `suffix$`, `!exclude`; a space
means AND and a lone `\|` means OR. Live grep takes a ripgrep regex instead. `<C-j>` does nothing in the
prompt, and `<C-k>` scrolls the preview sideways.

### Aerial ([09])

| Keys | Action |
|---|---|
| `<CR>` / `p` | Jump to the symbol / scroll the code to it but stay in the outline |
| `{` / `}` | Previous / next symbol |
| `[[` / `]]` | Up the tree backwards / forwards |
| `<C-j>` / `<C-k>` | Move down / up and scroll the code. This hides your window keys inside Aerial |
| `<C-v>` / `<C-s>` | Jump in a vertical / horizontal split |
| `o` or `za` / `l` or `zo` / `h` or `zc` | Toggle / expand / collapse a node |
| `zR` / `zM` | Expand / collapse everything |
| `q` / `?` or `g?` | Close / help |

Outside the outline `{` and `}` are still paragraph motions. Jump between symbols from code with
`:AerialNext` and `:AerialPrev`.

### Neogit ([12])

| Keys | Where | Action |
|---|---|---|
| `s` / `S` / `<c-s>` | status | Stage the item / all unstaged / everything. `<c-s>` hides your Save |
| `u` / `U` / `x` | status | Unstage the item / all staged / discard (asks first) |
| `V` then `s` / `u` / `x` | status | Stage / unstage / discard exactly the selected lines |
| `<tab>` or `za` | status | Fold or unfold the item. `<tab>` hides your `:bnext` |
| `{` / `}` / `<c-n>` / `<c-p>` | status | Previous / next hunk header / next / previous section |
| `<c-j>` / `<c-k>` | status | Peek down / up. This hides your window keys |
| `$` / `?` / `q` | status | Git command history / help / close the tab |
| `c` then `c` / `a` / `e` | status, then popup | Commit / amend / extend. In the popup, `-a` switches "all" on |
| `t` then `t` | status, on a commit | Tag popup, then create a tag on that commit ([18]) |
| `<c-c><c-c>` / `<c-c><c-k>` | commit editor | Commit / abort (Normal and Insert mode) |
| `ZZ` or `:wq` / `ZQ` / `q` | commit editor | Commit / abort / close (asks whether to save a changed message) |

`git commit` in a terminal opens Zed (`EDITOR`), so commit from Neogit or with fugitive's `:Git commit`.

### Diffview ([12])

| Keys | Where | Action |
|---|---|---|
| `<tab>` / `<s-tab>` | diff and panel | Next / previous file's diff. This hides buffer cycling |
| `<leader>e` / `<leader>b` | diff and panel | Focus / toggle the file panel. This hides the tree toggles |
| `[x` / `]x` | diff | Previous / next conflict |
| `<leader>co` `<leader>ct` `<leader>cb` `<leader>ca` | diff | Choose OURS / THEIRS / BASE / ALL for this conflict. This hides Codex, send-buffer and code action |
| `dx`, `2do` / `3do` | diff | Delete this conflict region; take the OURS / THEIRS hunk |
| `]c` / `[c`, `do` / `dp` | diff | Next / previous change; get / put a hunk (Neovim diff mode) |
| `g<C-x>` / `g?` | diff and panel | Cycle the layout / help |
| `j` / `k`, `<cr>` | file panel | Move; open the file's diff |
| `-` or `s` / `S` / `U` | file panel | Stage or unstage the entry / stage everything / unstage everything |

There is no `q` in Diffview. Close it with `<leader>gq` or `:DiffviewClose`. `:DiffviewOpen --staged` shows
only what the next commit will contain.

### Trouble ([11])

| Keys | Action |
|---|---|
| `<cr>` / `o` | Jump to the item / jump and close Trouble |
| `}` or `]]` / `{` or `[[` | Next / previous item |
| `p` / `P` | Preview / toggle auto-preview |
| `<c-s>` / `<c-v>` | Open in a horizontal / vertical split. `<c-s>` hides your Save |
| `gb` / `s` | Toggle the current-buffer filter / cycle the severity filter |
| `dd` | Remove the item from the list (not from the code) |
| `zo` / `zc`, `zR` / `zM` | Open / close a group; open / close every group |
| `?` / `q` | Help / close |

`j` and `k` are plain cursor motion, and the preview follows the cursor. Trouble opens without taking
focus: press `<C-j>` to go into it.

### Terminal mode, toggleterm and Codex ([06], [13])

| Keys or command | Mode | Action | Traps and notes |
|---|---|---|---|
| `<C-\><C-n>` | t | Leave Terminal mode | **Trap:** none of your bindings work in Terminal mode. `<Esc>` goes to the program, and must stay that way because Claude and Codex use `Esc` and `Esc Esc` |
| `<C-\><C-o>{cmd}` | t | Run one Normal-mode command, then return | – |
| `i` / `a` | n (terminal buffer) | Back into Terminal mode | A terminal you left in Normal mode comes back in Normal mode (`persist_mode`) |
| `[[` / `]]` | n (terminal buffer) | Previous / next shell prompt | Needs prompts marked with OSC 133 (verify on laptop-intel) |
| `:ToggleTerm` / `:2ToggleTerm` | c | Toggle the terminals / terminal 2 | `<leader>t` cannot pass a count |
| `:TermSelect` / `:TermSelect!` | c | Pick a terminal; `!` also lists hidden ones such as Codex | – |
| `:ToggleTermToggleAll` | c | Open or close every non-hidden terminal | Never Codex |
| `:TermNew` | c | Open a new terminal with the next free number | – |
| `:2ToggleTermSetName python` | c | Name terminal 2 in the lists | – |
| `:TermExec cmd="…"` | c | Type a command into a terminal from any window, and press Enter | Without a count it uses the first terminal; `:2TermExec` picks terminal 2 |
| `:CodexToggle` | c | The command behind `<leader>co` | – |
| `:checktime` | c | Reload buffers that changed on disk | Run it after Codex edits files |

### Claude Code ([13])

| Keys or command | Where | Action |
|---|---|---|
| `:ClaudeCode [args]` / `:ClaudeCodeFocus` | Neovim | Toggle / focus Claude. Arguments such as `--permission-mode manual` only apply when no Claude is running |
| `:ClaudeCodeAdd <path>` / `:ClaudeCodeTreeAdd` | Neovim | Add a file / add the file under the cursor in the neo-tree file tree |
| `:w` or `<C-s>` / `:q` or `<C-q>` | proposed diff | Accept / reject Claude's edit. You can edit the proposal first |
| `]c` / `[c` / `do` | proposed diff | Next / previous change / take the original text back for this hunk |
| `:ClaudeCodeDiffAccept` / `:ClaudeCodeDiffDeny` | proposed diff | The same as commands |
| `Shift+Tab` | Claude prompt | Cycle the permission modes. You want "manual mode on" to review diffs |
| `Esc` / `Esc Esc` | Claude prompt | Interrupt / clear the draft, or open the rewind menu when the prompt is empty |
| `@` / `!` / `\` then Enter, or `Ctrl+J` | Claude prompt | Mention a file / shell mode / new line |
| `/ide` `/resume` `/rewind` `/diff` | Claude prompt | Connect to Neovim / resume a session / rewind / review changes |

A diff will not open over a buffer with unsaved changes, so save first. Accepted edits skip
format-on-save, so press `<C-s>` in the real buffer afterwards. `Ctrl+G` in Claude opens the prompt in Zed.
In Codex: `/permissions`, `/review`, `/diff`, `/resume`, `@` for files and `Esc` to interrupt.

### Gitsigns and fugitive ([12])

Gitsigns has **no** keys in this config (`neovim.nix:736-744` only sets the signs). Use the commands:
`:Gitsigns nav_hunk next` / `prev` / `first` / `last`, `preview_hunk`, `preview_hunk_inline`, `stage_hunk`
(run it on a staged hunk to unstage it; `:'<,'>Gitsigns stage_hunk` stages selected lines), `reset_hunk`,
`blame_line`, `toggle_current_line_blame`, `blame` and `setqflist all`. `@:` repeats the last one. Brand-new
(untracked) files show no signs. [28] adds hunk keys: `]h`/`[h`, `<leader>gp`, `<leader>ga`,
`<leader>gr` and `<leader>gb`.

| Keys or command | Where | Action |
|---|---|---|
| `:Git` | Neovim | fugitive's summary window |
| `s` / `u` / `=` | summary | Stage / unstage / inline diff |
| `cc` | summary | Commit |
| `gq` / `g?` | summary | Close (plain `q` records a macro) / help |
| `:Git commit` | Neovim | Write the message in a split; `:wq` commits |
| `:Git blame` / `:Gvdiffsplit` | Neovim | Blame split (`gq` closes) / vimdiff against the index |

### Quickfix ([09])

| Keys or command | Action |
|---|---|
| `:copen` / `:cclose` | Open / close the quickfix window |
| `<CR>` | Jump to the entry under the cursor |
| `]q` / `[q` | Next / previous entry |
| `:cdo {cmd}` / `:cfdo {cmd}` | Run a command on every entry / every file |
| `:colder` / `:cnewer` | Older / newer quickfix list |

## Hyprland

From `config/hypr/60-keybinds.lua` unless noted. Lesson [00] teaches the launch keys, [05] the RETURN and
Z families, and [09] moving between the dev layout's windows. Only the Hyprland keys that a lesson uses are
listed; `~/.config/hypr/KEYBINDS.md` (`SUPER + /`) covers the rest, but it is hand-maintained and has drifted.

| Keys | Action | Lesson | Traps and notes |
|---|---|---|---|
| `SUPER + RETURN` | Plain Kitty (:25) | [00] | On laptop-intel it opens on workspace 10 without switching (`devices/laptop-intel.lua:115-121`): press `SUPER + 0` |
| `SUPER + SHIFT + RETURN` | `dev-layout --nvim`: the nix-config layout on workspace 2 (:26) | [00] | Only focuses workspace 2 if anything is already there. Full config only |
| `SUPER + CTRL + RETURN` | `dev-layout-pick --nvim`: wofi picker, then a layout on the first free workspace from 3 to 5 (:27) | [00], [09] | Lists `<account>/<project>` folders only. Full config only |
| `SUPER + ALT + RETURN` | `kitty -e nvim`: a bare Neovim in `$HOME` (:28) | [00] | Opens on workspace 10 |
| `SUPER + Z` / `SUPER + SHIFT + Z` / `SUPER + CTRL + Z` | Zed / Zed nix-config layout / Zed picker (:34, :50-51) | [05] | A Zed layout on workspace 2 blocks the Neovim one |
| `SUPER + /` | The **Hyprland** cheat sheet in `less` (:79) | [00] | Not the Neovim one, and hand-maintained, so it has drifted |
| `SUPER + Escape` | Workspace 1 dashboard (`devices/laptop-intel.lua:258-259`) | [05] | laptop-intel only. It shows the Hyprland cheat sheet, not the Neovim one |
| `SUPER + H` / `J` / `K` / `L`, or `SUPER` plus an arrow | Move focus between windows (:129-138) | [00], [09] | Between Kitty windows. Inside Neovim use `<C-h/j/k/l>` |
| `SUPER + Q` | Close the window (:93) | [00] | Prefer `:qa` for Neovim, so plugins shut down cleanly |
| `SUPER + F11` | Toggle full screen for the focused window (:96) | [16], [18] | Gives a TUI capstone the whole screen |
| `SUPER + 1` … `9`, `SUPER + 0` | Go to workspace 1 to 9, and 10 (:159-163) | [00] | 1 dashboard, 2 nix-config layout, 3 to 5 dev pool, 10 catch-all |

Focus follows the mouse (`follow_mouse = 1`, `config/hypr/30-input.lua:12`), so park the pointer.

## Traps at a glance

| Trap | Where it bites | Taught in | Fixed in |
|---|---|---|---|
| Space `x`, then a pause, closes the buffer (and its windows) | `<leader>x` | [05], [08] | [26] |
| `<Tab>` also takes over `<C-i>` (jump forward) | the jumplist | [02] | [23] |
| `2<leader>t` does not reach terminal 2 | terminals | [06] | [24] |
| None of your bindings work in Terminal mode; never map `<Esc>` there | ToggleTerm, Codex, Claude | [06], [13] | [28] (optional keys that avoid `<Esc>`) |
| `<C-q>` closes a window, not Neovim | quitting | [01] | – |
| `<C-l>` does not clear search highlighting | search | [04] | – |
| Virtual text is off, so errors do not show inline | diagnostics | [10] | – |
| `gr` waits 300 ms; `grr` does not | references | [10] | – |
| `<CR>` accepts the first completion | Insert mode | [11] | – |
| Saving reformats the whole file: nixfmt for Nix, `lua_ls` for Lua, taplo for TOML | `<C-s>`, `:w` | [11], [22] | – (save with `:noautocmd w`) |
| git_status panel: `gg` pushes, `A` stages everything | `<leader>gs` | [12] | – |
| Diffview takes over `<leader>e` `b` `co` `cb` `ca` and `<Tab>` | `<leader>gd` | [12] | – |
| Claude's auto mode applies edits without a diff | `<leader>cc` | [13] | [27] |
| Buffers go stale after Codex edits | `<leader>co` | [13] | – |
| pyright's `diagnosticsMode` typo | Python diagnostics | [10] | [25] |
| Telescope ignore patterns hide `.github`, `git.nix` and paths containing "target" | `<leader>ff` | [09] | – |
| Gitsigns has no keys: hunks need `:Gitsigns …` commands | hunks | [12] | [28] |
| `git commit` opens Zed | any terminal | [06], [12] | – |
| New Kitty windows land on workspace 10 (`SUPER + 0`) | `SUPER + RETURN`, `SUPER + ALT + RETURN` | [00] | – |

[00]: ../lessons/00-SETUP-AND-ORIENTATION.md
[01]: ../lessons/01-MODES-AND-SURVIVAL.md
[02]: ../lessons/02-MOTIONS.md
[03]: ../lessons/03-OPERATORS-AND-TEXT-OBJECTS.md
[04]: ../lessons/04-SEARCH-REGISTERS-MACROS.md
[05]: ../lessons/05-YOUR-KEYBINDINGS.md
[06]: ../lessons/06-TERMINAL.md
[07]: ../lessons/07-TREE.md
[08]: ../lessons/08-FILE-PANE.md
[09]: ../lessons/09-PROJECT-PANE.md
[10]: ../lessons/10-LSP.md
[11]: ../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md
[12]: ../lessons/12-GIT.md
[13]: ../lessons/13-CLAUDE-CODE-AND-CODEX.md
[16]: ../lessons/16-JUST-PANEL-RUNNING-RECIPES.md
[18]: ../lessons/18-SESSION-BROWSER-TUI-SKELETON.md
[22]: ../lessons/22-MAKING-THE-CONFIG-YOURS.md
[23]: ../lessons/23-FIX-JUMP-FORWARD.md
[24]: ../lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md
[25]: ../lessons/25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md
[26]: ../lessons/26-FIX-CLOSE-BUFFER-KEY.md
[27]: ../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md
[28]: ../lessons/28-GOING-FURTHER.md
