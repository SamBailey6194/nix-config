# Neovim Configuration

**Last Updated**: 28/09/2026
**Version**: 0.8.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Modern Neovim setup with Lua configuration, sharing LSP servers and linters with Zed.

## Overview

This configuration provides:
- **Neovim with Lua** for powerful text editing
- **Same LSP servers** as Zed (shared from `modules/software/development.nix`)
- **Same linters/formatters** (ruff, prettier, eslint)
- **Ayu Dark theme** to match Zed
- **Modern plugin ecosystem** (Treesitter, Telescope, LSP, etc.)

## Philosophy

**Neovim alongside Zed, not instead of:**
- Zed remains the default editor (`EDITOR=zed`)
- Neovim is for terminal editing, quick file edits, and when you prefer modal editing
- Both editors share the same LSP servers and linters from system packages
- No duplication of tools or configuration drift

## Shared Tools

All LSP servers, linters, and formatters are in `modules/software/development.nix`:

| Language | LSP Server | Linter | Formatter |
|----------|-----------|--------|-----------|
| Python | pyright | ruff | ruff |
| TypeScript/JavaScript | typescript-language-server | eslint | prettier |
| Rust | rust-analyzer | clippy | rustfmt |
| Lua | lua-language-server | - | stylua |
| Nix | nil | - | nixfmt |
| HTML/CSS/JSON | vscode-langservers-extracted | - | prettier |

Both Zed and Neovim use the **exact same binaries** from the Nix store.

## Features

### LSP Integration
- **Auto-completion** with nvim-cmp
- **Go to definition** (`gd`)
- **Find references** (`gr`)
- **Hover documentation** (`K`)
- **Rename symbol** (`<leader>rn`)
- **Code actions** (`<leader>ca`)
- **Format on save** for Python, Rust, TS, JS, Lua, Nix

### File Navigation
- **Telescope fuzzy finder** (`<leader>ff` for files, `<leader>fg` for grep)
- **File tree** (`<leader>e` to toggle the neo-tree file tree)
- **Buffer navigation** (`Tab` / `Shift+Tab`)

### Git Integration
- **Gitsigns** for git status in gutter
- **Git panel** (neo-tree `git_status`, right), open from the start in a git
  work tree; `D` on a file opens its diff in Diffview, `<leader>gq` closes it
- **Neogit** (`<leader>gg`) and **Diffview** (`<leader>gd`)
- **Fugitive** for git commands (`:Git`)

### UI Enhancements
- **Lualine** status bar (Ayu Dark theme)
- **Bufferline** for buffer tabs
- **Indent guides** with indent-blankline
- **Which-key** for keybinding hints
- **Trouble** for better diagnostics

### Syntax Highlighting
- **Treesitter** for all languages (all grammars included)
- **Better syntax** than traditional Vim regex

## Bare Start Layout

`nvim` with no file and no piped input fills the window with, left to right:

```
keybind reference | file tree (30) | editing window | git panel (40)
```

- The **keybind reference** is `~/.config/nvim/KEYBINDS.md`, read-only;
  `<leader>?` hides or shows it.
- The **editing window** starts on a shell terminal. Terminals are ordinary
  buffers, so each one is a tab in the bufferline next to the files you open.
- Inside a git work tree the **git panel** is already open, so the changes are
  in view from the start; `D` on a file in it opens that file's diff
  (`<leader>gq` closes it). Anywhere else it stays closed until `<leader>gs`.
- In a window too narrow for all of that (a half-screen Kitty, say) the
  keybind reference and then the git panel stay closed, so the editing window
  keeps at least 40 columns; they open as soon as the window is wide enough.
  One you show yourself with `<leader>?` or `<leader>gs` stays, though, and
  the other makes way for it; with both shown the editing window gets what is
  left. Claude's split (`<leader>cc`) and the outline (`<leader>o`) count too:
  at laptop width opening either hides the keybind reference, and closing it
  brings the reference back.
- A panel you resize by hand (`<C-w>>`, `<C-w><`, the mouse) keeps that width
  until you close it or the terminal's width changes.
