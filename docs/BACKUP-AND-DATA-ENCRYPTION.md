# Independent Ubuntu backup and staged drive encryption

## Backup destination identified on 5 October 2026

| Item | Observed value |
| --- | --- |
| USB drive | Seagate Backup+ Hub BK, serial `NA9R0S9H`, 10TB (9.1TiB) |
| Backup filesystem | second partition (was `sdf2`), ext4, label `BackupDrive` |
| Filesystem UUID | `883736aa-556a-4e5e-b42f-e58bd40f5668` |
| Ubuntu mount | `/mnt/backup`, mounted by hand for the script; no fstab entry, so the desktop automounts it at `/media/sam-dev/BackupDrive` ([details](LIVE-BACKUP-SCRIPT.md#before-running-it)) |
| Available space | ~8.6TiB before the backup; ~8.1TiB after the 2026-10-09 refresh |
| Other partition | first partition (was `sdf1`), 128MiB, no mounted filesystem shown |

Device letters are temporary. Mount by UUID and recheck model/serial in the live
installer. Neither partition needs formatting to make a backup.
The Intel NixOS configuration also mounts this filesystem at `/mnt/backup`,
on demand and without preventing boot if the USB drive is disconnected.

**Status on 12 October 2026: BackupDrive is not usable.** It fails to mount
(`/mnt/backup: No such device`), so don't rely on it for any step below until
it has been repaired or replaced and its copy re-checked. The Ubuntu home was
copied separately to the archive drive, at `/mnt/archive/pre-nixos-home/`, and
the home conversion restores from there.

The backup was taken on 2026-10-07 as the unencrypted rsync copy
`pre-nixos-2026-10-05/` and refreshed in place on 2026-10-09. BackupDrive now
has about 598GB (~557GiB) in use, per `df`. Docker is still at its cleaned-up
9.4GB, but `/nix` has grown back with Nix builds since its clean-up, from 17GB
in the 2026-10-07 copy to 118GB. The refresh had no `--delete`, so files
removed from Ubuntu between the two runs are still in the copy. No
Restic repository was created, so the Restic criteria below apply only if you
make one later. For the rsync copy, the equivalent checks are the offline
`rsync --checksum --dry-run` comparison and restore tests in
[LIVE-BACKUP-SCRIPT.md](LIVE-BACKUP-SCRIPT.md#encryption-and-verification).
The Windows, games and DaVinci
NTFS drives are outside that five-filesystem total; their contents are not
included automatically. DavinciProj is copied separately before it is
converted ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#1-copy-davinciproj-to-the-archive-drive-nixos)). If you intend to erase/encrypt any of
those too, back them up and verify them separately first.

## What counts as ready to erase a source

The [manual installation guide](INSTALL-INTEL-MANUALLY.md)'s section 2
describes an alternative: an **encrypted Restic repository on BackupDrive**,
made offline, covering all five Ubuntu data filesystems and their three EFI
filesystems. The backup actually taken is the rsync copy above, so the
criteria below apply only if you make a Restic repository later. The
development databases are recreated from scratch, so their dumps are not
needed.

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

The Linux data drives are erased and re-created encrypted **after** NixOS is
installed and working, one drive at a time. LUKS sits underneath the
filesystem, so encrypting means a new container and a fresh filesystem.
In-place conversion (`cryptsetup reencrypt --encrypt`) exists, but it is slow
and an interruption can lose data, so it isn't used here.

| Drive | Serial | Becomes | Mapper name | btrfs subvolumes | Unlocks |
| --- | --- | --- | --- | --- | --- |
| Samsung 512GB | `S1X1NYAG302936` | `/home` | `crypthome` | `@home` | initrd (needed for login) |
| Samsung 870 EVO 2TB | `S6PPNX0T910090T` | `/nix`, `/var/lib/docker` | `cryptstore` | `@nix`, `@docker` | initrd (needed to boot) |

The two 4TB drives (WD DavinciProj and the Seagate archive) are **not** LUKS
drives any more. Windows needs them too, so they become a VeraCrypt pair with
NTFS inside, the WD as the working drive and the Seagate as a scheduled mirror:
[SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md). The `cryptarchive` block in
`data-drives.nix` is superseded by that plan; leave `dataDrives.archive` null.

- **Unlocking:** each drive has its **own LUKS2 container and its own
  passphrase**, plus a TPM2 token, so both unlock automatically at boot. If the
  TPM refuses (for example after a firmware or Secure Boot change), the initrd
  asks for that drive's passphrase.
- **Configuration:** `hosts/devtower-intel/data-drives.nix` does the switching.
  A drive changes over when both of its UUIDs are filled in under `dataDrives`
  in `hosts/devtower-intel/disks.nix`. Until then its old Ubuntu filesystem
  stays mounted exactly as before. Filling in only one of the two UUIDs fails
  the build.
- **The old drive ESP goes too:** the Samsung home drive carries an old Ubuntu
  ESP (the 1GB second partition, `sdd2` today). The whole drive is erased.

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

2. **Go in this order: home, then the 4TB pair, then store.**
   - **Home** goes first and needs no live USB: the drive is only a data mount
     (`/mnt/ubuntu-home`), not the running `/home`. Nothing in the
     configuration needs it any more: the GitHub keys come from agenix, and
     `home/modules/mcp-sync.py` falls back to the old `.claude.json` only if it
     exists.
   - **The 4TB pair** comes next, from the running system and Windows. Its
     restore source is the old archive drive itself, so the old home backup on
     it moves with it.
   - **Store** is last, because it still needs the live installer and nothing
     else depends on it.

   Steps 3 to 6 below, and the common steps, are for the two LUKS drives. The
   4TB pair has its own procedure in
   [SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#conversion).
3. **Verify the copy** you will restore from, for the filesystem you are about
   to erase: an `rsync --checksum --dry-run --itemize-changes` against the
   source must list nothing.
4. **Choose the drive's passphrase** and store it in your password manager and
   offline before typing it into `luksFormat`. It is different for each drive.
5. **Have removable media ready** for the encrypted LUKS header backup.
6. **If BackupDrive is plugged in, unmount and unplug it** while erasing and
   partitioning (`sync; sudo umount /mnt/backup`), so it can't be picked by
   mistake.

### Steps common to every drive

Run these in a root shell (`sudo -i`): on the running system for home, from
the live installer for store. Replace `SERIAL`, `NAME` (`crypthome`,
`cryptstore`) and `LABEL` (`NIXOS_HOME`, `NIXOS_STORE`) for the drive in hand.

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
512GB and an hour or so for the 2TB.

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
2. **Enrol TPM2.** It asks for the drive's passphrase once. Home is formatted
   on the running system, so it is enrolled before its first boot and never
   prompts. Store is formatted from the live installer, so its first NixOS boot
   asks for the passphrase once; enrol it after that boot.

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

### Home (Samsung 512GB): first, from the running system

The new `@home` must hold the **NixOS** home (now the `@home` subvolume on the
Intel disk), including the repository with its `disks.nix` edit, plus whichever
Ubuntu personal files you still want. The Samsung is only mounted as
`/mnt/ubuntu-home`, so it can be erased while NixOS runs. The final copy is
made from a text console with the desktop logged out, so nothing is writing to
`/home` while it runs. No live USB is needed.

1. **Refresh the old home's copy.** It is on the archive drive at
   `/mnt/archive/pre-nixos-home/` (the root of the old filesystem, with
   `sam-dev/` inside). Every stage mounts the old home read-write, so make it
   read-only, bring the copy up to date and check it:

   ```sh
   sudo mount -o remount,ro /mnt/ubuntu-home
   sudo rsync -aHAXSx --numeric-ids /mnt/ubuntu-home/ /mnt/archive/pre-nixos-home/
   sudo rsync -aHAXSx --numeric-ids --checksum --dry-run --itemize-changes /mnt/ubuntu-home/ /mnt/archive/pre-nixos-home/
   ```

   The dry run must list nothing. This is now the **only** copy of the Ubuntu
   home, so if anything in it is irreplaceable, put a second copy of that
   somewhere else (another disk, or encrypted off-site) before going on.
2. **Commit and push the repository**, so the work in progress is safe
   whatever happens to either disk. If you haven't yet done the browser
   profile import ([BROWSER-MIGRATION.md](BROWSER-MIGRATION.md)), do it now:
   it reads `/mnt/ubuntu-home`, which disappears with this step.
3. **Unmount the old home and erase the drive:** in a `sudo -i` root shell,
   `umount /mnt/ubuntu-home`, then run the common steps 1 to 3 with
   `SERIAL=S1X1NYAG302936`, `NAME=crypthome`, `LABEL=NIXOS_HOME`. It stays
   unmounted until the reboot, so nothing recreates it.
4. **Create the subvolume, enrol TPM2 and make the first copy** while still
   logged in. Most of the data crosses now; the final pass only sends what
   changed since.

   ```sh
   mount /dev/mapper/crypthome /mnt/new
   btrfs subvolume create /mnt/new/@home
   systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$PART"
   rsync -aHAXS --numeric-ids --delete /home/ /mnt/new/@home/
   exit; exit                                       # leave nix-shell, then the root shell
   ```

   Leave `/mnt/new` mounted and `crypthome` open for step 6.
5. **Switch the configuration over:** `whoami` must print `sam-desktop`. Then
   in `~/Repos/personal/nix-config`, fill in `dataDrives.home` with the two UUIDs
   from common step 3, commit it, and run
   `just rebuild-host devtower-intel --boot`. **Don't reboot yet.**
6. **Final copy from a text console.** Close every app and log out of
   Hyprland. Press Ctrl+Alt+F3, log in as `sam-desktop`, then:

   ```sh
   sudo rsync -aHAXS --numeric-ids --delete /home/ /mnt/new/@home/
   sudo rsync -aHAXS --numeric-ids --delete --dry-run --itemize-changes /home/ /mnt/new/@home/
   ```

   The dry run should list nothing, or only shell history and state files from
   this console session. Then check that the `disks.nix` edit made it across,
   and reboot:

   ```sh
   grep -A1 'home = {' /mnt/new/@home/sam-desktop/Repos/personal/nix-config/hosts/devtower-intel/disks.nix
   sudo umount /mnt/new && sudo cryptsetup close crypthome
   sudo systemctl reboot
   ```

7. **Check the result.** `crypthome` unlocks through the TPM2 without a prompt.
   `findmnt /home` shows `/dev/mapper/crypthome[/@home]`, and
   `/mnt/ubuntu-home` is gone. A rebuild made from
   `~/Repos/personal/nix-config` must still have `dataDrives.home` filled in.
8. **Bring back Ubuntu files selectively** from
   `/mnt/archive/pre-nixos-home/sam-dev/` into `~/` (the Ubuntu uid is the
   same, 1000). Don't bring back the agent configs, shell histories or `~/.aws`
   that
   [INSTALL-INTEL-MANUALLY.md](INSTALL-INTEL-MANUALLY.md#7-first-boot-and-staged-upgrade)
   lists. The declarative config and agenix already provide them.
9. **Finish:** do finishing steps 3 and 4 (push, header backup).
10. **Only later, delete the Intel `@home`.** Older boot entries still mount
    `/home` from it, so first remove the older generations and rebuild, as in
    store step 5. Until then it is a fallback copy of the NixOS home as it was
    at the switch-over.

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
Their only copy was on BackupDrive (`filesystems/nix`, `filesystems/docker`),
which is not usable at the moment. Nothing from them is reused, so this loses
nothing the configuration needs; copy out anything you still want from
`/mnt/ubuntu-nix` or `/mnt/ubuntu-docker` before starting.

### What a LUKS header backup is not

A LUKS header is not a backup of the data. Mounting an unencrypted drive from
NixOS does not encrypt it. The rsync copy on BackupDrive is plaintext; keep it
physically secure, and don't format BackupDrive while it holds the only copy of
anything. The two 4TB drives use VeraCrypt instead of LUKS so Windows can
read them ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md)).
