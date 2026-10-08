# Single source of truth for devtower-intel UUIDs, shared by
# hardware-configuration.nix and full.nix (both define the LUKS device, and
# the two strings must match).
#
# REPLACE after partitioning:
#   blkid -s UUID -o value <ESP partition> <LUKS partition> /dev/mapper/cryptroot
{
  espUuid = "REPLACE-WITH-ESP-UUID";
  luksUuid = "REPLACE-WITH-LUKS-PARTITION-UUID";
  btrfsUuid = "REPLACE-WITH-CRYPTROOT-BTRFS-UUID";

  # Existing Ubuntu-side filesystems, mounted nofail until their drive is
  # converted (dataDrives below; data-drives.nix)
  archiveUuid = "9f544f15-8e9a-45de-9951-d84f51b62e57"; # sdd1 ext4 (/mnt/archive)
  ubuntuHomeUuid = "8eaacce9-a3bd-4e95-924c-feb9e2d050b4"; # sde1 ext4 (Ubuntu /home)

  # Linux data drives, each wiped into its own LUKS2 container after
  # installation (docs/BACKUP-AND-DATA-ENCRYPTION.md#encrypt-one-drive-at-a-time).
  # Leave both null until that drive has been converted and restored; then
  #   luksUuid = blkid -s UUID -o value <the drive's new LUKS partition>
  #   fsUuid   = blkid -s UUID -o value /dev/mapper/<crypthome|cryptstore|cryptarchive>
  dataDrives = {
    home = { luksUuid = null; fsUuid = null; }; # Samsung 512GB S1X1NYAG302936
    store = { luksUuid = null; fsUuid = null; }; # Samsung 870 EVO 2TB S6PPNX0T910090T
    archive = { luksUuid = null; fsUuid = null; }; # Seagate ST4000DM004 ZFN2J51Q
  };

  davinciUuid = "34201009200FD0B2"; # DavinciProj shared with Windows (NTFS)
  backupUuid = "883736aa-556a-4e5e-b42f-e58bd40f5668"; # Backup+ Hub BK, NA9R0S9H

  # Observed Ubuntu inventory, 2026-10-05. These are NOT replacements for
  # the new LUKS/btrfs UUIDs above: encryption/reformatting creates new UUIDs.
  ubuntuRootUuid = "e9605dca-3609-4cd7-be0b-cfac0661111e";
  ubuntuEspUuid = "27BE-92E7";
  ubuntuSwapUuid = "6b9a7bb1-febe-475f-9c98-5dfda3e97d4d";
  ubuntuNixUuid = "af95812e-4174-4c02-94fd-a142a7981165"; # Samsung 870 EVO /nix
  ubuntuDockerUuid = "0bb16801-79b4-435d-b8f6-646e3e12b38c"; # Samsung 870 EVO Docker
}
