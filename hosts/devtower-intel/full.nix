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
    ./calendar.nix
    ./client-store.nix
    ../../modules/boot/refind
  ];

  # Themed rEFInd menu (modules/boot/refind): one NixOS icon (older
  # generations in its F2/Insert submenu) and Windows from its own ESP on the
  # Crucial P3 (nvme0n1p1, FAT 8C32-B143).
  #
  # On trial as the last systemd-boot entry ("rEFInd", EFI/refind): generation
  # 7, which made rEFInd the firmware's EFI/BOOT/BOOTX64.EFI, left a black
  # screen and needed a rescue USB. systemd-boot stays the default, so a failed
  # rEFInd costs a reboot. Diagnostics for the trial:
  # - logLevel 1: rEFInd writes EFI/refind/refind.log (refind.log-old for the
  #   run before), readable afterwards with sudo
  # - no resolution token: generation 7 had "resolution max", which on the
  #   RTX 2080 Ti and 4K monitor may pick a mode the screen cannot show
  # If the screen goes black again, type the LUKS passphrase blind: rEFInd
  # boots NixOS after its timeout, so a boot means rEFInd worked and only the
  # display failed.
  bootloader.refind = {
    enable = true;
    chainload = true;
    logLevel = 1;
    maxGenerations = 5;
    inherit flakeRev;
    windows.partUuid = "89590b26-8a8f-4bc2-885f-3ba0241256bb";

    # EDK2 UEFI shell in the tools row (EFI/tools/shellx64.efi), for recovery.
    # Accepted trade-off: with Secure Boot off it can start the kernel with
    # init=/bin/sh while PCR 7 still unseals cryptroot - the same exposure as
    # booting a live USB (docs/BACKUP-AND-DATA-ENCRYPTION.md). Revisit when
    # Secure Boot is turned on.
    shell = true;
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
  # (hideui editor; the EFI shell above is the accepted exception); this keeps
  # systemd-boot locked too if rEFInd is turned off.
  boot.loader.systemd-boot.editor = false;
}
