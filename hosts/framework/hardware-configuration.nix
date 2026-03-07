# Hardware Configuration Template for Framework AMD Laptop
#
# BTRFS on LUKS with subvolumes: @root, @home, @nix, @snapshots, @log
#
# IMPORTANT: This is a TEMPLATE. During NixOS installation:
#   1. Partition disk (EFI + LUKS)
#   2. Open LUKS: cryptsetup luksFormat /dev/nvme0n1p2 && cryptsetup open /dev/nvme0n1p2 cryptroot
#   3. Create BTRFS: mkfs.btrfs /dev/mapper/cryptroot
#   4. Create subvolumes: @root, @home, @nix, @snapshots, @log
#   5. Mount and install, then REPLACE the UUIDs below with actual values
#
# Get UUIDs with: blkid /dev/nvme0n1p2 (LUKS) and blkid /dev/mapper/cryptroot (BTRFS)

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # CPU - AMD Ryzen (Framework 13 AMD)
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # LUKS encrypted root
  # REPLACE: Run `blkid /dev/nvme0n1p2` after partitioning
  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/REPLACE-WITH-LUKS-PARTITION-UUID";

  # BTRFS subvolumes (all on the same LUKS-decrypted filesystem)
  # REPLACE: Run `blkid /dev/mapper/cryptroot` after formatting
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@root" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@home" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@nix" ];
  };

  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@snapshots" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-FILESYSTEM-UUID";
    fsType = "btrfs";
    options = [ "subvol=@log" ];
  };

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

  # Framework-specific: 64GB RAM
  # This will be auto-detected, but noting it here for reference
}
