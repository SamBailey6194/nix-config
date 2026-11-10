# Teams backgrounds

teams-for-linux has no **Add new** button for your own images. Instead it lists
the images a local web server offers. `home/modules/teams-backgrounds.nix` sets
this up for every desktop stage. The `services.teamsBackgrounds.enable` option
turns it on or off.

## What it does

- Writes `~/.config/teams-for-linux/config.json` with `customBackground.enabled`,
  `serviceBaseUrl = http://127.0.0.1:47816` and a 300-second re-fetch of the list.
  Home Manager manages this file, so set any other app options in the module, not by
  hand.
- `teams-backgrounds.service`, a user service started at login, serves
  `~/.local/share/teams-for-linux-backgrounds/` on loopback with
  `Access-Control-Allow-Origin: *`. It uses port 47816, not 8080, because
  llama-server already uses 8080.
- `teams-backgrounds-sync` copies
  `~/Repos/syntek/syntek-content/production/src/renders/studio16-webcam-bg.1920x1080.jpg`
  into that folder. It then makes a 280 × 158 thumbnail and writes the server's
  `config.json` list. It runs before the server starts, and again whenever the
  render changes (`teams-backgrounds-sync.path`).
- If the render is missing, the script makes the background again from the SVG,
  `brand/src/exports/room/webcam-bg/studio16-webcam-bg.svg`. It renders at
  1920 × 1080, exactly 3 px a cell. The new copy goes only into the served
  folder, never into `production/src/renders/`.

## Using it

1. Rebuild, then restart teams-for-linux.
2. In a meeting, open **Video effects**. **Syntek studio** appears among the Teams
   backgrounds. Choose it once.

Check the server: `curl -si http://127.0.0.1:47816/config.json`.
Logs: `journalctl --user -u teams-backgrounds -u teams-backgrounds-sync`.

## Format notes (2.27.0)

The project's docs site shows the list as `{"videoBackgroundImages": [...]}`.
The 2.27.0 code (`app/customBackground/index.js`) instead loops over a
**top-level array**:

```json
[{ "filetype": "jpg", "id": "syntek_studio16", "name": "Syntek studio",
   "src": "/studio16-webcam-bg.jpg", "thumb_src": "/studio16-webcam-bg.thumb.jpg" }]
```

The paths are relative to `serviceBaseUrl`. The flat option names
(`isCustomBackgroundEnabled`, `customBGServiceBaseUrl`) are deprecated and will be
removed in 2.30.0. Use the nested `customBackground` object instead.

The upstream docs also warn that the project may drop this workaround now that
Teams supports custom backgrounds in the browser.