- When only panels (and Claude's split) are left, after `:q` in the editing
  window, Neovim quits.

`nvim file.rs`, `git commit`, `nvim +Neogit`, `nvim -c DiffviewOpen` and other
starts that already put something on screen are left alone.
`SUPER + SHIFT + Return` (nix-config, workspace 2) and `SUPER + CTRL + Return`
(dev pool) launch exactly this, as one Kitty window that fills the workspace;
see `config/hypr/KEYBINDS.md`.

## Keybindings

The complete list is generated from the `keymaps` attrset in
`home/modules/neovim.nix` into `~/.config/nvim/KEYBINDS.md`, the file the
keybind reference shows, so it cannot drift from the real bindings. The tables
below are a summary; when they disagree, KEYBINDS.md is right.

### Leader Key
`Space` is the leader key everywhere, the file tree and git panel included:
neo-tree's own Space (expand or collapse a folder) is switched off there, so a
pause after it shows which-key's list instead. `<CR>` opens and closes folders.

### File Operations
| Key | Action |
|-----|--------|
| `<leader>ff` | Find files (Telescope) |
| `<leader>fg` | Live grep (Telescope) |
| `<leader>fb` | Find buffers (Telescope) |
| `<leader>fh` | Help tags (Telescope) |
| `<leader>e` | Toggle file tree (neo-tree) |
| `<C-s>` | Save file |
| `<C-q>` | Quit |

### LSP Operations
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gi` | Go to implementation |
| `gr` | Find references |
| `K` | Hover documentation |
| `<leader>k` | Signature help |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code actions |
| `<leader>cf` | Format buffer |
| `[d` | Previous diagnostic |
| `]d` | Next diagnostic |
| `<leader>ld` | Show diagnostic float |

### Diagnostics (Trouble)
| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle diagnostics (all) |
| `<leader>xw` | Toggle diagnostics (current buffer) |

### Window Navigation
| Key | Action |
|-----|--------|
| `<C-h>` | Move to left window |
| `<C-j>` | Move to window below |
| `<C-k>` | Move to window above |
| `<C-l>` | Move to right window |

### Buffer Navigation
| Key | Action |
|-----|--------|
| `Tab` | Next buffer (inside the tree or git panel, neo-tree's own "select node") |
| `Shift+Tab` | Previous buffer |
| `<leader>x` | Close buffer, keep the window (asks first on a running terminal) |

### Terminal
Terminals are buffers shown in the editing window, one tab each; there is no
floating or docked terminal.

| Key | Action |
|-----|--------|
| `<leader>t` | Show the shell tab; again to go back to the previous tab |
| `2<leader>t` | The same for a second, separate shell (any count works) |
| `<leader>co` | The same for Codex; it keeps running while you are elsewhere |
| `<leader>cp` | The same for OpenCode |
| `<leader>cg` | The same for Antigravity (`agy`) |

### Misc
| Key | Action |
|-----|--------|
| `<leader>h` | Clear search highlight |
| `gcc` | Toggle line comment |
| `gbc` | Toggle block comment |

## Usage Examples

### Quick File Edit
```bash
# Edit a file from terminal
nvim config.nix

# Same LSP support as Zed!
# Press 'gd' to go to definition, 'K' for hover docs
```

### Quick Grep
```bash
# Open Neovim, then:
# Space + fg  → Live grep across project
# Start typing → See results update in real-time
```

### Git Workflow
```bash
# Open file with changes
nvim src/main.rs

# See git status in gutter (added/modified/deleted lines)
# Press ':Git' for fugitive commands
# Press ':Git blame' to see line-by-line blame
```

### Code Actions
```bash
# Place cursor on error/warning
# Press <leader>ca → See available code actions
# Select one → Applied automatically
```

## Zed vs Neovim: When to Use Each

**Use Zed when:**
- Starting a new project
- Working on large codebases
- Doing GUI-heavy work (visual debugging, split views)
- Prefer mouse interaction
- Want AI assistance (Claude integration)

**Use Neovim when:**
- Editing via SSH/remote server
- Quick terminal file edits
- Prefer modal editing (vim motions)
- Want ultimate keyboard efficiency
- Editing config files on the fly
- Git commit messages (`git config core.editor nvim`)

## Configuration Files

- **Neovim config**: `home/modules/neovim.nix`
- **Zed config**: `home/modules/editor.nix`
- **Shared LSP/linters**: `modules/software/development.nix`

## LSP Debugging

If LSP isn't working:

1. **Check LSP server is installed:**
   ```bash
   which pyright          # Should show /nix/store/... path
   which rust-analyzer
   which typescript-language-server
   ```

2. **Check LSP status in Neovim:**
   ```vim
   :LspInfo
   ```

3. **Check LSP logs:**
   ```vim
   :lua vim.cmd('e ' .. vim.lsp.get_log_path())
   ```

4. **Restart LSP server:**
   ```vim
   :LspRestart
   ```

## Customization

The Neovim config is in `home/modules/neovim.nix`. To customize:

1. **Change theme:**
   ```lua
   vim.cmd('colorscheme <theme-name>')
   ```

2. **Add more LSP servers:**
   - Add package to `modules/software/development.nix`
   - Configure in `initLua` with the `lsp('<server>', { ... })` helper, which
     wraps `vim.lsp.config` and `vim.lsp.enable`

3. **Change keybindings:** add an entry to the `keymaps` attrset at the top
   of `home/modules/neovim.nix`:
   ```nix
   { group = "Buffers"; lhs = "<your-key>"; rhs = "<cmd>YourCommand<CR>"; desc = "What it does"; }
   ```
   That one entry generates both the `vim.keymap.set` call and the row in
   `KEYBINDS.md`, the reference the keybind pane shows. For a binding defined
   elsewhere (buffer-local, or a Lua closure) add it with `docOnly = true` so
   it is still documented. A binding added with a bare `vim.keymap.set` works
   but never appears in the reference.

4. **Add plugins:**
   ```nix
   plugins = with pkgs.vimPlugins; [
     existing-plugins
     new-plugin-name
   ];
   ```

## Shared Configuration Benefits

**Before (duplication):**
- Zed uses system pyright
- Neovim uses separate pyright (via Mason or other package manager)
- Two versions, configuration drift possible

**After (shared):**
- Zed uses `/nix/store/.../pyright`
- Neovim uses `/nix/store/.../pyright` (same binary!)
- Single version, always in sync
- Declarative, reproducible

## Integration with Hyprland

| Keybind | What it opens |
|---------|---------------|
| `SUPER + SHIFT + Return` | The nix-config repo in Neovim, alone on workspace 2 |
| `SUPER + CTRL + Return` | A picked project in Neovim, on the next free workspace (3-5) |
| `SUPER + ALT + Return` | Neovim in a plain Kitty window, not placed |

All three are a single Kitty window running a bare `nvim`, so each gets the
bare start layout above. Running `nvim` in any Kitty window (`SUPER + Return`)
does the same.

## Post-Installation

After `nixos-rebuild switch`:

1. **Launch Neovim:**
   ```bash
   nvim
   ```

2. **Test LSP in a Python file:**
   ```bash
   nvim test.py
   # Type: import os
   # Press Ctrl+Space → Should see completions
   # Hover over 'os' and press 'K' → Should see documentation
   ```

3. **Test Telescope:**
   ```
   # In Neovim:
   Space + ff  → Should show file finder
   ```

4. **Check theme:**
   Should see Ayu Dark colors (matching Zed)

## Aliases

No aliases needed! Just use:
```bash
nvim <file>      # Neovim
vim <file>       # Also Neovim (viAlias = true)
vi <file>        # Also Neovim (viAlias = true)
```

## Learning Resources

**Neovim basics:**
- Run `:Tutor` in Neovim for interactive tutorial
- [Neovim docs](https://neovim.io/doc/)

**Lua configuration:**
- [Lua guide for Neovim](https://github.com/nanotee/nvim-lua-guide)
- [LSP configuration examples](https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md)

**Plugin documentation:**
- [Telescope](https://github.com/nvim-telescope/telescope.nvim)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

## Related Documentation

- `home/modules/neovim.nix` - Neovim configuration
- `home/modules/editor.nix` - Zed configuration
- `modules/software/development.nix` - Shared LSP servers
- `QUICK-START.md` - Installation guide
