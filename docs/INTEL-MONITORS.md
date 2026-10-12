# Intel desktop displays and workspaces

EDIDs and the active Ubuntu X11 session were inspected on 2026-10-05.
The workspace mapping and 150% 4K scale were selected by Sam. devtower-intel
has forty fixed workspaces plus overflow workspaces from 41 up, defined in `config/hypr/devices/devtower-intel.lua`;
laptop-intel keeps the default ten-workspace map.

| Physical display | EDID model | Current Ubuntu connector | DRM connector | NixOS mode / scale | Workspaces |
| --- | --- | --- | --- | --- | --- |
| Left | AOC U2879G6 | DP-4 | DP-3 | 3840×2160 / 60Hz / 150% | 12 Zen (media while working); 13 LibreWolf; 16 video and image viewers; 20 Resolve; 29 EffectCraft; 30 FilmCraft |
| Centre, primary work display | AOC AG271QG4 | DP-2 | DP-2 | 2560×1440 / 143.91Hz / 100% | 2 four terminals (2×2); 3 file managers; 4 mail; 5–10 LibreOffice; 11 Teams, Zoom; 14 Firefox Developer; 15 Brave; 17–19 Affinity; 21–28 Craft suite; 31 Nix config; 32–40 development; 41+ unassigned apps |
| Right, portrait | AOC 27G2WG3- | HDMI-0 | HDMI-A-1 | 1920×1080 / 144Hz / 100%, rotated | 1 dashboard |

Rules match `desc:AOC <model>` prefixes rather than assuming X11 output
numbers carry over to Wayland. The portrait transform preserves Ubuntu's
`xrandr left` rotation. At 150%, the 4K display has a 2560×1440 logical area;
positions are left 0×0, centre 2560×0, right 5120×0. This keeps the screen edges
adjacent instead of leaving a 1280-pixel gap after scaling.

The Intel profile replaces the future AMD tower's device file. This also
removes that file's stale Affinity-on-4 and Resolve-on-5 rules. Workspaces
32–40 are the development launcher's pool and 31 its nix-config layout; the
device file exports `DEV_LAYOUT_NIX_CONFIG_WS`, `DEV_LAYOUT_POOL_FIRST` and
`DEV_LAYOUT_POOL_LAST` with `hl.env` for `dev-layout`. In dev and higher Intel
stages, workspace 1 launches three terminals, top to bottom: keybinding sheet, btop,
nvtop, and workspace 2 four plain shells in a 2×2 grid (for commands and SSH),
starting in the home directory. They are independently sized floating panes
confined to their workspace, with margins for the top bar; login leaves focus
on workspace 2. `Super+Escape` focuses the dashboard and `Super+Shift+Escape`
the terminal grid; each reopens missing panes without duplicating existing
ones. Login also opens Yazi on workspace 3, aerc with its keybind sheet on 4
and Teams on 11, silently, so focus stays on workspace 2. The desktop stage
gets the display/workspace rules without any of this autostart.

After booting the NixOS desktop, run:

```sh
hyprctl monitors all
hyprctl configerrors
hyprctl workspaces
```

Confirm descriptions begin with the configured prefixes, refresh rates match
available modes, the 4K scale is 1.5, and portrait orientation is correct.
Use `Super+1` through `Super+0` (workspaces 1–10), with `Shift` (11–20),
`Ctrl` (21–30) or `Alt` (31–40) added, to confirm workspace placement. To move
a window, press `Super+period`, then the number with the same bank modifier
(`1` → 1, `Shift+1` → 11, `Ctrl+1` → 21, `Alt+1` → 31); `Escape` cancels. The
full sheet is `config/hypr/KEYBINDS-devtower-intel.md` (`Super+/`). Close/reopen
one dashboard pane and check
`Super+Escape`, and likewise one ws2 terminal with `Super+Shift+Escape`. Test Resolve's actual application class with `hyprctl clients`
once installed; the rule covers `resolve`, `Resolve` and `DaVinciResolve`.
Resolve opens on workspace 20, on the left. Zen (12) and LibreWolf (13) open
on the left; Firefox Developer (14) and Brave (15) on the centre. A window
without a specific assignment opens on the first free workspace from 41 up, on
the centre monitor, and takes focus (a floating dialog joins the window that
opened it instead); the device's app rules, dynamic development rules and
dashboard rules take precedence. Existing windows can be
moved with `Super+period` then `Ctrl+8`; these launch rules do not relocate
already open windows.

These changes target the configured Hyprland desktop on NixOS. Ubuntu GNOME's
current layout is only the audit source. GNOME/KDE workspace semantics require
their own configuration if you add those environments later. Actual Wayland
behaviour still needs the first-boot checks; Ubuntu X11 cannot validate it.

Configuration follows [Hyprland monitor rules](https://wiki.hypr.land/Configuring/Basics/Monitors/),
[workspace rules](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/)
and [window rules](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).
