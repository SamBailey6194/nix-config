{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking.wireguard-routes;
in
{
  options.networking.wireguard-routes = {
    enable = mkEnableOption "WireGuard custom routing tables and automation";

    device = mkOption {
      type = types.str;
      description = "Device hostname";
    };

    autoRotate = {
      enable = mkEnableOption "automatic server rotation";

      schedule = mkOption {
        type = types.str;
        default = "Sun *-*-* 03:00:00";
        description = "Systemd timer schedule";
      };
    };

    metricsLogging = {
      enable = mkEnableOption "VPN metrics logging";

      interval = mkOption {
        type = types.str;
        default = "5min";
        description = "Logging interval";
      };

      logFile = mkOption {
        type = types.str;
        default = "/var/log/vpn-logs.txt";
        description = "Log file path";
      };
    };
  };

  config = mkIf cfg.enable {
    # Create custom routing table (table 1000 = "vpn")
    networking.iproute2 = {
      enable = true;
      rttablesExtraConfig = ''
        1000 vpn
      '';
    };

    # Automatic server rotation systemd service
    systemd.services.wireguard-rotate = mkIf cfg.autoRotate.enable {
      description = "Rotate Mullvad WireGuard servers";
      path = with pkgs; [ wireguard-tools iproute2 ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "wireguard-rotate.sh" ''
          #!/usr/bin/env bash
          set -euo pipefail

          # Load Mullvad-assigned device addresses (static, tied to registered public key)
          source /etc/wireguard/device-addresses

          # Rotate multi-hop servers — exit is always UK
          /run/current-system/sw/bin/wireguard-helper rotate ${cfg.device} \
            --address "$DEVICE_ADDRESS" \
            --address6 "$DEVICE_ADDRESS6"

          # Re-activate NixOS so agenix re-decrypts the updated config secret
          /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos/nix-config#${cfg.device}

          # Restart VPN with new entry/exit servers
          systemctl restart wg-quick-mullvad0
        ''}";
      };
    };

    # Systemd timer for automatic rotation
    systemd.timers.wireguard-rotate = mkIf cfg.autoRotate.enable {
      description = "Weekly Mullvad server rotation timer";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.autoRotate.schedule;
        Persistent = true;
        Unit = "wireguard-rotate.service";
      };
    };

    # VPN metrics logging service
    systemd.services.vpn-metrics-logger = mkIf cfg.metricsLogging.enable {
      description = "VPN metrics logger";
      path = with pkgs; [ wireguard-tools iproute2 curl jq ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "vpn-metrics.sh" ''
          #!/usr/bin/env bash
          set -euo pipefail

          # Check if VPN is up
          if ! ip link show mullvad0 &>/dev/null; then
            echo "[$(date -Iseconds)] VPN down" >> ${cfg.metricsLogging.logFile}
            exit 0
          fi

          # Get interface stats
          RX_BYTES=$(cat /sys/class/net/mullvad0/statistics/rx_bytes 2>/dev/null || echo 0)
          TX_BYTES=$(cat /sys/class/net/mullvad0/statistics/tx_bytes 2>/dev/null || echo 0)
          RX_MB=$((RX_BYTES / 1024 / 1024))
          TX_MB=$((TX_BYTES / 1024 / 1024))

          # Get WireGuard stats
          WG_STATS=$(wg show mullvad0 2>/dev/null || echo "")
          HANDSHAKE=$(echo "$WG_STATS" | grep "latest handshake" | cut -d: -f2- | xargs)

          # Get exit location
          EXIT_INFO=$(curl -s https://am.i.mullvad.net/json 2>/dev/null || echo '{"country":"unknown","city":"unknown"}')
          COUNTRY=$(echo "$EXIT_INFO" | jq -r '.country // "unknown"')
          CITY=$(echo "$EXIT_INFO" | jq -r '.city // "unknown"')

          # Measure latency
          LATENCY=$(ping -c 1 -W 2 10.64.0.1 2>/dev/null | grep "time=" | sed 's/.*time=\([0-9.]*\).*/\1/' || echo "timeout")

          # Calculate uptime
          UPTIME_SEC=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
          UPTIME_MIN=$((UPTIME_SEC / 60))

          # Log metrics
          echo "[$(date -Iseconds)] rx_mb=$RX_MB tx_mb=$TX_MB latency=$LATENCY exit=$CITY,$COUNTRY uptime_min=$UPTIME_MIN handshake=$HANDSHAKE" >> ${cfg.metricsLogging.logFile}
        ''}";
      };
    };

    # Systemd timer for metrics logging
    systemd.timers.vpn-metrics-logger = mkIf cfg.metricsLogging.enable {
      description = "VPN metrics logging timer";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.metricsLogging.interval;
        Unit = "vpn-metrics-logger.service";
      };
    };

    # Ensure /var/log exists and has correct permissions
    systemd.tmpfiles.rules = mkIf cfg.metricsLogging.enable [
      "f ${cfg.metricsLogging.logFile} 0644 root root -"
    ];

    # Logrotate configuration for metrics log
    services.logrotate.settings.vpn-logs = mkIf cfg.metricsLogging.enable {
      files = cfg.metricsLogging.logFile;
      frequency = "weekly";
      rotate = 4;
      compress = true;
      missingok = true;
      notifempty = true;
    };
  };
}
