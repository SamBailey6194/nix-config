# Hardware Configuration Template for Framework AMD Laptop
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

  # CPU - AMD Ryzen (Framework 13 AMD)
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
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

  # Framework-specific: 64GB RAM
  # This will be auto-detected, but noting it here for reference
}
