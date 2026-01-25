{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking.wireguard-firewall;
in
{
  options.networking.wireguard-firewall = {
    enable = mkEnableOption "WireGuard VPN kill switch";

    vpnInterface = mkOption {
      type = types.str;
      default = "mullvad0";
      description = "VPN interface name";
    };

    lanNetworks = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" ];
      description = "LAN networks allowed even when VPN is down";
    };

    bypassIPs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Production server IPs allowed even when VPN is down";
    };
  };

  config = mkIf cfg.enable {
    # Firewall configuration for kill switch
    networking.firewall = {
      enable = true;

      # Allow WireGuard handshake (UDP 51820)
      allowedUDPPorts = [ 51820 ];

      # Custom iptables rules for kill switch
      extraCommands = ''
        # Flush any existing rules
        ${pkgs.iptables}/bin/iptables -F FORWARD || true

        # Allow loopback (localhost)
        ${pkgs.iptables}/bin/iptables -A OUTPUT -o lo -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A INPUT -i lo -j ACCEPT

        # Allow LAN networks (bypass VPN)
        ${concatMapStringsSep "\n" (net: ''
          ${pkgs.iptables}/bin/iptables -A OUTPUT -d ${net} -j ACCEPT
          ${pkgs.iptables}/bin/iptables -A INPUT -s ${net} -j ACCEPT
        '') cfg.lanNetworks}

        # Allow production server IPs (bypass VPN for audit trail)
        ${concatMapStringsSep "\n" (ip: ''
          ${pkgs.iptables}/bin/iptables -A OUTPUT -d ${ip} -j ACCEPT
          ${pkgs.iptables}/bin/iptables -A INPUT -s ${ip} -j ACCEPT
        '') cfg.bypassIPs}

        # Allow WireGuard handshake (UDP 51820)
        ${pkgs.iptables}/bin/iptables -A OUTPUT -p udp --dport 51820 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A INPUT -p udp --sport 51820 -j ACCEPT

        # Allow traffic through VPN interface
        ${pkgs.iptables}/bin/iptables -A OUTPUT -o ${cfg.vpnInterface} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A INPUT -i ${cfg.vpnInterface} -j ACCEPT

        # Allow DNS (for VPN connection)
        ${pkgs.iptables}/bin/iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

        # KILL SWITCH: Block all other outbound traffic (prevents leaks)
        ${pkgs.iptables}/bin/iptables -A OUTPUT -j REJECT
      '';

      extraStopCommands = ''
        # Clean up rules when stopping firewall
        ${pkgs.iptables}/bin/iptables -F OUTPUT || true
        ${pkgs.iptables}/bin/iptables -F INPUT || true
        ${pkgs.iptables}/bin/iptables -F FORWARD || true
      '';
    };

    # Ensure firewall starts before network
    systemd.services.firewall.before = [ "network-pre.target" ];
    systemd.services.firewall.wantedBy = [ "multi-user.target" ];
  };
}
