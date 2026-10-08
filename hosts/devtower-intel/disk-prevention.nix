{ config, lib, pkgs, ... }:

{
  imports = [ ../../modules/core/nix-gc.nix ];

  # Collect before the store partition fills. Explicitly avoid retaining
  # derivations/output closures solely for rebuild caching.
  nix.settings = {
    min-free = lib.mkDefault (5 * 1024 * 1024 * 1024);
    max-free = lib.mkDefault (15 * 1024 * 1024 * 1024);
    keep-derivations = false;
    keep-outputs = false;
  };

  # Share common.nix's weekly GC with generation retention at every stage. Catch
  # up after downtime, without creating a second competing GC service.
  systemd.timers.nix-gc-custom.timerConfig = {
    Persistent = true;
    RandomizedDelaySec = "1h";
  };

  # NixOS uses a fresh @docker subvolume; Ubuntu's old Docker data stays mounted
  # read-only until the 870 EVO is encrypted (data-drives.nix).
  # Use the classic image store to avoid the containerd image-store leases
  # left behind by interrupted BuildKit builds. Do not apply this backend
  # change to an existing containerd store: it would hide its containers.
  virtualisation.docker = lib.mkIf config.virtualisation.docker.enable {
    storageDriver = "overlay2";
    daemon.settings = {
      features.containerd-snapshotter = false;
      builder.gc = {
        enabled = true;
        defaultKeepStorage = "20GB";
      };
      log-driver = "local";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

  # Only build cache: keep images (including unused DDEV base images),
  # containers, networks and database volumes. Never delete raw leases.
  systemd.services.docker-build-cache-gc = lib.mkIf config.virtualisation.docker.enable {
    description = "Prune Docker build cache unused for a week";
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.docker}/bin/docker builder prune --force --filter until=168h --keep-storage 20GB";
      TimeoutStartSec = "30min";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    startAt = "weekly";
  };
  systemd.timers.docker-build-cache-gc = lib.mkIf config.virtualisation.docker.enable {
    timerConfig = {
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };
}
