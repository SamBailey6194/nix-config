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
    ../../modules/core/secrets-laptop.nix

    # SSH configuration (per-device keys)
    # ../../modules/core/ssh-config.nix

    # Hardware-specific
    ../../modules/hardware/intel-laptop.nix
    ../../modules/hardware/openrgb.nix  # RGB control for keyboard/mouse

    # Desktop environment
    ../../modules/desktop/hyprland

    # Network - VPN
    ../../modules/network/wireguard-mullvad.nix

    # User
    ../../modules/users/laptop.nix
  ];

  # Enable SSH to generate host keys for agenix
  services.openssh.enable = true;

  # Device identity
  networking.hostName = "laptop-intel";

  # # Mullvad WireGuard VPN Configuration (Phase 6)
  networking.wireguard-mullvad = {
    enable = true;
    device = "laptop-intel";

    # Production servers that bypass VPN (for audit trail)
    bypassIPs = [
      # Add production server IPs here
      # "203.0.113.5"
    ];

    # Kill switch enabled
    enableKillSwitch = true;

    # Per-app VPN routing via cgroups
    cgroupApps = [
      "firefox"       # Browser through VPN
      "librewolf"     # Browser through VPN
      "chrome"        # Browser through VPN
      "transmission"  # Torrents through VPN
    ];

    # Current exit location (uk/us/eu)
    currentExit = "uk";

    # Minimum hop count for multi-hop
    minHops = 5;

    # Enable automatic weekly rotation
    autoRotate = {
      enable = true;
      schedule = "Sun *-*-* 03:00:00";  # Sunday 3 AM
    };

    # Enable metrics logging
    metricsLogging = {
      enable = true;
      interval = "5min";
      logFile = "/var/log/vpn-logs.txt";
    };
  };
}
