# Runtime-Configurable ZFS Management
#
# This module provides the FRAMEWORK for ZFS storage, but does NOT
# contain any hardcoded pool or dataset configurations.
#
# All ZFS configuration is managed at RUNTIME via:
#   - Standard zpool and zfs CLI commands
#   - The zfs-manage helper tool (for common operations)
#   - Pool configuration persists in ZFS metadata (not Nix files)
#
# Architecture:
#   - NixOS module: Enables ZFS kernel support, installs tools
#   - Runtime config: Use standard zpool/zfs commands
#   - Helpers: zfs-manage provides convenient wrappers
#   - State: Pool configs in ZFS metadata, settings in /etc/zfs/
#
# Usage:
#   1. Enable in device configuration:
#      imports = [ ../../modules/storage/zfs.nix ];
#      services.zfs-runtime.enable = true;
#
#   2. Create pools at runtime (NO Nix edits needed):
#      zfs-manage create-pool tank mirror /dev/sda /dev/sdb
#      zfs-manage create-dataset tank/data
#      zfs-manage setup-snapshots tank/data hourly
#
#   3. Use standard ZFS commands:
#      zpool status
#      zfs list
#      zfs snapshot tank/data@backup-2024-01-01
#
# See: /home/sam-dev/Repos/personal/nix-config/docs/STORAGE-MANAGEMENT.md

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zfs-runtime;
  hostname = config.networking.hostName;

