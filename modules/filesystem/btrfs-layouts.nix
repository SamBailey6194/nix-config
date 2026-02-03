{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.filesystem.btrfsLayouts;
in
{
  options.filesystem.btrfsLayouts = {
    layout = mkOption {
      type = types.enum [ "laptop" "devtower-os" "devtower-home" "devtower-media" ];
      description = "Predefined BTRFS subvolume layout for this device";
    };

    rootDevice = mkOption {
      type = types.str;
      description = "Root device for BTRFS (e.g., /dev/mapper/cryptroot)";
    };
  };

  config = {
    filesystem.btrfs = {
      enable = true;
      rootDevice = cfg.rootDevice;

      compression = "zstd";
      compressionLevel = 1;

      subvolumes = mkMerge [
        # Laptop layout (single drive: OS + home)
        (mkIf (cfg.layout == "laptop") {
          root = {
            mountPoint = "/";
            subvolName = "@root";
          };

          home = {
            mountPoint = "/home";
            subvolName = "@home";
          };

          nix = {
            mountPoint = "/nix";
            subvolName = "@nix";
          };

          snapshots = {
            mountPoint = "/.snapshots";
            subvolName = "@snapshots";
          };

          log = {
            mountPoint = "/var/log";
            subvolName = "@log";
            enableCOW = false;  # Disable COW for log files
          };
        })

        # DevTower OS drive (OS only, no home)
        (mkIf (cfg.layout == "devtower-os") {
          root = {
            mountPoint = "/";
            subvolName = "@root";
          };

          nix = {
            mountPoint = "/nix";
            subvolName = "@nix";
          };

          snapshots = {
            mountPoint = "/.snapshots";
            subvolName = "@snapshots";
          };

          log = {
            mountPoint = "/var/log";
            subvolName = "@log";
            enableCOW = false;
          };
        })

        # DevTower home drive (separate SSD)
        (mkIf (cfg.layout == "devtower-home") {
          home = {
            mountPoint = "/home";
            subvolName = "@home";
          };
        })

        # DevTower media drive (3.6TB HDD)
        (mkIf (cfg.layout == "devtower-media") {
          media = {
            mountPoint = "/mnt/media";
            subvolName = "@media";
          };

          archive = {
            mountPoint = "/mnt/archive";
            subvolName = "@archive";
          };

          projects = {
            mountPoint = "/mnt/projects";
            subvolName = "@projects";
          };
        })
      ];

      snapshots = {
        enable = true;
        retention = {
          hourly = 0;
          daily = 7;
          weekly = 4;
          monthly = 6;
        };
        systemSnapshots = cfg.layout == "laptop" || cfg.layout == "devtower-os";
      };

      enableScrub = true;
    };
  };
}
