{ config, pkgs, ... }:

{
  # Stage 2: Desktop
  # Hyprland + Zsh + SSH + Terminal + Basic UI tools
  # No dev tools, editors, or productivity apps yet

  imports = [
    ./base.nix
    ../modules/hyprland.nix  # Hyprland Wayland compositor
    ../modules/shell.nix     # Zsh + Oh My Zsh
    ../modules/browsers.nix  # LibreWolf profile + Zen default browser
  ];

  # Desktop-only packages
  home.packages = with pkgs; [
    # Terminal (kitty is configured in home/common.nix)
    # kitty is already available via programs.kitty.enable

    # System tools
    htop
    btop
    fastfetch
    brightnessctl # Brightness control
    wl-clipboard  # Wayland clipboard utilities

    # Fonts
    jetbrains-mono             # JetBrains Mono

    # File managers
    thunar
    thunar-volman
    thunar-archive-plugin

    # Image viewers
    imv

    # PDF viewers
    zathura

    # Archive tools
    unzip
    zip
    p7zip

    # Network tools
    networkmanagerapplet

    # Bluetooth
    blueman
  ];

  # Kitty terminal is configured in home/common.nix (programs.kitty)
  # Launched via Super+Return (see config/hypr/keybinds.conf)

  # Dunst notification daemon
  services.dunst = {
    enable = true;
    settings = {
      global = {
        font = "JetBrainsMono Nerd Font 10";
        markup = "yes";
        format = "<b>%s</b>\\n%b";
        sort = "yes";
        indicate_hidden = "yes";
        alignment = "left";
        bounce_freq = 0;
        show_age_threshold = 60;
        word_wrap = "yes";
        ignore_newline = "no";
        geometry = "300x5-30+50";
        transparency = 10;
        idle_threshold = 120;
        monitor = 0;
        follow = "mouse";
        sticky_history = "yes";
        line_height = 0;
        separator_height = 2;
        padding = 8;
        horizontal_padding = 8;
        separator_color = "frame";
        startup_notification = false;
        dmenu = "${pkgs.wofi}/bin/wofi -p dunst";
        browser = "${pkgs.librewolf}/bin/librewolf";
        icon_position = "left";
        max_icon_size = 64;
        frame_width = 2;
        frame_color = "#ffb454";
      };

      urgency_low = {
        background = "#0f1419";
        foreground = "#ffffff";
        timeout = 10;
      };

      urgency_normal = {
        background = "#0f1419";
        foreground = "#ffffff";
        timeout = 10;
      };

      urgency_critical = {
        background = "#ff3333";
        foreground = "#ffffff";
        frame_color = "#ff0000";
        timeout = 0;
      };
    };
  };

  # GTK theme
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk4.theme = null; # New default in HM 26.05 — GTK4 apps use libadwaita
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Qt theme
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  # dconf settings to enforce dark mode system-wide
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
  };

  # Cursor theme
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Session variables for Wayland
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Hint Electron apps to use Wayland
    WLR_NO_HARDWARE_CURSORS = "1"; # Fix cursor rendering on some hardware
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    XDG_SESSION_TYPE = "wayland";
  };

  # Set Zen as default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
    };
  };
}
