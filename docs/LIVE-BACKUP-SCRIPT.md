# Using the prepared Ubuntu backup script

The existing `/home/sam-dev/backup-before-nixos.sh` was reviewed read-only.
It targets `/mnt/backup/pre-nixos-2026-10-05` and checks filesystem UUIDs.
It copies Ubuntu root, home, archive, Nix, Docker and Ubuntu EFI with
`rsync -aHAXSx --numeric-ids`, separately images home/archive EFI, and saves
partition tables/UUIDs. It avoids recursively backing up its own destination.
Its exit trap restarts the services/containers that were previously active.

## Before running it

Finish and save edits, close browser/IDE sessions and stop database writers.
(The development databases are recreated from scratch on NixOS, so no dumps
are needed.) Preserve the running
admin VPN and accountability credentials first:

```sh
cd /home/sam-dev/Repos/personal/nix-config
sudo python3 scripts/export-ubuntu-migration-secrets.py
```

If the export fails, resolve it while Ubuntu's VPN is still available. The backup
script's root copy then includes `/etc/nixos-migration` automatically.
Do not print or commit those credential files.

**Run record.** The export ran on 2026-10-05 at 15:09. The backup ran as unit
`pre-nixos-backup` from 2026-10-07 07:13 to 11:51 and ended with `COPY FINISHED`.
There were no vanished-file, `INCOMPLETE` or `LIVE-DATA CAVEATS` lines. It
copied root 45.9G, archive 122.5G, home 334.4G, Nix 17.0G, Docker 9.4G and the
Ubuntu EFI, plus images of the other two Ubuntu ESPs.

On 2026-10-09 the same script refreshed that copy in place. It was run directly
as `sudo bash ~/backup-before-nixos.sh --pause-services` in a terminal, from
10:37 to 11:41, and again ended with `COPY FINISHED` and none of those lines.
The Zen browser was closed before the `/home` copy began. `rsync` found nothing
to transfer for the archive or the Ubuntu EFI (a size and modification-time
check, not a checksum); root transferred 4.4G, home 4.5G and Docker 323M.
Nix transferred 101G, because `/nix` had grown back to 118G since the
2026-10-06 clean-up. Both ESP images were re-imaged. The copy now holds root
46.2G, archive 122.5G, home 336.0G, Nix 118.2G and Docker 9.4G. The archive was
copied from 10:39 to 11:23 and home from 11:23 to 11:27, so anything written
after those times is not in it. The offline verification below is still
outstanding.

**Mounting BackupDrive.** Ubuntu has no fstab entry for it. When plugged in,
the desktop automounts it at `/media/sam-dev/BackupDrive`, but the script
refuses to run unless it is mounted at `/mnt/backup`. Mount it there by UUID:

```sh
sudo umount /media/sam-dev/BackupDrive
sudo mount /dev/disk/by-uuid/883736aa-556a-4e5e-b42f-e58bd40f5668 /mnt/backup
```

If the `umount` says "target is busy" (a file-manager window, for example),
run the `mount` anyway: one filesystem at two mount points is harmless, and the
root copy excludes `/media` and `/mnt`. Before unplugging, unmount every mount
point that `findmnt -S UUID=883736aa-556a-4e5e-b42f-e58bd40f5668` lists.

Run your existing command only after the edits and checks are complete:

```sh
sudo systemd-run --unit=pre-nixos-backup --collect \
  /usr/bin/bash /home/sam-dev/backup-before-nixos.sh --pause-services
```

Running the script directly with `sudo bash`, as on 2026-10-09, works too if
the terminal stays open until it ends.

Monitor `backup.log` and `STATUS.txt` at the destination. `backup.log` is
appended on each run and holds `rsync` progress lines (about 955MB after the two
runs), so grep it for the summary lines rather than opening it whole:

```sh
grep -aE '^(Backup started|Copying |Number of files|Total file size|Total transferred file size|COPY FINISHED)' \
  /mnt/backup/pre-nixos-2026-10-05/backup.log
```

The script can take hours; do not shut down the machine or disconnect
BackupDrive during copying. `--pause-services` stops Docker, but Ubuntu's Nix
is a single-user install with no daemon, so nothing stops Nix: do not run `nix`
commands during the copy. A live copy can still contain changing journals or
browser files. Afterwards `docker.service` shows inactive until something next
uses Docker and `docker.socket` starts it again; that is expected.
`COPY FINISHED` explicitly means verification remains to be done.
`INCOMPLETE` or `LIVE-DATA CAVEATS` is not approval to erase a drive.

## Encryption and verification

This script does **not** encrypt its output. Restoring its data onto LUKS does
not retroactively encrypt the external copy. It contains SSH keys, passwords and
other private data: keep the physical backup drive secure. The manual guide's
Restic procedure is an encrypted alternative, and can be used for the final
backup from a cleanly shut-down live installer. Keep originals until restoration
checks pass. The script does not currently back up the separate DavinciProj drive;
see [its backup instructions](DAVINCI-SHARED-DRIVE.md).

For a final offline check of the rsync copy, mount each original filesystem
read-only after a clean shutdown. Compare it with its corresponding directory
using `rsync -aHAXSx --numeric-ids --checksum --dry-run --itemize-changes`, with
the same root exclusions as the backup script. Inspect every reported difference.
These full checksum comparisons may take hours; copying success alone does not
verify restored contents. Correct differences before formatting anything.
Verify the EFI images against their recorded SHA256 hashes and original source
partitions. This preserves files, not a bootable disk image. Databases are
recreated from scratch, so their files are not checked.

