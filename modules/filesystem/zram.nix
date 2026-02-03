{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.filesystem.zram;
in
{
  options.filesystem.zram = {
    enable = mkEnableOption "Zram compressed swap in RAM";

    memoryPercent = mkOption {
      type = types.int;
      default = 50;
      description = "Percentage of RAM to allocate for Zram (default: 50%)";
    };

    algorithm = mkOption {
      type = types.enum [ "zstd" "lzo" "lz4" ];
      default = "zstd";
      description = "Compression algorithm (zstd = best compression, lz4 = fastest)";
    };

    priority = mkOption {
      type = types.int;
      default = 100;
      description = "Swap priority (higher = preferred over disk swap)";
    };

    disableDiskSwap = mkOption {
      type = types.bool;
      default = true;
      description = "Disable all disk-based swap devices";
    };
  };

  config = mkIf cfg.enable {
    # Enable Zram swap
    zramSwap = {
      enable = true;
      algorithm = cfg.algorithm;
      memoryPercent = cfg.memoryPercent;
      priority = cfg.priority;
    };

    # Disable disk swap if requested
    swapDevices = mkIf cfg.disableDiskSwap [];

    # Kernel parameters for optimal Zram performance
    boot.kernel.sysctl = {
      # Prefer swap over dropping cache (good for Zram)
      "vm.swappiness" = 180;  # High swappiness for Zram (in-memory swap)

      # Page cluster (how many pages to swap at once)
      # 0 = swap single pages (optimal for Zram)
      "vm.page-cluster" = 0;

      # VFS cache pressure (lower = keep cache longer)
      "vm.vfs_cache_pressure" = 100;
    };

    # Install tools for monitoring Zram
    environment.systemPackages = with pkgs; [
      zram-generator
    ];

    # Systemd service to show Zram stats on boot
    systemd.services.zram-stats = {
      description = "Display Zram statistics";
      wantedBy = [ "multi-user.target" ];
      after = [ "zram-init.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = pkgs.writeShellScript "zram-stats.sh" ''
          #!/usr/bin/env bash
          echo "=== Zram Swap Status ==="
          ${pkgs.util-linux}/bin/swapon --show
          echo ""
          echo "=== Zram Device Details ==="
          ${pkgs.util-linux}/bin/zramctl
        '';
      };
    };
  };
}
