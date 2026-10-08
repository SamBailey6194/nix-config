# Linux data drives: the old Ubuntu filesystems until each one is converted,
# then that drive's own LUKS2 container (own passphrase, plus a TPM2 token so it
# unlocks automatically). Converted one at a time after installation:
# docs/BACKUP-AND-DATA-ENCRYPTION.md#encrypt-one-drive-at-a-time.
#
# A drive switches over when both of its UUIDs in ./disks.nix (dataDrives) are
# filled in. Until then nothing here changes for it.
#
#   home    Samsung 512GB   -> /home (replaces the Intel @home subvolume)
#   store   Samsung 870 EVO -> /nix and /var/lib/docker (replaces Intel @nix, @docker)
#   archive Seagate 4TB     -> /mnt/archive
#
# home and store unlock in the initrd like cryptroot, because the system needs
# them to boot; without a TPM2 token (or if the TPM refuses) the initrd asks for
# that drive's passphrase. The archive unlocks after boot from /etc/crypttab with
# nofail, so a missing or failing HDD never holds up boot. Its passphrase prompt
# can't be seen once the login screen is up, so if its TPM2 token fails, unlock
# it from a terminal (`sudo systemd-tty-ask-password-agent --query`); the
# automount then picks it up on the next access to /mnt/archive.
# TPM2 tokens are enrolled per drive with systemd-cryptenroll --tpm2-pcrs=7.

{ lib, ... }:

let
  disks = import ./disks.nix;
  drives = disks.dataDrives;
  byUuid = uuid: "/dev/disk/by-uuid/${uuid}";

  converted = name: drives.${name}.luksUuid != null && drives.${name}.fsUuid != null;
  halfFilled = name: (drives.${name}.luksUuid == null) != (drives.${name}.fsUuid == null);

  subvol = name: sv: extra: {
    device = byUuid drives.${name}.fsUuid;
    fsType = "btrfs";
    options = [ "subvol=${sv}" "compress=zstd:1" "noatime" ] ++ extra;
  };

  initrdLuks = name: {
    device = byUuid drives.${name}.luksUuid;
    allowDiscards = true;
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };
in
{
  config = lib.mkMerge [
    {
      assertions = map (name: {
        assertion = !(halfFilled name);
        message = "devtower-intel: disks.nix dataDrives.${name} needs both luksUuid and fsUuid (or neither).";
      }) (builtins.attrNames drives);
    }

    # ── home: Samsung 512GB ──────────────────────────────────────────────
    (lib.mkIf (!converted "home") {
      fileSystems."/mnt/ubuntu-home" = {
        device = byUuid disks.ubuntuHomeUuid;
        fsType = "ext4";
        options = [ "nofail" "noatime" ];
      };
    })
    (lib.mkIf (converted "home") {
      boot.initrd.luks.devices.crypthome = initrdLuks "home";
      fileSystems."/home" = lib.mkForce (subvol "home" "@home" [ ]);
      # A separate filesystem now, so scrub it in its own right.
      services.btrfs.autoScrub.fileSystems = [ "/home" ];
    })

    # ── store: Samsung 870 EVO 2TB ───────────────────────────────────────
    # Keep the old store and Docker data intact for recovery until this drive
    # is converted. Do not start a second daemon against old Docker data.
    (lib.mkIf (!converted "store") {
      fileSystems."/mnt/ubuntu-nix" = {
        device = byUuid disks.ubuntuNixUuid;
        fsType = "ext4";
        options = [ "ro" "nofail" "noatime" ];
      };
      fileSystems."/mnt/ubuntu-docker" = {
        device = byUuid disks.ubuntuDockerUuid;
        fsType = "ext4";
        options = [ "ro" "nofail" "noatime" ];
      };
    })
    (lib.mkIf (converted "store") {
      boot.initrd.luks.devices.cryptstore = initrdLuks "store";
      fileSystems."/nix" = lib.mkForce (subvol "store" "@nix" [ ]);
      fileSystems."/var/lib/docker" = lib.mkForce (subvol "store" "@docker" [ ]);
      services.btrfs.autoScrub.fileSystems = [ "/nix" ];
    })

    # ── archive: Seagate ST4000DM004 4TB ─────────────────────────────────
    (lib.mkIf (!converted "archive") {
      fileSystems."/mnt/archive" = {
        device = byUuid disks.archiveUuid;
        fsType = "ext4";
        options = [ "nofail" "noatime" ];
      };
    })
    (lib.mkIf (converted "archive") {
      environment.etc.crypttab.text = ''
        cryptarchive UUID=${drives.archive.luksUuid} - tpm2-device=auto,nofail,x-systemd.device-timeout=10s
      '';
      # automount: mounted on first access whenever the device is unlocked, so a
      # late (passphrase) unlock still works; a plain nofail mount would give up
      # after its device timeout and not retry.
      fileSystems."/mnt/archive" = subvol "archive" "@archive" [
        "nofail"
        "x-systemd.automount"
        "x-systemd.device-timeout=10s"
      ];
      # Scrubbing is what catches silent corruption on a long-term archive.
      # If the drive is absent that month's scrub unit fails visibly.
      services.btrfs.autoScrub.fileSystems = [ "/mnt/archive" ];
    })
  ];
}
