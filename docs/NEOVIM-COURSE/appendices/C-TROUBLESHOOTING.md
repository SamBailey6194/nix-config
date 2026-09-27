# Appendix C — Troubleshooting

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Symptom first, then the cause in this config, then the fix, then the lesson that covers it. The entries
are grouped by area. Search this page from Neovim with `/` and a word from what you see. Line numbers
like `neovim.nix:61` refer to `home/modules/neovim.nix`. Several traps have a lesson of their own that
changes the config to remove them, lessons 23 to 28; [lesson 22](../lessons/22-MAKING-THE-CONFIG-YOURS.md)
shows the safe way to make any such change. Problems with recordings, including a `vhs` that exits 0 and
writes nothing, are covered in [Appendix B](B-RECORDING-WITH-VHS.md#troubleshooting).

Where a fix is marked *verify on laptop-intel*, it follows from the documentation but has not been
tried on the real machine.

## Contents

- [Starting out and the dev layout](#starting-out-and-the-dev-layout)
- [Keys and modes](#keys-and-modes)
- [Terminals](#terminals)
- [Tree, buffers and search](#tree-buffers-and-search)
- [LSP and toolchains](#lsp-and-toolchains)
- [Completion and formatting](#completion-and-formatting)
- [Git](#git)
- [Claude Code and Codex](#claude-code-and-codex)
- [Capstone milestones](#capstone-milestones)
- [just and just-panel](#just-and-just-panel)
- [Nix builds and packaging](#nix-builds-and-packaging)
- [session-browser and Python](#session-browser-and-python)

## Starting out and the dev layout

### `nvim` will not start on the Ubuntu machine

- **Cause:** `/usr/local/bin/nvim` there is a 9-byte text file that says `Not Found`, left by a failed
  download.
- **Fix:** the course runs on laptop-intel. On Ubuntu, remove the stub (`sudo rm /usr/local/bin/nvim`)
  before you install Neovim another way.
- **See:** [lesson 00](../lessons/00-SETUP-AND-ORIENTATION.md).

### `SUPER + SHIFT + RETURN` only switches to workspace 2

- **Cause:** the nix-config layout is idempotent. If workspace 2 holds *any* window, including a Zed
  layout from `SUPER + SHIFT + Z`, `dev-layout` just focuses it (rust/dev-layout/src/main.rs:243-252).
- **Fix:** close the windows on workspace 2 (`SUPER + Q`) and press the keys again.
- **See:** [lesson 00](../lessons/00-SETUP-AND-ORIENTATION.md), [lesson 09](../lessons/09-PROJECT-PANE.md).

### `SUPER + SHIFT + RETURN` or `SUPER + CTRL + RETURN` does nothing at all

- **Cause:** `dev-layout`, `just` and the Rust tools are only installed by the **full** configuration
  (modules/core/common.nix:88, :96-97). On `laptop-intel-dev`, `-productivity` and `-creative`,
  `SUPER + SHIFT + RETURN` therefore does nothing, and `SUPER + CTRL + RETURN` shows its picker but
  builds nothing: `dev-layout-pick` comes from the desktop stage (home/modules/hyprland.nix:135) and
  hands over to the missing `dev-layout`. Errors from a keybind go to `notify-send`, not a terminal.
- **Fix:** `sudo nixos-rebuild switch --flake .#laptop-intel` from the repo.
- **See:** [lesson 00](../lessons/00-SETUP-AND-ORIENTATION.md).

### The picker (`SUPER + CTRL + RETURN`) does not offer `rust/just-panel`

- **Cause:** `dev-layout-pick` lists `<account>/<project>` folders two levels below `~/Repos`
  (home/modules/hyprland.nix:135-178), so it cannot reach a folder inside a project.
- **Fix:** from a terminal, run `dev-layout --new --nvim ~/Repos/personal/nix-config/rust/just-panel`.
- **See:** [lesson 09](../lessons/09-PROJECT-PANE.md).

### The Kitty window from `SUPER + RETURN` did not appear

- **Cause:** on laptop-intel a catch-all window rule sends every ordinary new window to workspace 10
  without switching to it (config/hypr/devices/laptop-intel.lua:115-121). That includes
  `SUPER + ALT + RETURN`, windows started by `kitty --detach` and your own Hyprland keys.
- **Fix:** `SUPER + 0` goes to workspace 10.
- **See:** [lesson 00](../lessons/00-SETUP-AND-ORIENTATION.md).

### `nvim` opened a tree and a terminal, but `nvim file` did not

- **Cause:** the dock layout runs only on a bare start (neovim.nix:889-905). A file argument, `nvim .`
  or piped input skips it. `SUPER + ALT + RETURN` gets the layout rooted at `$HOME`.
- **Fix:** nothing is wrong. Open the panels yourself with `<leader>e` and `<leader>t`.
- **See:** [lesson 00](../lessons/00-SETUP-AND-ORIENTATION.md).

## Keys and modes

### Pausing after Space x closed my buffer

- **Cause:** `<leader>x` is "close buffer" (neovim.nix:63) *and* the prefix of `<leader>xx` /
  `<leader>xw` (neovim.nix:55-56). After Space x, Neovim waits `timeoutlen` (300 ms) for another key,
  then runs `:bdelete`. The which-key popup labels `x` as `+diagnostics`, so the danger is invisible.
  `:bdelete` also closes every window that showed the buffer, so a split can vanish with it.
- **Fix:** type Space x x in one quick movement. Reopen the buffer you just closed with `:e #`. To
  close a buffer but keep its window, use `:bp | bd #`. For a permanent fix,
  [lesson 26](../lessons/26-FIX-CLOSE-BUFFER-KEY.md) moves close-buffer to `<leader>q`.
- **See:** [lesson 05](../lessons/05-YOUR-KEYBINDINGS.md), [lesson 08](../lessons/08-FILE-PANE.md),
  [lesson 26](../lessons/26-FIX-CLOSE-BUFFER-KEY.md).

### `<C-i>` switches buffers instead of jumping forward

- **Cause:** `<Tab>` runs `:bnext` (neovim.nix:61). While only `<Tab>` is mapped, the map applies to
  `<C-i>` too, even in Kitty. `:verbose nmap <C-i>` still says `No mapping found`.
- **Fix:** [lesson 23](../lessons/23-FIX-JUMP-FORWARD.md) maps `<C-i>` explicitly, which gives
  jump-forward back in Kitty. Or remove the `<Tab>` maps and use Neovim's `]b` / `[b` for buffers.
- **See:** [lesson 02](../lessons/02-MOTIONS.md), [lesson 23](../lessons/23-FIX-JUMP-FORWARD.md).

### `<C-l>` no longer clears the search highlight

- **Cause:** `<C-l>` is "window right" (neovim.nix:71), which replaces Neovim's default
  clear-and-redraw.
- **Fix:** Space h (`<leader>h`, neovim.nix:66), or `:nohlsearch`.
- **See:** [lesson 04](../lessons/04-SEARCH-REGISTERS-MACROS.md).

### `<C-q>` did not quit Neovim

- **Cause:** `<C-q>` is `:q` (neovim.nix:65), which closes the current **window**. With the tree and
  terminal docks open, Neovim keeps running. In Telescope, `<C-q>` sends the results to the quickfix
  list instead.
- **Fix:** `:qa` to quit everything; running terminal jobs end with it. `:qa!` is only needed to throw
  away unsaved changes.
- **See:** [lesson 01](../lessons/01-MODES-AND-SURVIVAL.md), [lesson 08](../lessons/08-FILE-PANE.md).

### `<C-s>` in Insert mode shows a popup instead of saving

- **Cause:** the config's save is Normal mode only (neovim.nix:64). In Insert mode, `<C-s>` is
  Neovim's own signature help. In other windows it means something else: Neogit status stages
  everything, neo-tree jumps and aerial splits.
- **Fix:** `<Esc>` then `<C-s>`.
- **See:** [lesson 01](../lessons/01-MODES-AND-SURVIVAL.md).

### `gr` waits before listing references

- **Cause:** in buffers with a language server, `gr` is buffer-local "references" (neovim.nix:343). It
  is also the start of Neovim's own `grn`, `gra`, `grr`, `gri`, `grt` and `grx`, so Neovim waits
  300 ms to see which you meant.
- **Fix:** `grr` gives references at once.
- **See:** [lesson 10](../lessons/10-LSP.md).

### `3]d` moves only one diagnostic

- **Cause:** the config's `]d` / `[d` (neovim.nix:353-354) hard-code a step of one. In buffers without
  a language server, Neovim's own `]d` does take a count.
- **Fix:** press `]d` three times, or use Trouble (`<leader>xx`).
- **See:** [lesson 10](../lessons/10-LSP.md).

### `<leader>k`, `<leader>rn`, `<leader>ca` or `gd` do nothing

- **Cause:** these are buffer-local LSP maps (neovim.nix:335-360). They only exist where a language
  server is attached.
- **Fix:** see [The language server does not attach](#the-language-server-does-not-attach). After
  Diffview, see [`<leader>ca` stopped working after Diffview](#leaderca-stopped-working-after-diffview).
- **See:** [lesson 10](../lessons/10-LSP.md).

### `<leader>cs` does nothing

- **Cause:** it is a Visual-mode map (neovim.nix:42).
- **Fix:** select first (`v`, `V`), then Space c s.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### My keys do something else inside a panel

- **Cause:** buffer-local maps beat global ones.
  - `<Tab>` is "select" in neo-tree, "toggle selection" in Telescope, "fold" in Neogit and "next
    file" in Diffview.
  - `<C-j>` / `<C-k>` scroll in aerial and peek in Neogit.
- **Fix:** leave the panel first (`q`, or `<C-h>` / `<C-l>`).
- **See:** [lesson 05](../lessons/05-YOUR-KEYBINDINGS.md).

### No which-key popup when I press Space inside the tree

- **Cause:** neo-tree maps `<space>` itself (expand or collapse), so which-key installs no popup
  there.
- **Fix:** the leader keys still work if you type them within 300 ms.
- **See:** [lesson 07](../lessons/07-TREE.md).

## Terminals

### `Esc` does not leave the terminal

- **Cause:** in Terminal mode, every key except `<C-\>` goes to the program (`:help terminal-input`).
  The config defines no Terminal-mode maps.
- **Fix:** `<C-\><C-n>`. Do **not** map `<Esc>` to it: Claude and Codex use `Esc` to interrupt and
  `Esc Esc` to rewind or edit. For quicker exits, [lesson 28](../lessons/28-GOING-FURTHER.md) adds
  Terminal-mode window keys, `Alt+h/j/k/l`, that leave `Esc` alone.
- **See:** [lesson 06](../lessons/06-TERMINAL.md), [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md),
  [lesson 28](../lessons/28-GOING-FURTHER.md).

### `<C-h/j/k/l>`, `<leader>t` or `<leader>cc` do nothing in a terminal, or type into it

- **Cause:** all the config's maps are Normal mode (neovim.nix:82). In Claude, `Ctrl+J` inserts a
  newline, `Ctrl+K` deletes to the end of the line and `Ctrl+L` redraws. In zsh, `Ctrl+L` clears the
  screen.
- **Fix:** `<C-\><C-n>` first, then the key.
- **See:** [lesson 06](../lessons/06-TERMINAL.md).

### `2<leader>t` did not open terminal 2

- **Cause:** `<leader>t` is a `<cmd>ToggleTerm<CR>` map (neovim.nix:27). A `<Cmd>` map never passes the
  count you type before it on to the command, so `2<leader>t` does the same smart toggle as `<leader>t`.
- **Fix:** `:2ToggleTerm`. [Lesson 24](../lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md) makes `<leader>t`
  count-aware: `2<leader>t` then opens terminal 2. The hidden Codex terminal takes one of the numbers
  too; `:TermSelect!` lists it with the others.
- **See:** [lesson 06](../lessons/06-TERMINAL.md), [lesson 24](../lessons/24-FIX-COUNTED-TERMINAL-TOGGLE.md).

### `<leader>t` does nothing

- **Cause:** only the hidden Codex terminal is open. toggleterm sees an open terminal window, tries to
  close the visible terminals, and finds none to close.
- **Fix:** hide Codex with `<leader>co` first, or open the shell by number (`:1ToggleTerm`).
- **See:** [lesson 06](../lessons/06-TERMINAL.md).

### The terminal came back in Normal mode

- **Cause:** toggleterm remembers the mode you left it in (`persist_mode`, on by default). A brand-new
  terminal can start in Normal mode too: `:2ToggleTerm` typed in the editor window, while terminal 1 was
  left in Normal mode, opens terminal 2 in Normal mode.
- **Fix:** press `i`.
- **See:** [lesson 06](../lessons/06-TERMINAL.md).

### `git commit` in a terminal opened Zed

- **Cause:** `core.editor`, `EDITOR` and `VISUAL` are `zeditor --wait` (home/modules/git.nix:21,
  home/stages/dev.nix:74-77).
- **Fix:** commit from Neogit (`<leader>gg`, then `c` `c`, then `<c-c><c-c>`) or fugitive
  (`:Git commit`). For one commit from the shell, use `GIT_EDITOR=nvim git commit`.
- **See:** [lesson 06](../lessons/06-TERMINAL.md), [lesson 12](../lessons/12-GIT.md).

## Tree, buffers and search

### `rust/target/` and `.venv/` show up in the tree

- **Cause:** `filtered_items.visible = true` shows gitignored items dimmed rather than hiding them
  (neovim.nix:654-658).
- **Fix:** collapse them, or press `H` in the tree to toggle filtered items.
- **See:** [lesson 07](../lessons/07-TREE.md).

### `gg` in the git status panel committed and pushed

- **Cause:** in neo-tree's `git_status` panel (`<leader>gs`), `gg` means "commit and push". `A` runs
  `git add -A` without asking, and `gr` reverts a file.
- **Fix:** in that panel, go to the top with `1G` or `:1`. A push cannot be undone from the panel:
  fix it with git.
- **See:** [lesson 12](../lessons/12-GIT.md).

### `w` in the tree only prints a message about a window picker

- **Cause:** that action needs the `nvim-window-picker` plugin, which is not installed.
- **Fix:** open in a split with `S`, `s` or `t` instead.
- **See:** [lesson 07](../lessons/07-TREE.md).

### Telescope cannot find `.github/…` or a file with "target" in its name

- **Cause:** `file_ignore_patterns` (neovim.nix:701) are Lua patterns, matched anywhere in the
  relative path. In `".git"` the dot matches any character, so every path with a character followed by
  "git" is hidden: `.github/`, but also `home/modules/git.nix` and `tapes/12-git.tape`. `"target"`
  hides every path containing it, `rust/fuzz/fuzz_targets/*.rs` included. `find_files` also skips
  dotfiles by default.
- **Fix:** `:Telescope find_files hidden=true` for dotfiles. For the patterns, tighten them in
  neovim.nix:701 (for example `"%.git/"` and `"/target/"`) and rebuild.
- **See:** [lesson 09](../lessons/09-PROJECT-PANE.md).

### `Esc` does not close Telescope

- **Cause:** the first `Esc` only moves the prompt into Normal mode.
- **Fix:** press `Esc` twice, or `<C-c>`.
- **See:** [lesson 09](../lessons/09-PROJECT-PANE.md).

### `'exact` or `^prefix` does nothing in live grep

- **Cause:** the `live_grep` prompt is a ripgrep regular expression. The fzf-style syntax only works
  in `find_files`, `buffers` and `help_tags`.
- **Fix:** write a regex. Or press `<C-Space>` in live grep to refine the results with fzf syntax.
- **See:** [lesson 09](../lessons/09-PROJECT-PANE.md).

## LSP and toolchains

### The language server does not attach

- **Cause:** the most common are:
  - the wrong filetype;
  - the server is not on `PATH`;
  - for Rust, a crate outside the workspace;
  - for Python, a file outside the project.
- **Fix:** work through these in order.
  1. `:checkhealth vim.lsp` lists the clients attached to the buffer and their root folders.
  2. `:set filetype?` checks the filetype.
  3. Find the server. rust-analyzer comes from rustup (neovim.nix:426): `command -v rust-analyzer`.
     pyright and ruff are pinned in the config.
  4. **Rust:** the root is the Cargo **workspace** (`rust/`), so `rust/just-panel` must be listed in
     `members` in `rust/Cargo.toml`. After changing it, run `:LspCargoReload` or restart Neovim.
  5. **Python:** open files under `python/session-browser`, whose `pyproject.toml` marks the root.
- **See:** [lesson 10](../lessons/10-LSP.md).

### rust-analyzer is missing, or "not installed for the toolchain"

- **Cause:** the config installs `rustup` only (modules/software/development.nix:82-84). The toolchain
  and its components are set up once, by hand.
- **Fix:** `rustup default stable && rustup component add rust-analyzer`. If Rust files are not
  formatted either, also run `rustup component add rustfmt clippy`.
- **See:** [lesson 10](../lessons/10-LSP.md).

### Two different Rust toolchains, or a build failing on `openssl-sys`

- **Cause:** there are two toolchains.
  - Neovim started by the dev layout uses **rustup**'s `cargo` and rust-analyzer.
  - A zsh inside the repo loads the flake's dev shell automatically (`.envrc` is `use flake`). That
    shell puts nixpkgs' Rust 1.98 `cargo`, `rust-analyzer`, `clippy` and `rustfmt` first, plus
    OpenSSL.

  Outside the dev shell, a workspace-wide build fails on `openssl-sys`, because `wireguard-helper` and
  `malware-scanner` need it (justfile:297-300).
- **Fix:**
  - Scope commands to your crate: `cargo build -p just-panel`, `cargo test -p just-panel`,
    `cargo clippy -p just-panel --all-targets -- -D warnings`.
  - Or use `just build-rust` / `just test-rust`, which run inside `nix develop`.
  - Or start Neovim from a shell inside the repo, so editor and terminal share one toolchain.

  If rust-analyzer's clippy check shows `openssl-sys` errors from other crates, the same fixes apply
  (verify on laptop-intel).
- **See:** [lesson 06](../lessons/06-TERMINAL.md), [lesson 10](../lessons/10-LSP.md).

### pyright: `Import "textual" could not be resolved`

- **Cause:** pyright looks for `[tool.pyright]` `venvPath` and `venv`, then a `python.pythonPath` setting,
  then the `python` on `PATH`: the system Python, which has no Textual or pytest. `uv run` always uses
  `.venv`, but pyright knows nothing about uv. How you started Neovim makes no difference.
- **Fix:**
  1. Check that `[tool.pyright]` in `python/session-browser/pyproject.toml` has `venvPath = "."` and
     `venv = ".venv"`. The capstone gets them at SB3, in lesson 10; before that milestone the import
     errors are expected.
  2. Check that `.venv` exists (`uv sync`).
  3. `:lsp restart pyright`, so pyright reads its configuration again.
- **See:** [lesson 10](../lessons/10-LSP.md).

### Python files show no diagnostics at all

- **Cause:** the capability set at neovim.nix:365-380 (`diagnostic.dynamicRegistration = false`) is
  load-bearing. Without it, pyright never delivers diagnostics to Neovim.
- **Fix:** if you edited that block, restore it and rebuild.
- **See:** [lesson 10](../lessons/10-LSP.md).

### pyright only reports files I have open

- **Cause:** neovim.nix:402 says `diagnosticsMode`. Pyright's key is `diagnosticMode`, so the setting is
  ignored and pyright stays on "open files only".
- **Fix:** [lesson 25](../lessons/25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md) corrects the key.
- **See:** [lesson 10](../lessons/10-LSP.md), [lesson 25](../lessons/25-FIX-PYRIGHT-DIAGNOSTIC-MODE.md).

### Errors show only as signs, with no text in the buffer

- **Cause:** Neovim 0.11 turned inline diagnostic text (`virtual_text`) off by default, and the config
  does not turn it on.
- **Fix:** `]d` (jumps and opens a float), `<leader>ld` or `<C-w>d` for the line, `<leader>xx` for the
  list.
- **See:** [lesson 10](../lessons/10-LSP.md), [lesson 11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md).

### `<leader>ca` stopped working after Diffview

- **Cause:** inside its tab, Diffview replaces `<leader>ca` in the file's buffer with "choose all
  versions". When it closes, it deletes that map and does not restore the LSP one.
- **Fix:** restart Neovim. `:lsp restart` should re-run the LSP setup and bring the map back (verify
  on laptop-intel). Neovim's own `gra` works meanwhile.
- **See:** [lesson 12](../lessons/12-GIT.md).

## Completion and formatting

### Enter inserted a completion instead of a new line

- **Cause:** `<CR>` confirms the **first** item whenever the menu is open (`select = true`,
  neovim.nix:305).
- **Fix:** `<C-e>` closes the menu, then press Enter.
- **See:** [lesson 11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md).

### Saving reformatted the whole file

- **Cause:** format-on-save runs for every filetype (neovim.nix:974-977). Markdown, JSON and YAML go
  through prettier, Python through ruff, and the rest through the language server. The config's own files
  are hit hardest: `nil` runs nixfmt over a Nix file (`neovim.nix` grows from 1003 lines to 1217), and
  `lua_ls` strips the column alignment from the Hyprland Lua files.
- **Fix:** `u` undoes it (one `u` undoes the formatting and keeps your edit). `:noautocmd w` saves without
  running it: conform formats in a `BufWritePre` autocommand, and `:noautocmd` skips every autocommand.
- **See:** [lesson 11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md),
  [lesson 22](../lessons/22-MAKING-THE-CONFIG-YOURS.md).

### `Formatter failed. See :ConformInfo for details`

- **Cause:** the formatter crashed or was not found. prettier and ruff are looked up on `PATH`, so a
  project's own copy wins (neovim.nix:959-964).
- **Fix:** `:ConformInfo` shows which formatters are available for the buffer and where the log is.
- **See:** [lesson 11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md).

### Code accepted from a Claude diff is not formatted

- **Cause:** conform formats on `BufWritePre`, but accepting a proposal writes through `BufWriteCmd`,
  which skips that step.
- **Fix:** go to the real buffer and save it again with `<C-s>`.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### Confirming a function completion does not add `(`

- **Cause:** nvim-autopairs is not connected to nvim-cmp in this config.
- **Fix:** type the `(` yourself; autopairs still closes it.
- **See:** [lesson 11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md).

### No completion menu on the `:` command line

- **Cause:** `cmp-cmdline` is installed (neovim.nix:132) but never set up.
- **Fix:** Neovim's own `<Tab>` completion on the command line still works.
- **See:** [lesson 11](../lessons/11-COMPLETION-FORMATTING-DIAGNOSTICS.md).

## Git

### `q` does not close Diffview

- **Cause:** Diffview maps no `q` in its diff and file windows.
- **Fix:** `<leader>gq` (neovim.nix:37) or `:DiffviewClose`.
- **See:** [lesson 12](../lessons/12-GIT.md).

### In Diffview, `<leader>co`, `<leader>cb`, `<Tab>`, `<leader>e` or `<leader>b` do something else

- **Cause:** Diffview binds these per buffer inside its tab:
  - `<leader>co` / `<leader>cb` choose OURS / BASE in a conflict;
  - `<Tab>` moves to the next file;
  - `<leader>e` / `<leader>b` focus or toggle its file panel.
- **Fix:** close Diffview (`<leader>gq`) or switch tab (`gt`) before you toggle Codex or the tree.
- **See:** [lesson 12](../lessons/12-GIT.md).

### `q` in fugitive's `:Git` window started recording a macro

- **Cause:** fugitive closes its summary with `gq`, not `q`.
- **Fix:** press `q` again to stop recording, then `gq`.
- **See:** [lesson 12](../lessons/12-GIT.md).

### My commits carry an unexpected email address

- **Cause:** the identity for `~/Repos/personal/` comes from `includeIf` in home/modules/git.nix.
  A repository-local setting overrides it, and this checkout has been seen with a misspelt one.
- **Fix:** `git config --show-origin user.email` shows which file sets it. Remove the stray setting
  from that file.
- **See:** [lesson 12](../lessons/12-GIT.md).

### A commit holds the wrong files or the wrong message

- **Cause:** a slip while staging, or a message you want to put differently. The course never pushes, so the
  commit can still be changed.
- **Fix:** `git reset --soft HEAD~1` undoes the last commit and keeps its changes staged: fix the staging and
  commit again. For the message or one forgotten file, stage the fix and amend instead: in Neogit, `c` then
  `a`. If the commit was already tagged, move the tag: `git tag -d course/<name>`, then tag the new commit.
- **See:** [lesson 12](../lessons/12-GIT.md).

### The gutter shows two kinds of git signs

- **Cause:** unstaged hunks use the config's `+ ~ _` signs (neovim.nix:736-744). Staged hunks use
  gitsigns' own default staged signs.
- **Fix:** none needed. The difference tells you what is staged.
- **See:** [lesson 12](../lessons/12-GIT.md).

### `:GBrowse` fails

- **Cause:** it needs a provider plugin (rhubarb.vim for GitHub), which is not installed.
- **Fix:** open the repository page in the browser yourself, or `gh browse` from a terminal.
- **See:** [lesson 12](../lessons/12-GIT.md).

## Claude Code and Codex

### Claude edits files without showing me a diff

- **Cause:** Claude is in `auto` (or `acceptEdits`) permission mode, which applies edits directly.
  claude.nix sets no default mode, and Claude Code 2.1.278 is likely to start in `auto`.
- **Fix:** `Shift+Tab` until the status bar says `⏸ manual mode on`. Or start Claude with
  `:ClaudeCode --permission-mode manual` before one is running. To make Manual the default,
  [lesson 27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md) sets `permissions.defaultMode` in claude.nix.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md), [lesson 27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md).

### "Cannot create diff: file has unsaved changes. Please save (:w) or discard (:e!)"

- **Cause:** the file Claude wants to change has unsaved edits in your buffer.
- **Fix:** save (`<C-s>`) or discard (`:e!`), then ask Claude again.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### `:ClaudeCodeDiffAccept` says "No active diff found in current buffer"

- **Cause:** it must run from the `(proposed)` buffer.
- **Fix:** move into the proposed side and run it there, or just save that buffer (`<C-s>`).
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### `:ClaudeCode --resume` (or any other flag) is ignored

- **Cause:** arguments only apply when the command launches Claude. While a Claude process exists, it
  only shows or hides the window.
- **Fix:** `/exit` inside Claude, then run the command again. Or use `/resume` inside the running
  Claude.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### Space c c typed " cc" into Claude

- **Cause:** you were in Terminal mode, where every key goes to Claude.
- **Fix:** `<C-\><C-n>` first, then Space c c.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### `<Tab>` in the Claude window replaced Claude with a file

- **Cause:** in that window's Normal mode, the global `<Tab>` runs `:bnext` there. Claude keeps
  running in the background (verify on laptop-intel).
- **Fix:** `<C-^>` returns to the previous buffer, or press `<leader>cc` twice to hide and show Claude
  again.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### `Ctrl+G` in Claude opened Zed

- **Cause:** `Ctrl+G` edits the prompt in `$EDITOR`, which is `zeditor --wait`.
- **Fix:** write the prompt in Claude itself. `\` then Enter, or `Ctrl+J`, starts a new line.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### A Claude setting I changed in the app did not stick

- **Cause:** `~/.claude/settings.json` is generated from home/modules/claude.nix and is a read-only
  link into `/nix/store`.
- **Fix:** make the change in claude.nix and run `just rebuild`. Lesson 27 walks through one such change.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md), [lesson 22](../lessons/22-MAKING-THE-CONFIG-YOURS.md),
  [lesson 27](../lessons/27-FIX-CLAUDE-DIFF-REVIEW.md).

### Claude ignores the capstone's `AGENTS.md`

- **Cause:** Claude only reads `AGENTS.md` when no `CLAUDE.md` exists in the folder or above it, and
  nix-config has `.claude/CLAUDE.md` at its root.
- **Fix:** give the capstone a `CLAUDE.md` containing the line `@AGENTS.md`.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### Adding files to Claude from `<leader>b` or `<leader>gs` does not work

- **Cause:** claudecode.nvim only reads neo-tree's **filesystem** source, the `<leader>e` tree.
- **Fix:** use `:ClaudeCodeTreeAdd` (or `V` then `<leader>cs`) in the `<leader>e` tree.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### Codex's edits do not appear in my buffers

- **Cause:** Codex writes files directly, and Neovim does not notice changes made by a program running
  inside it.
- **Fix:** `:checktime` reloads every unmodified buffer whose file changed. `:e` reloads one.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### Codex shows `[Process exited]`, and the next `<leader>co` starts a new conversation

- **Cause:** the Codex terminal keeps its window after Codex exits (`close_on_exit = false`,
  neovim.nix:792). A key pressed in Terminal mode then wipes the buffer, and the next toggle starts a
  fresh Codex.
- **Fix:** `/resume` inside the new Codex, or `codex resume --last` in a `<leader>t` shell.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### Codex asks before downloading crates, and cannot commit

- **Cause:** its default sandbox allows writing in the workspace but has no network, and `.git` is
  read-only.
- **Fix:** approve the request, or run `cargo` / `uv` yourself in `<leader>t`. Commit with Neogit.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### `/approvals` does not exist, or `--ask-for-approval untrusted` fails

- **Cause:** Codex 0.155.1 has retired both. The approval values are `on-request` and `never`.
- **Fix:** `/permissions` inside Codex picks a preset (Auto, Read Only, …).
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md).

### `:ToggleTerm` and `:ToggleTermToggleAll` never show Codex

- **Cause:** the Codex terminal is created `hidden = true` (neovim.nix:790), which keeps it out of the
  normal terminal commands.
- **Fix:** `<leader>co`, or pick it from `:TermSelect!` (with `!`).
- **See:** [lesson 06](../lessons/06-TERMINAL.md).

## Capstone milestones

### A milestone check fails and I cannot see why

- **Cause:** almost always a small difference from the lesson's listing: a missing line, a stray character, or
  a completion that `<CR>` accepted while you typed (lesson 11).
- **Fix:** compare your file with the listing inside Neovim:
  1. Copy the listing from the lesson.
  2. In your file's window, `:vnew` (a new, empty window on the right), then `:0put +` and `:$d _`.
  3. `:diffthis` there, `<C-h>` back to your file, and `:diffthis` again. `]c` and `[c` jump from difference
     to difference.
  4. `:diffoff!` when you are done, then `<C-l>` and `:q!` to throw the scratch copy away.

  To compare whole folders, use the milestone's worked example:
  [examples/README.md](../examples/README.md#compare-your-work) gives the `diff -ru` and `nvim -d` commands
  for both capstones. Once a milestone is committed and tagged, `git diff course/jp5` (or any other
  `course/*` tag) lists everything you have changed since it.
- **See:** [lesson 08](../lessons/08-FILE-PANE.md), [lesson 12](../lessons/12-GIT.md).

### My test counts differ from the lesson's

- **Cause:** three things change them, and none is a fault: the parser tests Claude drafted in lesson 13 (up
  to four more for just-panel), the Python in the venv (on 3.12 the two zstd tests are skipped; see
  `cat .python-version`), and any tests you added in lesson 21's quality pass.
- **Fix:** allow for those, then compare. If a count is still low, a test file is missing or was not
  collected: `cargo test -p just-panel -- --list` and `uv run pytest -q --collect-only` list the tests by name.
- **See:** [lesson 13](../lessons/13-CLAUDE-CODE-AND-CODEX.md), [lesson 17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md),
  [lesson 21](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md).

### I want to start a capstone lesson again from the last milestone

- **Cause:** a lesson's edits went wrong halfway. From lesson 12 on, every milestone ends in a commit, so the
  last milestone is your last commit.
- **Fix:** set the lesson's changes aside rather than delete them:

  ```bash
  # in ~/Repos/personal/nix-config
  git stash push --include-untracked -- rust/                    # just-panel (lessons 14 to 17)
  git stash push --include-untracked -- python/session-browser   # session-browser (lessons 18 to 21)
  ```

  The folder is then exactly as it was at your last commit. `git stash list` shows what you set aside,
  `git stash pop` brings it back and `git stash drop` throws it away. Before lesson 12 nothing is committed,
  so there is no milestone to return to: compare with the listings or the milestone's worked example
  instead (above).
- **See:** [lesson 12](../lessons/12-GIT.md).

## just and just-panel

### `just` in another project runs the nix-config recipes

- **Cause:** zsh exports `JUST_JUSTFILE` and `JUST_WORKING_DIRECTORY` pointing at nix-config
  (home/modules/shell.nix:79-80), so `just` anywhere uses that justfile.
- **Fix:** pass both flags, `just --justfile ./justfile --working-directory . <recipe>`. The
  working-directory variable still applies when you pass only `--justfile`. Or clear both for one
  command: `env -u JUST_JUSTFILE -u JUST_WORKING_DIRECTORY just <recipe>`.
- **See:** [lesson 06](../lessons/06-TERMINAL.md), [lesson 14](../lessons/14-JUST-PANEL-TUI-SKELETON.md).

### just-panel stops with `Error: cannot read …`

- **Cause:** the justfile it was given does not exist or cannot be read. The message names the path it
  tried, followed by `Caused by:` and the operating-system error. just-panel takes `--justfile`
  (`-f`), then `$JUST_JUSTFILE`, then `justfile` in the current folder. Launched from a Hyprland key
  rather than a shell, it may not have the zsh variables (verify on laptop-intel), so it looks in the
  folder it was started from.
- **Fix:** pass the path: `just-panel -f ~/Repos/personal/nix-config/justfile`.
- **See:** [lesson 14](../lessons/14-JUST-PANEL-TUI-SKELETON.md), [lesson 17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md).

### A recipe I just added is not in just-panel

- **Cause:** just-panel reads the justfile once, when it starts.
- **Fix:** quit (`q`) and start it again. The comment line directly above the recipe becomes its
  description.
- **See:** [lesson 15](../lessons/15-JUST-PANEL-SECTIONS-AND-FILTER.md), [lesson 28](../lessons/28-GOING-FURTHER.md).

### After just-panel died, the terminal no longer echoes what I type

- **Cause:** the terminal was left in raw mode. ratatui's panic hook normally restores it, but a
  killed process never runs the hook.
- **Fix:** type `reset` and press Enter, even though you cannot see it.
- **See:** [lesson 14](../lessons/14-JUST-PANEL-TUI-SKELETON.md).

## Nix builds and packaging

### I changed `neovim.nix`, rebuilt, and nothing changed

- **Cause:** a running Neovim keeps the maps it started with, and the dev layout's `less` pane keeps
  the old `KEYBINDS.md`.
- **Fix:** quit Neovim, close the layout's windows, and open it again (`SUPER + SHIFT + RETURN`).
- **See:** [lesson 22](../lessons/22-MAKING-THE-CONFIG-YOURS.md).

### A rebuild stops on a Nix syntax error

- **Cause:** usually a missing `;`, `}` or quote in the file you edited.
- **Fix:** `nix-instantiate --parse home/modules/neovim.nix > /dev/null` checks the syntax in a second
  and prints the line and column.
- **See:** [lesson 22](../lessons/22-MAKING-THE-CONFIG-YOURS.md).

### The build fails in just-panel's tests

- **Cause:** Nix runs `cargo test -p just-panel` inside its sandbox as part of every build (rust/nix/default.nix).
  In there, a test that calls `just`, needs a terminal or reads `$HOME` fails. So does a test whose
  insta snapshot is missing or out of date.
- **Fix:**
  1. Run `cargo test -p just-panel` in `rust/` first.
  2. Keep tests on the compiled-in fixtures.
  3. After a deliberate screen change, read the `.snap.new` insta wrote, then accept it with
     `INSTA_UPDATE=always cargo test -p just-panel` followed by one more `cargo test -p just-panel`,
     which deletes the leftover `.snap.new`. With `cargo-insta` (`nix shell nixpkgs#cargo-insta`), use
     `cargo insta test -p just-panel --review`, or `cargo insta review` in `rust/`: `review` itself has
     no `-p` option. Then `git add` the `.snap` file, never a `.snap.new`.
- **See:** [lesson 17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md).

### The build cannot see a file or crate I just created

- **Cause:** a flake only sees files git knows about. Untracked files are invisible to it.
- **Fix:** `git add rust/just-panel rust/Cargo.toml rust/Cargo.lock rust/nix/default.nix` (and any new
  fixtures or snapshots), then build again. Edits to files git already tracks need no `git add`.
- **See:** [lesson 17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md).

### The build cannot resolve a dependency I just added

- **Cause:** Nix builds offline, from `rust/Cargo.lock`, and the lock file does not have the new crate
  yet.
- **Fix:** run `cargo build -p just-panel` in `rust/` to update the lock file, then `git add
  rust/Cargo.lock`.
- **See:** [lesson 17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md).

### Adding one crate rebuilt every Rust tool

- **Cause:** all the tools are built from the whole `rust/` folder and its single lock file
  (rust/nix/default.nix).
- **Fix:** nothing: this is expected. It only happens when the lock file or shared sources change.
- **See:** [lesson 17](../lessons/17-JUST-PANEL-TESTING-AND-SHIPPING.md).

## session-browser and Python

### Typing in `app.tcss` puts `#` at the start of new lines

- **Cause:** Neovim 0.12.5 has no filetype for `.tcss`. For an unknown file type it falls back to `conf`
  when one of the first five lines starts with `#`, and `#sessions {` does. `conf` continues a `#` comment
  onto every new line you open.
- **Fix:** `:setlocal filetype= syntax=css` whenever you open a saved `app.tcss`: no filetype, CSS
  colours. Never `:set filetype=css`, or the CSS language server attaches and prettier reformats the file
  on every save.
- **See:** [lesson 18](../lessons/18-SESSION-BROWSER-TUI-SKELETON.md),
  [lesson 19](../lessons/19-SESSION-BROWSER-FILTER-AND-SEARCH.md).

### uv will not upgrade pytest to 9

- **Cause:** `pytest-textual-snapshot` 1.1.0 pins `syrupy` 4.8.0, which needs pytest older than 9.
  The capstone asks for `pytest-textual-snapshot>=1.1`, so its lock resolves pytest 8.4.2.
- **Fix:** stay on pytest 8.4 (nothing in the course needs 9). If you must have pytest 9, change the
  pin to `pytest-textual-snapshot<1.1`. That brings version 1.0.0 with syrupy 6, which ignores the
  plugin's file extension and saves snapshots as `.raw` instead of `.svg`, so regenerate them with
  `uv run pytest --snapshot-update` and review the new files.
- **See:** [lesson 21](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md).

### The snapshot test fails after I changed the screen on purpose

- **Cause:** the saved snapshot shows the old screen.
- **Fix:** `uv run pytest --snapshot-update`, look at the new file under `tests/__snapshots__/`, and
  commit it.
- **See:** [lesson 21](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md).

### Async tests do not run

- **Cause:** pytest-asyncio needs `@pytest.mark.asyncio` on every test unless `asyncio_mode = "auto"`
  is set.
- **Fix:** keep `asyncio_mode = "auto"` under `[tool.pytest.ini_options]` in `pyproject.toml`.
- **See:** [lesson 21](../lessons/21-SESSION-BROWSER-TESTING-AND-SHIPPING.md).

### A test raises `SuspendNotSupported`

- **Cause:** `App.suspend()` cannot hand over a terminal in a headless test run.
- **Fix:** test through the injectable launcher, and assert on the command it was given instead of
  running it.
- **See:** [lesson 20](../lessons/20-SESSION-BROWSER-ACTIONS.md).

### Text with `[` … `]` vanishes from the preview, or turns into styling

- **Cause:** `Static` parses its content as Textual markup by default.
- **Fix:** create it with `markup=False`, or escape the text with `textual.markup.escape`.
- **See:** [lesson 18](../lessons/18-SESSION-BROWSER-TUI-SKELETON.md).

### Row events never fire in the session table

- **Cause:** `DataTable`'s default cursor is a cell, and the row messages are only sent with a row
  cursor.
- **Fix:** `DataTable(cursor_type="row")`.
- **See:** [lesson 18](../lessons/18-SESSION-BROWSER-TUI-SKELETON.md).

### `kitten @ ls` fails

- **Cause:** Kitty's remote control is off by default, and this config does not turn it on
  (home/stages/desktop.nix). Each Hyprland-launched Kitty is also a separate process.
- **Fix:** the browser lists saved `*.kitty-session` files instead. To list live windows, enable
  `allow_remote_control` and `listen_on` in the Kitty settings deliberately.
- **See:** [lesson 20](../lessons/20-SESSION-BROWSER-ACTIONS.md).
