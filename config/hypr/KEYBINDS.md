# Hyprland Keybinds Reference

## Applications

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Return`     | Terminal (kitty)        |
| `SUPER + SHIFT + Return` | Terminal with Neovim |
| `SUPER + Space`      | App launcher (wofi)     |
| `SUPER + Z`          | Zed editor              |
| `SUPER + SHIFT + Z`  | nix-config layout: Zed + 2 terminals (ws 2) |
| `SUPER + CTRL + Z`   | Dev layout: Zed + 2 terminals (next free ws 3-5) |
| `SUPER + F`          | File manager (Thunar)   |
| `SUPER + W`          | Zen browser (default)   |
| `SUPER + SHIFT + W`  | Brave browser           |
| `SUPER + ALT + W`    | LibreWolf browser       |
| `SUPER + CTRL + W`   | Firefox Developer Ed.   |
| `SUPER + E`          | Email (Claws Mail)      |
| `SUPER + T`          | Teams                   |
| `SUPER + C`          | Zoom                    |
| `SUPER + R`          | RustDesk                |
| `SUPER + M`          | System monitor (htop)   |
| `SUPER + /`          | This keybinds help      |

`SUPER + CTRL + Z` opens a picker listing every project under `~/Repos`, then
builds the layout on the lowest free workspace in the 3-5 dev pool. With all
four already holding windows it raises a notification and stops — close a dev
space, or switch to one of them and work there.

From a terminal you can skip the picker: `dev-layout --new <path>`.

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

## Workspace Map

| Workspace | Contents                                     |
|-----------|----------------------------------------------|
| `1`       | Dashboard (keybinds + htop) — laptop only    |
| `2`       | nix-config dev layout (reserved)             |
| `3-5`     | Dev pool (allocated as needed)               |
| `6`       | Mail (Claws Mail)                            |
| `7`       | Browsers                                     |
| `8`       | Affinity Suite                               |
| `9`       | Comms (Teams, Zoom, Discord)                 |
| `10`      | Everything else (catch-all) — laptop only    |

Workspaces 1 and 10 are set up by `devices/laptop-intel.lua`, so they exist on
laptop-intel only; the other devices have no dashboard and no catch-all.

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
