{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.luksEncryption;
in
{
  options.security.luksEncryption = {
    enable = mkEnableOption "LUKS encryption with TPM2 support";

    devices = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          device = mkOption {
            type = types.str;
            description = "Path to the LUKS device (e.g., /dev/nvme0n1p2)";
          };

          name = mkOption {
            type = types.str;
            description = "Name of the mapped device (e.g., cryptroot)";
          };

          preLVM = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to unlock before LVM";
          };

          allowDiscards = mkOption {
            type = types.bool;
            default = true;
            description = "Enable TRIM support for SSDs";
          };

          fallbackToPassword = mkOption {
            type = types.bool;
            default = true;
            description = "Allow password fallback if TPM2 fails";
          };

          tpm2Device = mkOption {
            type = types.str;
            default = "auto";
            description = "TPM2 device path or 'auto' for automatic detection";
          };
        };
      });
      default = {};
      description = "LUKS devices to configure";
    };

    headerBackupPath = mkOption {
      type = types.str;
      default = "/var/lib/luks-backups";
      description = "Directory for LUKS header backups";
    };

    enableAutoBackup = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically backup LUKS headers on system activation";
    };
  };

  config = mkIf cfg.enable {
    # LUKS device configuration
    boot.initrd.luks.devices = mapAttrs (name: deviceCfg: {
      device = deviceCfg.device;
      preLVM = deviceCfg.preLVM;
      allowDiscards = deviceCfg.allowDiscards;

      # TPM2 configuration
      crypttabExtraOpts = [ "tpm2-device=${deviceCfg.tpm2Device}" ] ++
        (optional deviceCfg.fallbackToPassword "try-empty-password");
    }) cfg.devices;

    # TPM2 tools for key enrollment
    environment.systemPackages = with pkgs; [
      tpm2-tools
      tpm2-tss
      cryptsetup
    ];

    # Create LUKS header backup directory
    systemd.tmpfiles.rules = [
      "d ${cfg.headerBackupPath} 0700 root root - -"
    ];

    # Automatic LUKS header backup on system activation
    system.activationScripts.backupLuksHeaders = mkIf cfg.enableAutoBackup ''
      echo "Backing up LUKS headers..."
      ${pkgs.bash}/bin/bash ${pkgs.writeScript "backup-luks-headers.sh" ''
        #!/usr/bin/env bash
        set -euo pipefail

        BACKUP_DIR="${cfg.headerBackupPath}"
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)

        ${concatStringsSep "\n" (mapAttrsToList (name: deviceCfg: ''
          DEVICE="${deviceCfg.device}"
          NAME="${deviceCfg.name}"
          BACKUP_FILE="$BACKUP_DIR/$NAME-header-$TIMESTAMP.img"

          if [ -b "$DEVICE" ]; then
            echo "Backing up LUKS header for $NAME ($DEVICE)..."
            ${pkgs.cryptsetup}/bin/cryptsetup luksHeaderBackup "$DEVICE" \
              --header-backup-file "$BACKUP_FILE" 2>/dev/null || true

            # Keep only the 5 most recent backups per device
            ls -t "$BACKUP_DIR/$NAME-header-"*.img 2>/dev/null | tail -n +6 | xargs -r rm -f
          fi
        '') cfg.devices)}

        echo "LUKS header backup complete."
      ''}
    '';

    # TPM2 kernel modules
    boot.initrd.availableKernelModules = [ "tpm_tis" "tpm_crb" ];

    # Enable TPM2 support in systemd
    boot.initrd.systemd.enable = true;
  };
}
