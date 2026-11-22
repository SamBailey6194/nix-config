# Hyprland Keybinds Reference

This is laptop-intel's sheet, and the shared one: every device uses the same
fifty keyed workspaces and the same keys. devtower-intel has its own sheet,
`KEYBINDS-devtower-intel.md` (adding which monitor each workspace is on),
which home/devtower-intel.nix deploys in place of this one.

laptop-intel is a thin client: office, Craft, Affinity and the heavier media
apps run on devtower-intel, so their keys below simply do nothing here.

## Applications

| Keybind              | Action                  |
|----------------------|-------------------------|
| `SUPER + Return`     | Terminal (kitty)        |
| `SUPER + SHIFT + Return` | nix-config layout: Neovim alone (ws 31) |
| `SUPER + CTRL + Return`  | Dev layout: Neovim alone (next free ws 32-40) |
| `SUPER + ALT + Return`   | Neovim in plain Kitty (first free ws 51+) |
| `SUPER + Space`      | App launcher (wofi)     |
| `SUPER + Z`          | Zed editor              |
| `SUPER + SHIFT + Z`  | nix-config layout: Zed alone (ws 31) |
| `SUPER + CTRL + Z`   | Dev layout: Zed alone (next free ws 32-40) |
| `SUPER + F`          | File manager: Yazi (ws 3; F1 inside = its keys) |
| `SUPER + W`          | Zen browser, default (ws 12) |
| `SUPER + SHIFT + W`  | Brave browser (ws 15)   |
| `SUPER + ALT + W`    | LibreWolf browser (ws 13) |
| `SUPER + CTRL + W`   | Firefox Developer Ed. (ws 14) |
| `SUPER + E`          | Mail: aerc + its keybind sheet (ws 4) |
| `SUPER + A`, then a key | Launch an app on its workspace (below) |
| `SUPER + T`          | Teams (ws 11)           |
| `SUPER + C`          | Zoom (ws 11)            |
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
alone. A Neovim layout is one Kitty window: the keybind reference,
file tree, git panel and shell are panes and tabs inside Neovim, and its own
bindings are listed in `~/.config/nvim/KEYBINDS.md`.

## App launcher (SUPER + A)

Press `SUPER + A`, then one key. The app opens on its own workspace and takes
you there; `SHIFT` opens its Craft pair instead. One launch per press, and
`Esc` cancels. An app this device does not install just fails to start (on
laptop-intel that is most of them).

| Key         | App (workspace)          | With `SHIFT`             |
|-------------|--------------------------|--------------------------|
| `s`         | LibreOffice Start Center (5) |                      |
| `w`         | LibreOffice Writer (5)   | WordCraft (5)            |
| `i`         | LibreOffice Impress (6)  | DeckCraft (6)            |
| `c`         | LibreOffice Calc (7)     | GridCraft (7)            |
| `p`         | Zathura (8)              | PdfCraft (8)             |
| `u`         | DesignCraft (9)          |                          |
| `m`         | LibreOffice Math (10)    | MaterialCraft (26)       |
| `b`         | LibreOffice Base (10)    |                          |
| `k`         | Slack (11)               |                          |
| `v`         | VLC (16)                 | mpv (16)                 |
| `g`         | GIMP (17)                | PhotoCraft (17)          |
| `d`         | LibreOffice Draw (18)    | VectorCraft (18)         |
| `l`         | LightCraft (19)          |                          |
| `r`         | DaVinci Resolve (20)     | FilmCraft (21)           |
| `e`         | EffectCraft (22)         |                          |
| `a`         | AniCraft (23)            |                          |
| `o`         | Reaper (24)              | SoundCraft (24); `CTRL + o`: Audacity (24) |
| `3`         | Blender (25)             |                          |
| `t`         | TextureCraft (27)        |                          |
| `x`         | CADCraft (28)            |                          |
| `f`         | FigCraft (29)            |                          |
| `Esc`       | Cancel                   |                          |

## Affinity Suite

Affinity has no workspace: it opens on the first free one from 51 up. It is
not installed on laptop-intel's full config, so these keys do nothing there.

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

