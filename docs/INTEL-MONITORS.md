# Intel desktop displays and workspaces

EDIDs and the active Ubuntu X11 session were inspected on 2026-10-05.
The workspace mapping and 150% 4K scale were selected by Sam. devtower-intel
has forty workspaces, defined in `config/hypr/devices/devtower-intel.lua`;
laptop-intel keeps the default ten-workspace map.

| Physical display | EDID model | Current Ubuntu connector | DRM connector | NixOS mode / scale | Workspaces |
| --- | --- | --- | --- | --- | --- |
| Left | AOC U2879G6 | DP-4 | DP-3 | 3840×2160 / 60Hz / 150% | 11 Zen (media while working); 12 LibreWolf; 15 video and image viewers; 19 Resolve; 29 EffectCraft; 30 FilmCraft |
| Centre, primary work display | AOC AG271QG4 | DP-2 | DP-2 | 2560×1440 / 143.91Hz / 100% | 2 file managers; 3 mail; 4–9 LibreOffice; 10 Teams, Zoom; 13 Firefox Developer; 14 Brave; 16–18 Affinity; 20 spare (catches unassigned apps); 21–28 Craft suite; 31 Nix config; 32–40 development |
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
nvtop. They are independently sized floating panes confined to workspace 1,
with margins for the top bar. `Super+Escape` focuses the dashboard and reopens
missing panes without duplicating existing ones. The desktop stage gets the
display/workspace rules without development dashboard autostart.

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
`Super+Escape`. Test Resolve's actual application class with `hyprctl clients`
once installed; the rule covers `resolve`, `Resolve` and `DaVinciResolve`.
Resolve opens on workspace 19, on the left. Zen (11) and LibreWolf (12) open
on the left; Firefox Developer (13) and Brave (14) on the centre. Workspace 20
catches windows without a specific assignment; the device's app rules, dynamic
development rules and dashboard rules take precedence. Existing windows can be
moved with `Super+period` then `Ctrl+8`; these launch rules do not relocate
already open windows.

These changes target the configured Hyprland desktop on NixOS. Ubuntu GNOME's
current layout is only the audit source. GNOME/KDE workspace semantics require
their own configuration if you add those environments later. Actual Wayland
behaviour still needs the first-boot checks; Ubuntu X11 cannot validate it.

Configuration follows [Hyprland monitor rules](https://wiki.hypr.land/Configuring/Basics/Monitors/),
[workspace rules](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/)
and [window rules](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).
