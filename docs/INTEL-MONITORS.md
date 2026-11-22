# Intel desktop displays and workspaces

EDIDs and the active Ubuntu X11 session were inspected on 2026-10-05.
The workspace mapping and 150% 4K scale were selected by Sam. Every device
shares one map of fifty keyed workspaces (1–40 assigned, spares on 41–50) and
overflow workspaces from 51 up, defined in `config/hypr/00-vars.lua` and
registered by `config/hypr/70-windowrules.lua`. Only the monitor placement
below is devtower-intel's own (`config/hypr/devices/devtower-intel.lua`);
laptop-intel has one screen and uses the map as it is.

| Physical display | EDID model | Current Ubuntu connector | DRM connector | NixOS mode / scale | Workspaces |
| --- | --- | --- | --- | --- | --- |
| Left | AOC U2879G6 | DP-4 | DP-3 | 3840×2160 / 60Hz / 150% | 12 Zen (media while working); 13 LibreWolf; 16 video and image viewers; 20 Resolve; 21 FilmCraft; 22 EffectCraft; 23 AniCraft |
| Centre, primary work display | AOC AG271QG4 | DP-2 | DP-2 | 2560×1440 / 143.91Hz / 100% | 2 four terminals (2×2); 3 Yazi; 4 mail and calendar; 5 Start Center, Writer, WordCraft; 6 Impress, DeckCraft; 7 Calc, GridCraft; 8 PdfCraft, Zathura; 9 DesignCraft; 10 Math, Base; 11 Teams, Zoom, Slack; 14 Firefox Developer; 15 Brave; 17 PhotoCraft, GIMP; 18 Draw, VectorCraft; 19 LightCraft; 24 SoundCraft, Reaper, Audacity; 25 Blender; 26 MaterialCraft; 27 TextureCraft; 28 CADCraft; 29 FigCraft; 30 Playwright Chromium; 31 Nix config; 32–40 development; 41–50 spare; 51+ unassigned apps (including Affinity) |
| Right, portrait | AOC 27G2WG3- | HDMI-0 | HDMI-A-1 | 1920×1080 / 144Hz / 100%, rotated | 1 dashboard |

Rules match `desc:AOC <model>` prefixes rather than assuming X11 output
numbers carry over to Wayland. The portrait transform preserves Ubuntu's
`xrandr left` rotation. At 150%, the 4K display has a 2560×1440 logical area;
positions are left 0×0, centre 2560×0, right 5120×0. This keeps the screen edges
adjacent instead of leaving a 1280-pixel gap after scaling.

The Intel profile replaces the future AMD tower's device file. Workspaces
32–40 are the development launcher's pool and 31 its nix-config layout; the
shared `70-windowrules.lua` exports `DEV_LAYOUT_NIX_CONFIG_WS`,
`DEV_LAYOUT_POOL_FIRST` and `DEV_LAYOUT_POOL_LAST` with `hl.env` for
`dev-layout`, on every device. In dev and higher Intel
stages, workspace 1 launches two terminals, top to bottom: btop, nvtop.
Workspace 2 gets four plain shells (for commands and SSH), starting in the
home directory. All of them are tiled by dwindle like any window; login leaves focus
on workspace 2. `Super+Escape` focuses the dashboard and `Super+Shift+Escape`
the terminal grid; each reopens missing panes without duplicating existing
ones. Login also opens Yazi on workspace 3, aerc with khal's interactive
calendar on 4 (aerc's keybind sheet stays on `Super+E`), Zen on 12 and Brave on 15, silently, so focus stays on workspace 2. The desktop stage
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
`Ctrl` (21–30), `Alt` (31–40) or `Ctrl+Shift` (41–50) added, to confirm workspace placement. To move
a window, press `Super+period`, then the number with the same bank modifier
(`1` → 1, `Shift+1` → 11, `Ctrl+1` → 21, `Alt+1` → 31, `Ctrl+Shift+1` → 41); `Escape` cancels. The
full sheet is `config/hypr/KEYBINDS-devtower-intel.md` (`Super+/`). Close/reopen
one dashboard pane and check
`Super+Escape`, and likewise one ws2 terminal with `Super+Shift+Escape`. Test Resolve's actual application class with `hyprctl clients`
once installed; the rule covers `resolve`, `Resolve` and `DaVinciResolve`.
Resolve opens on workspace 20, on the left. Zen (12) and LibreWolf (13) open
on the left; Firefox Developer (14) and Brave (15) on the centre. A window
without a specific assignment opens on the first free workspace from 51 up, on
the centre monitor, and takes focus (a floating dialog joins the window that
opened it instead); the shared app rules, dynamic development rules and
dashboard rules take precedence. `Super+comma` moves the focused workspace
between the centre and left monitors (meant for 41+, which all open on the
centre). Existing windows can be moved with `Super+period` then the target's
chord (for example `Shift+0` for Resolve on 20); these launch rules do not
relocate already open windows.

These changes target the configured Hyprland desktop on NixOS. Ubuntu GNOME's
current layout is only the audit source. GNOME/KDE workspace semantics require
their own configuration if you add those environments later. Actual Wayland
behaviour still needs the first-boot checks; Ubuntu X11 cannot validate it.

Configuration follows [Hyprland monitor rules](https://wiki.hypr.land/Configuring/Basics/Monitors/),
[workspace rules](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/)
and [window rules](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).