| Keybind                  | Action                        |
|--------------------------|-------------------------------|
| `SUPER + 1-9, 0`         | Switch to workspace 1-10      |
| `SUPER + SHIFT + 1-9, 0` | Switch to workspace 11-20     |
| `SUPER + CTRL + 1-9, 0`  | Switch to workspace 21-30     |
| `SUPER + ALT + 1-9, 0`   | Switch to workspace 31-40     |
| `SUPER + CTRL + SHIFT + 1-9, 0` | Switch to workspace 41-50 |
| `SUPER + .`, then `1-9, 0` (+ `SHIFT` / `CTRL` / `ALT` / `CTRL + SHIFT`) | Move window to that workspace (same banks) |
| `SUPER + .`, then `Esc`  | Cancel the move               |
| Numpad `1-9, 0`          | Same as the top-row numbers in every bind above, NumLock on or off |
| `SUPER + S`              | Toggle scratchpad             |
| `SUPER + SHIFT + S`      | Move to scratchpad            |
| `SUPER + Scroll`         | Cycle workspaces              |
| `SUPER + Escape`         | Dashboard (ws 1): reopens a closed pane |

## Workspace Map

The same map on every device; an app a device does not install just never
appears.

| Workspace | Key                  | Contents                               |
|-----------|----------------------|----------------------------------------|
| `1`       | `SUPER + 1`          | Dashboard (keybinds + btop on laptop-intel) |
| `2`       | `SUPER + 2`          | Ordinary workspace (devtower-intel: four terminals) |
| `3`       | `SUPER + 3`          | File manager (Yazi)                    |
| `4`       | `SUPER + 4`          | Mail (aerc + keybind sheet; khal on devtower-intel) |
| `5`       | `SUPER + 5`          | LibreOffice Start Center + Writer, WordCraft |
| `6`       | `SUPER + 6`          | LibreOffice Impress, DeckCraft         |
| `7`       | `SUPER + 7`          | LibreOffice Calc, GridCraft            |
| `8`       | `SUPER + 8`          | PDFs: PdfCraft, Zathura                |
| `9`       | `SUPER + 9`          | DesignCraft                            |
| `10`      | `SUPER + 0`          | LibreOffice Math + Base                |
| `11`      | `SUPER + SHIFT + 1`  | Comms (Teams, Zoom, Slack)             |
| `12`      | `SUPER + SHIFT + 2`  | Zen (streaming)                        |
| `13`      | `SUPER + SHIFT + 3`  | LibreWolf                              |
| `14`      | `SUPER + SHIFT + 4`  | Firefox Developer Edition              |
| `15`      | `SUPER + SHIFT + 5`  | Brave                                  |
| `16`      | `SUPER + SHIFT + 6`  | Video and image viewers (VLC, mpv, imv)|
| `17`      | `SUPER + SHIFT + 7`  | PhotoCraft, GIMP                       |
| `18`      | `SUPER + SHIFT + 8`  | LibreOffice Draw, VectorCraft          |
| `19`      | `SUPER + SHIFT + 9`  | LightCraft                             |
| `20`      | `SUPER + SHIFT + 0`  | DaVinci Resolve                        |
| `21`      | `SUPER + CTRL + 1`   | FilmCraft                              |
| `22`      | `SUPER + CTRL + 2`   | EffectCraft                            |
| `23`      | `SUPER + CTRL + 3`   | AniCraft                               |
| `24`      | `SUPER + CTRL + 4`   | SoundCraft, Reaper, Audacity           |
| `25`      | `SUPER + CTRL + 5`   | Blender                                |
| `26`      | `SUPER + CTRL + 6`   | MaterialCraft                          |
| `27`      | `SUPER + CTRL + 7`   | TextureCraft                           |
| `28`      | `SUPER + CTRL + 8`   | CADCraft                               |
| `29`      | `SUPER + CTRL + 9`   | FigCraft                               |
| `30`      | `SUPER + CTRL + 0`   | Playwright browser testing (Chromium)  |
| `31`      | `SUPER + ALT + 1`    | nix-config dev layout (reserved)       |
| `32-40`   | `SUPER + ALT + 2-9, 0` | Dev pool (allocated as needed)       |
| `41-50`   | `SUPER + CTRL + SHIFT + 1-9, 0` | Spare (overflow skips them) |
| `51+`     | none                 | Unassigned windows, one per workspace  |

Files opened from Yazi go to that app's workspace (a browser link to 12, a
video to 16, and so on). An app with no workspace of its own (Affinity
included) opens on the first free workspace from 51 up and takes focus;
floating dialogs open beside the window that asked. Workspaces 51+ have no
keybind: reach them with `SUPER + Scroll`. An app's "Open / Save file"
dialog is Yazi too: it floats over the app, on the current workspace.

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
