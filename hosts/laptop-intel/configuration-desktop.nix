{ config, pkgs, inputs, ... }:

{
  # STAGE 2: DESKTOP ENVIRONMENT
  # Adds: Hyprland + zsh + GitHub SSH config
  # After minimal install boots successfully, rebuild with this config

  imports = [
    # Previous stage
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/intel-laptop.nix
    ../../modules/users/laptop.nix

    # NEW: Desktop environment + SSH
    ../../modules/desktop/hyprland
    ../../modules/core/ssh-config.nix
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

  # System packages (minimal + desktop essentials)
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch
    efibootmgr  # Manage UEFI boot order
  ];

  # Enable zsh (required for user shell)
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
