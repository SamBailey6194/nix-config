{ lib, ... }:

let
  disks = import ./disks.nix;
  placeholders = lib.filterAttrs (_: v: lib.isString v && lib.hasPrefix "REPLACE-" v) disks;
in
{
  # DEVTOWER-INTEL: stand-in for devtower on the current Ubuntu/Windows PC
  # (i9-9900K + RTX 2080 Ti + 32GB + GoXLR Mini) until the AMD tower arrives.
  #
  # Layered on top of any hosts/devtower/configuration-<stage>.nix (see
  # mkDevtowerIntel in flake.nix). Everything except the hardware is the real
  # devtower config, so what works here carries over.

  # The devtower stage files import these two AMD files directly; drop them here
  disabledModules = [
    ../devtower/hardware-configuration.nix
    ../../modules/hardware/amd-desktop.nix
  ];

  imports = [
    ./hardware-configuration.nix
    ./connectivity.nix
    ./disk-prevention.nix
    ../../modules/hardware/intel-nvidia-desktop.nix
    ../../modules/filesystem/zram.nix # deduplicated with the full stage's own import
  ];

  # Own identity: SSH key and secret names become *-devtower-intel, never the
  # real devtower's (per-device secrets model)
  networking.hostName = lib.mkForce "devtower-intel";

  # Use the existing zram policy for every stage on this machine.
  filesystem.zram.enable = true;

  # Reserve room on the 32GB PC for the existing 16GB Nix build budget, the
  # desktop and up to 1GB of workload swap. Limits apply to all media jobs
  # together, rather than allowing each concurrent job this much RAM.
  workloads.memoryHigh = "10G";
  workloads.memoryMax = "12G";

  # Same uid as Ubuntu's sam-dev, so /mnt/ubuntu-home and /mnt/archive ownership lines up
  users.users.sam-desktop.uid = 1000;

  # Dual boot from a dedicated ESP: leave NVRAM BootOrder alone (pick NixOS
  # from the firmware boot menu). Each NVIDIA initrd carries ~100MB of GSP
  # firmware, so keep the generation count as low as the full stage does.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 5;

  warnings = lib.optional (placeholders != { })
    "devtower-intel: hosts/devtower-intel/disks.nix still has placeholder UUIDs (${lib.concatStringsSep ", " (lib.attrNames placeholders)}). Do not install until they are filled in.";
}
