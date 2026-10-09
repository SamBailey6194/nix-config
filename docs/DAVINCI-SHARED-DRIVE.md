# Sharing DavinciProj between Windows and NixOS

Keep the existing NTFS filesystem on the WD 4TB drive, serial
`WD-WCC7K0FU5LY2`, label `DavinciProj`, UUID `34201009200FD0B2`.
It is `sdc1` today, but device letters change, so the NixOS configuration uses
the UUID. No partitioning, formatting or filesystem conversion is required.
Windows keeps its existing drive letter.

- **Where:** every devtower-intel stage mounts the drive at boot at
  `/mnt/davinci`, using NTFS-3G (`hosts/devtower-intel/hardware-configuration.nix`).
- **Ownership:** files are owned by `sam-desktop` (uid 1000, group `users`).
  Files are 0644 and folders 0755, so only `sam-desktop` can write and nothing
  on the drive is executable.
- **Safety options:**
  - `windows_names` stops Linux creating names Windows cannot open.
  - `norecover` mounts a volume Windows did not shut down cleanly read-only,
    instead of clearing its journal and writing to it.
  - `nofail` means a missing drive never blocks boot.
- **Home folder:** `~/DavinciProj` links to the drive root. In Yazi, `g D` goes
  to the drive and `g a` to its `Affinity` folder.
- **Ubuntu:** the drive has no entry in Ubuntu's fstab and is not mounted there
  today, so there is nothing to undo on that side.

## Before switching operating systems

Close Resolve, Affinity and anything else using the drive, then fully shut down
Windows. Disable Windows Fast Startup in its power settings. Alternatively,
`powercfg /h off` in an administrator terminal disables both hibernation and
Fast Startup; use it only if you also want hibernation off.

