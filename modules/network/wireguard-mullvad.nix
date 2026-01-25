{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking.wireguard-mullvad;
in
{
  options.networking.wireguard-mullvad = {
    enable = mkEnableOption "Mullvad WireGuard VPN with multi-hop";

    device = mkOption {
      type = types.str;
      description = "Device hostname (e.g., laptop-intel)";
    };

    bypassIPs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Production server IPs that bypass VPN (for audit trail)";
    };

    lanNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" ];
      description = "LAN networks that bypass VPN";
    };

    enableKillSwitch = mkOption {
      type = types.bool;
      default = true;
      description = "Block all non-VPN traffic if tunnel drops";
    };

    cgroupApps = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Applications to route through VPN via cgroups (e.g., firefox, transmission)";
    };

    currentExit = mkOption {
      type = types.enum [ "uk" "us" "eu" ];
      default = "uk";
      description = "Current VPN exit location";
    };

    minHops = mkOption {
      type = types.int;
      default = 5;
      description = "Minimum number of hops for multi-hop routing";
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
    # Import firewall, routing, and cgroup modules
    imports = [
      ./wireguard-firewall.nix
      ./wireguard-routes.nix
      ./wireguard-cgroups.nix
    ];

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

    # WireGuard interface configuration
    networking.wg-quick.interfaces.mullvad0 = {
      # Read generated config from agenix
      configFile = config.age.secrets."mullvad-wg-config-${cfg.device}".path;

      # Mark packets for routing (fwmark for split tunneling)
      preUp = ''
        # Ensure directories exist
        mkdir -p /var/lib/wireguard
        mkdir -p /var/log

        # Set firewall mark for VPN traffic
        ${pkgs.iproute2}/bin/ip rule add fwmark 0x1 table 1000 priority 100 || true
      '';

      postUp = ''
        # Apply firewall rules (kill switch)
        ${pkgs.iptables}/bin/iptables -A FORWARD -o mullvad0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A FORWARD -i mullvad0 -j ACCEPT

        # Add bypass rules for LAN networks (priority 50 = higher than VPN)
        ${concatMapStringsSep "\n" (net: ''
          ${pkgs.iproute2}/bin/ip rule add to ${net} table main priority 50 || true
        '') cfg.lanNetworks}

        # Add bypass rules for production servers
        ${concatMapStringsSep "\n" (ip: ''
          ${pkgs.iproute2}/bin/ip rule add to ${ip} table main priority 50 || true
        '') cfg.bypassIPs}

        # Default route through VPN (priority 100)
        ${pkgs.iproute2}/bin/ip route add default dev mullvad0 table 1000 || true
      '';

      preDown = ''
        # Remove routing rules
        ${concatMapStringsSep "\n" (net: ''
          ${pkgs.iproute2}/bin/ip rule del to ${net} table main priority 50 || true
        '') cfg.lanNetworks}

        ${concatMapStringsSep "\n" (ip: ''
          ${pkgs.iproute2}/bin/ip rule del to ${ip} table main priority 50 || true
        '') cfg.bypassIPs}

        ${pkgs.iproute2}/bin/ip rule del fwmark 0x1 table 1000 priority 100 || true
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
