{ config, lib, pkgs, ... }:

# Custom video-call backgrounds for teams-for-linux (docs/TEAMS-BACKGROUNDS.md).
#
# teams-for-linux has no "Add new" button. With customBackground enabled it
# fetches <serviceBaseUrl>/config.json and lists every entry among the Teams
# backgrounds, loading each image from the same server. Read from the 2.27.0
# source (app/customBackground/index.js), not the docs site:
#   - the served config.json is a top-level JSON array of
#     { filetype, id, name, src, thumb_src }; the docs' {"videoBackgroundImages":
#     [...]} wrapper is not what this release parses;
#   - src and thumb_src are paths relative to serviceBaseUrl;
#   - the list is fetched once at start, then every configFetchInterval
#     seconds, so a server that comes up after Teams is still picked up.
#
# The images are renders: git-ignored in syntek-content, so never in the Nix
# store. teams-backgrounds-sync copies the 1920x1080 JPG into a served folder
# (re-run whenever the render changes) and, if the render is gone, makes one
# again from the tracked SVG.
let
  cfg = config.services.teamsBackgrounds;
  baseUrl = "http://127.0.0.1:${toString cfg.port}";
  served = "${config.xdg.dataHome}/teams-for-linux-backgrounds";
  content = "${config.home.homeDirectory}/Repos/syntek/syntek-content";
  render = "${content}/production/src/renders/studio16-webcam-bg.1920x1080.jpg";
  svg = "${content}/brand/src/exports/room/webcam-bg/studio16-webcam-bg.svg";

  # Static files with the Access-Control-Allow-Origin header the app needs,
  # loopback only. http.server already refuses paths outside --directory.
  server = pkgs.writeText "teams-backgrounds-server.py" ''
    import argparse
    import functools
    import http.server

    class Handler(http.server.SimpleHTTPRequestHandler):
        def end_headers(self):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-cache")
            super().end_headers()

        def list_directory(self, path):
            self.send_error(404)

    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--directory", required=True)
    args = parser.parse_args()
    handler = functools.partial(Handler, directory=args.directory)
    http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler).serve_forever()
  '';

  sync = pkgs.writeShellApplication {
    name = "teams-backgrounds-sync";
    runtimeInputs = with pkgs; [ coreutils imagemagick librsvg jq ];
    text = ''
      served=${lib.escapeShellArg served}
      render=${lib.escapeShellArg render}
      svg=${lib.escapeShellArg svg}
      image="$served/studio16-webcam-bg.jpg"
      thumb="$served/studio16-webcam-bg.thumb.jpg"
      mkdir -p "$served"

      if [ -f "$render" ]; then
        if ! cmp -s "$render" "$image"; then
          install -m 0644 "$render" "$image.tmp" && mv -f "$image.tmp" "$image"
          echo "Copied $render"
        fi
      elif [ ! -f "$image" ] && [ -f "$svg" ]; then
        # The render is gone: make it again from the SVG. 640 x 360 cells at
        # exactly 3 px a cell; the SVG asks for crisp edges, so no smoothing.
        echo "No render at $render; rendering $svg"
        rsvg-convert --width 1920 --height 1080 "$svg" \
          | magick png:- -background white -flatten -quality 92 "$image.tmp.jpg"
        mv -f "$image.tmp.jpg" "$image"
      elif [ ! -f "$image" ]; then
        echo "Neither $render nor $svg exists; serving no backgrounds" >&2
      fi

      if [ -f "$image" ]; then
        if [ ! -f "$thumb" ] || [ "$image" -nt "$thumb" ]; then
          magick "$image" -resize 280x158 -quality 90 "$thumb.tmp.jpg"
          mv -f "$thumb.tmp.jpg" "$thumb"
        fi
        jq -n '[{
          filetype: "jpg",
          id: "syntek_studio16",
          name: "Syntek studio",
          src: "/studio16-webcam-bg.jpg",
          thumb_src: "/studio16-webcam-bg.thumb.jpg"
        }]' > "$served/config.json.tmp"
      else
        echo '[]' > "$served/config.json.tmp"
      fi
      mv -f "$served/config.json.tmp" "$served/config.json"
    '';
  };
in
{
  options.services.teamsBackgrounds = {
    enable = lib.mkEnableOption "custom teams-for-linux backgrounds served from a local web server";
    port = lib.mkOption {
      type = lib.types.port;
      # Not 8080, the docs' example: llama-server (modules/software/local-llm.nix) has it.
      default = 47816;
      description = "Loopback port the background server listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The app's own settings file. Nested keys: the flat isCustomBackgroundEnabled
    # and customBGServiceBaseUrl are deprecated and go in 2.30.0 (issue #2842).
    xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
      customBackground = {
        enabled = true;
        serviceBaseUrl = baseUrl;
        configFetchInterval = 300;
      };
    };

    home.packages = [ sync ];

    systemd.user.services.teams-backgrounds-sync = {
      Unit.Description = "Copy the video-call background into the teams-for-linux background folder";
      Service = {
        Type = "oneshot";
        ExecStart = "${sync}/bin/teams-backgrounds-sync";
      };
    };

    # Pick up a new render without logging out.
    systemd.user.paths.teams-backgrounds-sync = {
      Unit.Description = "Watch the video-call background render";
      Path = {
        PathChanged = render;
        Unit = "teams-backgrounds-sync.service";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.teams-backgrounds = {
      Unit = {
        Description = "Local background server for teams-for-linux";
        Wants = [ "teams-backgrounds-sync.service" ];
        After = [ "teams-backgrounds-sync.service" ];
      };
      Service = {
        ExecStart = "${pkgs.python3}/bin/python3 -I ${server} --port ${toString cfg.port} --directory ${served}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
