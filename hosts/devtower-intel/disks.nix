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

  # Existing Ubuntu-side filesystems, mounted nofail
  archiveUuid = "9f544f15-8e9a-45de-9951-d84f51b62e57"; # sdd1 ext4 (/mnt/archive)
  ubuntuHomeUuid = "8eaacce9-a3bd-4e95-924c-feb9e2d050b4"; # sde1 ext4 (Ubuntu /home)
}
