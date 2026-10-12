{ lib, inputs, ... }:

let
  disks = import ./disks.nix;
  self = inputs.self;

  # Build badge on the NixOS boot icon: the commit this generation was built
  # from, "<rev>*" when tracked files were uncommitted, or the build date for
  # path: builds (prepare-nix-source.py copies), which carry no Git revision.
  flakeRev =
    if self ? shortRev then { text = self.shortRev; dirty = false; }
    else if self ? dirtyShortRev then { text = lib.removeSuffix "-dirty" self.dirtyShortRev; dirty = true; }
    else {
      text = let d = self.lastModifiedDate or "00000000"; in
        "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";
      dirty = false;
    };
in
{
  imports = [
    ./secrets.nix
    ../../modules/boot/refind
  ];

  # Themed rEFInd menu (modules/boot/refind) in place of systemd-boot: one
  # NixOS icon (older generations in its F2/Insert submenu) and Windows from
  # its own ESP on the Crucial P3 (nvme0n1p1, FAT 8C32-B143). Firmware still
  # boots EFI/BOOT/BOOTX64.EFI on the Intel disk, which rEFInd now occupies.
  bootloader.refind = {
    enable = true;
    maxGenerations = 5;
    inherit flakeRev;
    windows.partUuid = "89590b26-8a8f-4bc2-885f-3ba0241256bb";
  };

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
  # give a root shell on a TPM-unlocked disk. rEFInd hides its options editor
  # (hideui editor); this keeps systemd-boot locked too if rEFInd is turned off.
  boot.loader.systemd-boot.editor = false;
}
