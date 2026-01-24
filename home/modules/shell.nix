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

      # NVM integration (if nvm is installed)
      # Note: On NixOS, consider using Home Manager's nodejs instead
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    '';

    # Shell aliases
    shellAliases = {
      # Claude Code with custom TMPDIR
      claude = "TMPDIR=/home/sam-dev/.claude/tmp claude";
      code = "TMPDIR=/home/sam-dev/.claude/tmp code";

      # Convenience aliases for apt (Ubuntu-specific, not needed on NixOS)
      # These are kept for backwards compatibility but won't work on NixOS
      apt-update = "apt update";
      apt-upgrade = "apt upgrade";
      apt-install = "apt install";
      apt-remove = "apt remove";
      apt-search = "apt search";
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

  # Custom apt wrapper function (Ubuntu-specific)
  # This won't be needed on NixOS, but kept for reference
  # On NixOS, you use nixos-rebuild and home-manager instead
  home.file.".zsh_functions/apt_wrapper".text = ''
    # Custom apt wrapper to handle Python version switching
    # Note: This is Ubuntu-specific and not needed on NixOS
    apt() {
        # Store the current Python alternative
        local current_python=$(readlink -f /usr/bin/python3)

        echo "🔄 Current Python: $current_python"
        echo "🔧 Switching to Python 3.12 for apt..."

        # Switch to Python 3.12 for apt commands
        sudo update-alternatives --set python3 /usr/bin/python3.12 > /dev/null 2>&1

        echo "✅ Running: sudo apt $@"
        echo ""

        # Run the apt command with all arguments
        command sudo apt "$@"

        echo ""
        echo "🔄 Switching back to $current_python..."

        # Switch back to the previous Python version
        sudo update-alternatives --set python3 "$current_python" > /dev/null 2>&1

        echo "✅ Done! Python restored."
    }
  '';

  # Source custom functions
  programs.zsh.initExtra = lib.mkAfter ''
    # Source custom functions (Ubuntu-specific, not needed on NixOS)
    if [ -f ~/.zsh_functions/apt_wrapper ]; then
      source ~/.zsh_functions/apt_wrapper
    fi
  '';

  # Starship prompt (alternative to Oh My Zsh themes)
  # Disabled by default since you're using custom PROMPT
  # Uncomment to use Starship instead of robbyrussell
  # programs.starship = {
  #   enable = true;
  #   enableZshIntegration = true;
  # };
}
