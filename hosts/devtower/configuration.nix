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
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/go-xlr.nix  # Go XLR audio interface

    # Software
    ../../modules/software/creative.nix  # DaVinci Resolve Studio

    # Desktop environment
    ../../modules/desktop/hyprland

    # User
    ../../modules/users/devtower.nix
  ];

  # Device identity
  networking.hostName = "devtower";

  # No device-specific overrides needed - everything is in modules!
}
