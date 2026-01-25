{ config, pkgs, lib, ... }:

{
  # Zsh shell configuration with Oh My Zsh
  # Integrated from existing .zshrc

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    # Oh My Zsh integration
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "docker"
        "docker-compose"
      ];
    };

    # Custom prompt (overrides robbyrussell theme)
    # Green arrow, cyan directory
    initExtra = ''
      PROMPT='%F{green}%B→%b %F{cyan}%B%~%b%f '

      # Cyan input text color
      autoload -U colors && colors
      precmd () { print -Pn "\e[93m" }

      # Keep cyan input color active during editing
      zle-keymap-select() { print -Pn "\e[93m" }
      zle-line-init() { print -Pn "\e[93m" }
      zle -N zle-keymap-select
      zle -N zle-line-init

      # DDEV completions (if ddev is installed)
      if command -v ddev &> /dev/null; then
        eval "$(ddev completion zsh)"
      fi
    '';

    # Shell aliases
    shellAliases = {
      # Claude Code with custom TMPDIR
      claude = "TMPDIR=/home/sam-dev/.claude/tmp claude";
      code = "TMPDIR=/home/sam-dev/.claude/tmp code";
    };

    # Session variables
    sessionVariables = {
      # Browser
      BROWSER = "${pkgs.google-chrome}/bin/google-chrome-stable";

      # UV package manager - use copy mode for cross-filesystem installs
      UV_LINK_MODE = "copy";

      # Android SDK (if you use React Native or Android development)
      ANDROID_HOME = "$HOME/Android/Sdk";

      # Claude Code OAuth Token
      # Note: In Phase 2, this should be moved to secrets management
      # For now, set it manually or via environment.d
      # CLAUDE_CODE_OAUTH_TOKEN will be set via systemd user environment
    };

    # Additional PATH entries
    # Note: On NixOS, prefer adding packages to home.packages instead
    sessionVariables.PATH = lib.mkAfter [
      "$ANDROID_HOME/emulator"
      "$ANDROID_HOME/platform-tools"
    ];
  };


  # Starship prompt (alternative to Oh My Zsh themes)
  # Disabled by default since you're using custom PROMPT
  # Uncomment to use Starship instead of robbyrussell
  # programs.starship = {
  #   enable = true;
  #   enableZshIntegration = true;
  # };
}
