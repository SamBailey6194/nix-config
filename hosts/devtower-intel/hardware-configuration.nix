# Hardware Configuration for devtower-intel (i9-9900K + RTX 2080 Ti)
#
# Layout mirrors devtower-os so the full stage's LUKS, btrfs-layouts and
# snapper modules get exercised:
#   LUKS2 -> btrfs @root, @nix, @snapshots, @log
#   plus @home (no separate home SSD here) and @docker (keeps Docker layers
#   out of the pre-rebuild snapshots of /)
#
# UUIDs live in ./disks.nix. Ubuntu's /home and the archive HDD are mounted
# nofail. Never mount Ubuntu's swap: zram replaces it.

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

  fileSystems."/" = sub "@root";
  fileSystems."/nix" = sub "@nix";
  fileSystems."/.snapshots" = sub "@snapshots";
  fileSystems."/var/log" = sub "@log";
  fileSystems."/home" = sub "@home"; # real devtower: separate SSD
  fileSystems."/var/lib/docker" = sub "@docker";

  # EFI System Partition (dedicated to NixOS; Ubuntu's and Windows' ESPs are untouched)
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/${disks.espUuid}";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Existing Ubuntu-side data. Always shut down fully (no hibernate) before
  # switching OS: both systems mount these read-write.
  fileSystems."/mnt/archive" = {
    device = "/dev/disk/by-uuid/${disks.archiveUuid}";
    fsType = "ext4";
    options = [ "nofail" "noatime" ];
  };

  fileSystems."/mnt/ubuntu-home" = {
    device = "/dev/disk/by-uuid/${disks.ubuntuHomeUuid}";
    fsType = "ext4";
    options = [ "nofail" "noatime" ];
  };

  # Keep the old store and Docker data intact for recovery. The new /nix and
  # Docker directories live inside the encrypted NixOS root, not on these
  # plaintext partitions. Do not start a second daemon against old Docker data.
  fileSystems."/mnt/ubuntu-nix" = {
    device = "/dev/disk/by-uuid/${disks.ubuntuNixUuid}";
    fsType = "ext4";
    options = [ "ro" "nofail" "noatime" ];
  };
  fileSystems."/mnt/ubuntu-docker" = {
    device = "/dev/disk/by-uuid/${disks.ubuntuDockerUuid}";
    fsType = "ext4";
    options = [ "ro" "nofail" "noatime" ];
  };

  # Shared media/project files: retain NTFS so Windows can access this drive.
  # Never force a mount of a hibernated/dirty Windows volume.
  fileSystems."/mnt/davinci" = {
    device = "/dev/disk/by-uuid/${disks.davinciUuid}";
    fsType = "ntfs-3g";
    options = [ "nofail" "noatime" "uid=1000" "gid=100" "fmask=0133" "dmask=0022" "windows_names" "x-systemd.automount" "x-systemd.device-timeout=10s" ];
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
