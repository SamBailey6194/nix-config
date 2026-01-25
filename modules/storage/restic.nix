# Runtime-Configurable Restic Backup System
#
# This module provides the FRAMEWORK for Restic backups, but does NOT
# contain any hardcoded repository or backup configurations.
#
# All backup configuration is managed at RUNTIME via:
#   - External JSON files in /var/lib/restic/<hostname>/
#   - The restic-manage CLI tool (Rust)
#   - Standard restic CLI (all commands work normally)
#
# Architecture:
#   - NixOS module: Installs restic, creates systemd services framework
#   - Runtime config: JSON files define repos, backups, schedules
#   - Secrets: Referenced via agenix but loaded at runtime
#   - State: All state in /var/lib/restic/<hostname>/
#
# Usage:
#   1. Enable in device configuration:
#      imports = [ ../../modules/storage/restic.nix ];
#      services.restic-runtime.enable = true;
#
#   2. Configure at runtime (NO Nix edits needed):
#      restic-manage add-repo local /mnt/backups
#      restic-manage add-backup home /home local daily
#
#   3. Secrets stored via agenix:
#      - restic-password-<device>.age (repository password)
#      - restic-b2-env-<device>.age (B2/S3 credentials)
#
# See: /home/sam-dev/Repos/personal/nix-config/docs/STORAGE-MANAGEMENT.md

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.restic-runtime;
  hostname = config.networking.hostName;
  stateDir = "/var/lib/restic/${hostname}";
  configFile = "${stateDir}/config.json";

