{ config, pkgs, inputs, ... }:

{
  # STAGE 3: DEVELOPMENT TOOLS
  # Adds: Browsers + Zed + Neovim + dev tools
  # Rebuild with this after desktop environment is working

  imports = [
    # Previous stages
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/intel-laptop.nix
    ../../modules/users/laptop.nix

    # Desktop environment + SSH
    ../../modules/desktop/hyprland
    ../../modules/core/ssh-config.nix

    # NEW: Development tools
    ../../modules/software/browsers.nix
    ../../modules/software/development.nix
  ];

  # Device identity
  networking.hostName = "laptop-intel";

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # System packages (core + desktop)
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch
  ];

  # Enable zsh
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
