{ config, pkgs, ... }:

let
  # opengrep is not in nixpkgs (upstream ships only a dev-shell flake), so it is
  # built from the prebuilt release binary. callPackage keeps it dependent on
  # `pkgs` only, so it resolves in every stage/host that imports this file.
  opengrep = pkgs.callPackage ../../pkgs/opengrep.nix { };
in
{
  # Stage 3: Development
  # Everything from desktop + Git + Editors + Dev CLI tools

  imports = [
    ./desktop.nix
    ../modules/git.nix       # Git multi-account configuration
    ../modules/editor.nix    # Zed editor settings
    ../modules/neovim.nix    # Neovim configuration
    ../modules/claude.nix    # Claude Code: settings, MCP servers, monitor, Brave link
  ];

  # Direnv - auto-load dev environments from .envrc files
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;  # Cached nix develop (much faster reloads)
    config = {
      whitelist = {
        prefix = [ "~/Repos" ];
      };
    };
  };

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

    # Security / cloud / infra CLIs
    cosign      # Sigstore container/artifact signing & verification
    awscli2     # AWS CLI v2
    stripe-cli  # Stripe CLI (webhooks, API testing)
    terraform   # IaC (unfree/BSL 1.1 — allowUnfree enabled via nix-settings.nix)
    opentofu    # IaC — FOSS (MPL 2.0) fork of terraform, `tofu` binary
    opengrep    # SAST scanner (from ../../pkgs/opengrep.nix; not in nixpkgs)
  ];

  # Editor environment variables
  home.sessionVariables = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
  };
}