in {
  options.services.restic-runtime = {
    enable = mkEnableOption "Runtime-configurable Restic backup system";

    stateDirectory = mkOption {
      type = types.str;
      default = stateDir;
      description = "Directory for Restic runtime state and configuration";
    };

    secretsPath = mkOption {
      type = types.str;
      default = "/run/agenix";
      description = "Path to agenix secrets directory";
    };

    defaultSchedule = mkOption {
      type = types.str;
      default = "daily";
      description = "Default backup schedule for new backups";
    };

    defaultRetention = mkOption {
      type = types.attrs;
      default = {
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 2;
      };
      description = "Default retention policy for pruning";
    };
  };

  config = mkIf cfg.enable {
    # Install Restic
    environment.systemPackages = [
      pkgs.restic
      # Rust tool installed separately via workspace
    ];

    # Create state directory
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDirectory} 0750 root root -"
      "d ${cfg.stateDirectory}/repos 0750 root root -"
      "d ${cfg.stateDirectory}/backups 0750 root root -"
      "d ${cfg.stateDirectory}/logs 0750 root root -"
      "f ${configFile} 0640 root root -"
    ];

    # Restic configuration reader service
    # This service watches config.json and creates/updates systemd services
    systemd.services.restic-config-sync = {
      description = "Sync Restic configuration to systemd services";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "restic-config-sync" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          CONFIG="${configFile}"

          # Create default config if doesn't exist
          if [ ! -f "$CONFIG" ]; then
            echo '{"repositories": {}, "backups": {}}' > "$CONFIG"
            chmod 640 "$CONFIG"
          fi

          # Validate JSON
          if ! ${pkgs.jq}/bin/jq empty "$CONFIG" 2>/dev/null; then
            echo "ERROR: Invalid JSON in $CONFIG"
            exit 1
          fi

          echo "Restic configuration synced from $CONFIG"

          # Trigger systemd reload to pick up new timer configs
          # (actual service generation happens via restic-manage)
        '';
      };
    };

    # Path-based activation for config changes
    systemd.paths.restic-config-watch = {
      description = "Watch for Restic configuration changes";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathModified = configFile;
        Unit = "restic-config-sync.service";
      };
    };

    # Dynamic backup service template
    # Individual backup services are created by restic-manage
    systemd.services."restic-backup@" = {
      description = "Restic backup for %i";
      serviceConfig = {
        Type = "oneshot";
        # Actual ExecStart injected by restic-manage based on config.json
        EnvironmentFile = "-${cfg.secretsPath}/restic-env-${hostname}";
      };
    };

    # Dynamic backup timer template
    systemd.timers."restic-backup@" = {
      description = "Timer for Restic backup %i";
      timerConfig = {
        Persistent = true;
        RandomizedDelaySec = "1h";
        # OnCalendar injected by restic-manage based on config.json
      };
    };

    # Helper scripts that work with runtime config
    environment.systemPackages = [
      # List all configured backups
      (pkgs.writeScriptBin "restic-list" ''
        #!${pkgs.bash}/bin/bash
        CONFIG="${configFile}"

        if [ ! -f "$CONFIG" ]; then
          echo "No Restic configuration found at $CONFIG"
          echo "Run: restic-manage add-repo <name> <path> to get started"
          exit 0
        fi

        echo "Restic Repositories:"
        ${pkgs.jq}/bin/jq -r '.repositories | to_entries[] | "  \(.key): \(.value.path)"' "$CONFIG"
        echo ""
        echo "Restic Backups:"
        ${pkgs.jq}/bin/jq -r '.backups | to_entries[] | "  \(.key): \(.value.paths | join(", ")) -> \(.value.repository) (\(.value.schedule))"' "$CONFIG"
      '')

      # Show backup status
      (pkgs.writeScriptBin "restic-status" ''
        #!${pkgs.bash}/bin/bash

        echo "Restic Backup Status for ${hostname}:"
        echo ""

        # List all restic-backup@ services
        for service in $(systemctl list-units --all 'restic-backup@*.service' --no-legend | awk '{print $1}'); do
          echo "Service: $service"
          systemctl status "$service" --no-pager --lines=5
          echo ""
        done

        # Show next scheduled backups
        echo "Scheduled Backups:"
        systemctl list-timers 'restic-backup@*' --no-pager
      '')

      # Run backup immediately
      (pkgs.writeScriptBin "restic-backup-now" ''
        #!${pkgs.bash}/bin/bash

        if [ -z "$1" ]; then
          echo "Usage: restic-backup-now <backup-name>"
          echo ""
          echo "Available backups:"
          ${pkgs.jq}/bin/jq -r '.backups | keys[]' "${configFile}" 2>/dev/null || echo "  (none configured)"
          exit 1
        fi

        BACKUP_NAME="$1"
        SERVICE="restic-backup@$BACKUP_NAME.service"

        echo "Starting backup: $BACKUP_NAME"
        sudo systemctl start "$SERVICE"

        echo ""
        echo "Follow logs with: journalctl -fu $SERVICE"
      '')

      # Repository operations wrapper
      (pkgs.writeScriptBin "restic-repo" ''
        #!${pkgs.bash}/bin/bash

        if [ -z "$1" ]; then
          echo "Usage: restic-repo <repository-name> <restic-command> [args...]"
          echo ""
          echo "Examples:"
          echo "  restic-repo local snapshots"
          echo "  restic-repo local check"
          echo "  restic-repo local forget --keep-daily 7 --prune"
          echo "  restic-repo local restore latest --target /tmp/restore"
          echo ""
          echo "Available repositories:"
          ${pkgs.jq}/bin/jq -r '.repositories | keys[]' "${configFile}" 2>/dev/null || echo "  (none configured)"
          exit 1
        fi

        REPO_NAME="$1"
        shift

        # Load repository config
        REPO_PATH=$(${pkgs.jq}/bin/jq -r ".repositories.\"$REPO_NAME\".path // empty" "${configFile}")
        REPO_TYPE=$(${pkgs.jq}/bin/jq -r ".repositories.\"$REPO_NAME\".type // \"local\"" "${configFile}")

        if [ -z "$REPO_PATH" ]; then
          echo "Error: Repository '$REPO_NAME' not found in config"
          exit 1
        fi

        # Load password from agenix
        PASSWORD_FILE="${cfg.secretsPath}/restic-password-${hostname}"
        if [ ! -f "$PASSWORD_FILE" ]; then
          echo "Error: Password file not found: $PASSWORD_FILE"
          echo "Create with: agenix -e restic-password-${hostname}.age"
          exit 1
        fi

        # Set environment based on repository type
        case "$REPO_TYPE" in
          b2|s3)
            ENV_FILE="${cfg.secretsPath}/restic-''${REPO_TYPE}-env-${hostname}"
            if [ -f "$ENV_FILE" ]; then
              source "$ENV_FILE"
            fi
            ;;
        esac

        # Run restic command
        export RESTIC_PASSWORD_FILE="$PASSWORD_FILE"
        export RESTIC_REPOSITORY="$REPO_PATH"

        exec ${pkgs.restic}/bin/restic "$@"
      '')
    ];

    # Monitoring and notifications
    # Email alerts on backup failure (if configured)
    systemd.services."restic-backup@".serviceConfig = {
      # OnFailure = optional "restic-backup-failed@%i.service"
    };
  };
}
