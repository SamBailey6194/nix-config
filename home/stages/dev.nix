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
    ../modules/aws.nix       # ~/.aws/config from the agenix aws-config secret
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
      # Skip the long "direnv: export +AR +AS ..." variable diff on every cd;
      # loading/error messages still show.
      global.hide_env_diff = true;
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
    cloc      # Count lines of code by language
    wget
    curl

    # Terminal recording
    # Scripted terminal recordings (.tape -> GIF/MP4); wraps its own ttyd + ffmpeg.
    # 0.12.1, not nixpkgs' 0.12.0: 0.12.0 cancels its own render context, so it
    # plays a tape, exits 0 and writes no GIF, MP4 or PNG (charmbracelet/vhs#787,
    # fixed by #788). go.mod is unchanged, so the vendorHash carries over. Drop
    # the override once the pinned nixpkgs has 0.12.1.
    (vhs.overrideAttrs (old: {
      version = "0.12.1";
      src = old.src.override {
        tag = "v0.12.1";
        hash = "sha256-9O9f/3B42BhhJ5LWNyHrQtaOKwVnAZR309Dvbpx3d4g=";
      };
    }))

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
    EDITOR = "zeditor --wait";
    VISUAL = "zeditor --wait";
  };
}
