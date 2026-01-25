# Runtime-Configurable RAID Management (mdadm)
#
# This module provides the FRAMEWORK for Linux software RAID, but does NOT
# contain any hardcoded array configurations.
#
# All RAID configuration is managed at RUNTIME via:
#   - Standard mdadm CLI commands
#   - The raid-manage helper tool (for common operations)
#   - Array configuration persists in /etc/mdadm.conf (managed outside Nix)
#
# Architecture:
#   - NixOS module: Enables mdadm, installs tools, sets up monitoring
#   - Runtime config: Use standard mdadm commands
#   - Helpers: raid-manage provides convenient wrappers
#   - State: Array configs in /etc/mdadm.conf
#
# Usage:
#   1. Enable in device configuration:
#      imports = [ ../../modules/storage/raid.nix ];
#      services.raid-runtime.enable = true;
#
#   2. Create arrays at runtime (NO Nix edits needed):
#      raid-manage create raid1 /dev/md0 /dev/sda /dev/sdb
#      raid-manage monitor --enable
#
#   3. Use standard mdadm commands:
#      mdadm --detail /dev/md0
#      mdadm --examine /dev/sda
#      cat /proc/mdstat
#
# See: /home/sam-dev/Repos/personal/nix-config/docs/STORAGE-MANAGEMENT.md

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.raid-runtime;
  hostname = config.networking.hostName;

