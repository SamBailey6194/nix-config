{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.folderEncryption;
in
{
  options.security.folderEncryption = {
    enable = mkEnableOption "Per-folder encryption with gocryptfs";

    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          vaultsPath = mkOption {
            type = types.str;
            description = "Path to encrypted vault storage";
            example = "$HOME/vaults";
          };

          mountPath = mkOption {
            type = types.str;
            description = "Path for mount points of unlocked vaults";
            example = "$HOME/mnt";
          };

          defaultVaults = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of vault names to create by default";
            example = [ "secure" "projects" "personal" ];
          };
        };
      });
      default = {};
      description = "Per-user vault configuration";
    };

    autoUnmountOnLogout = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically unmount all vaults on user logout";
    };

    idleTimeout = mkOption {
      type = types.int;
      default = 0;
      description = "Auto-unmount vaults after N minutes of inactivity (0 = disabled)";
    };
  };

  config = mkIf cfg.enable {
    # Install gocryptfs
    environment.systemPackages = with pkgs; [
      gocryptfs
    ];

    # Enable FUSE for user mounts
    programs.fuse.userAllowOther = true;

    # Create vault directories for each user
    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (username: userCfg: [
        "d ${userCfg.vaultsPath} 0700 ${username} users - -"
        "d ${userCfg.mountPath} 0700 ${username} users - -"
      ]) cfg.users
    );

    # Auto-unmount on logout via PAM
    security.pam.services = mkIf cfg.autoUnmountOnLogout (
      listToAttrs (map (username: {
        name = username;
        value = {
          text = ''
            session optional ${pkgs.bash}/bin/bash -c '${pkgs.procps}/bin/pkill -u ${username} gocryptfs 2>/dev/null || true'
          '';
        };
      }) (attrNames cfg.users))
    );

    # Systemd user service for idle timeout (if enabled)
    systemd.user.services.vault-idle-monitor = mkIf (cfg.idleTimeout > 0) {
      description = "Monitor vault idle time and auto-unmount";
      wantedBy = [ "default.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        ExecStart = pkgs.writeShellScript "vault-idle-monitor.sh" ''
          #!/usr/bin/env bash
          set -euo pipefail

          TIMEOUT_SECONDS=$((${toString cfg.idleTimeout} * 60))
          CHECK_INTERVAL=60  # Check every minute

          while true; do
            sleep "$CHECK_INTERVAL"

            # Get all gocryptfs mount points for current user
            MOUNTS=$(${pkgs.util-linux}/bin/findmnt -t fuse.gocryptfs -n -o TARGET 2>/dev/null || true)

            if [ -z "$MOUNTS" ]; then
              continue
            fi

            while IFS= read -r mount; do
              # Get time since last access
              LAST_ACCESS=$(${pkgs.findutils}/bin/find "$mount" -type f -amin -$((TIMEOUT_SECONDS / 60)) 2>/dev/null | wc -l)

              if [ "$LAST_ACCESS" -eq 0 ]; then
                echo "Unmounting idle vault: $mount"
                ${pkgs.fuse}/bin/fusermount -u "$mount" 2>/dev/null || true
              fi
            done <<< "$MOUNTS"
          done
        '';
      };
    };

    # Helper script for vault management (will be replaced by Rust CLI)
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "vault-manage-simple" ''
        #!/usr/bin/env bash
        set -euo pipefail

        VAULTS_PATH="''${VAULTS_PATH:-$HOME/vaults}"
        MOUNT_PATH="''${MOUNT_PATH:-$HOME/mnt}"

        show_usage() {
          cat <<EOF
        Usage: vault-manage-simple <command> [vault-name]

        Commands:
          create <name>      Create a new encrypted vault
          mount <name>       Mount an encrypted vault
          unmount <name>     Unmount a vault
          unmount-all        Unmount all vaults
          list               List all vaults
          status             Show mounted vaults

        Environment Variables:
          VAULTS_PATH        Path to encrypted vault storage (default: $HOME/vaults)
          MOUNT_PATH         Path for mount points (default: $HOME/mnt)
        EOF
        }

        create_vault() {
          local name="$1"
          local vault_dir="$VAULTS_PATH/$name"
          local mount_dir="$MOUNT_PATH/$name"

          if [ -d "$vault_dir" ]; then
            echo "Error: Vault '$name' already exists"
            exit 1
          fi

          mkdir -p "$vault_dir" "$mount_dir"
          echo "Creating encrypted vault: $name"
          ${pkgs.gocryptfs}/bin/gocryptfs -init "$vault_dir"
          echo "Vault created at: $vault_dir"
          echo "Mount with: vault-manage-simple mount $name"
        }

        mount_vault() {
          local name="$1"
          local vault_dir="$VAULTS_PATH/$name"
          local mount_dir="$MOUNT_PATH/$name"

          if [ ! -d "$vault_dir" ]; then
            echo "Error: Vault '$name' not found"
            exit 1
          fi

          if ${pkgs.util-linux}/bin/mountpoint -q "$mount_dir" 2>/dev/null; then
            echo "Vault '$name' is already mounted"
            exit 0
          fi

          mkdir -p "$mount_dir"
          echo "Mounting vault: $name"
          ${pkgs.gocryptfs}/bin/gocryptfs "$vault_dir" "$mount_dir"
          echo "Vault mounted at: $mount_dir"
        }

        unmount_vault() {
          local name="$1"
          local mount_dir="$MOUNT_PATH/$name"

          if ! ${pkgs.util-linux}/bin/mountpoint -q "$mount_dir" 2>/dev/null; then
            echo "Vault '$name' is not mounted"
            exit 0
          fi

          echo "Unmounting vault: $name"
          ${pkgs.fuse}/bin/fusermount -u "$mount_dir"
          echo "Vault unmounted"
        }

        unmount_all() {
          echo "Unmounting all vaults..."
          ${pkgs.procps}/bin/pkill gocryptfs 2>/dev/null || true
          echo "All vaults unmounted"
        }

        list_vaults() {
          if [ ! -d "$VAULTS_PATH" ]; then
            echo "No vaults directory found: $VAULTS_PATH"
            exit 0
          fi

          echo "Available vaults:"
          for vault in "$VAULTS_PATH"/*; do
            if [ -d "$vault" ]; then
              echo "  - $(basename "$vault")"
            fi
          done
        }

        show_status() {
          echo "Mounted vaults:"
          ${pkgs.util-linux}/bin/findmnt -t fuse.gocryptfs -o TARGET,SOURCE 2>/dev/null || echo "  (none)"
        }

        case "''${1:-}" in
          create)
            [ -z "''${2:-}" ] && show_usage && exit 1
            create_vault "$2"
            ;;
          mount)
            [ -z "''${2:-}" ] && show_usage && exit 1
            mount_vault "$2"
            ;;
          unmount)
            [ -z "''${2:-}" ] && show_usage && exit 1
            unmount_vault "$2"
            ;;
          unmount-all)
            unmount_all
            ;;
          list)
            list_vaults
            ;;
          status)
            show_status
            ;;
          *)
            show_usage
            exit 1
            ;;
        esac
      '')
    ];
  };
}
