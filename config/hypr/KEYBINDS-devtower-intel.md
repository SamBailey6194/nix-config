# Hyprland Keybinds Reference (devtower-intel)

laptop-intel uses `KEYBINDS.md`; this sheet replaces it on devtower-intel
(home/devtower-intel.nix).

## Applications

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Return`     | Terminal (kitty)        |
| `SUPER + SHIFT + Return` | nix-config layout: Neovim alone (ws 31) |
| `SUPER + CTRL + Return`  | Dev layout: Neovim alone (next free ws 32-40) |
| `SUPER + ALT + Return`   | Neovim in plain Kitty (ws 20) |
| `SUPER + Space`      | App launcher (wofi)     |
| `SUPER + Z`          | Zed editor              |
| `SUPER + SHIFT + Z`  | nix-config layout: Zed + 2 terminals (ws 31) |
| `SUPER + CTRL + Z`   | Dev layout: Zed + 2 terminals (next free ws 32-40) |
| `SUPER + F`          | File manager: Yazi (ws 2; F1 inside = its keys) |
| `SUPER + SHIFT + F`  | Backup file manager: Thunar (ws 2) |
| `SUPER + W`          | Zen browser (ws 11)     |
| `SUPER + SHIFT + W`  | Brave browser (ws 14)   |
| `SUPER + ALT + W`    | LibreWolf browser (ws 12) |
| `SUPER + CTRL + W`   | Firefox Developer Ed. (ws 13) |
| `SUPER + E`          | Mail: aerc + its keybind sheet (ws 3) |
| `SUPER + SHIFT + E`  | Backup mail client: Claws Mail (ws 3) |
| `SUPER + T`          | Teams (ws 10)           |
| `SUPER + C`          | Zoom (ws 10)            |
| `SUPER + R`          | RustDesk                |
| `SUPER + M`          | System monitor (btop)   |
| `SUPER + SHIFT + M`  | Backup monitor (htop)   |
| `SUPER + /`          | This keybinds help      |

`SUPER + CTRL + Z` and `SUPER + CTRL + Return` open a picker listing every
project under `~/Repos`, then build the layout on the lowest free workspace in
the 32-40 dev pool. With all nine already holding windows it raises a
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
| `SUPER + D`          | Affinity Designer (ws 16) |
| `SUPER + P`          | Affinity Photo (ws 17)  |
| `SUPER + B`          | Affinity Publisher (ws 18) |

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

| Keybind                  | Action                        |
|--------------------------|-------------------------------|
| `SUPER + 1-9, 0`         | Switch to workspace 1-10      |
| `SUPER + SHIFT + 1-9, 0` | Switch to workspace 11-20     |
| `SUPER + CTRL + 1-9, 0`  | Switch to workspace 21-30     |
| `SUPER + ALT + 1-9, 0`   | Switch to workspace 31-40     |
| `SUPER + .`, then `1-9, 0` (+ `SHIFT` / `CTRL` / `ALT`) | Move window to that workspace (same banks) |
| `SUPER + .`, then `Esc`  | Cancel the move               |
| `SUPER + S`              | Toggle scratchpad             |
| `SUPER + SHIFT + S`      | Move to scratchpad            |
| `SUPER + Scroll`         | Cycle workspaces              |
| `SUPER + Escape`         | Dashboard (ws 1): reopens a closed pane |

## Workspace Map

L = left 4K, C = centre 1440p, R = right portrait.

| Workspace | Key                  | Mon | Contents                               |
|-----------|----------------------|-----|----------------------------------------|
| `1`       | `SUPER + 1`          | R   | Dashboard: this sheet, btop, nvtop     |
| `2`       | `SUPER + 2`          | C   | File managers (Yazi, Thunar)           |
| `3`       | `SUPER + 3`          | C   | Mail (aerc + sheet, Claws Mail)        |
| `4`       | `SUPER + 4`          | C   | LibreOffice Writer (and Start Center)  |
| `5`       | `SUPER + 5`          | C   | LibreOffice Calc                       |
| `6`       | `SUPER + 6`          | C   | LibreOffice Impress                    |
| `7`       | `SUPER + 7`          | C   | LibreOffice Draw                       |
| `8`       | `SUPER + 8`          | C   | LibreOffice Math                       |
| `9`       | `SUPER + 9`          | C   | LibreOffice Base                       |
| `10`      | `SUPER + 0`          | C   | Comms (Teams, Zoom)                    |
| `11`      | `SUPER + SHIFT + 1`  | L   | Zen (streaming)                        |
| `12`      | `SUPER + SHIFT + 2`  | L   | LibreWolf                              |
| `13`      | `SUPER + SHIFT + 3`  | C   | Firefox Developer Edition              |
| `14`      | `SUPER + SHIFT + 4`  | C   | Brave                                  |
| `15`      | `SUPER + SHIFT + 5`  | L   | Video and image viewers (VLC, mpv, imv)|
| `16`      | `SUPER + SHIFT + 6`  | C   | Affinity Designer                      |
| `17`      | `SUPER + SHIFT + 7`  | C   | Affinity Photo                         |
| `18`      | `SUPER + SHIFT + 8`  | C   | Affinity Publisher                     |
| `19`      | `SUPER + SHIFT + 9`  | L   | DaVinci Resolve                        |
| `20`      | `SUPER + SHIFT + 0`  | C   | Spare; everything unassigned lands here |
| `21`      | `SUPER + CTRL + 1`   | C   | PhotoCraft                             |
| `22`      | `SUPER + CTRL + 2`   | C   | VectorCraft                            |
| `23`      | `SUPER + CTRL + 3`   | C   | LightCraft                             |
| `24`      | `SUPER + CTRL + 4`   | C   | PdfCraft                               |
| `25`      | `SUPER + CTRL + 5`   | C   | DesignCraft                            |
| `26`      | `SUPER + CTRL + 6`   | C   | SoundCraft                             |
| `27`      | `SUPER + CTRL + 7`   | C   | WordCraft                              |
| `28`      | `SUPER + CTRL + 8`   | C   | DeckCraft                              |
| `29`      | `SUPER + CTRL + 9`   | L   | EffectCraft                            |
| `30`      | `SUPER + CTRL + 0`   | L   | FilmCraft                              |
| `31`      | `SUPER + ALT + 1`    | C   | nix-config dev layout (reserved)       |
| `32-40`   | `SUPER + ALT + 2-9, 0` | C | Dev pool (allocated as needed)         |

Files opened from Yazi or Thunar go to that app's workspace (a video to 15,
and so on); apps with no workspace of their own go to 20. An app's
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
