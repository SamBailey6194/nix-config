{ config, pkgs, inputs, ... }:

{
  # STAGE 5: CREATIVE SOFTWARE (framework)
  # Adds: DaVinci Resolve Studio + Blender
  # AMD Radeon GPU supports DaVinci Resolve Studio via Rusticl
  # Affinity Apps via affinity-nix (Wine-based)

  imports = [
    # Previous stages
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/amd-laptop.nix
    ../../modules/users/framework.nix

    # Desktop + SSH
    ../../modules/desktop/hyprland
    ../../modules/core/ssh-config.nix

    # Development
    ../../modules/software/browsers.nix
    ../../modules/software/development.nix

    # Productivity
    ../../modules/software/office.nix
    ../../modules/software/communication.nix
    ../../modules/software/media.nix

    # NEW: Creative suite (AMD GPU required)
    ../../modules/software/creative.nix
  ];

  # Device identity
  networking.hostName = "framework";

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch
    # Affinity Apps (via overlay — see nix-settings.nix)
    affinity-designer
    affinity-photo
    affinity-publisher
  ];

  # Enable zsh
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
