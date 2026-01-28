{ config, pkgs, inputs, ... }:

{
  # MINIMAL INSTALLATION CONFIGURATION
  # Use this for initial nixos-install to avoid tmpfs space issues
  # After successful boot, switch to configuration.nix and rebuild

  imports = [
    # Hardware (required)
    ./hardware-configuration.nix

    # Essential only
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/intel-laptop.nix
    ../../modules/users/laptop.nix

    # Storage management (runtime-configurable - available from start)
    ../../modules/storage/restic.nix
    ../../modules/storage/zfs.nix
    ../../modules/storage/raid.nix
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

  # Minimal system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    efibootmgr  # Manage UEFI boot order
  ];

  # Enable zsh (required for user shell)
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
