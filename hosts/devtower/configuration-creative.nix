{ config, pkgs, inputs, ... }:

{
  # STAGE 5: CREATIVE SOFTWARE (devtower)
  # Adds: DaVinci Resolve Studio + Blender + Go XLR audio
  # AMD Radeon GPU supports DaVinci Resolve Studio via Rusticl
  # Affinity Apps via affinity-nix (Wine-based)

  imports = [
    # Previous stages
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/go-xlr.nix  # Go XLR audio interface
    ../../modules/users/devtower.nix

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
  networking.hostName = "devtower";

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
  ] ++ [
    # Affinity Apps (via Wine - from affinity-nix flake)
    inputs.affinity-nix.packages.${pkgs.system}.designer
    inputs.affinity-nix.packages.${pkgs.system}.photo
    inputs.affinity-nix.packages.${pkgs.system}.publisher
  ];

  # Enable zsh
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