**Where to run it.** The comparison needs the originals, which are on the
desktop's internal drives, so run it **on the desktop from the live
installer**. Running Ubuntu is no good, because its files keep changing. The
laptop can see only BackupDrive, so it can browse the copy or check the EFI
image hashes, but it cannot compare.

**Root exclusions (confirmed 2026-10-09).** Lines 128–131 of the backup
script exclude these from the root copy, and the root comparison below uses
the same ones:

```text
/dev  /proc  /sys  /run  /tmp  /mnt  /media
/home  /nix  /var/lib/docker  /boot/efi
```

Each is passed as `--exclude='/path/***'`, which skips the directory itself
and everything in it. `/home`, `/nix`, Docker and `/boot/efi` were copied
separately, and `/mnt` held BackupDrive and the archive. A leading `/` anchors
the pattern to the top of the transfer, not to the live system's root, so
`/media/***` skips `/media/ubuntu-root/media` and leaves the installer's own
`/media` alone.

**In the live installer**, mount the sources as in section 2 of the
[manual guide](INSTALL-INTEL-MANUALLY.md), with BackupDrive `ro,noload`. To
recheck the root exclusions against the script:

```sh
grep -n -- '--exclude' /media/ubuntu-home/sam-dev/backup-before-nixos.sh
```

Check the `.env` files first; no output means they all match:

```sh
copy=/media/backup/pre-nixos-2026-10-05
cd /media/ubuntu-home
find . -name '.env*' -type f -print0 \
  | rsync -a --from0 --files-from=- --checksum --dry-run --itemize-changes ./ "$copy/filesystems/home/"
```

Then run the full comparisons. Home and archive should list nothing apart from
files you know changed after the 2026-10-09 refresh. On root, only `/etc`
matters; ignore database files. Root also lists a `.d..t......` line for each
`snap/<name>/<rev>/` directory: these were snap mount points, which `-x`
copied with the mounted snap's attributes. The Ubuntu EFI, which also holds
`EFI/Microsoft_backup`, is compared by content only. Ubuntu keeps the hardware
clock in local time, so its FAT timestamps read an hour out in the installer,
and `-a` would list every file. `/nix` and Docker are skipped because NixOS
starts both fresh:

```sh
rsync -aHAXSx --numeric-ids --checksum --dry-run --itemize-changes /media/ubuntu-home/ "$copy/filesystems/home/"
rsync -aHAXSx --numeric-ids --checksum --dry-run --itemize-changes /media/archive/ "$copy/filesystems/archive/"
rsync -aHAXSx --numeric-ids --checksum --dry-run --itemize-changes \
  --exclude='/dev/***' --exclude='/proc/***' --exclude='/sys/***' \
  --exclude='/run/***' --exclude='/tmp/***' --exclude='/mnt/***' \
  --exclude='/media/***' --exclude='/home/***' --exclude='/nix/***' \
  --exclude='/var/lib/docker/***' --exclude='/boot/efi/***' \
  /media/ubuntu-root/ "$copy/filesystems/root/"
rsync -rc --dry-run --itemize-changes /media/ubuntu-efi/ "$copy/filesystems/efi/"
```

The copy is now a superset: `rsync` never deletes without `--delete`, so files
removed from Ubuntu between 2026-10-07 and 2026-10-09 are still in it. The
commands above do not list files that exist only in the copy. Add `--delete` to
a dry run to list them as `*deleting` lines; a dry run deletes nothing, and
BackupDrive is mounted `ro,noload` anyway. They matter only when restoring
whole directories. The EFI images and `metadata/efi-images.sha256` were
regenerated on 2026-10-09, so check the images against the current hashes.

## Using this backup with the manual installer

The [manual installation guide](INSTALL-INTEL-MANUALLY.md) normally creates an
encrypted Restic backup in section 2. If you use this verified rsync copy instead,
mount BackupDrive at `/media/backup` in the installer and verify its UUID and
serial as described there. Do not run `restic restore` against the rsync directory.
After offline comparison and before erasing Intel, prepare the same temporary
credential-restore location used by the guide. Run this as root in the section 2
shell; don't start a new `sudo -i`, which would drop the `nix-shell` tools that
sections 5 and 6 need:

```sh
copy=/media/backup/pre-nixos-2026-10-05
restored=/tmp/restore-check/media/ubuntu-root/etc
install -d -m 0700 "$restored"
test -d "$copy/filesystems/root/etc/nixos-migration" || exit 1
cp -a "$copy/filesystems/root/etc/nixos-migration" "$restored/"
new_keys=/tmp/restore-check/media/ubuntu-home/sam-dev/.config/wireguard
install -d -m 0700 "$new_keys"
cp -a "$copy/filesystems/home/sam-dev/.config/wireguard/sam-desktop" "$new_keys/"
for file in private.key public.key preshared.key; do
  cmp "$copy/filesystems/home/sam-dev/.config/wireguard/sam-desktop/$file" "$new_keys/sam-desktop/$file" || exit 1
done
for file in arwyn-private.key arwyn-psk.key squid-digest.env; do
  cmp "$copy/filesystems/root/etc/nixos-migration/$file" "$restored/nixos-migration/$file" || exit 1
done
```

The new encrypted target in section 5 receives those files. Keep the independent
backup attached only for restoration and physically disconnect it during
partitioning. The Restic LUKS-header backup command in section 4 also needs
adapting if there is no Restic repository: keep the header in the live system's
private temporary directory and then copy it onto encrypted storage or into a
new encrypted backup repository. Do not put an unprotected header backup beside
the plaintext rsync copy. Record how to recover it independently of the target.
