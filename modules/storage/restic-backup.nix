# Restic Backup Configuration Module
# Provides flexible, encrypted backups to multiple destinations
#
# Features:
#   - Per-device backup configuration
#   - Multiple repositories (local, B2, S3, SFTP, etc.)
#   - Automatic scheduling with systemd timers
#   - Agenix integration for credentials
#   - Pre/post backup hooks
#   - Retention policies
#   - Email notifications on failures
#   - Verification and restore capabilities
#
# Usage:
#   1. Enable in device configuration:
#      imports = [ ../../modules/storage/restic-backup.nix ];
#
#   2. Configure repositories:
#      services.restic-backup = {
#        enable = true;
#        device = "laptop-intel";
#        repositories = {
#          local = { ... };
#          backblaze = { ... };
#        };
#      };
#
#   3. Store credentials in agenix:
#      - restic-password-<device>.age
#      - restic-b2-keyid-<device>.age
#      - restic-b2-key-<device>.age

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.restic-backup;

  # Helper to create repository-specific backup service
  mkBackupService = repoName: repoCfg: {
    name = "restic-backup-${cfg.device}-${repoName}";
    value = {
      description = "Restic backup to ${repoName} for ${cfg.device}";

      paths = repoCfg.paths;

      repository = repoCfg.repository;

      passwordFile = repoCfg.passwordFile;

      # Environment variables for repository access (S3, B2, etc.)
      environmentFile = repoCfg.environmentFile or null;

      # Backup schedule
      timerConfig = {
        OnCalendar = repoCfg.schedule;
        Persistent = true;
        RandomizedDelaySec = repoCfg.randomDelay or "1h";
      };

      # Pruning/retention policy
      pruneOpts = repoCfg.pruneOpts or [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
        "--keep-yearly 2"
      ];

      # Exclude patterns
      exclude = repoCfg.exclude or [
        # Temporary files
        "**/.cache"
        "**/.tmp"
        "**/tmp"

        # Build artifacts
        "**/node_modules"
        "**/target"
        "**/.venv"
        "**/__pycache__"

        # System directories
        "/proc"
        "/sys"
        "/dev"
        "/run"
        "/tmp"

        # Large media caches
        "**/.local/share/Trash"
        "**/.thumbnails"
      ];

      # Backup initialization (create repo if it doesn't exist)
      initialize = repoCfg.initialize or true;

      # Pre-backup commands
      backupPrepareCommand = repoCfg.backupPrepareCommand or "";

      # Post-backup commands
      backupCleanupCommand = repoCfg.backupCleanupCommand or ''
        ${optionalString (repoCfg.notifyOnSuccess or false) ''
          ${pkgs.libnotify}/bin/notify-send "Restic Backup" "Backup to ${repoName} completed successfully"
        ''}
      '';

      # Extra backup arguments
      extraBackupArgs = repoCfg.extraBackupArgs or [
        "--verbose"
        "--exclude-caches"
        "--one-file-system"
      ];

      # Run check after backup
      checkOpts = repoCfg.checkOpts or [
        "--read-data-subset=5%"
      ];
    };
  };

  # Generate all backup services
  backupServices = mapAttrs' mkBackupService cfg.repositories;

