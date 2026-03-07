{ config, pkgs, lib, ... }:

{
  # Zsh shell configuration with Oh My Zsh
  # Integrated from existing .zshrc

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
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
    initContent = ''
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

      # fnm (Fast Node Manager) for per-project Node.js versions
      # Auto-switches when cd-ing into a directory with .node-version or .nvmrc
      if command -v fnm &> /dev/null; then
        eval "$(fnm env --use-on-cd)"
      fi
    '';

    # Shell aliases
    shellAliases = {
      # Claude Code with custom TMPDIR
      claude = "TMPDIR=${config.home.homeDirectory}/.claude/tmp claude";
      code = "TMPDIR=${config.home.homeDirectory}/.claude/tmp code";

      # Zed editor (nixpkgs installs as 'zeditor' to avoid name conflict)
      zed = "zeditor";
    };

    # Session variables
    sessionVariables = {
      # Browser
      BROWSER = "${pkgs.google-chrome}/bin/google-chrome-stable";

      # UV package manager - use copy mode for cross-filesystem installs
      UV_LINK_MODE = "copy";

      # Justfile - accessible from any directory
      JUST_JUSTFILE = "$HOME/Repos/personal/nix-config/justfile";
      JUST_WORKING_DIRECTORY = "$HOME/Repos/personal/nix-config";

      # Android SDK (if you use React Native or Android development)
      ANDROID_HOME = "$HOME/Android/Sdk";



      # Claude Code OAuth Token
      # Note: In Phase 2, this should be moved to secrets management
      # For now, set it manually or via environment.d
      # CLAUDE_CODE_OAUTH_TOKEN will be set via systemd user environment
    };
  };

  # Additional PATH entries for Android SDK (top-level Home Manager option)
  # Note: Only needed if you do Android/React Native development
  home.sessionPath = [
    "$HOME/.cargo/bin"                # Rustup-managed tools (rust-analyzer, cargo, etc.)
    "$HOME/Android/Sdk/emulator"
    "$HOME/Android/Sdk/platform-tools"
  ];


  # Starship prompt (alternative to Oh My Zsh themes)
  # Disabled by default since you're using custom PROMPT
  # Uncomment to use Starship instead of robbyrussell
  # programs.starship = {
  #   enable = true;
  #   enableZshIntegration = true;
  # };
}
