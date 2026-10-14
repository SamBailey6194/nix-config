# Shared encrypted data drives (VeraCrypt pair)

The two 4TB hard drives hold personal and business documents, photos and
videos, plus the working files for Affinity, DaVinci Resolve and the Craft
apps (PhotoCraft, VectorCraft, ...). Windows (dual-boot on this PC) and NixOS both need them, so each one
gets a **VeraCrypt** volume with **NTFS** inside, and NixOS keeps the second
drive as a scheduled one-way mirror of the first.

This is the plan as of 12 October 2026. The procedure below is done by hand;
the NixOS configuration for it (unlock, mounts, mirror timer) is written but
switched off until each drive's identifier is filled in (step 7), see
[NixOS configuration](#nixos-configuration).

| Drive | Serial | Recording | Role | Mapper name | NixOS mount |
| --- | --- | --- | --- | --- | --- |
| WD Blue WD40EZRZ 4TB | `WD-WCC7K0FU5LY2` | CMR | working drive, mounted in both OSes | `cryptdata` | `/mnt/data` |
| Seagate BarraCuda ST4000DM004 4TB | `ZFN2J51Q` | SMR | mirror, written only by NixOS | `cryptmirror` | `/mnt/data-mirror` |

## Why not RAID1

- **Windows can't read Linux RAID.** An mdadm or btrfs RAID1, with LUKS or
  VeraCrypt on top, is invisible to Windows. Sharing it over the network
  doesn't help: Windows runs on this PC, so NixOS isn't running at the time.
- **Intel RST firmware RAID** (the Maximus XI Hero supports it) would give a
  mirror both systems can see, but it means switching the SATA controller from
  AHCI to RAID (Windows needs a driver change first, and every SATA drive is
  affected), has no data checksums, and rebuilds onto the SMR Seagate would be
  slow.
- **The Seagate is SMR.** Shingled drives slow down badly under long sustained
  writes, which is exactly what a RAID rebuild is. A nightly incremental copy
  is a light, mostly sequential load it handles well.
- **A delayed mirror is also a safety net.** RAID1 copies a deletion, an
  overwrite or ransomware to both drives instantly. The mirror only follows
  after the next sync, and keeps what it replaces for 30 days.

The trade-off: anything changed since the last sync exists on the WD only.

## How it works

- **The WD is the only drive you work on**, from either OS. Pin it to the same
  drive letter in Windows (VeraCrypt favourite) so Affinity's linked files and
  Resolve's mapped mounts resolve on both sides
  ([DAVINCI-SHARED-DRIVE.md](DAVINCI-SHARED-DRIVE.md#affinity-files)).
- **The Seagate is written only by the NixOS mirror job.** Don't mount it in
  Windows, or mount it read-only there if you must look at it.
- **Unlocking.** VeraCrypt volumes have no TPM2 support.
  - **Windows:** VeraCrypt asks for the passphrase at logon (favourite with
    "Mount selected volume upon logon").
  - **NixOS:** systemd-cryptsetup opens VeraCrypt volumes natively
    (`tcrypt-veracrypt` in `/etc/crypttab`, see `man crypttab`). The passphrase
    comes from a root-only file on the encrypted OS disk, so the WD unlocks
    after boot without a prompt, and the Seagate only while the mirror job
    runs. Same trust as the TPM2 tokens: whoever can unlock the OS disk can
    read the files.
- **NTFS on Linux** uses NTFS-3G with the options DavinciProj already uses:
  `windows_names`, `norecover`, `nofail`, owned by `sam-desktop`. The Windows
  rules in [DAVINCI-SHARED-DRIVE.md](DAVINCI-SHARED-DRIVE.md#before-switching-operating-systems)
  still apply: Fast Startup off, always shut Windows down fully.
- **NTFS has no Unix permissions, owners or reliable symlinks.** Ordinary files
  (documents, photos, video, project files) are fine. Anything that needs Unix
  metadata, such as the pre-NixOS system backups, old repositories with
  executable bits, or Docker data, is stored as `.tar.zst` archives.

### Suggested layout

Keep the existing DavinciProj tree at the root, unchanged, so existing Resolve
media paths and Affinity links (`E:\Affinity\...`) still resolve. Add the new
folders beside it:

```text
<volume root>/
├── <existing DavinciProj folders, including Affinity/>
├── Personal/        Documents/, Photos/, Videos/
├── Business/        Documents/, Photos/, Videos/, plus the two Syntek repos:
│   ├── syntek-business-docs/   business documents and Python scripts (git)
│   └── syntek-content/         photos, videos and Python scripts (git)
├── Craft/           PhotoCraft, VectorCraft, ... project files
├── Archive/         *.tar.zst of Unix-only material (pre-NixOS backups, old repos)
└── .data-primary    marker file the mirror job checks for (WD only)
```

## Conversion

Both drives are erased, one at a time, with no extra disk: the archive drive's
contents move to the WD first, then the archive drive is wiped and becomes the
mirror. BackupDrive is not usable at the moment, so between steps 4 and 6 the
archive contents exist on the WD only. If anything there is irreplaceable, put
a second copy of it somewhere else (encrypted off-site, for example) first.

**Before starting:**

- Do the [home conversion](BACKUP-AND-DATA-ENCRYPTION.md#home-samsung-512gb-first-from-the-running-system)
  first. It refreshes `/mnt/archive/pre-nixos-home/`, which moves with the
  archive.
- **Windows:** check Fast Startup is off; VeraCrypt is installed there only
  for step 8.
- **Passphrases:** choose one per volume and store them in your password
  manager and offline before typing them in.
- **USB stick** for the VeraCrypt header backups.

### 1. Copy DavinciProj to the archive drive (NixOS)

Shut Windows down fully first. Close Resolve and Affinity, and mount the drive
read-only so nothing changes after the copy. NTFS-3G can't switch a mount to
read-only in place (`remount,ro` fails), so unmount it and mount it again:

```sh
sudo umount /mnt/davinci && sudo mount -o ro /mnt/davinci
D=$(date +%F)
sudo rsync -rtS /mnt/davinci/ /mnt/archive/davinciproj-$D/
sudo rsync -rtS --checksum --dry-run --itemize-changes /mnt/davinci/ /mnt/archive/davinciproj-$D/
```

The dry run must list nothing.

### 2. Create the VeraCrypt volume on the WD (NixOS)

VeraCrypt is run once from a root `nix shell`, not installed: it is unfree, so
the first run compiles it (5 to 10 minutes), and the next garbage collection
removes it. NixOS itself only ever opens the volumes, with cryptsetup.
`ntfs3g` provides the `mkfs.ntfs` VeraCrypt uses for the filesystem inside.

```sh
sudo -i
NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#veracrypt nixpkgs#ntfs3g nixpkgs#util-linux
umount /mnt/davinci
DISK=$(ls /dev/disk/by-id/ata-*WD-WCC7K0FU5LY2 | grep -v -- -part)
test "$(udevadm info --query=property --property=ID_SERIAL_SHORT --value --name="$DISK")" = WD-WCC7K0FU5LY2 || exit 1
lsblk -o NAME,SIZE,FSTYPE,PARTUUID,MOUNTPOINTS "$DISK"     # one 3.6T ntfs partition, nothing mounted
test -z "$(lsblk -nro MOUNTPOINTS "$DISK" | tr -d '\n')" || exit 1
PART="${DISK}-part1"
read -r -p 'Type ERASE-WD-WCC7K0FU5LY2 to continue: ' CONFIRM && test "$CONFIRM" = ERASE-WD-WCC7K0FU5LY2 || exit 1
veracrypt --text --create "$PART" --volume-type=normal \
  --encryption=AES --hash=SHA-512 --filesystem=NTFS \
  --pim=0 --keyfiles="" --random-source=/dev/urandom
```

It asks for the WD's passphrase twice. There is no `--quick`, so this is a full
format: it fills the whole partition with ciphertext, overwriting the old
plaintext, and takes several hours (about 350MiB/s on the outer tracks, slower
towards the end). The volume goes inside the existing partition, so its
PARTUUID doesn't change. Afterwards, back up the header to the USB stick and
note the PARTUUID for step 7:

```sh
veracrypt --text --backup-headers "$PART"     # e.g. <stick>/veracrypt/wd-data-header.bin
blkid -s PARTUUID -o value "$PART"
```

The old `/mnt/davinci` NTFS mount no longer finds its UUID; it is `nofail`, so
NixOS boots normally. Windows is not needed until step 8.

### 3. Copy the archive onto the WD (NixOS)

Open and mount the new volume by hand (opening takes a few seconds; VeraCrypt's
key derivation is deliberately slow):

```sh
sudo -i
nix-shell -p cryptsetup ntfs3g rsync zstd util-linux parted
DATA=$(ls /dev/disk/by-id/*WD-WCC7K0FU5LY2-part1)
cryptsetup open --type tcrypt --veracrypt "$DATA" cryptdata
mkdir -p /mnt/data
mount -t ntfs-3g -o windows_names,norecover,uid=1000,gid=100,fmask=0133,dmask=0022 /dev/mapper/cryptdata /mnt/data
D=YYYY-MM-DD                                   # the date used in step 1
rsync -rtS /mnt/archive/davinciproj-$D/ /mnt/data/
rsync -rtS --checksum --dry-run --itemize-changes /mnt/archive/davinciproj-$D/ /mnt/data/
mkdir -p /mnt/data/Personal /mnt/data/Business /mnt/data/Archive
touch /mnt/data/.data-primary
```

Then the Unix-only folders, one archive each, each checked with
`tar --compare` (no output and exit status 0 means it matches):

```sh
set -o pipefail
for d in pre-nixos-home pre-nixos-intel OldRepos docker-data nix static .Trash-1000; do
  tar --xattrs --acls --numeric-owner -cpf - -C /mnt/archive "$d" | zstd -T0 > "/mnt/data/Archive/$d.tar.zst" \
    || { echo "FAILED: $d" >&2; break; }
  zstd -dc "/mnt/data/Archive/$d.tar.zst" | tar --compare --numeric-owner -f - -C /mnt/archive \
    || { echo "FAILED: $d" >&2; break; }
done
```

`.pnpm-store` is a package cache and is not kept; add it to the loop if you
want it anyway. Then check every top-level folder is accounted for. This must
print nothing; if it prints `FAILED` or `MISSING`, fix that before step 4:

```sh
for d in $(ls -A /mnt/archive | grep -vx -e lost+found -e .pnpm-store -e "davinciproj-$D"); do
  test -s "/mnt/data/Archive/$d.tar.zst" || echo "MISSING $d"
done
```

(`davinciproj-$D` is already on the volume as plain files.) Sort personal and
business files into `Personal/` and `Business/` later, on the new volume.

### 4. Erase the Seagate and partition it for Windows (NixOS)

The archive contents now exist only on the WD. In a root shell (`sudo -i`,
then `nix-shell` as in step 3):

```sh
umount /mnt/archive
DISK=$(ls /dev/disk/by-id/ata-*ZFN2J51Q | grep -v -- -part)
test "$(udevadm info --query=property --property=ID_SERIAL_SHORT --value --name="$DISK")" = ZFN2J51Q || exit 1
test -z "$(lsblk -nro MOUNTPOINTS "$DISK" | tr -d '\n')" || exit 1
read -r -p 'Type ERASE-ZFN2J51Q to continue: ' CONFIRM && test "$CONFIRM" = ERASE-ZFN2J51Q || exit 1
wipefs -a "$DISK"-part1 "$DISK"-part2              # old ext4 and the old Ubuntu ESP
parted --script "$DISK" mklabel gpt mkpart data-mirror ntfs 1MiB 100%
udevadm settle
wipefs -a "$DISK"-part1                              # nothing left at the new start
```

`/mnt/archive` will fail to mount from now on; it is `nofail`.

### 5. Create the mirror's VeraCrypt volume (NixOS)

As step 2, in a root `nix shell` with VeraCrypt, on the Seagate's new
partition, with the Seagate's passphrase and a full format:

```sh
DISK=$(ls /dev/disk/by-id/ata-*ZFN2J51Q | grep -v -- -part)
test "$(udevadm info --query=property --property=ID_SERIAL_SHORT --value --name="$DISK")" = ZFN2J51Q || exit 1
test -z "$(lsblk -nro MOUNTPOINTS "$DISK" | tr -d '\n')" || exit 1
PART="${DISK}-part1"
veracrypt --text --create "$PART" --volume-type=normal \
  --encryption=AES --hash=SHA-512 --filesystem=NTFS \
  --pim=0 --keyfiles="" --random-source=/dev/urandom
veracrypt --text --backup-headers "$PART"     # e.g. <stick>/veracrypt/seagate-mirror-header.bin
blkid -s PARTUUID -o value "$PART"
```

The Seagate is SMR, so the full format may slow down part-way; let it finish.

### 6. First mirror copy (NixOS)

```sh
sudo -i
nix-shell -p cryptsetup ntfs3g rsync util-linux
# cryptdata is already open and mounted at /mnt/data if the WD has been
# switched on (step 7); otherwise open and mount it as in step 3. Then:
MIRROR=$(ls /dev/disk/by-id/ata-*ZFN2J51Q-part1)
cryptsetup open --type tcrypt --veracrypt "$MIRROR" cryptmirror
mkdir -p /mnt/data-mirror
mount -t ntfs-3g -o windows_names,norecover,uid=1000,gid=100,fmask=0133,dmask=0022 /dev/mapper/cryptmirror /mnt/data-mirror
EX=(--exclude=/.data-primary --exclude=/.mirror-history --exclude='/System Volume Information' --exclude='/$RECYCLE.BIN')
rsync -rtS --delete "${EX[@]}" /mnt/data/ /mnt/data-mirror/
rsync -rtS --delete "${EX[@]}" --checksum --dry-run --itemize-changes /mnt/data/ /mnt/data-mirror/
```

The excludes are the same list the nightly job uses: `.data-primary` marks
the WD only, and `System Volume Information` and `$RECYCLE.BIN` belong to each
volume, not to the data. The dry run must list nothing. From here the two
drives are the only copies of the archive, so the off-site backup (below) is
the next priority. Once the Seagate is switched on (step 7), refresh the mirror
only with `sudo systemctl start data-mirror`, never by hand.

### 7. Switch NixOS over to the pair (NixOS)

The configuration in [NixOS configuration](#nixos-configuration) is already in
the repository, inert until each drive's `partUuid` is filled in. Do this for
both drives now, or for the WD alone earlier, straight after step 3 (it is then
mounted at `/mnt/data` by the system while steps 4 to 6 run, and `/mnt/archive`
stays until the Seagate is switched on).

1. **Close the volumes you opened by hand**, in the root shell (only the ones
   being switched on):

   ```sh
   umount /mnt/data-mirror && cryptsetup close cryptmirror
   umount /mnt/data && cryptsetup close cryptdata
   ```

2. **Create each passphrase file** (`data.pass` for the WD, `mirror.pass` for
   the Seagate; root-only, not agenix). Type the passphrase at the prompt; it
   is written without a trailing newline:

   ```sh
   sudo bash -c 'umask 077; IFS= read -rs -p "Passphrase: " p; echo; printf %s "$p" > /var/lib/desktop-secrets/data.pass'
   sudo chmod 0400 /var/lib/desktop-secrets/data.pass
   ```

   systemd-cryptsetup reads only the first line of the file and drops its line
   ending, so a newline added later by an editor does no harm, but spaces at
   either end count as part of the passphrase.

3. **Test the file the way boot uses it**, with the volume closed. Don't test
   with `cryptsetup --key-file`: for a VeraCrypt volume that means a VeraCrypt
   keyfile, not a passphrase.

   ```sh
   P=$(blkid -s PARTUUID -o value /dev/disk/by-id/ata-WDC_WD40EZRZ-00GXCB0_WD-WCC7K0FU5LY2-part1)
   echo "$P"
   sudo systemd-cryptsetup attach cryptdata /dev/disk/by-partuuid/$P /var/lib/desktop-secrets/data.pass tcrypt-veracrypt
   sudo systemd-cryptsetup detach cryptdata
   ```

   For the Seagate: `ata-ST4000DM004-2CV104_ZFN2J51Q-part1`, `cryptmirror`
   and `mirror.pass`.

4. **Fill in `hosts/devtower-intel/disks.nix`**: the PARTUUID printed above
   goes in `dataPair.data.partUuid` (WD) or `dataPair.mirror.partUuid`
   (Seagate), as a string. The WD's PARTUUID is the one its NTFS partition
   always had (VeraCrypt formatted inside it); the Seagate's is the new
   partition from step 4.

5. **Rebuild for the next boot and reboot**, with Resolve and Affinity closed.
   `data-pair.nix` is a new file, and a Git flake can't see untracked files,
   so `git add` it first:

   ```sh
   git add hosts/devtower-intel/data-pair.nix
   just check devtower-intel
   just rebuild --boot
   systemctl reboot
   ```

6. **Check the result:**

   ```sh
   systemctl --failed                                # nothing listed
   systemctl status systemd-cryptsetup@cryptdata mnt-data.mount
   findmnt -o SOURCE,FSTYPE,OPTIONS /mnt/data       # fuseblk, rw
   ls -A /mnt/data                                   # the DavinciProj tree, .data-primary
   readlink ~/DavinciProj                            # /mnt/data
   findmnt /mnt/davinci                              # nothing
   systemctl status smartd
   ```

   Yazi `g D` and `g a` now go to `/mnt/data` and `/mnt/data/Affinity`.
   With the Seagate switched on as well:

   ```sh
   findmnt /mnt/archive                              # nothing
   systemctl list-timers data-mirror                 # next run 03:30 to 04:00
   sudo systemctl start data-mirror                  # first run by hand
   journalctl -u data-mirror -b                      # no "refusing", rsync status 0
   findmnt /mnt/data-mirror                          # nothing: unmounted again
   ls /dev/mapper                                    # no cryptmirror: locked again
   ```

   If `/mnt/data` gave up at boot (drive late, unlock slower than a minute),
   check `journalctl -b -u systemd-cryptsetup@cryptdata`, then
   `sudo systemctl start mnt-data.mount`.

7. **Commit** `disks.nix` and the new files once it works.

After the Seagate is switched on, the old blocks can be deleted:
`/mnt/davinci` in `hardware-configuration.nix`, the ext4 `/mnt/archive`
block and its assertion in `data-drives.nix`, and `davinciUuid`,
`archiveUuid` and `dataDrives.archive` in `disks.nix`.

### 8. Mount the WD in Windows (Windows, once)

Install VeraCrypt in Windows first (Windows only; NixOS doesn't need it).

1. If Windows says a disk needs formatting, **always choose Cancel**. It is
   seeing an encrypted partition without VeraCrypt. If Disk Management has
   given either drive's raw partition a letter, remove it.
2. In VeraCrypt, select the WD's partition (3.64TB,
   `\Device\HarddiskN\Partition1`) and mount it at the letter DavinciProj had,
   then **Favorites → Add Mounted Volume to Favorites**: tick "Mount selected
   volume upon logon" and give it the label `Data`.
3. Don't add the Seagate: only NixOS writes the mirror.
4. Open a project in Resolve and in Affinity to check their paths resolve,
   then shut Windows down fully.

## NixOS configuration

`hosts/devtower-intel/data-pair.nix` (imported by `hardware-configuration.nix`
beside `data-drives.nix`), switched on per drive by `dataPair` in
`hosts/devtower-intel/disks.nix`:

```nix
dataPair = {
  data   = { partUuid = null; byId = "ata-WDC_WD40EZRZ-00GXCB0_WD-WCC7K0FU5LY2"; }; # cryptdata -> /mnt/data
  mirror = { partUuid = null; byId = "ata-ST4000DM004-2CV104_ZFN2J51Q"; };         # cryptmirror -> /mnt/data-mirror
};
```

With both `partUuid`s null, every devtower-intel stage builds exactly the
system it did before: `/mnt/davinci` and `/mnt/archive` as now, no new units.
`byId` is the whole drive, used by smartd and the commands in step 7. Filling
in `data` switches on the WD's unlock, `/mnt/data` and its smartd entry, and
retires `/mnt/davinci`; filling in `mirror` switches on the Seagate's and
retires the ext4 `/mnt/archive`. The mirror job needs both. An assertion stops
the Seagate being both `dataDrives.archive` (LUKS) and `dataPair.mirror`.

- **`/etc/crypttab`**, by `/dev/disk/by-partuuid/<partUuid>`: a VeraCrypt
  volume has no LUKS UUID, and crypttab(5) documents only `UUID=` and device
  paths. Options `tcrypt-veracrypt,nofail,x-systemd.device-timeout=10s`, key
  `/var/lib/desktop-secrets/{data,mirror}.pass`, unlocked after boot (not in
  the initrd). A wrong passphrase fails `systemd-cryptsetup@<name>.service`; a
  missing file makes it ask instead, which nobody sees once the login screen
  is up (`sudo systemd-tty-ask-password-agent --query` answers it).
  `cryptmirror` is also `noauto`: not unlocked at boot, only when the mirror
  job mounts it, and locked again afterwards, so the mirror can't be changed
  by mistake between runs and the SMR drive sits idle.
- **Mounts**, by `/dev/mapper/cryptdata` and `/dev/mapper/cryptmirror`, not
  the NTFS UUID: the mapper name is ours (crypttab), known now and unchanged if
  a volume is ever re-created, while the NTFS UUID only exists after Windows
  formats the volume and would be a second identifier to keep in step.
  NTFS-3G with the DavinciProj options (`nofail`, `noatime`, `norecover`,
  `uid=1000`, `gid=100`, `fmask=0133`, `dmask=0022`, `windows_names`) and
  `x-systemd.device-timeout=1min`, long enough for VeraCrypt's slow unlock (the
  mount gives up after it without retrying).
  - `/mnt/data` is mounted at boot, not automounted: Affinity's Wine sandbox
    and Wine's drive-letter scan need it mounted already.
  - `/mnt/data-mirror` is `noauto`; its NTFS-3G process runs at idle I/O
    priority and nice 19.
- **Home:** `davinci` in `home/devtower-intel.nix` becomes `/mnt/data` once
  `dataPair.data` is filled in, so `~/DavinciProj` and the Affinity
  drive-letter mapping (`davinciDriveLetter`, the letter of the VeraCrypt
  favourite) follow it. Yazi's `g D` / `g a` (`home/modules/file-manager.nix`)
  go to `/mnt/data` and `/mnt/data/Affinity` on any host that mounts
  `/mnt/data`.
- **Mirror job** (`data-mirror.service`), only when both drives are switched
  on:
  1. Starts `/mnt/data` and `/mnt/data-mirror` itself, which unlocks the
     mirror. A mount that fails (for example a volume NTFS-3G refuses) fails
     the job.
  2. Refuses to run unless both are NTFS-3G mounts of their own mapper
     devices (compared by device number), read-write (read-only means Windows
     left that volume hibernated, in Fast Startup or not shut down cleanly),
     `/mnt/data/.data-primary` exists, the mirror has no `.data-primary`, and
     `.mirror-history` is not a link. So an unmounted, empty or swapped drive
     can never make `--delete` empty the mirror.
  3. Deletes `.mirror-history/<YYYY-MM-DD>` folders more than 30 days old,
     before the copy, on every run, whether or not the copy then succeeds.
     Anything else in `.mirror-history` is left alone.
  4. Copies, with `/mnt/data` read-only to the job and only the mirror
     writable:
     `rsync -rtS --delete --backup --backup-dir=.mirror-history/<date> --exclude=/.mirror-history --exclude=/.data-primary --exclude='/System Volume Information' --exclude='/$RECYCLE.BIN' /mnt/data/ /mnt/data-mirror/`.
     Status 24 (files vanished during the copy) is only a warning; any other
     failure logs `df -h` of both drives and fails the job.
  5. Afterwards, whatever happened (a failed mount included), unmounts the
     mirror and then locks it again. If something has `/mnt/data-mirror` open
     at the time, that fails and shows as a failed unit.

  It runs at idle I/O priority and nice 19, daily at 03:30 with up to 30 minutes'
  random delay, and `Persistent=true`, so a day spent in Windows or switched
  off is caught up at the next boot. Run it by hand with
  `sudo systemctl start data-mirror`; read it with `journalctl -u data-mirror`.
- **Health:** smartd, which nothing else in the repository configures, on the
  switched-on drives only (by `byId`): short self-test daily at 02:00, long
  test monthly on the 1st at 03:00, temperature warnings at 45 and 55°C, and
  never spinning up a sleeping drive just to poll it. smartd exits if a listed
  drive is missing. Failures of the mirror job and smartd show in
  `systemctl --failed`.
- **syntek-studio GitHub config** for the repos in `Business/` (see
  [Syntek repos on the data drive](#syntek-repos-on-the-data-drive)):
  `includeIf."gitdir:/mnt/data/Business/".path = "~/.gitconfig-syntek"` in
  `home/modules/git.nix`, beside the existing `~/Repos/syntek/` and
  `/mnt/archive/OldRepos/syntek/` rules. `~/.gitconfig-syntek` sets the
  syntek-studio identity (`Syntek-Studio`, `sam.bailey@syntekstudio.com`) and
  rewrites `git@github.com:` to `git@github-syntek:`, so pushes use the
  per-device syntek key (`~/.ssh/github-devtower-intel-syntek`). Without the
  rule, commits there get the default identity and pushes the wrong key.
  Check with `git config user.email` and `git remote -v` in each repo.

### Syntek repos on the data drive

`syntek-business-docs` and `syntek-content` live in `/mnt/data/Business/`, so
they are on the drive Windows can open and are copied to the mirror every
night. GitHub remains their off-site copy. NTFS changes how they are used:

- **No executable bits** (the mount's `fmask=0133`). Set
  `git config core.fileMode false` in both repos, or every file shows as
  modified. Run scripts as `python script.py` or `uv run …`, not
  `./script.py`.
- **No reliable symlinks**, so Python environments stay off the drive: with
  uv, `UV_PROJECT_ENVIRONMENT=~/.cache/venvs/<repo>` (for example from the
  repo's `.envrc`) keeps the environment on the SSD.
- **Large media in git:** every committed version of a photo or video is kept
  in full. Track them with Git LFS (or keep them beside the repo, outside git)
  so the repos don't grow without limit.
- **Speed:** a hard disk through NTFS-3G (FUSE) is slower than the SSD;
  `git status` over many media files takes noticeably longer.
- **Ownership:** the mount is owned by `sam-desktop` (`uid=1000`), so git's
  safe-directory check passes without exceptions.

**From laptop-intel**, once the WireGuard link and sshd (see [Later](#later))
are in place, the work runs on devtower-intel:

- SSH in, or open the folder with Zed's SSH remote: the Python scripts run on
  devtower-intel against its own drive, so nothing heavy crosses the network.
- The Samba share of `/mnt/data/Business` is for browsing and opening files in
  the laptop's file manager, not for running the scripts.
- Only while devtower-intel is booted into NixOS; when it is in Windows, the
  laptop cannot reach the drive.

## Later

- **Off-site, ciphertext only:** back up `/mnt/data` with client-side
  encryption (for example `rclone crypt` or restic) to Google Drive, later a
  Hetzner Storage Box. Personal and business data in separate encrypted
  repositories with separate keys.
- **Network access:** Samba on NixOS, reachable only over WireGuard, for other
  devices with the right keys. It works only while NixOS is running. Bind it
  to the WireGuard interface only, with SMB3 and encryption required.
- **Remote Docker from laptop-intel** (after the drives are done): a dedicated
  WireGuard link between laptop and PC (for example `wg-lan`, `10.200.0.0/24`,
  keys in agenix, bypassing Mullvad on devtower-intel), and a Docker context
  over SSH: `docker context create devtower --docker host=ssh://sam-desktop@<tunnel IP>`.
  - Containers run on devtower-intel and use `/var/lib/docker` on the 870 EVO.
  - Bind mounts and compose volumes resolve on devtower-intel, so the source
    must live there: edit it with Zed's SSH remote, or mount it on the laptop
    over Samba at the same absolute path.
  - Never share `/var/lib/docker` itself over Samba, and never expose
    `tcp://2375`.
  - First: sshd key-only and listening only on `wg-lan`, and Docker-published
    ports bound to `127.0.0.1` or the tunnel IP (they bypass the NixOS
    firewall today).
- **NAS** as a further backup target, then the homelab and business server.
- **Replacing the Seagate** with a CMR drive (WD Red Plus, Seagate IronWolf):
  create a new VeraCrypt mirror volume on it and run the first mirror copy
  again.
