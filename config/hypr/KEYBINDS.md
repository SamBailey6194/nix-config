# Hyprland Keybinds Reference

## Applications

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Return`     | Terminal (kitty)        |
| `SUPER + SHIFT + Return` | nix-config layout: Neovim alone (ws 2) |
| `SUPER + CTRL + Return`  | Dev layout: Neovim alone (next free ws 3-5) |
| `SUPER + ALT + Return`   | Neovim in plain Kitty (not placed; laptop: ws 10) |
| `SUPER + Space`      | App launcher (wofi)     |
| `SUPER + Z`          | Zed editor              |
| `SUPER + SHIFT + Z`  | nix-config layout: Zed + 2 terminals (ws 2) |
| `SUPER + CTRL + Z`   | Dev layout: Zed + 2 terminals (next free ws 3-5) |
| `SUPER + F`          | File manager: Yazi (ws 10; F1 inside = its keys) |
| `SUPER + SHIFT + F`  | Backup file manager: Thunar (ws 10) |
| `SUPER + W`          | Zen browser (default)   |
| `SUPER + SHIFT + W`  | Brave browser           |
| `SUPER + ALT + W`    | LibreWolf browser       |
| `SUPER + CTRL + W`   | Firefox Developer Ed.   |
| `SUPER + E`          | Email (Claws Mail)      |
| `SUPER + T`          | Teams                   |
| `SUPER + C`          | Zoom                    |
| `SUPER + R`          | RustDesk                |
| `SUPER + M`          | System monitor (btop)   |
| `SUPER + SHIFT + M`  | Backup monitor (htop)   |
| `SUPER + /`          | This keybinds help      |

`SUPER + CTRL + Z` and `SUPER + CTRL + Return` open a picker listing every
project under `~/Repos`, then build the layout on the lowest free workspace in
the 3-5 dev pool. With all three already holding windows it raises a
notification and stops — close a dev space, or switch to one of them and work
there.

From a terminal you can skip the picker: `dev-layout --new [--nvim] <path>`.

A Zed layout is Zed at 75% with two terminals stacked on the right. A Neovim
layout is a single Kitty window filling the workspace: the keybind reference,
file tree, git panel and shell are panes and tabs inside Neovim, and its own
bindings are listed in `~/.config/nvim/KEYBINDS.md`.

## Affinity Suite

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + D`          | Affinity Designer       |
| `SUPER + P`          | Affinity Photo          |
| `SUPER + B`          | Affinity Publisher      |

## Window Management

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Q`          | Close window            |
| `SUPER + SHIFT + Q`  | Exit Hyprland           |
| `SUPER + V`          | Toggle floating         |
| `SUPER + F11`        | Fullscreen              |
| `SUPER + `` ` ``     | Toggle split direction  |

## Session Control

All three require your password to get back in.

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + CTRL + L`   | Lock screen             |
| `SUPER + CTRL + S`   | Lock, then sleep        |
| `SUPER + CTRL + Q`   | Log out (to login screen) |

Equivalents in a terminal: `just lock`, `just sleep`, `just logout`.

## Focus Navigation

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + H` / `Left`  | Focus left            |
| `SUPER + L` / `Right` | Focus right           |
| `SUPER + K` / `Up`    | Focus up              |
| `SUPER + J` / `Down`  | Focus down            |

## Move Windows

| Keybind                    | Action                  |
|----------------------------|-------------------------|
| `SUPER + SHIFT + H` / `Left`  | Move left           |
| `SUPER + SHIFT + L` / `Right` | Move right          |
| `SUPER + SHIFT + K` / `Up`    | Move up             |
| `SUPER + SHIFT + J` / `Down`  | Move down           |

## Workspaces

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + 1-9, 0`    | Switch to workspace 1-10 |
| `SUPER + SHIFT + 1-9, 0` | Move window to workspace 1-10 |
| `SUPER + S`          | Toggle scratchpad       |
| `SUPER + SHIFT + S`  | Move to scratchpad      |
| `SUPER + Scroll`     | Cycle workspaces        |
| `SUPER + Escape`     | Dashboard (ws 1): reopens a closed pane — laptop only |

## Workspace Map

| Workspace | Contents                                     |
|-----------|----------------------------------------------|
| `1`       | Dashboard (keybinds + btop) — laptop only    |
| `2`       | nix-config dev layout (reserved)             |
| `3-5`     | Dev pool (allocated as needed)               |
| `6`       | Mail (Claws Mail)                            |
| `7`       | Browsers                                     |
| `8`       | Affinity Suite                               |
| `9`       | Comms (Teams, Zoom, Discord)                 |
| `10`      | File managers; everything else (catch-all) — laptop, devtower-intel |

The workspace-10 catch-all exists on laptop-intel (`devices/laptop-intel.lua`)
and devtower-intel (`devices/devtower-intel.lua`); framework and devtower have
none. The ws1 dashboard above is laptop-intel's. The file managers go to 10 on
every device.

Files opened from Yazi or Thunar go to that app's usual workspace (a browser
to 7, and so on); apps with no workspace of their own stay on 10. An app's
"Open / Save file" dialog is Yazi too: it floats over the app, on the current
workspace.

## Screenshots

| Keybind              | Action                  |
|----------------------|-------------------------|
| `Print`              | Screenshot region       |
| `SUPER + Print`      | Screenshot full screen  |

## Media / Hardware

| Keybind              | Action                  |
|----------------------|-------------------------|
| `Volume Up/Down`     | Adjust volume (5%)      |
| `Mute`               | Toggle mute             |
| `Mic Mute`           | Toggle mic mute         |
| `Brightness Up/Down` | Adjust brightness (5%)  |

## Mouse

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Left-click drag`  | Move window        |
| `SUPER + Right-click drag` | Resize window      |
