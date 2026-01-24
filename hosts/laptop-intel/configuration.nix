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
    ../../modules/hardware/intel-laptop.nix

    # Desktop environment
    ../../modules/desktop/hyprland

    # User
    ../../modules/users/laptop.nix
  ];

  # Device identity
  networking.hostName = "laptop-intel";

  # No device-specific overrides needed - everything is in modules!
}
