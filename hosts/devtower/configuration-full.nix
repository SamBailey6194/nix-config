{ config, pkgs, inputs, ... }:

{
  # FULL CONFIGURATION (devtower)
  # Use this after staged installation is complete
  # All future updates should use this configuration

  imports = [
    # Hardware
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/go-xlr.nix  # Go XLR audio interface
    ../../modules/users/devtower.nix

    # Desktop + SSH
    ../../modules/desktop/hyprland
    ../../modules/core/ssh-config.nix

    # Software suites
    ../../modules/software/browsers.nix
    ../../modules/software/development.nix
    ../../modules/software/office.nix
    ../../modules/software/communication.nix
    ../../modules/software/media.nix
    ../../modules/software/creative.nix  # DaVinci Resolve Studio + Blender

    # Hardware-specific (devtower only)
    ../../modules/hardware/openrgb.nix  # RGB keyboard/peripherals

    # Security and networking (installed last - Phase 6+)
    ../../modules/network/wireguard-mullvad.nix
    ../../modules/security/malware-scanner.nix

    # Secrets (when ready for Phase 2)
    # ../../modules/core/secrets-desktop.nix
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

  # System packages (minimal - software is in modules)
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
