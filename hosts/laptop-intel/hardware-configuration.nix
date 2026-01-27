# Hardware Configuration Template for Intel i5-10210U Laptop
#
# IMPORTANT: This is a TEMPLATE. During NixOS installation, run:
#   nixos-generate-config --root /mnt
#
# Then REPLACE this file with the generated /mnt/etc/nixos/hardware-configuration.nix
#
# This template is provided so the flake can build, but it won't work until replaced
# with your actual hardware configuration.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # CPU - Intel i5-10210U (Comet Lake)
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Blacklist problematic SD Card
  boot.blacklistedKernelModules = [ "rtsx_pci" "rtsx_pci_sdmmc" ];

  # File Systems - TEMPLATE (REPLACE DURING INSTALLATION)
  # These are placeholder UUIDs and must be replaced with real ones
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # Swap - TEMPLATE (REPLACE DURING INSTALLATION)
  swapDevices = [
    { device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID"; }
  ];

  # Hardware Configuration
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  networking.useDHCP = lib.mkDefault true;
}
