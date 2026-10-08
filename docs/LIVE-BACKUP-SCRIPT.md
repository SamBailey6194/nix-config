# Using the prepared Ubuntu backup script

The existing `/home/sam-dev/backup-before-nixos.sh` was reviewed read-only.
It targets `/mnt/backup/pre-nixos-2026-10-05` and checks filesystem UUIDs.
It copies Ubuntu root, home, archive, Nix, Docker and Ubuntu EFI with
`rsync -aHAXSx --numeric-ids`, separately images home/archive EFI, and saves
partition tables/UUIDs. It avoids recursively backing up its own destination.
Its exit trap restarts the services/containers that were previously active.

## Before running it

Finish and save edits, close browser/IDE sessions and stop database writers.
Export important databases using their own dump tools. Preserve the running
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
Ubuntu EFI, plus images of the other two Ubuntu ESPs. The offline verification
below is still outstanding.

Run your existing command only after the edits and checks are complete:

```sh
sudo systemd-run --unit=pre-nixos-backup --collect \
  /usr/bin/bash /home/sam-dev/backup-before-nixos.sh --pause-services
```

Monitor `backup.log` and `STATUS.txt` at the destination. The script can take
hours; do not shut down the machine or disconnect BackupDrive during copying.
A live copy can contain changing journals/browser files even with Docker and
Nix stopped. `COPY FINISHED` explicitly means verification remains to be done.
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
partitions; test restoring personal files, the complete uncommitted repository,
credentials and database dumps. This preserves files, not a bootable disk image.

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
