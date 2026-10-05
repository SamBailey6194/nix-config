# Preserving this desktop during migration

Inventory observed on 2026-10-05. Device letters can change: verify model,
serial, size and UUID from a live installer before selecting any target.
No disk has been formatted or installation started by these configuration edits.

| Drive / serial | Current use | Filesystem UUID |
| --- | --- | --- |
| Intel 256GB / PHHH93710CN8256B | Ubuntu root (ext4), ~49GiB used | `e9605dca-3609-4cd7-be0b-cfac0661111e` |
| Same Intel | Ubuntu EFI | `27BE-92E7` |
| Same Intel | Ubuntu swap | `6b9a7bb1-febe-475f-9c98-5dfda3e97d4d` |
| Samsung 512GB / S1X1NYAG302936 | Ubuntu `/home`, ~257GiB used | `8eaacce9-a3bd-4e95-924c-feb9e2d050b4` |
| Samsung 870 EVO 2TB / S6PPNX0T910090T | Ubuntu `/nix`, ~716GiB used | `af95812e-4174-4c02-94fd-a142a7981165` |
| Same Samsung 870 EVO | Docker, ~444GiB used | `0bb16801-79b4-435d-b8f6-646e3e12b38c` |
| Seagate 4TB / ZFN2J51Q | Archive, ~123GiB used | `9f544f15-8e9a-45de-9951-d84f51b62e57` |

The new independent BackupDrive is Backup+ Hub BK, serial `NA9R0S9H`,
ext4 UUID `883736aa-556a-4e5e-b42f-e58bd40f5668`, currently `sdf2` at
`/mnt/backup`, with about 8.6TiB free. Use it for the encrypted Restic backup of
all five Ubuntu data filesystems and EFI files; include the archive as a source.
See [backup and staged data-drive encryption](BACKUP-AND-DATA-ENCRYPTION.md).

Additional drives contain Windows, games and DaVinci data. Preserve them too:
Games_2 `E87AFC317AFBF9E0`, DaVinci `34201009200FD0B2`, Windows
`FAC43471C434326D`, Games_1 `CC64454F64453E08`, Windows EFI `8C32-B143`.
Samsung home has another EFI `244E-5B6F`, archive EFI `2537-6BE7`.

## Today’s safe sequence

1. Choose an installation target explicitly. Replacing the Intel drive removes
   its Ubuntu root, EFI and swap; retaining the other drives does not preserve
   a bootable Ubuntu installation. For dual boot, use another verified target
   or a separately planned resize after backup. There is no empty drive in this
   inventory. The current hardware module is a layout specification, not an
   automatic partitioning script.
2. Back up and verify restoration **before** changing partitions. Preserve
   `/etc`, personal files, Git work including untracked changes, SSH/GPG keys,
   age identity keys, credentials, browser profiles and application configs.
   Export databases and stop Docker before backing up volumes; compose files
   alone do not contain application data. A live/offline backup avoids changing
   files during copying. Use the independent BackupDrive; existing archive data
   is a backup source too. Encrypt backups containing credentials.
3. Test restoration of representative files and databases and record ownership,
   ACLs and extended attributes. Preserve a recovery copy of the Ubuntu root if
   replacing Intel; NixOS generation rollback cannot restore a formatted Ubuntu
   filesystem. Keep a working live USB and encryption recovery material.
4. Verify the target from the installer using `lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,UUID,MOUNTPOINTS`
   and `blkid`. Disconnect non-target drives during partitioning where practical.
   Only then create the intended EFI and LUKS2/btrfs layout, with subvolumes
   `@root`, `@nix`, `@snapshots`, `@log`, `@home`, `@docker`. Reconnect retained
   drives before validating their mounts. Existing Windows/other-drive EFI
   partitions must not be formatted.
5. Put the **new** EFI, LUKS container and inner btrfs UUIDs into
   `hosts/devtower-intel/disks.nix`. Ubuntu root/swap UUIDs are inventory only;
   they cannot identify a new encrypted filesystem. Evaluate and build the
   selected stage before installing. New untracked files require `path:.` or
   adding the files to Git for a Git-backed flake.
6. Start with a small stage if space/build time requires it; the AI tooling and
   Neovim are in dev and above. Confirm boot, LUKS unlocking, NVIDIA, network,
   backups and retained mounts before enabling more workloads. Restore selected
   personal files to the new home and adjust ownership to `sam-desktop` rather
   than blindly copying Ubuntu's user/database files over NixOS settings.

The Intel disk cannot hold all your existing data: Ubuntu home alone is larger
than its entire capacity, before the 716GiB store and 444GiB Docker data. The
new encrypted `/home`, `/nix` and Docker subvolumes start fresh on the chosen
OS filesystem. Retained data stays accessible separately. Download only the
models you use; the seven candidate files alone total roughly 100GiB, and
builds need additional free space. Plan additional encrypted capacity before
moving all home, models or Docker workloads onto encrypted storage.
The Intel Nix configuration starts automatic store garbage collection below
5GiB free and aims for 15GiB, reclaiming only unreferenced store data. It cannot
remove rooted generations or runtime model files. Use the source-copy helper
in the manual guide to avoid archiving multi-gigabyte Rust build directories.

## Keeping the other drives and encryption

Yes, NixOS can mount existing ext4/NTFS filesystems without reformatting them.
The supplied Intel configuration mounts archive at `/mnt/archive`, old home at
`/mnt/ubuntu-home`, and old Nix/Docker data read-only at `/mnt/ubuntu-nix` and
`/mnt/ubuntu-docker`. It does **not** reuse the Ubuntu store or start Docker
against the old data directory. Ubuntu swap is not enabled; zram is used.
Always shut down completely before switching systems, including disabling
Windows fast startup/hibernation before writing its NTFS volumes.

LUKS on the OS drive encrypts only files stored within that encrypted device.
Plaintext home, archive, Docker partitions and backups remain readable if their
drives are removed. Mounting them from encrypted NixOS does not encrypt them.
For full coverage, back up a data drive, create an encrypted replacement,
restore and verify it, then repeat one drive at a time. Root needs new UUIDs
after this operation, and each data device needs its own unlock/mount plan.
In-place conversion is a separate risky operation, unsuitable as a shortcut
to a same-day migration with irreplaceable data.

For now, retain the data drives and protect new credentials in the encrypted
NixOS home. The EFI partition remains unencrypted; verified boot is a separate
concern from data-at-rest encryption. Filesystem snapshots share a failure
domain with their disk and do not replace an independent backup.

See the [NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation)
and [cryptsetup documentation](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home)
for installation and LUKS recovery procedures.