If Windows was hibernated, still has Fast Startup on, or crashed or lost
power, NixOS mounts the drive **read-only** (`norecover` covers the crash case).
Boot Windows, let it check the drive, and shut it down fully. Do not force a
read-write mount from Linux. [NTFS-3G's manual](https://github.com/tuxera/ntfs-3g/wiki/Manual)
explains why.

On NixOS, after rebuilding:

```sh
findmnt -o FSTYPE,OPTIONS /mnt/davinci   # fuseblk, rw
stat -c '%U %G %a' /mnt/davinci          # sam-desktop users 755
ls /mnt/davinci
```

If `findmnt` shows `ro`, `journalctl -b -u mnt-davinci.mount` gives the reason
(usually an unclean or hibernated Windows volume).

Confirm the existing folders appear and the mount is writable by `sam-desktop`.
Create and delete a small test file from each operating system before using the
drive for active work. Do not rename existing media folders during the initial
test.

**Case.** Linux can create two names that differ only in case (`Clip.mov` and
`clip.mov`); `windows_names` doesn't prevent it, and Windows then sees only one
of them. Avoid doing that on this drive.

## Suggested layout

Keep whatever already exists. Add folders beside it rather than moving media:

```text
DavinciProj/
├── <existing Resolve media, proxies, exports>
└── Affinity/
    ├── Photo/
    ├── Designer/
    ├── Publisher/
    └── Assets/      exported brushes, assets, macros, palettes
```

## Affinity files

Affinity's documents (`.afphoto`, `.afdesign`, `.afpub`) are the same format on
Windows and Linux, so a folder on this drive works for both.

**Versions must match.**

- NixOS installs Affinity **v2** (2.6.5: Designer, Photo and Publisher, through
  affinity-nix, from the creative stage up). Keep Windows on v2 2.6.x.
- If Windows runs Affinity v3 (Affinity by Canva), the v2 apps cannot open what
  it saves. In that case switch NixOS to affinity-nix's `affinity-v3` package,
  and extend the drive-letter mapping below to the `affinity-v3` prefix.

**Give Affinity the same drive letter as Windows.** Affinity stores absolute
paths for linked (not embedded) images and fonts. Under Wine, `/mnt/davinci` is
normally `Z:\mnt\davinci\...`, which Windows cannot resolve.

1. In Windows Disk Management, note DavinciProj's letter, for example `E:`.
   Pin it there so it doesn't change.
2. Set it, lower case, in `home/devtower-intel.nix`:

   ```nix
   davinciDriveLetter = "e";
   ```

3. Rebuild with no Affinity app open. Wine then treats `/mnt/davinci` as `E:`
   in Designer, Photo and Publisher, so a linked image saved on one OS resolves
   on the other.

**Open and save through the drive's real path.** Use `/mnt/davinci/Affinity`
(Yazi `g a`) or `~/DavinciProj/Affinity`. Never use a symlink to a subfolder,
such as a `~/Affinity` link: Wine works out the drive letter from the path as
written, and a subfolder link records `Z:\home\...` instead. After the first
save, Affinity's Resource Manager should show `E:\Affinity\...`.

**Settings and assets stay per system.** On NixOS they live in
`~/.local/share/affinity`. Move brushes, assets, macros and palettes between the
two by exporting and importing them through `Affinity/Assets`. Embed resources
in a document when you don't need live links.

## Resolve projects and media

DaVinci Resolve Studio 21.1 arrives with the creative stage and uses the NVIDIA
GPU through CUDA.

- **Launching:** use the `resolve` (or `dvr`) alias, which sets
  `QT_QPA_PLATFORM=xcb`. Resolve cannot run as a native Wayland client, and the
  session defaults Qt apps to Wayland, so an app-launcher start may fail.
- **Media Storage:** add `/mnt/davinci` itself, not `~/DavinciProj`.
- **Path mapping:** in Preferences, set up a Mapped Mount pairing `/mnt/davinci`
  with the Windows letter (for example `E:\`). That should let projects moved
  between systems find their media without relinking. This hasn't been tested
  here, so try it with a copy of one project first, and relink by hand if it
  doesn't work.
- **Project libraries:** keep one local library per system. Move projects by
  exporting `.drp` (or `.dra` archives) to this drive and importing on the other
  side. Sharing the filesystem does not create a shared project library.
- **A library already on this drive:** if the Windows project library lives on
  DavinciProj, don't connect NixOS Resolve to it until both systems run the same
  Resolve version and it is backed up. Opening it from a newer Resolve can
  upgrade it beyond what the other side can read.
- **Versions:** match them where possible, and back up a project before
  upgrading.
- **Backup:** keep footage, exports, proxies and exported project files on the
  drive, and back up the project libraries as well. Rendered exports are not a
  backup of an editable timeline.

## Backup and encryption

**DavinciProj is not in the pre-NixOS backup.** The rsync copy (taken
2026-10-07, refreshed 2026-10-09) covers the Ubuntu filesystems only. Installing NixOS doesn't put this drive at risk,
because the install erases only the Intel disk. The risk starts with the first
read-write use from Linux. Back the drive up before then.

Don't put this NTFS partition through the data-drive LUKS conversion procedure
while Windows needs native access. It stays unencrypted under the current plan,
and cross-platform encryption would need its own setup.

Every NixOS stage, minimal included, mounts the drive read-write at boot, so
take this backup from the live installer **before the first NixOS boot**. Shut
Windows down cleanly first, then mount the drive **read-only**:

```sh
sudo -i
nix-shell -p ntfs3g restic
mkdir -p /media/davinci /media/backup
mount -t ntfs-3g -o ro /dev/disk/by-uuid/34201009200FD0B2 /media/davinci
mount /dev/disk/by-uuid/883736aa-556a-4e5e-b42f-e58bd40f5668 /media/backup
findmnt /media/backup              # must show the BackupDrive UUID
export RESTIC_REPOSITORY=/media/backup/davinci-restic
restic init                        # no Restic repository exists yet
restic backup --one-file-system --tag davinci-before-nixos /media/davinci
restic check --read-data
```

- **Check the destination:** if `findmnt` shows nothing, stop. A plain
  unmounted directory is not a backup destination.
- **Check the space:** about 8.1TiB is free after the rsync copy, against at
  most 3.6TiB from this drive. Recheck with `df -h /media/backup`.
- **After the backup:** record the snapshot ID, and test restoring
  representative media and project exports.
