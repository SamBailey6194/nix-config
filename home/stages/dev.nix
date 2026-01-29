{ config, pkgs, ... }:

{
  # Stage 3: Development
  # Everything from desktop + Git + Editors + Dev CLI tools

  imports = [
    ./desktop.nix
    ../modules/git.nix       # Git multi-account configuration
    ../modules/editor.nix    # Zed editor settings
    ../modules/neovim.nix    # Neovim configuration
  ];

  # Development tools
  home.packages = with pkgs; [
    # Version control
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
  ];

  # Editor environment variables
  home.sessionVariables = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
  };
}
