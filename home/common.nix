{ config, pkgs, ... }:

{
  # Shared Home Manager configuration for ALL users/devices
  # Device-specific additions go in home/{laptop,framework,devtower}.nix

  # Home Manager state version
  home.stateVersion = "24.11";

  # Fonts
  fonts.fontconfig.enable = true;

  # Shared packages across all devices
  home.packages = with pkgs; [
    # Development tools
    vscode
    git
    gh # GitHub CLI

    # CLI utilities
    ripgrep
    fd
    bat
    eza
    fzf
    starship

    # Productivity
    obsidian
    discord

    # Fonts
    ubuntu_font_family  # Ubuntu Mono for Zed

    # Claude Code CLI
    # Note: Claude Code plugins should be configured in ~/.config/claude/
    # after installation. Nix manages the CLI, but plugins are user-specific.
    # Your custom plugins (syntek-dev-suite, syntek-rust-security, syntek-infra)
    # should be symlinked or configured post-installation.
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Sam Bailey";
    userEmail = "sambailey6194@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # Zed editor
  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "rust"
      "python"
      "toml"
      "markdown"
    ];
    userSettings = {
      buffer_font_family = "Ubuntu Mono";
      buffer_font_size = 14;
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
      # Your existing Zed config from config/zed/settings.json
      # will be integrated in Phase 4
    };
  };

  # Zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Kitty terminal
  programs.kitty = {
    enable = true;
    theme = "Tokyo Night";
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
  };

  # Hyprland - base configuration
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";
      monitor = ",preferred,auto,1";

      bind = [
        # Apps
        "$mod, RETURN, exec, kitty"
        "$mod, D, exec, wofi --show drun"
        "$mod, Q, killactive"
        "$mod SHIFT, E, exit"

        # Focus
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Move windows
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"

        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"

        # Screenshot
        ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"

        # Toggle floating
        "$mod, F, togglefloating"
        "$mod, M, fullscreen"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      exec-once = [
        "waybar"
        "hyprpaper"
        "dunst"
      ];
    };
  };
}
