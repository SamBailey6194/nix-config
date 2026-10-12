{ lib, ... }:

let
  disks = import ./disks.nix;
in
{
  imports = [ ./secrets.nix ];

  # Full stage only: configuration-full.nix hard-codes REPLACE-* placeholders
  # for the LUKS device and btrfs root at normal priority, so override them
  security.luksEncryption.devices.cryptroot.device = lib.mkForce "/dev/disk/by-uuid/${disks.luksUuid}";
  filesystem.btrfsLayouts.rootDevice = lib.mkForce "/dev/disk/by-uuid/${disks.btrfsUuid}";

  # OpenRGB probes the SMBus (DIMM SPD EEPROMs live there) and tells us nothing
  # about the AMD board, so keep the service off on this PC. The package is
  # still installed for manual use.
  services.hardware.openrgb.enable = lib.mkForce false;

  # The full stage adds tpm2-device=auto to cryptroot. PCR 7 does not cover
  # the kernel command line, so an editable boot entry (init=/bin/sh) would
  # give a root shell on a TPM-unlocked disk. Lock it before enrolling.
  boot.loader.systemd-boot.editor = false;
}
