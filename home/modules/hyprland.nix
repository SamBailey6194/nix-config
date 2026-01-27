{ config, pkgs, lib, ... }:

{
  # Hyprland Wayland Compositor Configuration
  # Base configuration with vim-style navigation
  #
  # NOTE: This Home Manager module ONLY provides user-level configuration.
  # The actual Hyprland package and system integration is handled by the
  # NixOS module (programs.hyprland.enable) in modules/desktop/hyprland/default.nix
  #
  # See: https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/
  # See: https://wiki.nixos.org/wiki/Hyprland

  wayland.windowManager.hyprland = {
    enable = true;

    # CRITICAL: Use the Hyprland package from NixOS module, not Home Manager
    # This prevents duplicate systemd services and symlink conflicts
    # Requires Home Manager 5dc1c2e40410f7dabef3ba8bf4fdb3145eae3ceb or later
    package = null;
    portalPackage = null;

    # CRITICAL: Disable systemd integration to prevent conflicts with UWSM
    # The NixOS module handles session management via UWSM (if enabled)
    # or via its own systemd integration
    systemd.enable = false;

    settings = {
      # Modifier key
      "$mod" = "SUPER";

      # Monitor configuration
      # Default: auto-detect
      # Device-specific overrides in home/{laptop,framework,devtower}.nix
      monitor = ",preferred,auto,1";

      # Startup applications
      exec-once = [
        "waybar"           # Status bar
        "hyprpaper"        # Wallpaper daemon
        "dunst"            # Notification daemon
        "nm-applet"        # NetworkManager applet
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      # Input configuration
      input = {
        kb_layout = "gb";  # UK keyboard layout
        follow_mouse = 1;

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification

        touchpad = {
          natural_scroll = true;
        };
      };

      # General window settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;

        # Ayu Dark colors
        "col.active_border" = "rgba(ffb454ee) rgba(59c2ffee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        resize_on_border = true;
        allow_tearing = false;

        layout = "dwindle";
      };

      # Decoration
      decoration = {
        rounding = 8;

        active_opacity = 1.0;
        inactive_opacity = 0.95;

        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";

        blur = {
          enabled = true;
          size = 3;
          passes = 1;

          vibrancy = 0.1696;
        };
      };

      # Animations
      animations = {
        enabled = true;

        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # Layout: Dwindle
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      # Layout: Master
      master = {
        new_status = "master";
      };

      # Misc settings
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      # Keybindings
      bind = [
        # Applications
        "$mod, RETURN, exec, kitty"
        "$mod, D, exec, wofi --show drun"
        "$mod, B, exec, ${pkgs.librewolf}/bin/librewolf"
        "$mod SHIFT, B, exec, ${pkgs.firefox}/bin/firefox"
        "$mod, E, exec, thunar"

        # Window management
        "$mod, Q, killactive"
        "$mod SHIFT, E, exit"
        "$mod, V, togglefloating"
        "$mod, P, pseudo" # dwindle
        "$mod, J, togglesplit" # dwindle
        "$mod, M, fullscreen"

        # Focus navigation (vim-style)
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Move windows (vim-style)
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"

        # Workspace navigation
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Special workspace (scratchpad)
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # Screenshot
        ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "$mod, Print, exec, grim - | swappy -f -"

        # Audio controls (laptop volume keys)
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

        # Brightness controls (laptop brightness keys)
        ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Window rules
      windowrulev2 = [
        # Float certain windows
        "float, class:^(pavucontrol)$"
        "float, class:^(qpwgraph)$"
        "float, class:^(nm-connection-editor)$"

        # Opacity rules
        "opacity 0.95 0.95, class:^(kitty)$"
        "opacity 0.95 0.95, class:^(thunar)$"
      ];
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
