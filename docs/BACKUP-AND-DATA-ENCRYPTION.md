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

All three Linux data drives are erased and re-created encrypted **after** NixOS
is installed and working, one drive at a time. Each drive restores from
BackupDrive (or, for the NixOS-side data, from the Intel disk). LUKS sits
underneath the filesystem, so encrypting means a new container and a fresh
filesystem. In-place conversion (`cryptsetup reencrypt --encrypt`) exists, but
it is slow and an interruption can lose data, so it isn't used here.

| Drive | Serial | Becomes | Mapper name | btrfs subvolumes | Unlocks |
| --- | --- | --- | --- | --- | --- |
| Samsung 512GB | `S1X1NYAG302936` | `/home` | `crypthome` | `@home` | initrd (needed for login) |
| Samsung 870 EVO 2TB | `S6PPNX0T910090T` | `/nix`, `/var/lib/docker` | `cryptstore` | `@nix`, `@docker` | initrd (needed to boot) |
| Seagate ST4000DM004 4TB | `ZFN2J51Q` | `/mnt/archive` | `cryptarchive` | `@archive` | after boot, `nofail`, automount |

- **Unlocking:** each drive has its **own LUKS2 container and its own
  passphrase**, plus a TPM2 token, so all of them unlock automatically at boot.
  - **Home and store:** if the TPM refuses (for example after a firmware or
    Secure Boot change), the initrd asks for that drive's passphrase.
  - **Archive:** its prompt can't be seen once the login screen is up. If its
    token fails, run `sudo systemd-tty-ask-password-agent --query` in a
    terminal; `/mnt/archive` mounts on the next access.
- **Configuration:** `hosts/devtower-intel/data-drives.nix` does the switching.
  A drive changes over when both of its UUIDs are filled in under `dataDrives`
  in `hosts/devtower-intel/disks.nix`. Until then its old Ubuntu filesystem
  stays mounted exactly as before. Filling in only one of the two UUIDs fails
  the build.
- **The old drive ESPs go too:** the Samsung home and archive drives each carry
  an old Ubuntu ESP (`244E-5B6F`, `2537-6BE7`). The whole drive is erased, and
  both ESPs are already imaged in the backup.

**What TPM2 auto-unlock does and doesn't protect.** Every enrolment here binds
to PCR 7 (Secure Boot state), the same as the OS disk. Secure Boot is currently
**off**, so PCR 7 reads the same whatever this PC boots, a live USB included.

- **Protected:** a drive taken out of the PC. Its key only exists inside this
  PC's TPM.
- **Not protected:** someone who can boot this PC from their own USB; the TPM
  will release the keys to them too.
- **To close that gap:** enable Secure Boot with signed boot files (for example
  lanzaboote, a separate project), then re-enrol every drive. Until then, the
  passphrases are what protect the whole machine.

Without `--tpm2-pcrs=7`, current systemd binds a token to **no** PCRs at all,
so never leave it out.

**Rebuilding.** Run rebuilds from the repository as `sam-desktop`. Both forms
pick up the `disks.nix` edits:

- `just rebuild-host devtower-intel` switches straight away.
- `just rebuild-host devtower-intel --boot` applies the change at next boot.

### Before converting any drive

1. **Be on the full stage** (`.#devtower-intel`), and enrol the **OS disk** in
   TPM2 if you haven't already. Back up its header afterwards, as in step 4 of
   the finishing steps below.

   ```sh
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<disks.nix luksUuid>
   ```

2. **Go in this order: archive, store, home.** The install reads
   `/mnt/ubuntu-home` for the GitHub key bridge, the MCP key import and the
   repository copy, so the old home drive is converted last.
