{ config, pkgs, inputs, ... }:

{
  imports = [ ./nix-gc.nix ];

  # System-wide common configuration for all hosts

  # Enable Flakes and Nix Command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto-optimize store
  nix.settings.auto-optimise-store = true;

  # Common system packages
  environment.systemPackages = with pkgs; [
    # Core utilities
    coreutils
    curl
    wget
    git
    vim
    neovim
    rclone
    fuse

    # System monitoring
    htop
    btop
    tree

    # Network tools
    dig
    nmap
    traceroute
    wireguard-tools

    # DDEV/mkcert (locally-trusted SSL certs)
    mkcert
    nss.tools # needed for Firefox cert trust

    # Archive tools
    unzip
    zip
    p7zip

    # SSL/TLS
    openssl

    # Build tools
    gcc
    gnumake
    pkg-config
    just

    # Profiling & debugging
    valgrind

    # Secrets management
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ]
  # Rust CLI tools (secrets-verify, agenix-helper, wireguard-helper, etc.)
  ++ (builtins.attrValues inputs.self.packages.${pkgs.stdenv.hostPlatform.system});

  # Shell configuration
  programs.zsh.enable = true;
  programs.bash.completion.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Console keymap and font
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
}
