# Neovim keybinds

Leader is `<Space>`. Generated from `home/modules/neovim.nix` — do not edit
by hand; the file is rewritten on every `nixos-rebuild`.

## Panels

| Key | Action |
| --- | --- |
| `<leader>e` | Toggle file tree (left) |
| `<leader>b` | Toggle buffer list (left) |
| `<leader>o` | Toggle outline (left) |
| `<leader>t` | Toggle terminal (bottom) |

## Find

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |

## Git

| Key | Action |
| --- | --- |
| `<leader>gs` | Git status panel (right) |
| `<leader>gg` | Full git UI (Neogit) |
| `<leader>gd` | Diff view |
| `<leader>gq` | Close diff view |
| `<leader>gh` | History of this file |

## AI

| Key | Action |
| --- | --- |
| `<leader>cc` | Toggle Claude Code |
| `<leader>cb` | Send buffer to Claude |
| `<leader>cs` | Send selection to Claude |
| `<leader>co` | Toggle Codex CLI |

## Code

| Key | Action |
| --- | --- |
| `<leader>ca` | Code action |
| `<leader>cf` | Format buffer |
| `<leader>rn` | Rename symbol |
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gi` | Go to implementation |
| `gr` | References |
| `K` | Hover docs |
| `<leader>k` | Signature help |

## Diagnostics

| Key | Action |
| --- | --- |
| `<leader>xx` | All diagnostics |
| `<leader>xw` | Buffer diagnostics |
| `<leader>ld` | Line diagnostic |
| `[d` | Previous diagnostic |
| `]d` | Next diagnostic |

## Buffers

| Key | Action |
| --- | --- |
| `<Tab>` | Next buffer |
| `<S-Tab>` | Previous buffer |
| `<leader>x` | Close buffer |
| `<C-s>` | Save |
| `<C-q>` | Quit |
| `<leader>h` | Clear search highlight |

## Windows

| Key | Action |
| --- | --- |
| `<C-h>` | Window left |
| `<C-j>` | Window down |
| `<C-k>` | Window up |
| `<C-l>` | Window right |
