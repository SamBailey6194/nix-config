{ config, lib, pkgs, ... }:

let
  cfg = config.workloads;
  limits = {
    CPUAccounting = true;
    MemoryAccounting = true;
    IOAccounting = true;
    CPUQuota = cfg.cpuQuota;
    CPUWeight = 25;
    IOWeight = 25;
    MemoryHigh = cfg.memoryHigh;
    MemoryMax = cfg.memoryMax;
    MemorySwapMax = cfg.memorySwapMax;
    TasksMax = 4096;
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "60%";
  };
in
{
  options.workloads = {
    memoryHigh = lib.mkOption {
      type = lib.types.str;
      default = "50%";
      description = "Aggregate heavy-job memory reclaim threshold (percentage of physical RAM or bytes).";
    };
    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "60%";
      description = "Aggregate heavy-job hard memory ceiling (percentage of physical RAM or bytes).";
    };
    memorySwapMax = lib.mkOption {
      type = lib.types.str;
      default = "1G";
      description = "Aggregate heavy-job swap ceiling; zram also consumes physical RAM.";
    };
    cpuQuota = lib.mkOption {
      type = lib.types.str;
      default = "400%";
      description = "Aggregate heavy-job CPU ceiling; 100% is one logical CPU.";
    };
  };

  config = {
    # NixOS uses cgroup v2. PSI is required by systemd-oomd.
    boot.kernelParams = [ "psi=1" ];
    systemd.oomd = {
      enable = true;
      enableRootSlice = false;
      enableSystemSlice = false;
      enableUserSlices = false;
      settings.OOM.DefaultMemoryPressureDurationSec = "20s";
    };

    # Only descendants of the workload slices are oomd candidates. Do not
    # monitor the whole user session: that could kill the compositor/terminal.
    systemd.user.slices.workload.sliceConfig = limits;
    systemd.slices.workload.sliceConfig = limits;

    # A swap cushion on early stages too; full-stage filesystem.zram settings
    # take precedence. This is compressed RAM, not additional physical memory.
    zramSwap.enable = lib.mkDefault true;
    zramSwap.memoryPercent = lib.mkDefault 25;

    # Builders have a separate budget. Preserve the daemon if one builder dies.
    # The Intel tower's existing explicit 14G/16G limits take precedence.
    nix.daemonCPUSchedPolicy = lib.mkDefault "batch";
    systemd.services.nix-daemon.serviceConfig = {
      MemoryHigh = lib.mkDefault "25%";
      MemoryMax = lib.mkDefault "30%";
      MemorySwapMax = lib.mkDefault "0";
      CPUWeight = lib.mkDefault 25;
      IOWeight = lib.mkDefault 25;
      OOMPolicy = lib.mkDefault "continue";
    };

    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "resource-run";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if [ "$#" -eq 0 ]; then
            echo 'Usage: resource-run COMMAND [ARGUMENTS...]' >&2
            exit 2
          fi
          # Keep subprocesses in their parent's limited cgroup. In particular,
          # wrapping an entire script also covers its parallel child jobs.
          if [ "''${NIX_RESOURCE_SCOPE:-}" = 1 ]; then
            exec "$@"
          fi
          manager=(--user)
          if [ "$EUID" -eq 0 ]; then
            manager=()
          fi
          export NIX_RESOURCE_SCOPE=1
          exec systemd-run "''${manager[@]}" --scope --quiet \
            --slice=workload.slice \
            --property=MemoryHigh=${lib.escapeShellArg cfg.memoryHigh} \
            --property=MemoryMax=${lib.escapeShellArg cfg.memoryMax} \
            --property=MemorySwapMax=${lib.escapeShellArg cfg.memorySwapMax} \
            --property=MemoryOOMGroup=yes \
            --property=OOMPolicy=kill \
            -- "$@"
        '';
      })
    ];
  };
}