3. **Verify the backup** for the filesystem you are about to erase (the offline
   checksum comparison in
   [LIVE-BACKUP-SCRIPT.md](LIVE-BACKUP-SCRIPT.md#encryption-and-verification)).
4. **Choose the drive's passphrase** and store it in your password manager and
   offline before typing it into `luksFormat`. It is different for each drive.
5. **Have removable media ready** for the encrypted LUKS header backup.
6. **Unplug BackupDrive while erasing and partitioning**, and plug it back in
   only for the restore step. Unmount it before unplugging
   (`sync; sudo umount /mnt/backup` on NixOS, `umount /media/backup` in the live
   installer).

### Steps common to every drive

Run these in a root shell (`sudo -i`): from the live installer for home and
store, or on the running system for the archive. Replace `SERIAL`, `NAME`
(`crypthome`, `cryptstore`, `cryptarchive`) and `LABEL` (`NIXOS_HOME`,
`NIXOS_STORE`, `NIXOS_ARCHIVE`) for the drive in hand.

**1. Identify the drive** by its serial:

```sh
nix-shell -p cryptsetup parted btrfs-progs rsync age util-linux
ls /dev/disk/by-id/*SERIAL                            # the whole-disk path (no -partN)
read -r -p 'Whole-disk by-id path: ' DISK
test "$(lsblk -dn -o SERIAL "$DISK" | tr -d ' ')" = SERIAL || exit 1
lsblk -o NAME,SIZE,FSTYPE,UUID,MOUNTPOINTS "$DISK"
test -z "$(lsblk -nro MOUNTPOINTS "$DISK" | tr -d '\n')" || exit 1   # nothing may be mounted
read -r -p 'Type ERASE-SERIAL to continue: ' CONFIRM && test "$CONFIRM" = ERASE-SERIAL || exit 1
```

**2. Create the container, and erase the drive for real.** Repartitioning and
`luksFormat` write only a few MiB, so the old plaintext filesystem would stay
readable from the raw disk. Filling the new container with zeros overwrites
every sector with ciphertext. TRIM is not used for this: the 512GB Samsung isn't
guaranteed to read back zeros after it. Expect roughly 20 minutes for the
512GB, an hour or so for the 2TB and several hours for the 4TB HDD.

```sh
parted --script "$DISK" mklabel gpt mkpart NAME 1MiB 100%
udevadm settle
PART="${DISK}-part1"
cryptsetup luksFormat --type luks2 "$PART"            # this drive's own passphrase
cryptsetup open "$PART" NAME
dd if=/dev/zero of=/dev/mapper/NAME bs=4M status=progress oflag=direct
#   ends with "No space left on device" and exit status 1: that is expected
```

**3. Create the filesystem:**

```sh
mkfs.btrfs -L LABEL /dev/mapper/NAME
mkdir -p /mnt/new
blkid -s UUID -o value "$PART"                        # -> dataDrives.<drive>.luksUuid
blkid -s UUID -o value /dev/mapper/NAME               # -> dataDrives.<drive>.fsUuid
```

Write both UUIDs down. Then create the drive's subvolumes and restore into them
(the per-drive sections below), and finish with these steps:

1. **Fill in the two UUIDs** in `disks.nix` and rebuild as each drive's section
   says. Check `findmnt` shows the new device.
2. **Enrol TPM2.** It asks for the drive's passphrase once. Home and store are
   formatted from the live installer, so their first NixOS boot asks for the
   passphrase once; enrol them after that boot. The archive is enrolled
   straight after restoring.

   ```sh
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<luksUuid>
   ```

3. **Commit the `disks.nix` change** (UUIDs are not secret) and push it, so a
   fresh clone or another machine builds the same layout.
4. **Back up the LUKS header after enrolling**, because enrolment adds a token
   to the header. Encrypt it and keep it off the drive itself:

   ```sh
   sudo -i
   nix-shell -p age
   cryptsetup luksHeaderBackup /dev/disk/by-uuid/<luksUuid> --header-backup-file /root/NAME-header
   age -p -o /path/to/usb/NAME-header.age /root/NAME-header
   age -d /path/to/usb/NAME-header.age | cmp - /root/NAME-header && shred -u /root/NAME-header
   ```

5. **Reboot once more** and confirm the drive unlocked without a prompt.

If you later enable Secure Boot, PCR 7 changes. Every drive, the OS disk
included, then asks for its passphrase until you re-enrol it, one command per
LUKS UUID:

```sh
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<luksUuid>
```

### Archive (Seagate 4TB): first, from the running system

The archive is not needed to boot, so it can be done without the live installer.

1. **Refresh its backup first.** Every stage mounts `/mnt/archive` read-write,
   so anything written since 2026-10-07 is not in the backup yet. Stop anything
   using the archive, make it read-only so nothing changes during the copy, and
   plug BackupDrive in:

   ```sh
   sudo mount -o remount,ro /mnt/archive
   sudo rsync -aHAXSx --numeric-ids /mnt/archive/ /mnt/backup/archive-$(date +%F)/
   sudo rsync -aHAXSx --numeric-ids --checksum --dry-run --itemize-changes /mnt/archive/ /mnt/backup/archive-$(date +%F)/
   sudo umount /mnt/archive
   sync; sudo umount /mnt/backup
   ```

   The dry run must list nothing. Then unplug BackupDrive.
2. **Erase and format:** run the common steps with `NAME=cryptarchive` in a
   `sudo -i` root shell.
3. **Restore:** plug BackupDrive back in, then create the subvolume and restore
   from the refreshed copy (same date as step 1):

   ```sh
   mount /dev/mapper/cryptarchive /mnt/new
   btrfs subvolume create /mnt/new/@archive
   rsync -aHAXS --numeric-ids /mnt/backup/archive-YYYY-MM-DD/ /mnt/new/@archive/
   rsync -aHAXS --numeric-ids --checksum --dry-run --itemize-changes /mnt/backup/archive-YYYY-MM-DD/ /mnt/new/@archive/
   ```

   The dry run must list nothing.
4. **Enrol TPM2 now**, before switching over, so the first boot never prompts.
   Still as root:

   ```sh
   systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<archive luksUuid>
   umount /mnt/new; cryptsetup close cryptarchive
   exit                                             # leave the root shell
   ```

5. **Switch over:** as `sam-desktop` in `~/Repos/personal/nix-config`, fill in
   `dataDrives.archive`, run `just rebuild-host devtower-intel --boot`, and
   reboot. Check that
   `ls /mnt/archive` works and `findmnt /mnt/archive` shows `cryptarchive`.
   Then do finishing steps 3 to 5.

### Store (Samsung 870 EVO 2TB): live installer, in two visits

`/nix` holds the running system, so the copy must happen **after** the
generation that mounts the new drive has been built. Otherwise the new drive
would lack that generation.

1. **Live installer:** run the common steps with `NAME=cryptstore`. Create the
   subvolumes, then reboot into NixOS:

   ```sh
   mount /dev/mapper/cryptstore /mnt/new
   btrfs subvolume create /mnt/new/@nix
   btrfs subvolume create /mnt/new/@docker
   umount /mnt/new; cryptsetup close cryptstore
   ```

2. **NixOS:** fill in `dataDrives.store` and run
   `just rebuild-host devtower-intel --boot`. This builds the new generation
   into the Intel `/nix` and makes it the default. **Don't reboot into it
   yet**: its `/nix` drive is still empty. Shut down instead. The previous
   generation in the boot menu still uses the Intel `/nix` if you need it.
3. **Live installer again:** unlock both disks and copy `/nix` and Docker
   across while nothing is running:

   ```sh
   sudo -i
   cryptsetup open /dev/disk/by-uuid/<cryptroot luksUuid> cryptroot
   cryptsetup open /dev/disk/by-uuid/<store luksUuid> cryptstore
   mkdir -p /mnt/old /mnt/new
   mount /dev/mapper/cryptroot /mnt/old            # btrfs top level: @nix, @docker inside
   mount /dev/mapper/cryptstore /mnt/new
   rsync -aHAXS --numeric-ids --delete /mnt/old/@nix/ /mnt/new/@nix/
   rsync -aHAXS --numeric-ids --delete /mnt/old/@docker/ /mnt/new/@docker/
   umount /mnt/old /mnt/new
   ```

4. **Reboot into the new generation.** It asks for the store passphrase once.
   Check that `findmnt /nix` shows `cryptstore` and that
   `sudo nix-store --verify --check-contents` passes. Then do finishing steps
   2 to 5.
5. **Only later, free the Intel copies.** Older boot entries still mount
   `/nix` from the Intel `@nix`, so remove those generations first:

   ```sh
   sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +1   # keep only the current one
   just rebuild-host devtower-intel --boot                                # drops their boot entries
   ```

   Then, from a live session, `btrfs subvolume delete` the Intel disk's old
   `@nix` and `@docker`. Or leave them as a fallback until space is needed.

The old Ubuntu `/nix` and Docker partitions on this drive are erased by step 1.
Their contents are in the backup (`filesystems/nix`, `filesystems/docker`).
Nothing from them is reused.

### Home (Samsung 512GB): live installer, in two visits, last

The new `@home` must hold the **NixOS** home (now on the Intel disk), including
the repository with its `disks.nix` edit, plus whichever Ubuntu personal files
you still want. So, like the store, the copy happens after the rebuild.

1. **Before you start:** make sure the full stage is working and nothing
   still reads `/mnt/ubuntu-home`. The old home's contents are in
   `filesystems/home/sam-dev` on BackupDrive. Every stage mounts the old home
   read-write, so if anything you want changed there after 2026-10-07, copy it
   into a dated folder on BackupDrive first, as for the archive, and restore it
   from there.
2. **Live installer:** run the common steps with `NAME=crypthome`. Create the
   subvolume, then reboot into NixOS:

   ```sh
   mount /dev/mapper/crypthome /mnt/new
   btrfs subvolume create /mnt/new/@home
   umount /mnt/new; cryptsetup close crypthome
   ```

3. **NixOS:** fill in `dataDrives.home` and commit it, then run
   `just rebuild-host devtower-intel --boot`. **Don't reboot into it yet**:
   shut down instead.
4. **Live installer again:** copy the NixOS home across, then add Ubuntu data
   selectively. Plug BackupDrive in only after the first `rsync`.

   ```sh
   sudo -i
   cryptsetup open /dev/disk/by-uuid/<cryptroot luksUuid> cryptroot
   cryptsetup open /dev/disk/by-uuid/<home luksUuid> crypthome
   mkdir -p /mnt/old /mnt/new /media/backup
   mount /dev/mapper/cryptroot /mnt/old
   mount /dev/mapper/crypthome /mnt/new
   rsync -aHAXS --numeric-ids --delete /mnt/old/@home/ /mnt/new/@home/
   mount -o ro,noload /dev/disk/by-uuid/883736aa-556a-4e5e-b42f-e58bd40f5668 /media/backup
   # Copy chosen folders from /media/backup/pre-nixos-2026-10-05/filesystems/home/sam-dev/
   # into /mnt/new/@home/sam-desktop/, then: chown -R 1000:100 on what you copied.
   umount /mnt/old /mnt/new /media/backup
   ```

   Don't bring back the agent configs, shell histories or `~/.aws` that
   [INSTALL-INTEL-MANUALLY.md](INSTALL-INTEL-MANUALLY.md#7-first-boot-and-staged-upgrade)
   lists. The declarative config and agenix already provide them.
5. **Reboot into the new generation.** It asks for the home passphrase once.
   `/home` now comes from `crypthome`, and `/mnt/ubuntu-home` disappears. Check
   that `findmnt /home` shows `crypthome`, and that a rebuild made from
   `~/Repos/personal/nix-config` still has `dataDrives.home` filled in. Then
   do finishing steps 2 to 5.
6. **Only later, delete the Intel `@home`.** First remove the older generations
   and rebuild, as in store step 5, so no boot entry still mounts it.

### What a LUKS header backup is not

A LUKS header is not a backup of the data. Mounting an unencrypted drive from
NixOS does not encrypt it. The rsync copy on BackupDrive is plaintext; keep it
physically secure, and don't format BackupDrive while it holds the only copy of
anything. DavinciProj stays plain NTFS while Windows needs it
(see [its page](DAVINCI-SHARED-DRIVE.md#backup-and-encryption)).
