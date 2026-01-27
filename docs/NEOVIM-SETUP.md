# Neovim Configuration

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

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
- **File tree** (`<leader>e` to toggle nvim-tree)
- **Buffer navigation** (`Tab` / `Shift+Tab`)

### Git Integration
- **Gitsigns** for git status in gutter
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

## Keybindings

### Leader Key
`Space` is the leader key

### File Operations
| Key | Action |
|-----|--------|
| `<leader>ff` | Find files (Telescope) |
| `<leader>fg` | Live grep (Telescope) |
| `<leader>fb` | Find buffers (Telescope) |
| `<leader>fh` | Help tags (Telescope) |
| `<leader>e` | Toggle file tree (nvim-tree) |
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
| `<C-k>` | Signature help |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code actions |
| `<leader>f` | Format buffer |
| `[d` | Previous diagnostic |
| `]d` | Next diagnostic |
| `<leader>e` | Show diagnostic float |

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
| `Tab` | Next buffer |
| `Shift+Tab` | Previous buffer |
| `<leader>x` | Close buffer |

### Terminal
| Key | Action |
|-----|--------|
| `<C-`>` | Toggle floating terminal |

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
   - Configure in `extraLuaConfig` using `lspconfig.<server>.setup()`

3. **Change keybindings:**
   ```lua
   vim.keymap.set('n', '<your-key>', '<action>', { noremap = true })
   ```

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

Neovim works great in Hyprland terminals:

```bash
# Open kitty terminal (Super+Return)
kitty

# Start Neovim
nvim

# Full LSP, completion, everything works!
```

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
