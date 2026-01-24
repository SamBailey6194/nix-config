{ config, pkgs, ... }:

{
  # Shared Home Manager configuration for ALL users/devices
  # This imports all modular configurations

  imports = [
    ./modules/git.nix       # Git multi-account configuration
    ./modules/editor.nix    # Zed editor settings
    ./modules/shell.nix     # Zsh + Oh My Zsh configuration
    ./modules/hyprland.nix  # Hyprland Wayland compositor
  ];

  # Home Manager state version
  home.stateVersion = "24.11";

  # Enable XDG user directories
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    publicShare = "$HOME/Public";
    templates = "$HOME/Templates";
    videos = "$HOME/Videos";
  };

  # Fonts
  fonts.fontconfig.enable = true;

  # Shared packages across all devices
  home.packages = with pkgs; [
    # Development tools
    vscode
    gh # GitHub CLI

    # CLI utilities
    ripgrep
    fd
    bat
    eza
    fzf
    jq
    tree
    wget
    curl

    # System tools
    htop
    btop
    fastfetch
    brightnessctl # Brightness control
    wl-clipboard  # Wayland clipboard utilities

    # Productivity
    obsidian
    discord

    # Fonts
    ubuntu_font_family         # Ubuntu Mono for Zed
    jetbrains-mono             # JetBrains Mono
    nerdfonts                  # Nerd Fonts for icons

    # File managers
    thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin

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

    # Claude Code CLI
    # Note: Claude Code plugins should be configured in ~/.config/claude/
    # after installation. Your custom plugins (syntek-dev-suite, syntek-rust-security,
    # syntek-infra) should be cloned to ~/Repos/personal/claude-plugins/ and symlinked.
  ];

  # Kitty terminal
  programs.kitty = {
    enable = true;
    theme = "Tokyo Night";
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      window_padding_width = 4;
    };
  };

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

  # Cursor theme
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Session variables (additional to shell-specific ones)
  home.sessionVariables = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
    NIXOS_OZONE_WL = "1"; # Hint Electron apps to use Wayland
    WLR_NO_HARDWARE_CURSORS = "1"; # Fix cursor rendering on some hardware
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    XDG_SESSION_TYPE = "wayland";
  };

  # Systemd user services
  # Claude Code OAuth token (will be moved to secrets in Phase 2)
  systemd.user.sessionVariables = {
    # CLAUDE_CODE_OAUTH_TOKEN = ""; # Set this via secrets or manually
  };

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;
}
