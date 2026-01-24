# Hardware Configuration Template for DevTower AMD Desktop
#
# IMPORTANT: This is a TEMPLATE. During NixOS installation, run:
#   nixos-generate-config --root /mnt
#
# Then REPLACE this file with the generated /mnt/etc/nixos/hardware-configuration.nix

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

  # File Systems - TEMPLATE (REPLACE DURING INSTALLATION)
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
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  networking.useDHCP = lib.mkDefault true;

  # DevTower-specific: 64GB RAM, AMD GPU, Go XLR
  # This will be auto-detected, but noting it here for reference
}