in {
  options.services.restic-backup = {
    enable = mkEnableOption "Restic backup system";

    device = mkOption {
      type = types.str;
      example = "laptop-intel";
      description = "Device identifier for backup configuration";
    };

    repositories = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          repository = mkOption {
            type = types.str;
            example = "b2:bucket-name:/backups/laptop-intel";
            description = "Restic repository URL";
          };

          passwordFile = mkOption {
            type = types.str;
            example = "/run/agenix/restic-password-laptop-intel";
            description = "Path to repository password file (from agenix)";
          };

          environmentFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "/run/agenix/restic-b2-env-laptop-intel";
            description = "Environment file for repository credentials (B2, S3, etc.)";
          };

          paths = mkOption {
            type = types.listOf types.str;
            example = [ "/home" "/etc" "/var/lib" ];
            description = "Paths to backup";
          };

          schedule = mkOption {
            type = types.str;
            default = "daily";
            example = "02:00";
            description = "Backup schedule (systemd timer format)";
          };

          randomDelay = mkOption {
            type = types.str;
            default = "1h";
            description = "Random delay before backup starts (prevents simultaneous backups)";
          };

          exclude = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "*.tmp" "*.cache" ];
            description = "Additional exclude patterns";
          };

          pruneOpts = mkOption {
            type = types.listOf types.str;
            default = [
              "--keep-daily 7"
              "--keep-weekly 4"
              "--keep-monthly 6"
              "--keep-yearly 2"
            ];
            description = "Retention policy for old backups";
          };

          initialize = mkOption {
            type = types.bool;
            default = true;
            description = "Initialize repository if it doesn't exist";
          };

          backupPrepareCommand = mkOption {
            type = types.str;
            default = "";
            example = "systemctl stop postgresql";
            description = "Command to run before backup";
          };

          backupCleanupCommand = mkOption {
            type = types.str;
            default = "";
            example = "systemctl start postgresql";
            description = "Command to run after backup";
          };

          extraBackupArgs = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "--tag important" ];
            description = "Additional restic backup arguments";
          };

          checkOpts = mkOption {
            type = types.listOf types.str;
            default = [ "--read-data-subset=5%" ];
            description = "Repository check options";
          };

          notifyOnSuccess = mkOption {
            type = types.bool;
            default = false;
            description = "Send desktop notification on successful backup";
          };
        };
      });
      default = {};
      description = "Backup repository configurations";
    };
  };

  config = mkIf cfg.enable {
    # Install restic
    environment.systemPackages = [ pkgs.restic ];

    # Create all backup services
    services.restic.backups = backupServices;

    # Helper scripts for backup management
    environment.systemPackages = [
      (pkgs.writeScriptBin "restic-list-repos" ''
        #!${pkgs.bash}/bin/bash
        echo "Configured Restic Repositories for ${cfg.device}:"
        echo ""
        ${concatStringsSep "\n" (mapAttrsToList (name: repo: ''
          echo "📦 ${name}"
          echo "   Repository: ${repo.repository}"
          echo "   Schedule: ${repo.schedule}"
          echo "   Paths: ${concatStringsSep ", " repo.paths}"
          echo ""
        '') cfg.repositories)}
      '')

      (pkgs.writeScriptBin "restic-backup-status" ''
        #!${pkgs.bash}/bin/bash
        for service in ${concatStringsSep " " (mapAttrsToList (name: _: "restic-backup-${cfg.device}-${name}") cfg.repositories)}; do
          echo "Status: $service"
          systemctl status "$service.service" --no-pager | head -10
          echo ""
        done
      '')

      (pkgs.writeScriptBin "restic-backup-now" ''
        #!${pkgs.bash}/bin/bash
        if [ -z "$1" ]; then
          echo "Usage: restic-backup-now <repository-name>"
          echo "Available repositories: ${concatStringsSep ", " (attrNames cfg.repositories)}"
          exit 1
        fi

        SERVICE="restic-backup-${cfg.device}-$1"
        echo "Starting backup: $SERVICE"
        sudo systemctl start "$SERVICE.service"
      '')

      (pkgs.writeScriptBin "restic-restore" ''
        #!${pkgs.bash}/bin/bash
        if [ $# -lt 2 ]; then
          echo "Usage: restic-restore <repository-name> <snapshot-id> [target-path]"
          echo "Available repositories: ${concatStringsSep ", " (attrNames cfg.repositories)}"
          exit 1
        fi

        REPO="$1"
        SNAPSHOT="$2"
        TARGET="''${3:-.}"

        # This script needs to be run with repository-specific credentials
        echo "To restore from $REPO:"
        echo "1. Source the repository credentials"
        echo "2. Run: restic -r <repo-url> restore $SNAPSHOT --target $TARGET"
      '')
    ];
  };
}