in {
  options.services.raid-runtime = {
    enable = mkEnableOption "Runtime-configurable RAID storage management";

    enableMonitoring = mkOption {
      type = types.bool;
      default = true;
      description = "Enable mdadm monitoring daemon for array health checks";
    };

    enableAutoScrub = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic array scrubbing (consistency checks)";
    };

    scrubInterval = mkOption {
      type = types.str;
      default = "monthly";
      description = "How often to scrub RAID arrays (systemd timer format)";
    };

    emailOnFailure = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin@example.com";
      description = "Email address for RAID failure alerts";
    };

    checkSpeed = mkOption {
      type = types.int;
      default = 200000;
      description = "RAID resync/check speed limit in KB/s (200MB/s default)";
    };
  };

  config = mkIf cfg.enable {
    # Enable mdadm
    boot.swraid.enable = true;
    boot.swraid.mdadmConf = ''
      # Runtime RAID configuration
      # This file is managed by raid-manage and mdadm commands
      # DO NOT edit directly in Nix configuration

      MAILADDR ${if cfg.emailOnFailure != null then cfg.emailOnFailure else "root"}

      # Auto-detect and assemble arrays at boot
      ARRAY <ignore> UUID=*
    '';

    # Install RAID utilities
    environment.systemPackages = [
      pkgs.mdadm
      # Rust tool installed separately via workspace
    ];

    # RAID monitoring daemon
    systemd.services.mdmonitor = mkIf cfg.enableMonitoring {
      description = "mdadm Software RAID Monitor";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${pkgs.mdadm}/bin/mdadm --monitor --scan --daemonise --syslog";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "on-failure";
      };
    };

    # Automatic array scrubbing (consistency check)
    systemd.services.mdadm-scrub = mkIf cfg.enableAutoScrub {
      description = "mdadm RAID Array Scrub";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "mdadm-scrub" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          echo "Starting RAID array scrub..."

          # Find all active md devices
          MD_DEVICES=$(ls /dev/md* 2>/dev/null | grep -E '/dev/md[0-9]+$' || true)

          if [ -z "$MD_DEVICES" ]; then
            echo "No RAID arrays found"
            exit 0
          fi

          for md in $MD_DEVICES; do
            echo "Scrubbing $md..."

            # Check if array is active
            if ${pkgs.mdadm}/bin/mdadm --detail "$md" &>/dev/null; then
              # Initiate check
              echo "check" > /sys/block/$(basename "$md")/md/sync_action
              echo "Scrub started for $md"
            else
              echo "Skipping inactive array: $md"
            fi
          done

          echo "RAID scrub initiated for all arrays"
          echo "Monitor progress with: cat /proc/mdstat"
        '';
      };
    };

    # Scrub timer
    systemd.timers.mdadm-scrub = mkIf cfg.enableAutoScrub {
      description = "mdadm RAID Array Scrub Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.scrubInterval;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # RAID health check
    systemd.services.mdadm-health-check = mkIf cfg.enableMonitoring {
      description = "mdadm RAID Health Check";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "mdadm-health-check" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          MD_DEVICES=$(ls /dev/md* 2>/dev/null | grep -E '/dev/md[0-9]+$' || true)

          if [ -z "$MD_DEVICES" ]; then
            echo "No RAID arrays configured"
            exit 0
          fi

          DEGRADED=0

          for md in $MD_DEVICES; do
            STATUS=$(${pkgs.mdadm}/bin/mdadm --detail "$md" | grep "State :" | awk '{print $3}')

            case "$STATUS" in
              clean|active)
                echo "✓ $md: $STATUS"
                ;;
              degraded)
                echo "⚠ $md: DEGRADED"
                DEGRADED=1
                ${pkgs.mdadm}/bin/mdadm --detail "$md"
                ${optionalString (cfg.emailOnFailure != null) ''
                  ${pkgs.mdadm}/bin/mdadm --detail "$md" | \
                    ${pkgs.mailutils}/bin/mail -s "RAID Alert: $md Degraded" ${cfg.emailOnFailure}
                ''}
                ;;
              *)
                echo "✗ $md: $STATUS (FAILED)"
                DEGRADED=1
                ${pkgs.mdadm}/bin/mdadm --detail "$md"
                ${optionalString (cfg.emailOnFailure != null) ''
                  ${pkgs.mdadm}/bin/mdadm --detail "$md" | \
                    ${pkgs.mailutils}/bin/mail -s "RAID CRITICAL: $md Failed" ${cfg.emailOnFailure}
                ''}
                ;;
            esac
          done

          exit $DEGRADED
        '';
      };
    };

    # Health check timer (runs every 15 minutes)
    systemd.timers.mdadm-health-check = mkIf cfg.enableMonitoring {
      description = "mdadm RAID Health Check Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15"; # Every 15 minutes
        Persistent = true;
      };
    };

    # Kernel tuning for RAID performance
    boot.kernel.sysctl = {
      # RAID resync speed limits (prevent system slowdown during rebuild)
      "dev.raid.speed_limit_min" = 10000;  # 10MB/s minimum
      "dev.raid.speed_limit_max" = cfg.checkSpeed;
    };

    # Helper scripts
    environment.systemPackages = [
      # Show RAID status
      (pkgs.writeScriptBin "raid-status" ''
        #!${pkgs.bash}/bin/bash

        echo "RAID Array Status:"
        echo ""

        cat /proc/mdstat
        echo ""

        MD_DEVICES=$(ls /dev/md* 2>/dev/null | grep -E '/dev/md[0-9]+$' || true)

        if [ -z "$MD_DEVICES" ]; then
          echo "No RAID arrays found"
          exit 0
        fi

        for md in $MD_DEVICES; do
          echo "Details for $md:"
          ${pkgs.mdadm}/bin/mdadm --detail "$md"
          echo ""
        done
      '')

      # Quick array creation helper
      (pkgs.writeScriptBin "raid-quick-create" ''
        #!${pkgs.bash}/bin/bash

        echo "RAID Quick Create Helper"
        echo ""
        echo "This is a helper for mdadm --create. For full control, use 'mdadm' directly."
        echo ""

        if [ $# -lt 3 ]; then
          echo "Usage: raid-quick-create <level> <md-device> <devices...>"
          echo ""
          echo "Levels: 0, 1, 5, 6, 10"
          echo ""
          echo "Examples:"
          echo "  raid-quick-create 1 /dev/md0 /dev/sda /dev/sdb"
          echo "  raid-quick-create 5 /dev/md1 /dev/sd{c,d,e,f}"
          exit 1
        fi

        LEVEL="$1"
        MD_DEVICE="$2"
        shift 2
        DEVICES=("$@")
        NUM_DEVICES=''${#DEVICES[@]}

        echo "Creating RAID array:"
        echo "  Level: RAID$LEVEL"
        echo "  Device: $MD_DEVICE"
        echo "  Devices: ''${DEVICES[*]}"
        echo "  Count: $NUM_DEVICES"
        echo ""

        # Validate level
        case "$LEVEL" in
          0|1|5|6|10) ;;
          *)
            echo "Error: Invalid RAID level '$LEVEL'"
            exit 1
            ;;
        esac

        read -p "⚠️  This will DESTROY all data on these devices. Proceed? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
          echo "Aborted"
          exit 0
        fi

        # Create array
        sudo ${pkgs.mdadm}/bin/mdadm --create "$MD_DEVICE" \
          --level="$LEVEL" \
          --raid-devices="$NUM_DEVICES" \
          "''${DEVICES[@]}"

        # Update mdadm.conf
        echo ""
        echo "Updating /etc/mdadm.conf..."
        sudo ${pkgs.mdadm}/bin/mdadm --detail --scan | sudo tee -a /etc/mdadm.conf

        echo ""
        echo "Array created successfully!"
        echo ""
        sudo ${pkgs.mdadm}/bin/mdadm --detail "$MD_DEVICE"
        echo ""
        echo "Monitor build progress with: cat /proc/mdstat"
      '')

      # Show rebuild progress
      (pkgs.writeScriptBin "raid-progress" ''
        #!${pkgs.bash}/bin/bash

        echo "RAID Rebuild/Resync Progress:"
        echo ""

        watch -n 1 'cat /proc/mdstat'
      '')

      # Fail/remove/add disk helpers
      (pkgs.writeScriptBin "raid-fail-disk" ''
        #!${pkgs.bash}/bin/bash

        if [ $# -ne 2 ]; then
          echo "Usage: raid-fail-disk <md-device> <disk>"
          echo "Example: raid-fail-disk /dev/md0 /dev/sda1"
          exit 1
        fi

        MD="$1"
        DISK="$2"

        echo "Marking $DISK as failed in $MD"
        sudo ${pkgs.mdadm}/bin/mdadm --manage "$MD" --fail "$DISK"
      '')

      (pkgs.writeScriptBin "raid-remove-disk" ''
        #!${pkgs.bash}/bin/bash

        if [ $# -ne 2 ]; then
          echo "Usage: raid-remove-disk <md-device> <disk>"
          echo "Example: raid-remove-disk /dev/md0 /dev/sda1"
          exit 1
        fi

        MD="$1"
        DISK="$2"

        echo "Removing $DISK from $MD"
        sudo ${pkgs.mdadm}/bin/mdadm --manage "$MD" --remove "$DISK"
      '')

      (pkgs.writeScriptBin "raid-add-disk" ''
        #!${pkgs.bash}/bin/bash

        if [ $# -ne 2 ]; then
          echo "Usage: raid-add-disk <md-device> <disk>"
          echo "Example: raid-add-disk /dev/md0 /dev/sdb1"
          exit 1
        fi

        MD="$1"
        DISK="$2"

        echo "Adding $DISK to $MD"
        sudo ${pkgs.mdadm}/bin/mdadm --manage "$MD" --add "$DISK"
        echo ""
        echo "Rebuild started. Monitor with: raid-progress"
      '')
    ];

    # Ensure mdadm.conf exists
    systemd.tmpfiles.rules = [
      "f /etc/mdadm.conf 0644 root root -"
    ];
  };
}
