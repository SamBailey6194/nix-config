# Single source of truth for devtower-intel UUIDs, shared by
# hardware-configuration.nix and full.nix (both define the LUKS device, and
# the two strings must match).
#
# REPLACE after partitioning:
#   blkid -s UUID -o value <ESP partition> <LUKS partition> /dev/mapper/cryptroot
{
  espUuid = "12CE-A600";
  luksUuid = "3f44cce0-d46f-49ff-bbdf-306ef8a4e7c8";
  btrfsUuid = "2d379673-11ff-433c-b378-efece05dadf0";

  # Existing Ubuntu-side filesystems, mounted nofail until their drive is
  # converted (dataDrives below; data-drives.nix; the Seagate's: dataPair.mirror)
  archiveUuid = "9f544f15-8e9a-45de-9951-d84f51b62e57"; # Seagate 4TB ext4 (/mnt/archive)
  ubuntuHomeUuid = "8eaacce9-a3bd-4e95-924c-feb9e2d050b4"; # Samsung 512GB ext4 (Ubuntu /home)

  # Linux data drives, each wiped into its own LUKS2 container after
  # installation (docs/BACKUP-AND-DATA-ENCRYPTION.md#encrypt-one-drive-at-a-time).
  # Leave both null until that drive has been converted and restored; then
  #   luksUuid = blkid -s UUID -o value <the drive's new LUKS partition>
  #   fsUuid   = blkid -s UUID -o value /dev/mapper/<crypthome|cryptstore|cryptarchive>
  dataDrives = {
    home = { luksUuid = "4ce3ec83-3913-41ab-96e1-ea2405157802"; fsUuid = "fef98229-e0df-444b-8143-9e3152ee8834"; }; # Samsung 512GB S1X1NYAG302936
    store = { luksUuid = "0002f65b-071e-4668-8c03-5aa420f27ff1"; fsUuid = "e5af6c1f-aa78-4880-ac5f-b596deaeb77a"; }; # Samsung 870 EVO 2TB S6PPNX0T910090T
    # Superseded: the Seagate becomes a VeraCrypt mirror (docs/SHARED-DATA-DRIVES.md).
    archive = { luksUuid = null; fsUuid = null; }; # Seagate ST4000DM004 ZFN2J51Q
  };

  # btrfs simple-quota caps on the store's subvolumes (1,863GiB usable; about
  # 60GiB left for metadata and SSD headroom). Applied at every boot by
  # data-drives.nix once dataDrives.store is filled in, so changing a cap is a
  # single number here and a rebuild.
  storeQuotas = {
    docker = "950G"; # @docker  -> /var/lib/docker
    vm = "450G"; # @vm      -> /var/lib/libvirt/images
    clients = "400G"; # @clients -> /srv/clients
  };

  # The two 4TB hard drives, each a VeraCrypt volume with NTFS inside, shared
  # with Windows (docs/SHARED-DATA-DRIVES.md; data-pair.nix). Leave partUuid
  # null until that drive's VeraCrypt volume exists and its passphrase file is
  # in place; then
  #   partUuid = blkid -s PARTUUID -o value /dev/disk/by-id/<byId>-part1
  # VeraCrypt has no LUKS UUID and the NTFS UUID is hidden inside the volume,
  # so the GPT partition UUID is what identifies it. The WD keeps its existing
  # partition (VeraCrypt formats inside it), the Seagate gets a new one.
  # byId is the whole drive (/dev/disk/by-id), for smartd and the commands above.
  dataPair = {
    data = { partUuid = "dca3a85f-a2b7-4ece-bf07-d2f43c7da4e9"; byId = "ata-WDC_WD40EZRZ-00GXCB0_WD-WCC7K0FU5LY2"; }; # WD Blue 4TB, cryptdata -> /mnt/data
    mirror = { partUuid = "b0ca0856-b219-4240-8216-d1bf103ea6a3"; byId = "ata-ST4000DM004-2CV104_ZFN2J51Q"; }; # Seagate 4TB, cryptmirror -> /mnt/data-mirror
  };

  # Retired with the conversion above: /mnt/davinci goes when dataPair.data is
  # filled in, archiveUuid's /mnt/archive when dataPair.mirror is.
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
