{ config, pkgs, inputs, ... }:

{
  imports = [
    # Hardware
    ./hardware-configuration.nix

    # Shared base configuration
    ../../modules/core/base-configuration.nix
    ../../modules/core/common.nix
    ../../modules/core/nix-settings.nix

    # Secrets management
    ../../modules/core/secrets-desktop.nix

    # Declarative Wi-Fi profiles; PSKs come from the wifi-passwords agenix
    # secret, never the Nix store.
    ../../modules/network/wifi-profiles.nix

    # SSH configuration (per-device keys)
    ../../modules/core/ssh-config.nix

    # Hardware-specific
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/go-xlr.nix   # Go XLR audio interface
    ../../modules/hardware/openrgb.nix  # RGB control for keyboard/mouse/components

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
