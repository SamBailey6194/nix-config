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
