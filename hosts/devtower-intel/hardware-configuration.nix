# Hardware Configuration for devtower-intel (i9-9900K + RTX 2080 Ti)
#
# Layout mirrors devtower-os so the full stage's LUKS, btrfs-layouts and
# snapper modules get exercised:
#   LUKS2 -> btrfs @root, @nix, @snapshots, @log
#   plus @home and @docker (keeps Docker layers out of the pre-rebuild
#   snapshots of /) until those move to their own encrypted drives
#
# UUIDs live in ./disks.nix. The Linux data drives (old Ubuntu home, store and
# Docker, archive) are handled by ./data-drives.nix, which keeps their old
# filesystems mounted until each is converted to its own LUKS2 container.
# Never mount Ubuntu's swap: zram replaces it.

{ config, lib, modulesPath, ... }:

let
  disks = import ./disks.nix;
  btrfsDev = "/dev/disk/by-uuid/${disks.btrfsUuid}";
  sub = name: {
    device = btrfsDev;
    fsType = "btrfs";
    options = [ "subvol=${name}" "compress=zstd:1" "noatime" ];
  };
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./data-drives.nix
  ];

  # CPU - Intel Core i9-9900K (Desktop)
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # LUKS encrypted root
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-uuid/${disks.luksUuid}";
    allowDiscards = true;
  };

  # /home, /nix and /var/lib/docker move to their own encrypted drives once
  # converted (data-drives.nix overrides these three).
  fileSystems."/" = sub "@root";
  fileSystems."/nix" = sub "@nix";
  fileSystems."/.snapshots" = sub "@snapshots";
  fileSystems."/var/log" = sub "@log";
  fileSystems."/home" = sub "@home";
  fileSystems."/var/lib/docker" = sub "@docker";

  # EFI System Partition (dedicated to NixOS; Ubuntu's and Windows' ESPs are untouched)
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/${disks.espUuid}";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Shared media/project files (DaVinci and Affinity): retain NTFS so Windows
  # can access this drive. Never force a mount of a hibernated/dirty volume.
  #
  # norecover: with the default `recover`, ntfs-3g clears an unclean journal and
  # mounts read-write; norecover makes it fall back to a read-only mount instead
  # (boot Windows, let it check the disk, shut down fully). Hibernated / Fast
  # Startup volumes already fall back to read-only.
  # Mounted at boot rather than x-systemd.automount: Affinity's Wine sandbox
  # (own mount namespace) and Wine's drive-letter scan need it mounted already.
  # nofail + the device timeout keep a missing drive from blocking boot.
  fileSystems."/mnt/davinci" = {
    device = "/dev/disk/by-uuid/${disks.davinciUuid}";
    fsType = "ntfs-3g";
    options = [ "nofail" "noatime" "norecover" "uid=1000" "gid=100" "fmask=0133" "dmask=0022" "windows_names" "x-systemd.device-timeout=10s" ];
  };

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/${disks.backupUuid}";
    fsType = "ext4";
    options = [ "nofail" "noatime" "x-systemd.automount" "x-systemd.device-timeout=10s" ];
  };

  # No swap partition (zram replaces it)
  swapDevices = [ ];

  # Hardware Configuration
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  networking.useDHCP = lib.mkDefault true;
}
