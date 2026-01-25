{ config, pkgs, ... }:

{
  # System-wide common configuration for all hosts

  # Enable Flakes and Nix Command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto-optimize store
  nix.settings.auto-optimise-store = true;

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

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

    # Archive tools
    unzip
    zip
    p7zip

    # Build tools
    gcc
    gnumake
    pkg-config
  ];

  # Shell configuration
  programs.zsh.enable = true;
  programs.bash.enableCompletion = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Console keymap and font
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
}
