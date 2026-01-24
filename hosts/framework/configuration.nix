{ config, pkgs, inputs, ... }:

{
  imports = [
    # Hardware
    ./hardware-configuration.nix

    # Shared base configuration
    ../../modules/core/base-configuration.nix
    ../../modules/core/common.nix
    ../../modules/core/nix-settings.nix

    # Hardware-specific
    ../../modules/hardware/amd-laptop.nix

    # Software
    ../../modules/software/creative.nix  # DaVinci Resolve Studio

    # Desktop environment
    ../../modules/desktop/hyprland

    # User
    ../../modules/users/framework.nix
  ];

  # Device identity
  networking.hostName = "framework";

  # No device-specific overrides needed - everything is in modules!
}
