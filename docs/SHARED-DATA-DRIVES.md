# Shared encrypted data drives (VeraCrypt pair)

The two 4TB hard drives hold personal and business documents, photos and
videos, plus the working files for Affinity, DaVinci Resolve and the Craft
apps (PhotoCraft, VectorCraft, ...). Windows (dual-boot on this PC) and NixOS both need them, so each one
gets a **VeraCrypt** volume with **NTFS** inside, and NixOS keeps the second
drive as a scheduled one-way mirror of the first.

This is the plan as of 12 October 2026. The procedure below is done by hand;
the NixOS configuration for it (unlock, mounts, mirror timer) is still to be
written, see [Configuration to add](#configuration-to-add).

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
    comes from a root-only file on the encrypted OS disk, so it unlocks at boot
    without a prompt, with the same trust as the TPM2 tokens: whoever can
    unlock the OS disk can read it.
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
- **Windows:** install VeraCrypt, and check Fast Startup is off.
- **Passphrases:** choose one per volume and store them in your password
  manager and offline before typing them in.
- **USB stick** for the VeraCrypt header backups.

### 1. Copy DavinciProj to the archive drive (NixOS)

Shut Windows down fully first. Close Resolve and Affinity, and make the drive
read-only so nothing changes after the copy (a mount that is already read-only
because Windows was hibernated or unclean is fine too):

```sh
sudo mount -o remount,ro /mnt/davinci
D=$(date +%F)
sudo rsync -rtS /mnt/davinci/ /mnt/archive/davinciproj-$D/
sudo rsync -rtS --checksum --dry-run --itemize-changes /mnt/davinci/ /mnt/archive/davinciproj-$D/
```

The dry run must list nothing.

### 2. Create the VeraCrypt volume on the WD (Windows)

1. Before opening anything else, in Disk Management find the WD (3.64TB,
   DavinciProj), note its disk number and drive letter, and remove the drive
   letter from the old NTFS partition. Don't open Resolve or Affinity in
   Windows until the new volume is mounted: anything saved to the old
   partition now is lost in the format.
2. VeraCrypt → **Create Volume** → **Encrypt a non-system partition/drive** →
   **Standard VeraCrypt volume** → select that disk's partition
   (`\Device\HarddiskN\Partition1`, check the size).
3. Choose **Create encrypted volume and format it**, not "Encrypt partition in
   place".
4. AES with SHA-512 (both supported by cryptsetup on Linux), the WD's
   passphrase, default PIM, **files larger than 4GiB: yes**, filesystem
   **NTFS**, and leave **Quick Format off**. The full format fills the whole
   drive with ciphertext, overwriting the old plaintext. Expect several hours.
5. If Windows says the disk needs formatting, **always choose Cancel**. It is
   seeing the encrypted partition without VeraCrypt.
6. Mount it in VeraCrypt at the letter DavinciProj had, then **Favorites → Add
   Mounted Volume to Favorites**: tick "Mount selected volume upon logon" and
   give it the label `Data`.
7. **Tools → Backup Volume Header** to the USB stick.
8. Shut Windows down fully.

The old `/mnt/davinci` NTFS mount no longer finds its UUID; it is `nofail`, so
NixOS boots normally.

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

The archive contents now exist only on the WD. Still in the root shell:

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

### 5. Create the mirror's VeraCrypt volume (Windows)

As step 2, on the Seagate's new partition, with the Seagate's passphrase and a
full format. If Windows has given the new partition a drive letter, remove it
in Disk Management first. Don't add it as a logon favourite. Back up its header too, then
shut Windows down fully.

### 6. First mirror copy (NixOS)

```sh
sudo -i
nix-shell -p cryptsetup ntfs3g rsync util-linux
# open and mount cryptdata as in step 3, then:
MIRROR=$(ls /dev/disk/by-id/ata-*ZFN2J51Q-part1)
cryptsetup open --type tcrypt --veracrypt "$MIRROR" cryptmirror
mkdir -p /mnt/data-mirror
mount -t ntfs-3g -o windows_names,norecover,uid=1000,gid=100,fmask=0133,dmask=0022 /dev/mapper/cryptmirror /mnt/data-mirror
rsync -rtS --delete --exclude=/.data-primary /mnt/data/ /mnt/data-mirror/
rsync -rtS --delete --exclude=/.data-primary --checksum --dry-run --itemize-changes /mnt/data/ /mnt/data-mirror/
```

The dry run must list nothing. From here the two drives are the only copies of
the archive, so the off-site backup (below) is the next priority.

## Configuration to add

To be implemented in `hosts/devtower-intel/` once the drives are converted:

- **Passphrase files** in `/var/lib/desktop-secrets/` (root, `0400`), one per
  volume.
- **`/etc/crypttab`** entries, by partition UUID (`blkid -s PARTUUID`), since a
  VeraCrypt volume has no LUKS UUID:
  `cryptdata PARTUUID=<…> /var/lib/desktop-secrets/data.pass tcrypt-veracrypt,nofail,x-systemd.device-timeout=10s`,
  and the same for `cryptmirror`.
- **Mounts:** `/mnt/data` mounted at boot (Affinity's Wine sandbox needs it
  already mounted), `/mnt/data-mirror` on demand, both with the DavinciProj
  NTFS-3G options. Point `davinci`/`davinciDriveLetter` in
  `home/devtower-intel.nix` and the Yazi `g D` / `g a` keys at `/mnt/data`.
- **Retire** the `/mnt/davinci` mount in `hardware-configuration.nix`, the
  archive blocks in `data-drives.nix` and `archive`/`archiveUuid`/`davinciUuid`
  in `disks.nix`.
- **Mirror job:** a systemd service and daily timer (`Persistent=true`, so a
  day spent in Windows is caught up at the next boot) running
  `rsync -rtS --delete --backup --backup-dir=.mirror-history/<date> --exclude=/.mirror-history --exclude=/.data-primary`,
  then deleting `.mirror-history` folders older than 30 days. It refuses to run
  unless both paths are mounted from the expected mapper devices and
  `/mnt/data/.data-primary` exists, so an unmounted or empty working drive can
  never wipe the mirror.
- **Health:** smartd on both drives. The mirror job's failures show in
  `systemctl --failed`.
- **syntek-studio GitHub config** for the repos in `Business/` (see
  [Syntek repos on the data drive](#syntek-repos-on-the-data-drive)): add
  `includeIf."gitdir:/mnt/data/Business/".path = "~/.gitconfig-syntek"` to
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
