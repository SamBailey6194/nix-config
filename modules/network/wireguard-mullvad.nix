{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.networking.wireguard-mullvad;
in
{
  # Import submodules at top level (imports cannot be inside config)
  imports = [
    ./wireguard-firewall.nix
    ./wireguard-routes.nix
    ./wireguard-cgroups.nix
  ];

  options.networking.wireguard-mullvad = {
    enable = mkEnableOption "Mullvad WireGuard VPN with multi-hop";

    device = mkOption {
      type = types.str;
      description = "Device hostname (e.g., laptop-intel)";
    };

    deviceAddress = mkOption {
      type = types.str;
      description = "Mullvad-assigned IPv4 address for this device (shown in Mullvad account portal after registering the public key, e.g. 10.74.122.237/32)";
      example = "10.74.122.237/32";
    };

    deviceAddress6 = mkOption {
      type = types.str;
      description = "Mullvad-assigned IPv6 address for this device (shown in Mullvad account portal after registering the public key)";
      example = "fc00:bbbb:bbbb:bb01::b:7aec/128";
    };

    bypassIPs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Production server IPs that bypass VPN (for audit trail)";
    };

    lanNetworks = mkOption {
      type = types.listOf types.str;
      default = [
        "192.168.0.0/16"
        "10.0.0.0/8"
        "172.16.0.0/12"
      ];
      description = "LAN networks that bypass VPN";
    };

    enableKillSwitch = mkOption {
      type = types.bool;
      default = true;
      description = "Block all non-VPN traffic if tunnel drops";
    };

    cgroupApps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Applications to route through VPN via cgroups (e.g., firefox, transmission)";
    };

    currentExit = mkOption {
      type = types.enum [
        "uk"
        "us"
        "eu"
      ];
      default = "uk";
      description = "Current VPN exit location";
    };

    autoRotate = {
      enable = mkEnableOption "automatic weekly server rotation";

      schedule = mkOption {
        type = types.str;
        default = "Sun *-*-* 03:00:00";
        description = "Systemd timer schedule for rotation (default: Sunday 3 AM)";
      };
    };

    metricsLogging = {
      enable = mkEnableOption "VPN metrics logging";

      interval = mkOption {
        type = types.str;
        default = "5min";
        description = "Metrics logging interval";
      };

      logFile = mkOption {
        type = types.str;
        default = "/var/log/vpn-logs.txt";
        description = "Metrics log file path";
      };
    };
  };

  config = mkIf cfg.enable {
    # Agenix secrets
    age.secrets = {
      "wireguard-${cfg.device}-private" = {
        file = ../../secrets + "/wireguard-${cfg.device}-private.age";
        mode = "0400";
      };

      "mullvad-account-${cfg.device}" = {
        file = ../../secrets + "/mullvad-account-${cfg.device}.age";
        mode = "0400";
      };

      "mullvad-wg-config-${cfg.device}" = {
        file = ../../secrets + "/mullvad-wg-config-${cfg.device}.age";
        mode = "0400";
      };

      "mullvad-relay-cache-${cfg.device}" = {
        file = ../../secrets + "/mullvad-relay-cache-${cfg.device}.age";
        mode = "0600";
        owner = "root";
      };

      "mullvad-route-history-${cfg.device}" = {
        file = ../../secrets + "/mullvad-route-history-${cfg.device}.age";
        mode = "0600";
        owner = "root";
      };
    };

    # Ensure wg-quick waits for agenix to decrypt the VPN config before starting.
    # Without this, wg-quick races agenix at boot — the interface comes up with no
    # peers, no addresses, and no routing rules (silent failure).
    systemd.services."wg-quick-mullvad0".preStart =
      let
        configPath = config.age.secrets."mullvad-wg-config-${cfg.device}".path;
      in
      ''
        timeout=30
        while [ ! -s "${configPath}" ] && [ "$timeout" -gt 0 ]; do
          echo "Waiting for agenix to decrypt VPN config... (''${timeout}s remaining)"
          sleep 1
          timeout=$((timeout - 1))
        done
        if [ ! -s "${configPath}" ]; then
          echo "ERROR: VPN config not available after 30s. Is agenix configured correctly?"
          exit 1
        fi
      '';

    # Fix boot-time race condition: wg-quick must wait until NetworkManager has
    # established an internet connection before attempting the Mullvad handshake.
    # Without this the interface comes up but the handshake to Mullvad's servers
    # fails (no route yet), and the kill switch then locks out all traffic.
    systemd.services."wg-quick-mullvad0".after = [ "network-online.target" ];
    systemd.services."wg-quick-mullvad0".wants = [ "network-online.target" ];

    # Ensure NetworkManager-wait-online actually gates on real connectivity
    # (not just "an interface exists") before network-online.target fires.
    systemd.services.NetworkManager-wait-online.enable = lib.mkDefault true;

    # Prevent NetworkManager from managing the WireGuard interface.
    # If NM touches mullvad0 it can overwrite wg-quick's routing rules.
    networking.networkmanager.unmanaged = [ "interface-name:mullvad0" ];

    # Write device addresses to a well-known path so the auto-rotate systemd
    # service and justfile can source them without needing them as CLI args.
    # These addresses are NOT secret — they are the Mullvad-assigned IPs tied
    # to the registered WireGuard public key and never change between rotations.
    environment.etc."wireguard/device-addresses" = {
      text = ''
        DEVICE_ADDRESS=${cfg.deviceAddress}
        DEVICE_ADDRESS6=${cfg.deviceAddress6}
      '';
      mode = "0644";
    };

    # WireGuard interface configuration
    networking.wg-quick.interfaces.mullvad0 = {
      # Read generated config from agenix
      configFile = config.age.secrets."mullvad-wg-config-${cfg.device}".path;

      # wg-quick handles all routing automatically when AllowedIPs = 0.0.0.0/0
      # (creates its own fwmark, routing table, and policy rules)
      preUp = ''
        # Ensure directories exist
        mkdir -p /var/lib/wireguard
        mkdir -p /var/log
      '';

      postUp = ''
        # Allow forwarding through VPN interface
        ${pkgs.iptables}/bin/iptables -A FORWARD -o mullvad0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i mullvad0 -j ACCEPT

        # Explicit LAN bypass rules (belt-and-braces alongside wg-quick's
        # suppress_prefixlength 0 which already allows specific LAN routes)
        ${concatMapStringsSep "\n" (net: ''
          ${pkgs.iproute2}/bin/ip rule add to ${net} table main priority 50 || true
        '') cfg.lanNetworks}

        # Bypass rules for production servers
        ${concatMapStringsSep "\n" (ip: ''
          ${pkgs.iproute2}/bin/ip rule add to ${ip} table main priority 50 || true
        '') cfg.bypassIPs}
      '';

      preDown = ''
        # Remove routing rules
        ${concatMapStringsSep "\n" (net: ''
          ${pkgs.iproute2}/bin/ip rule del to ${net} table main priority 50 || true
        '') cfg.lanNetworks}

        ${concatMapStringsSep "\n" (ip: ''
          ${pkgs.iproute2}/bin/ip rule del to ${ip} table main priority 50 || true
        '') cfg.bypassIPs}
      '';

      postDown = ''
        # Clean up firewall rules
        ${pkgs.iptables}/bin/iptables -D FORWARD -o mullvad0 -j ACCEPT || true
        ${pkgs.iptables}/bin/iptables -D FORWARD -i mullvad0 -j ACCEPT || true
      '';
    };

    # Enable IP forwarding for multi-hop
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Ensure WireGuard tools are available
    environment.systemPackages = with pkgs; [
      wireguard-tools
      iproute2
      iptables
    ];

    # Pass configuration to submodules
    networking.wireguard-firewall = {
      enable = cfg.enableKillSwitch;
      vpnInterface = "mullvad0";
      lanNetworks = cfg.lanNetworks;
      bypassIPs = cfg.bypassIPs;
    };

    networking.wireguard-routes = {
      enable = true;
      device = cfg.device;
      autoRotate = cfg.autoRotate;
      metricsLogging = cfg.metricsLogging;
    };

    networking.wireguard-cgroups = {
      enable = (length cfg.cgroupApps) > 0;
      apps = cfg.cgroupApps;
    };
  };
}
