# Intel desktop displays and workspaces

EDIDs and the active Ubuntu X11 session were inspected on 2026-10-05.
The workspace mapping and 150% 4K scale were selected by Sam.

| Physical display | EDID model | Current Ubuntu connector | DRM connector | NixOS mode / scale | Workspaces |
| --- | --- | --- | --- | --- | --- |
| Left | AOC U2879G6 | DP-4 | DP-3 | 3840×2160 / 60Hz / 150% | 7 Zen, mainly media while working |
| Centre, primary work display | AOC AG271QG4 | DP-2 | DP-2 | 2560×1440 / 143.91Hz / 100% | 2 Nix config; 3–5 development; 8 Affinity + Resolve; 9 chat; 10 Brave, Firefox Developer, LibreWolf and unassigned apps |
| Right, portrait | AOC 27G2WG3- | HDMI-0 | HDMI-A-1 | 1920×1080 / 144Hz / 100%, rotated | 1 dashboard; 6 mail |

Rules match `desc:AOC <model>` prefixes rather than assuming X11 output
numbers carry over to Wayland. The portrait transform preserves Ubuntu's
`xrandr left` rotation. At 150%, the 4K display has a 2560×1440 logical area;
positions are left 0×0, centre 2560×0, right 5120×0. This keeps the screen edges
adjacent instead of leaving a 1280-pixel gap after scaling.

The Intel profile replaces the future AMD tower's device file. This also
removes that file's stale Affinity-on-4 and Resolve-on-5 rules. Workspaces 3–5
stay available to the development launcher. In dev and higher Intel stages,
workspace 1 launches three terminals, top to bottom: keybinding sheet, btop,
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
Use `Super+1` through `Super+0` to confirm workspace placement; `Super+Shift`
plus that key moves a window. Close/reopen one dashboard pane and check
`Super+Escape`. Test Resolve's actual application class with `hyprctl clients`
once installed; the rule covers `resolve`, `Resolve` and `DaVinciResolve`.
Brave, Firefox Developer and LibreWolf open on the centre's workspace 10.
Only Zen opens on workspace 7 for media. Workspace 10 also catches windows
without a specific assignment; shared app rules, dynamic development rules
and dashboard rules take precedence. Existing windows can be moved with
`Super+Shift+0`; these launch rules do not relocate already open windows.

These changes target the configured Hyprland desktop on NixOS. Ubuntu GNOME's
current layout is only the audit source. GNOME/KDE workspace semantics require
their own configuration if you add those environments later. Actual Wayland
behaviour still needs the first-boot checks; Ubuntu X11 cannot validate it.

Configuration follows [Hyprland monitor rules](https://wiki.hypr.land/Configuring/Basics/Monitors/),
[workspace rules](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/)
and [window rules](https://wiki.hypr.land/Configuring/Basics/Window-Rules/).