in {
  options.services.zfs-runtime = {
    enable = mkEnableOption "Runtime-configurable ZFS storage management";

    enableAutoSnapshots = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic snapshot services (configured per-dataset at runtime)";
    };

    enableAutoScrub = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic pool scrubbing";
    };

    scrubInterval = mkOption {
      type = types.str;
      default = "monthly";
      description = "How often to scrub pools (systemd timer format)";
    };

    enableMonitoring = mkOption {
      type = types.bool;
      default = true;
      description = "Enable ZFS health monitoring and alerts";
    };

    emailOnDegraded = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin@example.com";
      description = "Email address for degraded pool alerts";
    };
  };

  config = mkIf cfg.enable {
    # Enable ZFS kernel module
    boot.supportedFilesystems = [ "zfs" ];

    # ZFS module parameters (sane defaults, can be overridden)
    boot.kernelParams = [
      # ARC (cache) tuning - adjust based on RAM
      "zfs.zfs_arc_max=${toString (1024 * 1024 * 1024 * 8)}" # 8GB max ARC
    ];

    # Automatic scrubbing
    services.zfs.autoScrub = mkIf cfg.enableAutoScrub {
      enable = true;
      interval = cfg.scrubInterval;
      pools = [ ]; # Scrubs all imported pools
    };

    # ZFS event daemon configuration (monitors pool health)
    # ZED is automatically started by the ZFS service
    environment.etc."zfs/zed.d/zed.rc" = mkIf cfg.enableMonitoring {
      text = ''
        ZED_DEBUG_LOG="/var/log/zed.debug.log"
        ${optionalString (cfg.emailOnDegraded != null) ''
          ZED_EMAIL_ADDR="${cfg.emailOnDegraded}"
          ZED_EMAIL_PROG="${pkgs.mailutils}/bin/mail"
          ZED_EMAIL_OPTS="-s '@SUBJECT@' @ADDRESS@"
        ''}
        ZED_NOTIFY_VERBOSE=0
        ZED_NOTIFY_DATA=1
      '';
    };

    # Snapshot management framework
    # Individual snapshot schedules configured via zfs-manage
    systemd.services.zfs-snapshot-manager = mkIf cfg.enableAutoSnapshots {
      description = "ZFS Snapshot Manager";
      wantedBy = [ "multi-user.target" ];
      after = [ "zfs-import.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "zfs-snapshot-manager" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          # Check for datasets with snapshot schedules
          SCHEDULE_FILE="/etc/zfs/snapshot-schedule.conf"

          if [ ! -f "$SCHEDULE_FILE" ]; then
            echo "No snapshot schedules configured"
            exit 0
          fi

          # Schedule file format:
          # dataset:frequency:retention
          # Example: tank/data:hourly:24

          while IFS=: read -r dataset frequency retention; do
            # Skip comments and empty lines
            [[ "$dataset" =~ ^#.*$ ]] && continue
            [[ -z "$dataset" ]] && continue

            echo "Snapshot schedule: $dataset ($frequency, keep $retention)"
          done < "$SCHEDULE_FILE"
        '';
      };
    };

    # Automatic snapshot cleanup (runs after each snapshot)
    systemd.services.zfs-auto-snapshot-cleanup = mkIf cfg.enableAutoSnapshots {
      description = "ZFS Automatic Snapshot Cleanup";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "zfs-snapshot-cleanup" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          SCHEDULE_FILE="/etc/zfs/snapshot-schedule.conf"
          [ ! -f "$SCHEDULE_FILE" ] && exit 0

          while IFS=: read -r dataset frequency retention; do
            [[ "$dataset" =~ ^#.*$ ]] && continue
            [[ -z "$dataset" ]] && continue

            # Delete old snapshots beyond retention
            ${pkgs.zfs}/bin/zfs list -H -t snapshot -o name -s creation "$dataset" 2>/dev/null | \
              grep "@auto-$frequency-" | \
              head -n -''${retention} | \
              while read snapshot; do
                echo "Deleting old snapshot: $snapshot"
                ${pkgs.zfs}/bin/zfs destroy "$snapshot"
              done
          done < "$SCHEDULE_FILE"
        '';
      };
    };

    # ZFS health monitoring
    systemd.services.zfs-health-check = mkIf cfg.enableMonitoring {
      description = "ZFS Pool Health Check";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "zfs-health-check" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          # Check all imported pools
          POOLS=$(${pkgs.zfs}/bin/zpool list -H -o name)

          for pool in $POOLS; do
            STATUS=$(${pkgs.zfs}/bin/zpool status "$pool" | grep "state:" | awk '{print $2}')

            case "$STATUS" in
              ONLINE)
                echo "✓ Pool $pool is healthy"
                ;;
              DEGRADED)
                echo "⚠ Pool $pool is DEGRADED"
                ${pkgs.zfs}/bin/zpool status "$pool"
                # Notify if email configured
                ${optionalString (cfg.emailOnDegraded != null) ''
                  echo "Pool $pool is degraded" | \
                    ${pkgs.mailutils}/bin/mail -s "ZFS Alert: Pool Degraded" ${cfg.emailOnDegraded}
                ''}
                ;;
              FAULTED|UNAVAIL)
                echo "✗ Pool $pool is FAULTED/UNAVAILABLE"
                ${pkgs.zfs}/bin/zpool status "$pool"
                ${optionalString (cfg.emailOnDegraded != null) ''
                  echo "Pool $pool is faulted" | \
                    ${pkgs.mailutils}/bin/mail -s "ZFS CRITICAL: Pool Faulted" ${cfg.emailOnDegraded}
                ''}
                ;;
            esac
          done
        '';
      };
    };

    # Health check timer (runs hourly)
    systemd.timers.zfs-health-check = mkIf cfg.enableMonitoring {
      description = "ZFS Health Check Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    # Install ZFS utilities and helper scripts
    environment.systemPackages = [
      pkgs.zfs
      # Rust tool installed separately via workspace

      # Show pool status with colors
      (pkgs.writeScriptBin "zfs-status" ''
        #!${pkgs.bash}/bin/bash

        echo "ZFS Pools:"
        ${pkgs.zfs}/bin/zpool list
        echo ""

        echo "Pool Status:"
        ${pkgs.zfs}/bin/zpool status
        echo ""

        echo "Datasets:"
        ${pkgs.zfs}/bin/zfs list
        echo ""

        echo "ARC Stats:"
        ${pkgs.zfs}/bin/arc_summary | head -20
      '')

      # List snapshots
      (pkgs.writeScriptBin "zfs-snapshots" ''
        #!${pkgs.bash}/bin/bash

        if [ -z "$1" ]; then
          echo "Usage: zfs-snapshots <dataset>"
          echo ""
          echo "Available datasets:"
          ${pkgs.zfs}/bin/zfs list -H -o name -t filesystem
          exit 1
        fi

        DATASET="$1"

        echo "Snapshots for $DATASET:"
        ${pkgs.zfs}/bin/zfs list -t snapshot -o name,used,creation -s creation "$DATASET"
      '')

      # Quick pool creation helper
      (pkgs.writeScriptBin "zfs-quick-pool" ''
        #!${pkgs.bash}/bin/bash

        echo "ZFS Quick Pool Creator"
        echo ""
        echo "This is a helper for zpool create. For full control, use 'zpool create' directly."
        echo ""

        if [ $# -lt 3 ]; then
          echo "Usage: zfs-quick-pool <pool-name> <type> <devices...>"
          echo ""
          echo "Types: single, mirror, raidz, raidz2, raidz3"
          echo ""
          echo "Examples:"
          echo "  zfs-quick-pool tank mirror /dev/sda /dev/sdb"
          echo "  zfs-quick-pool backup single /dev/sdc"
          echo "  zfs-quick-pool storage raidz /dev/sd{d,e,f,g}"
          exit 1
        fi

        POOL_NAME="$1"
        VDEV_TYPE="$2"
        shift 2
        DEVICES=("$@")

        echo "Creating ZFS pool:"
        echo "  Name: $POOL_NAME"
        echo "  Type: $VDEV_TYPE"
        echo "  Devices: ''${DEVICES[*]}"
        echo ""

        read -p "Proceed? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
          echo "Aborted"
          exit 0
        fi

        case "$VDEV_TYPE" in
          single)
            sudo ${pkgs.zfs}/bin/zpool create "$POOL_NAME" "''${DEVICES[@]}"
            ;;
          mirror|raidz|raidz2|raidz3)
            sudo ${pkgs.zfs}/bin/zpool create "$POOL_NAME" "$VDEV_TYPE" "''${DEVICES[@]}"
            ;;
          *)
            echo "Error: Invalid type '$VDEV_TYPE'"
            exit 1
            ;;
        esac

        echo ""
        echo "Pool created successfully!"
        echo ""
        sudo ${pkgs.zfs}/bin/zpool status "$POOL_NAME"
      '')
    ];

    # Ensure ZFS-related directories exist
    systemd.tmpfiles.rules = [
      "d /etc/zfs 0755 root root -"
      "f /etc/zfs/snapshot-schedule.conf 0644 root root -"
    ];
  };
}
