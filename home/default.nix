{ config, pkgs, ... }:

{
  # Home Manager configuration for user: sam-dev
  # This is Phase 1 - basic setup
  # Full dotfiles integration happens in Phase 4

  # Home Manager state version
  home.stateVersion = "24.11";

  # Basic user packages
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
  ];

  # Git configuration (basic - will be enhanced in Phase 4)
  programs.git = {
    enable = true;
    userName = "Sam Bailey";
    userEmail = "sambailey6194@gmail.com"; # Personal account
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # Zsh (basic - will be enhanced in Phase 4)
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

  # Kitty terminal (basic - will use config file in Phase 4)
  programs.kitty = {
    enable = true;
    theme = "Tokyo Night";
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
  };

  # Hyprland configuration (basic keybinds)
  # Full config will be in config/hypr/ in Phase 4
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # Modifier key
      "$mod" = "SUPER";

      # Monitor setup (auto-detect)
      monitor = ",preferred,auto,1";

      # Basic keybinds
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

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Startup apps
      exec-once = [
        "waybar"
        "hyprpaper"
        "dunst"
      ];
    };
  };
}
