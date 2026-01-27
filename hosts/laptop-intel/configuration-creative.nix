{ config, pkgs, inputs, ... }:

{
  # STAGE 5: CREATIVE SOFTWARE (laptop-intel)
  # Adds: Blender only (Intel UHD Graphics - NO DaVinci Resolve)
  # DaVinci Resolve Studio requires AMD/NVIDIA GPU
  # Note: Affinity Apps are not available on Linux

  imports = [
    # Previous stages
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/intel-laptop.nix
    ../../modules/users/laptop.nix

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

  # System packages + creative tools
  environment.systemPackages = with pkgs; [
    # Core
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch

    # Creative (limited - Intel GPU)
    # blender              # 3D creation suite
    gimp                 # Image editing
    inkscape             # Vector graphics
    krita                # Digital painting
    # kdenlive           # Video editing (lighter than DaVinci)
  ];

  # Enable zsh
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
