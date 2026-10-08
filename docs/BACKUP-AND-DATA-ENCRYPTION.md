# Independent Ubuntu backup and staged drive encryption

## Backup destination identified on 5 October 2026

| Item | Observed value |
| --- | --- |
| USB drive | Seagate Backup+ Hub BK, serial `NA9R0S9H`, 10TB (9.1TiB) |
| Backup filesystem | second partition (was `sdf2`), ext4, label `BackupDrive` |
| Filesystem UUID | `883736aa-556a-4e5e-b42f-e58bd40f5668` |
| Ubuntu mount | `/mnt/backup` |
| Available space | ~8.6TiB before the backup; ~8.1TiB estimated after it |
| Other partition | first partition (was `sdf1`), 128MiB, no mounted filesystem shown |

Device letters are temporary. Mount by UUID and recheck model/serial in the live
installer. Neither partition needs formatting to make a backup.
The Intel NixOS configuration also mounts this filesystem at `/mnt/backup`,
on demand and without preventing boot if the USB drive is disconnected.

The backup was taken on 2026-10-07 as the unencrypted rsync copy
`pre-nixos-2026-10-05/` (about 530GB, ~495GiB, after the /nix and Docker
clean-up). No
Restic repository was created, so the Restic criteria below apply only if you
make one later. For the rsync copy, the equivalent checks are the offline
`rsync --checksum --dry-run` comparison and restore tests in
[LIVE-BACKUP-SCRIPT.md](LIVE-BACKUP-SCRIPT.md#encryption-and-verification).
The Windows, games and DaVinci
NTFS drives are outside that five-filesystem total and remain unchanged; their
contents are not included automatically. If you intend to erase/encrypt any of
those too, back them up and verify them separately first.

## What counts as ready to erase a source

Use the [manual installation guide](INSTALL-INTEL-MANUALLY.md), which now backs
up all five Ubuntu data filesystems and their three EFI filesystems to an
**encrypted Restic repository on BackupDrive**. Shut Ubuntu down cleanly and
back up offline. Stop containers and export databases before shutdown.
Preserve VPN/accountability secrets using the export helper first.

Record disk UUIDs, models, serials and partition layouts outside the target. A
filesystem backup does not preserve partition tables or automatically recreate
a bootable Ubuntu installation. Keep the install USB working.
For each whole disk that will be changed, use its confirmed by-id path when
saving the partition table with `sfdisk --dump`; never guess a changing letter.
Save those records in the encrypted repository as a separate metadata snapshot.

Proceed only after:

1. The backup command succeeds with exit status zero, without unreadable or
   changing-source errors. `restic snapshots --tag before-nixos` shows all eight
   source mounts; record that snapshot ID independently of the PC.
2. `restic check --read-data` succeeds, reading every repository data pack.
3. Restored representative files match their originals, including credentials,
   the uncommitted Nix repository, personal documents/media and database dumps.
   Test importing important database dumps into a separate disposable instance.
   Check ownership, ACLs, extended attributes and symlinks where used.
4. You can unlock the repository with a password saved independently, without
   relying on a file that exists only on a disk you are about to erase.

[Restic documents](https://restic.readthedocs.io/en/stable/manual_rest.html)
its metadata handling and full data checks. A check verifies backup integrity;
a restoration test also verifies that you selected the right data and can use it.
One external disk remains a single independent backup copy, so keep the remaining
originals until their restored replacements pass checks. For irreplaceable files,
an additional independent copy is preferable before erasing their last original.

Do not treat `latest` as the permanent Ubuntu backup reference: later header or
metadata backups create newer snapshots. Select the recorded `before-nixos`
snapshot ID when restoring Ubuntu data.

## Encrypt one drive at a time

First install and validate encrypted NixOS on the Intel OS disk, using the
existing manual guide. Keep Samsung home/Nix/Docker and Seagate archive intact
through that first boot. Then convert only one data drive at a time. Disconnect
BackupDrive physically during partitioning; reconnect it for restoration.

For each data partition, the sequence is:

1. Verify its confirmed disk serial, partition and matching backup snapshot.
2. Unmount it and stop every service using it. Work from the live installer for
   home, Nix and Docker drives. Do not reformat a mounted store or running Docker
   directory.
3. Create the intended LUKS2 container and a filesystem inside it. This erases
   the old filesystem. Record both the new outer LUKS UUID and inner filesystem
   UUID. Do not apply the Intel root partitioning commands to a data drive.
4. Restore the corresponding source from the recorded snapshot into the new
   encrypted filesystem, using `restic restore --verify`. Restic normally
   recreates source paths beneath the target: account for that nesting rather
   than assuming files appear directly at the mount root.
5. Check restored files and database imports before changing live mounts.
   Save a LUKS header backup inside the encrypted Restic repository, and keep
   recoverable passphrases. Update that header backup after key-slot changes.
6. Update NixOS's unlock and mount declarations with the new UUIDs. Keep the
   backup and other original drives until boot/unlock/application checks pass.

Planned destinations should retain the drives' capacities and purposes:

| Drive | Intended encrypted data | Migration constraint |
| --- | --- | --- |
| Intel 256GB | NixOS root/initial subvolumes | Too small for all old home/store/Docker data |
| Samsung 512GB | Home/user files | Restore personal data and profiles; reconcile generated configs |
| Samsung 870 EVO 2TB | Nix and Docker partitions | Never blindly reuse the Ubuntu store database or start Docker against unvalidated old data |
| Seagate 4TB | Archive | Preserve every archive file and check representative restores |

The current NixOS mount configuration still describes the initial safe state:
root encrypted, other existing data filesystems retained. **It does not yet
encrypt those data drives.** Their unlock/mount declarations must be changed
as each conversion is actually performed and its new UUIDs become known.
No additional data-drive formatting commands have been generated or executed.

A LUKS header is not a backup of the data. Mounting an unencrypted drive from
NixOS does not encrypt it. Restic encrypts the backed-up file contents inside
its repository, so the external filesystem can remain ext4; do not format
BackupDrive after storing the only backup there. Plaintext exports or restored
files placed alongside the repository would not receive Restic's protection.
