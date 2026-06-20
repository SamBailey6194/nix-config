{ config, pkgs, lib, ... }:

{
  # Hyprland Wayland Compositor Configuration
  # Uses modular .conf files from config/hypr/ for Hyprland settings
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
    configType = "hyprlang"; # Keep hyprlang — our config files use this format

    # CRITICAL: Use the Hyprland package from NixOS module, not Home Manager
    # This prevents duplicate systemd services and symlink conflicts
    # Requires Home Manager 5dc1c2e40410f7dabef3ba8bf4fdb3145eae3ceb or later
    package = null;
    portalPackage = null;

    # CRITICAL: Disable systemd integration to prevent conflicts with UWSM
    # The NixOS module handles session management via UWSM (if enabled)
    # or via its own systemd integration
    systemd.enable = false;

    # Source the modular .conf files instead of using Nix settings
    # This allows easier editing with familiar Hyprland syntax
    extraConfig = builtins.readFile ../../config/hypr/hyprland.conf;
  };

  # Copy the modular config files to ~/.config/hypr/
  # This allows Hyprland to source them at runtime
  home.file = {
    ".config/hypr/base.conf".source = ../../config/hypr/base.conf;
    ".config/hypr/monitors.conf".source = ../../config/hypr/monitors.conf;
    ".config/hypr/input.conf".source = ../../config/hypr/input.conf;
    ".config/hypr/appearance.conf".source = ../../config/hypr/appearance.conf;
    ".config/hypr/animations.conf".source = ../../config/hypr/animations.conf;
    ".config/hypr/keybinds.conf".source = ../../config/hypr/keybinds.conf;
    ".config/hypr/windowrules.conf".source = ../../config/hypr/windowrules.conf;
    ".config/hypr/autostart.conf".source = ../../config/hypr/autostart.conf;
    ".config/hypr/KEYBINDS.md".source = ../../config/hypr/KEYBINDS.md;
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
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
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
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  # Hyprlock configuration (screen locker)
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 0;
        hide_cursor = true;
        no_fade_in = false;
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
