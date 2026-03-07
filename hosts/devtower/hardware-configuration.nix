# Hardware Configuration Template for DevTower AMD Desktop
#
# Multi-drive setup:
#   Drive 1 (NVMe): LUKS → BTRFS OS drive (@root, @nix, @snapshots, @log — no @home)
#   Drive 2 (SSD):  BTRFS home drive (@home)
#   Drive 3 (HDD):  ZFS media pool (runtime-configured via zfs-manage, not declared here)
#
# IMPORTANT: This is a TEMPLATE. During NixOS installation:
#   1. NVMe: Partition (EFI + LUKS), open LUKS, create BTRFS with subvolumes
#   2. SSD: Create BTRFS with @home subvolume
#   3. HDD: Leave unpartitioned (ZFS pool created at runtime via zfs-manage)
#   4. REPLACE all placeholder UUIDs below with actual values
#
# Get UUIDs with: blkid /dev/nvme0n1p2 (LUKS), blkid /dev/mapper/cryptroot (BTRFS OS),
#                 blkid /dev/sdX1 (BTRFS home SSD)

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # CPU - AMD Ryzen (Desktop)
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # LUKS encrypted root (NVMe OS drive)
  # REPLACE: Run `blkid /dev/nvme0n1p2` after partitioning
  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/REPLACE-WITH-LUKS-PARTITION-UUID";

  # ========================================================================
  # NVMe OS Drive — BTRFS subvolumes (LUKS-decrypted, no @home)
  # REPLACE: Run `blkid /dev/mapper/cryptroot` after formatting
  # ========================================================================
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-OS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@root" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-OS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@nix" ];
  };

  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-OS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@snapshots" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-OS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@log" ];
  };

  # ========================================================================
  # SSD Home Drive — BTRFS @home on separate physical drive
  # REPLACE: Run `blkid /dev/sdX1` (or /dev/nvme1n1p1) for the home SSD
  # ========================================================================
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-HOME-SSD-UUID";
    fsType = "btrfs";
    options = [ "subvol=@home" ];
  };

  # ========================================================================
  # HDD Media Drive — ZFS pool (runtime-configured, NOT declared here)
  # Create pool after installation: zfs-manage create-pool media /dev/sdX
  # ========================================================================

  # EFI System Partition
  # REPLACE: Run `blkid /dev/nvme0n1p1` after partitioning
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-EFI-UUID";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # No swap partition (zram replaces it)
  swapDevices = [ ];

  # Hardware Configuration
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # DevTower-specific: 64GB RAM, AMD GPU, Go XLR
  # This will be auto-detected, but noting it here for reference
}
