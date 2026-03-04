{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.filesystem.btrfs;
in
{
  options.filesystem.btrfs = {
    enable = mkEnableOption "BTRFS filesystem configuration";

    rootDevice = mkOption {
      type = types.str;
      description = "Root device for BTRFS (e.g., /dev/mapper/cryptroot)";
    };

    compression = mkOption {
      type = types.enum [ "zstd" "lzo" "zlib" "none" ];
      default = "zstd";
      description = "Compression algorithm to use";
    };

    compressionLevel = mkOption {
      type = types.int;
      default = 1;
      description = "Compression level (1-15 for zstd, higher = more compression but slower)";
    };

    mountOptions = mkOption {
      type = types.listOf types.str;
      default = [ "noatime" "space_cache=v2" ];
      description = "Additional mount options for all BTRFS filesystems";
    };

    subvolumes = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          mountPoint = mkOption {
            type = types.str;
            description = "Mount point for the subvolume";
          };

          subvolName = mkOption {
            type = types.str;
            description = "Name of the BTRFS subvolume (e.g., @root, @home)";
          };

          extraOptions = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional mount options specific to this subvolume";
          };

          disableCompression = mkOption {
            type = types.bool;
            default = false;
            description = "Disable compression for this subvolume (useful for databases)";
          };

          enableCOW = mkOption {
            type = types.bool;
            default = true;
            description = "Enable copy-on-write (disable for databases and VMs)";
          };
        };
      });
      default = {};
      description = "BTRFS subvolumes to mount";
    };

    snapshots = {
      enable = mkEnableOption "automatic BTRFS snapshots";

      location = mkOption {
        type = types.str;
        default = "/.snapshots";
        description = "Directory for storing snapshots";
      };

      retention = {
        hourly = mkOption {
          type = types.int;
          default = 0;
          description = "Number of hourly snapshots to keep (0 = disabled)";
        };

        daily = mkOption {
          type = types.int;
          default = 7;
          description = "Number of daily snapshots to keep";
        };

        weekly = mkOption {
          type = types.int;
          default = 4;
          description = "Number of weekly snapshots to keep";
        };

        monthly = mkOption {
          type = types.int;
          default = 6;
          description = "Number of monthly snapshots to keep";
        };
      };

      systemSnapshots = mkOption {
        type = types.bool;
        default = true;
        description = "Create snapshots before/after system rebuilds";
      };
    };

    enableScrub = mkOption {
      type = types.bool;
      default = true;
      description = "Enable monthly BTRFS scrub for data integrity";
    };

    enableAutoBalance = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic BTRFS balance (can be I/O intensive)";
    };
  };

  config = mkIf cfg.enable {
    # Install BTRFS tools
    environment.systemPackages = with pkgs; [
      btrfs-progs
      compsize  # Check compression ratio
    ];

    # Configure BTRFS subvolume mounts with compression and tuned options.
    # Uses mkOverride 90 per-mount so these take priority over
    # hardware-configuration.nix (priority 100) while preserving non-BTRFS
    # mounts like /boot which are not declared here.
    fileSystems = mapAttrs' (name: subvolCfg:
      nameValuePair subvolCfg.mountPoint (lib.mkOverride 90 {
        device = cfg.rootDevice;
        fsType = "btrfs";
        options = cfg.mountOptions ++ [
          "subvol=${subvolCfg.subvolName}"
        ] ++ (if subvolCfg.disableCompression then
          [ "compress=no" ]
        else
          [ "compress=${cfg.compression}:${toString cfg.compressionLevel}" ]
        ) ++ (if subvolCfg.enableCOW then
          []
        else
          [ "nodatacow" ]
        ) ++ subvolCfg.extraOptions;
      })
    ) cfg.subvolumes;

    # Automatic scrub for data integrity
    services.btrfs.autoScrub = mkIf cfg.enableScrub {
      enable = true;
      interval = "monthly";
      fileSystems = [ "/" ];
    };

    # Snapshot management with snapper
    services.snapper = mkIf cfg.snapshots.enable {
      configs = {
        root = {
          SUBVOLUME = "/";
          ALLOW_USERS = [ ];
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = toString cfg.snapshots.retention.hourly;
          TIMELINE_LIMIT_DAILY = toString cfg.snapshots.retention.daily;
          TIMELINE_LIMIT_WEEKLY = toString cfg.snapshots.retention.weekly;
          TIMELINE_LIMIT_MONTHLY = toString cfg.snapshots.retention.monthly;
        };

        home = mkIf (hasAttr "home" cfg.subvolumes) {
          SUBVOLUME = "/home";
          ALLOW_USERS = [ ];
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = toString cfg.snapshots.retention.hourly;
          TIMELINE_LIMIT_DAILY = toString cfg.snapshots.retention.daily;
          TIMELINE_LIMIT_WEEKLY = toString cfg.snapshots.retention.weekly;
          TIMELINE_LIMIT_MONTHLY = toString cfg.snapshots.retention.monthly;
        };
      };
    };

    # Create snapshot directory
    systemd.tmpfiles.rules = mkIf cfg.snapshots.enable [
      "d ${cfg.snapshots.location} 0755 root root - -"
    ];

    # Pre/post rebuild snapshots
    system.activationScripts.btrfsSnapshot = mkIf (cfg.snapshots.enable && cfg.snapshots.systemSnapshots) ''
      echo "Creating pre-rebuild BTRFS snapshot..."
      ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r / ${cfg.snapshots.location}/root-pre-rebuild-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
    '';
  };
}
