# Hyprland Keybinds Reference (devtower-intel)

laptop-intel uses `KEYBINDS.md`; this sheet replaces it on devtower-intel
(home/devtower-intel.nix).

## Applications

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Return`     | Terminal (kitty)        |
| `SUPER + SHIFT + Return` | nix-config layout: Neovim alone (ws 31) |
| `SUPER + CTRL + Return`  | Dev layout: Neovim alone (next free ws 32-40) |
| `SUPER + ALT + Return`   | Neovim in plain Kitty (first free ws 41+) |
| `SUPER + Space`      | App launcher (wofi)     |
| `SUPER + Z`          | Zed editor              |
| `SUPER + SHIFT + Z`  | nix-config layout: Zed alone (ws 31) |
| `SUPER + CTRL + Z`   | Dev layout: Zed alone (next free ws 32-40) |
| `SUPER + F`          | File manager: Yazi (ws 3; F1 inside = its keys) |
| `SUPER + SHIFT + F`  | Backup file manager: Thunar (ws 3) |
| `SUPER + W`          | Zen browser (ws 12)     |
| `SUPER + SHIFT + W`  | Brave browser (ws 15)   |
| `SUPER + ALT + W`    | LibreWolf browser (ws 13) |
| `SUPER + CTRL + W`   | Firefox Developer Ed. (ws 14) |
| `SUPER + E`          | Mail: aerc + its keybind sheet (ws 4) |
| `SUPER + SHIFT + E`  | Backup mail client: Claws Mail (ws 4) |
| `SUPER + T`          | Teams (ws 11)           |
| `SUPER + C`          | Zoom (ws 11)            |
| `SUPER + SHIFT + C`  | Calendar: khal (ws 4)   |
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

Both layouts are a single window filling the workspace. A Zed layout is Zed
alone; for shells, use the four terminals on workspace 2. A Neovim layout is
one Kitty window: the keybind reference,
file tree, git panel and shell are panes and tabs inside Neovim, and its own
bindings are listed in `~/.config/nvim/KEYBINDS.md`.

## Affinity Suite

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + D`          | Affinity Designer (ws 17) |
| `SUPER + P`          | Affinity Photo (ws 18)  |
| `SUPER + B`          | Affinity Publisher (ws 19) |

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
| Numpad `1-9, 0`          | Same as the top-row numbers in every bind above, NumLock on or off |
| `SUPER + ,`              | Move the focused workspace between centre and left monitors |
| `SUPER + S`              | Toggle scratchpad             |
| `SUPER + SHIFT + S`      | Move to scratchpad            |
| `SUPER + Scroll`         | Cycle workspaces              |
| `SUPER + Escape`         | Dashboard (ws 1): reopens a closed pane |
| `SUPER + SHIFT + Escape` | Terminal grid (ws 2): reopens a closed terminal |

## Workspace Map

L = left 4K, C = centre 1440p, R = right portrait.

| Workspace | Key                  | Mon | Contents                               |
|-----------|----------------------|-----|----------------------------------------|
| `1`       | `SUPER + 1`          | R   | Dashboard: this sheet, btop, nvtop     |
| `2`       | `SUPER + 2`          | C   | Four terminals, 2x2 (commands, SSH)    |
| `3`       | `SUPER + 3`          | C   | File managers (Yazi, Thunar)           |
| `4`       | `SUPER + 4`          | C   | Mail (aerc + sheet, Claws Mail)        |
| `5`       | `SUPER + 5`          | C   | LibreOffice Writer (and Start Center)  |
| `6`       | `SUPER + 6`          | C   | LibreOffice Calc                       |
| `7`       | `SUPER + 7`          | C   | LibreOffice Impress                    |
| `8`       | `SUPER + 8`          | C   | LibreOffice Draw                       |
| `9`       | `SUPER + 9`          | C   | LibreOffice Math                       |
| `10`      | `SUPER + 0`          | C   | LibreOffice Base                       |
| `11`      | `SUPER + SHIFT + 1`  | C   | Comms (Teams, Zoom)                    |
| `12`      | `SUPER + SHIFT + 2`  | L   | Zen (streaming)                        |
| `13`      | `SUPER + SHIFT + 3`  | L   | LibreWolf                              |
| `14`      | `SUPER + SHIFT + 4`  | C   | Firefox Developer Edition              |
| `15`      | `SUPER + SHIFT + 5`  | C   | Brave                                  |
| `16`      | `SUPER + SHIFT + 6`  | L   | Video and image viewers (VLC, mpv, imv)|
| `17`      | `SUPER + SHIFT + 7`  | C   | Affinity Designer                      |
| `18`      | `SUPER + SHIFT + 8`  | C   | Affinity Photo                         |
| `19`      | `SUPER + SHIFT + 9`  | C   | Affinity Publisher                     |
| `20`      | `SUPER + SHIFT + 0`  | L   | DaVinci Resolve                        |
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
| `41+`     | none                 | C   | Unassigned windows, one per workspace  |

Files opened from Yazi or Thunar go to that app's workspace (a video to 16,
and so on). An app with no workspace of its own opens on the first free
workspace from 41 up, on the centre monitor, and takes focus; floating
dialogs open beside the window that asked. Workspaces 41+ have no keybind:
reach them with `SUPER + Scroll`. To put one on the left monitor (or bring it
back), focus it and press `SUPER + ,`; it stays there until it empties. An app's "Open / Save file" dialog
is Yazi too: it floats over the app, on the current workspace.

## Screenshots

| Keybind              | Action                  |
|----------------------|-------------------------|
| `Print`              | Screenshot region       |
| `SUPER + Print`      | Screenshot full screen  |

## Media / Hardware

| Keybind              | Action                  |
|----------------------|-------------------------|
| `Volume Up/Down`     | Adjust volume (5%)      |
| `SUPER + =` / `SUPER + -` | Volume up/down (5%, repeats when held) |
| `Mute`               | Toggle mute             |
| `Mic Mute`           | Toggle mic mute         |
| `Brightness Up/Down` | Adjust brightness (5%)  |

## Mouse

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Left-click drag`  | Move window        |
| `SUPER + Right-click drag` | Resize window      |
