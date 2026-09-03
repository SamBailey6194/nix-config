{ config, pkgs, lib, osConfig ? null, ... }:

{
  # Hyprland Wayland Compositor Configuration
  # Uses modular .lua files from config/hypr/ for Hyprland settings
  # (Hyprland 0.56 Lua config provider — see hl.meta.lua stubs for the API)
  # Uses Nix for companion programs (waybar, wofi, etc.)
  #
  # NOTE: This Home Manager module ONLY provides user-level configuration.
  # The actual Hyprland package and system integration is handled by the
  # NixOS module (programs.hyprland.enable) in modules/desktop/hyprland/default.nix
  #
  # See: https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/
  # See: https://wiki.nixos.org/wiki/Hyprland

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua"; # Lua config provider — our config files are .lua modules

    # CRITICAL: Use the Hyprland package from NixOS module, not Home Manager
    # This prevents duplicate systemd services and symlink conflicts
    # Requires Home Manager 5dc1c2e40410f7dabef3ba8bf4fdb3145eae3ceb or later
    package = null;
    portalPackage = null;

    # Bring up graphical-session.target.
    #
    # This was previously false, on the theory that the NixOS module handles
    # session management via UWSM. It does not: modules/desktop/hyprland
    # sets programs.hyprland.enable without withUWSM, and greetd launches
    # `start-hyprland` directly, so nothing ever started the target. The
    # user services home-manager wires to it - hypridle, hyprpaper, waybar -
    # therefore sat "enabled, inactive (dead)" for the whole session. waybar
    # and hyprpaper only appeared to work because 80-autostart.lua also
    # exec'd them by hand; hypridle had no such fallback, which is why the
    # laptop suspended without ever locking.
    #
    # With this true, home-manager defines hyprland-session.target (BindsTo
    # graphical-session.target, so starting it starts that too) and emits an
    # hl.exec_cmd into the generated hyprland.lua that runs
    # dbus-update-activation-environment and then starts the target. That
    # path is Lua-aware - see home-manager .../hyprland/lib.nix,
    # startupCommands - so it works under the 0.56 config provider, and it is
    # not gated on `package`, which stays null below.
    systemd.enable = true;

    # Modular Lua config files, deployed to ~/.config/hypr/<name>.lua.
    #
    # Home Manager generates ~/.config/hypr/hyprland.lua itself: it prepends
    # ~/.config/hypr to Lua's package.path and then emits one require() per
    # entry that has autoLoad = true. There is no hand-written manifest any
    # more — the old config/hypr/hyprland.conf "source = ..." list is gone.
    #
    # LOAD ORDER: the generated require() calls are sorted by attribute name
    # (home-manager .../hyprland/lib.nix, renderLuaFiles: `sort lib.lessThan`).
    # Every name below is a fixed-width two-digit prefix, so lexicographic
    # order and numeric order agree — 10 before 20 before ... before 80.
    # This is why the numeric prefixes exist; do not rename them to bare words.
    #
    # Per-device overrides live in the device-specific home/*.nix files and use
    # a "90-device" prefix so that they are required last and win.
    extraLuaFiles = {
      # Shared locals ($mod and friends). Returns a table and is pulled in with
      # require("00-vars") by 60-keybinds, so it must NOT be auto-required by
      # hyprland.lua — requiring it at top level would be a no-op at best.
      "00-vars" = {
        content = ../../config/hypr/00-vars.lua;
        autoLoad = false;
      };

      # Everything below is auto-required, in this order.
      "10-base" = ../../config/hypr/10-base.lua;
      "20-monitors" = ../../config/hypr/20-monitors.lua;
      "30-input" = ../../config/hypr/30-input.lua;
      "40-appearance" = ../../config/hypr/40-appearance.lua;
      "50-animations" = ../../config/hypr/50-animations.lua;
      "60-keybinds" = ../../config/hypr/60-keybinds.lua;
      "70-windowrules" = ../../config/hypr/70-windowrules.lua;
      "80-autostart" = ../../config/hypr/80-autostart.lua;
    };
  };

  # Keybind cheat sheet — read by the Super+Slash keybind and by the laptop
  # dashboard, so it stays a plain file rather than an extraLuaFiles entry.
  home.file = {
    ".config/hypr/KEYBINDS.md".source = ../../config/hypr/KEYBINDS.md;
  };

  # Project picker for the generic dev layout (SUPER + CTRL + Z).
  #
  # dev-layout needs a project PATH: the folder name becomes Zed's window
  # title, which is the only thing the placement rule can match on (Zed has no
  # --class). A keybind has no useful working directory of its own — it
  # inherits Hyprland's, which is $HOME — so the path has to be chosen
  # interactively. This lists every <account>/<project> directory under
  # ~/Repos and hands the choice to dev-layout.
  #
  # `--show dmenu` is explicit rather than `--dmenu` because programs.wofi
  # below sets `show = "drun"` in the config file, and the explicit mode flag
  # overrides it.
  home.packages = [
    # Lock, verify the lock is really up, then suspend.
    #
    # `systemctl suspend` on its own relies on hypridle being alive to catch
    # PrepareForSleep and run before_sleep_cmd. That is exactly the assumption
    # that silently failed before graphical-session.target was fixed - the
    # laptop suspended wide open. So this does not trust it: it locks first,
    # waits for hyprlock to actually exist, and refuses to suspend if it never
    # appears. Better to stay awake than to sleep unlocked.
    (pkgs.writeShellScriptBin "lock-and-suspend" ''
      set -euo pipefail

      loginctl lock-session

      # hyprlock takes a moment to grab the session lock; poll rather than
      # guessing a fixed sleep. 5s is far longer than the ~20ms it took in
      # testing, and only matters when something is wrong.
      for _ in $(seq 1 50); do
        if ${pkgs.procps}/bin/pidof hyprlock >/dev/null 2>&1; then
          break
        fi
        sleep 0.1
      done

      if ! ${pkgs.procps}/bin/pidof hyprlock >/dev/null 2>&1; then
        notify-send --urgency=critical \
          "Suspend aborted" \
          "hyprlock did not start - refusing to suspend an unlocked session."
        exit 1
      fi

      systemctl suspend
    '')

    (pkgs.writeShellScriptBin "dev-layout-pick" ''
      set -euo pipefail

      root="''${DEV_LAYOUT_REPO_ROOT:-$HOME/Repos}"

      if [ ! -d "$root" ]; then
        notify-send --urgency=critical "dev-layout" "No repo root at $root"
        exit 1
      fi

      # <account>/<project>, two levels down: personal/, syntek/, missional-gen/
      mapfile -t projects < <(
        find "$root" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' 2>/dev/null | sort
      )

      if [ "''${#projects[@]}" -eq 0 ]; then
        notify-send --urgency=critical "dev-layout" "No projects found under $root"
        exit 1
      fi

      # wofi exits non-zero when dismissed with Escape — that is a normal
      # cancel, not a failure, so leave quietly without a notification.
      choice=$(printf '%s\n' "''${projects[@]}" \
        | ''${WOFI:-wofi} --show dmenu --prompt "Dev space") || exit 0

      [ -n "$choice" ] || exit 0

      exec dev-layout --new "$root/$choice"
    '')
  ];

  # LuaLS stubs for editor completion on the hl.* API.
  #
  # Home Manager normally writes hypr/.luarc.json itself, but it guards that on
  # `finalPackage != null` and we deliberately set package = null above (see the
  # note there — a non-null package would duplicate the systemd services the
  # NixOS module already provides). So we point at the stubs from the Hyprland
  # package that the NixOS module installs instead. Mirrors the JSON that
  # home-manager .../hyprland/default.nix (luaLanguageServerConfig) generates.
  xdg.configFile."hypr/.luarc.json" = lib.mkIf (osConfig != null) {
    text = builtins.toJSON {
      workspace.library = [
        "${
          osConfig.programs.hyprland.finalPackage or osConfig.programs.hyprland.package
        }/share/hypr/stubs"
      ];
      diagnostics.globals = [ "hl" ];
    };
  };

  # Hyprpaper configuration (wallpaper daemon)
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [
        "~/Pictures/wallpapers/default.png"
      ];
      wallpaper = [
        ",~/Pictures/wallpapers/default.png"
      ];
    };
  };

  # Hypridle configuration (idle daemon)
  services.hypridle = {
    enable = true;
    settings = {
      # NOTE: under the Lua config provider, `hyprctl dispatch` wraps its
      # argument as `hl.dispatch(<text>)`, so the legacy flat form
      # (`hyprctl dispatch dpms on`) is a Lua syntax error and exits 7.
      # Verified live on 0.56: the legacy form fails, `hl.dsp.dpms('on')`
      # returns ok. Getting this wrong means the screen never wakes.
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch \"hl.dsp.dpms('on')\"";
      };

      listener = [
        {
          timeout = 300; # 5 minutes
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 600; # 10 minutes
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 900; # 15 minutes
          on-timeout = "hyprctl dispatch \"hl.dsp.dpms('off')\"";
          on-resume = "hyprctl dispatch \"hl.dsp.dpms('on')\"";
        }
      ];
    };
  };

  # Hyprlock configuration (screen locker)
  programs.hyprlock = {
    enable = true;
    settings = {
      # hyprlock 0.9.6 removed three options that used to live in this block,
      # and they are hard errors now rather than being ignored:
      #
      #   disable_loading_bar - gone outright, there is no loading bar any more
      #   grace               - moved to the CLI as `--grace <seconds>`, which
      #                         already defaults to 0 (main.cpp: value_or(0)),
      #                         exactly what we were setting here
      #   no_fade_in          - superseded by the `animations` section, whose
      #                         `enabled` defaults to true, matching the old
      #                         `no_fade_in = false`
      #
      # So all three are simply dropped: behaviour is unchanged in every case.
      # The valid general: keys in 0.9.6 (ConfigManager.cpp) are text_trim,
      # hide_cursor, ignore_empty_input, immediate_render, fractional_scaling,
      # screencopy_mode and fail_timeout.
      #
      # Note that grace being a CLI flag means hypridle's
      # `lock_cmd = "pidof hyprlock || hyprlock"` gets grace 0 by default -
      # a password is required immediately, which is what we want.
      general = {
        hide_cursor = true;
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
          outline_thickness = 5;
          placeholder_text = "Password...";
          shadow_passes = 2;
        }
      ];
    };
  };

  # Waybar configuration (status bar)
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;

        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "temperature"
          "backlight"
          "battery"
          "tray"
        ];

        # Module configurations
        "hyprland/workspaces" = {
          format = "{icon}";
          on-click = "activate";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            "10" = "10";
          };
        };

        "hyprland/window" = {
          format = "{}";
          max-length = 50;
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%A, %d %B %Y (%H:%M:%S)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#ffead3'><b>{}</b></span>";
              days = "<span color='#ecc6d9'><b>{}</b></span>";
              weeks = "<span color='#99ffdd'><b>W{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          format = " {usage}%";
          tooltip = false;
        };

        memory = {
          format = " {}%";
        };

        temperature = {
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = [ "" "" "" ];
        };

        backlight = {
          format = "{icon} {percent}%";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-alt = "{icon} {time}";
          format-icons = [ "" "" "" "" "" ];
        };

        network = {
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ipaddr}/{cidr}";
          tooltip-format = " {ifname} via {gwaddr}";
          format-linked = " {ifname} (No IP)";
          format-disconnected = "⚠ Disconnected";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-bluetooth-muted = " {icon}";
          format-muted = " {volume}%";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };

        tray = {
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
      }

      window#waybar {
        background-color: rgba(43, 48, 59, 0.95);
        color: #ffffff;
        transition-property: background-color;
        transition-duration: .5s;
      }

      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #ffffff;
      }

      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
      }

      #workspaces button.active {
        background-color: rgba(255, 180, 84, 0.5);
      }

      #window,
      #workspaces {
        margin: 0 4px;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #tray {
        padding: 0 10px;
        color: #ffffff;
      }

      #battery.charging, #battery.plugged {
        color: #26A65B;
      }

      #battery.critical:not(.charging) {
        background-color: #f53c3c;
        color: #ffffff;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      @keyframes blink {
        to {
          background-color: #ffffff;
          color: #000000;
        }
      }
    '';
  };

  # Wofi configuration (app launcher)
  programs.wofi = {
    enable = true;
    settings = {
      width = 600;
      height = 400;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
      gtk_dark = true;
    };

    style = ''
      window {
        margin: 0px;
        border: 2px solid #ffb454;
        background-color: #0f1419;
        border-radius: 8px;
      }

      #input {
        margin: 5px;
        border: none;
        color: #ffffff;
        background-color: #1f2430;
        border-radius: 4px;
      }

      #inner-box {
        margin: 5px;
        border: none;
        background-color: #0f1419;
      }

      #outer-box {
        margin: 5px;
        border: none;
        background-color: #0f1419;
      }

      #scroll {
        margin: 0px;
        border: none;
      }

      #text {
        margin: 5px;
        border: none;
        color: #ffffff;
      }

      #entry:selected {
        background-color: #ffb454;
        color: #0f1419;
      }
    '';
  };
}
