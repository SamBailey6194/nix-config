# Sharing DavinciProj between Windows and NixOS

> **Being replaced (13 October 2026):** this drive becomes the working half of
> an encrypted VeraCrypt pair with the Seagate archive drive, mounted at
> `/mnt/data` instead of `/mnt/davinci`
> ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md)). The configuration is
> written (`hosts/devtower-intel/data-pair.nix`): once `dataPair.data.partUuid`
> is filled in to `disks.nix`, `/mnt/davinci` is no longer mounted,
> `~/DavinciProj` goes to `/mnt/data`, `g D` to `~/Data` (the same drive bound
> into the home folder) and Yazi's `g a` to `~/Data/business/design`. The
> Windows rules, the Affinity drive-letter mapping and the Resolve advice below
> still apply after the move (use `/mnt/data` wherever this page says
> `/mnt/davinci`); the volume gains per-area folders
> ([layout](SHARED-DATA-DRIVES.md#suggested-layout)), and Affinity and Resolve
> work moves into them as described below.

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
  to the drive and `g a` to an `Affinity` folder on it (not created; on the
  data volume `g a` goes to `business/design`).
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

Keep whatever already exists (`Databases/`, `Media/`, `Projects/`,
`Renders/`) and don't move it with a file manager. On the data volume the
layout is per area, `business/` and `personal/`
([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#suggested-layout)); the parts
for these apps:

```text
<volume root>/
├── Databases/ Media/ Projects/ Renders/   existing, until moved in Resolve
└── <area>/          business/ or personal/
    ├── assets/      logos, fonts, icons, reusable graphics; exported Affinity assets
    ├── design/      Affinity (.afphoto, .afdesign, .afpub) and Craft image files
    ├── film/
    │   ├── resolve-library/   this area's Resolve project library
    │   ├── projects/          FilmCraft and EffectCraft project files
    │   ├── media/             source footage
    │   └── renders/           work-in-progress renders
    ├── photos/      finished images
    └── videos/      finished videos
```

There is no `Affinity/` folder on the drive today; Affinity files start in
`<area>/design/`.

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

The letter maps the volume root, so on the data volume a file in
`business/design/` is `E:\business\design\...` on both systems.

**Open and save through the drive's real path.** On the data volume use
`~/Data/<area>/design` (Yazi `g a` for business), `/mnt/data/<area>/design`
or `~/DavinciProj/<area>/design`; `~/Data` is a bind mount of the root, not
a link. Never use a symlink to a subfolder, such as a `~/Affinity` link: Wine
works out the drive letter from the path as written, and a subfolder link
records `Z:\home\...` instead. After the first save, Affinity's Resource
Manager should show `E:\business\design\...`; if it shows `Z:\...`, open the
file through `/mnt/data` instead.

**Settings and assets stay per system.** On NixOS they live in
`~/.local/share/affinity`. Move brushes, assets, macros and palettes between the
two by exporting and importing them through `<area>/assets/`. Embed resources
in a document when you don't need live links.

## Resolve projects and media

DaVinci Resolve Studio 21.1 arrives with the creative stage and uses the NVIDIA
GPU through CUDA.

- **Launching:** use the `resolve` (or `dvr`) alias, which sets
  `QT_QPA_PLATFORM=xcb`. Resolve cannot run as a native Wayland client, and the
  session defaults Qt apps to Wayland, so an app-launcher start may fail.
  Start it from the Hyprland session (alias or launcher), not through
  `systemd-run --user`: the systemd user environment has no `XCURSOR_THEME`
  or `XCURSOR_SIZE`, and Resolve then draws an oversized fallback cursor.
- **Media Storage:** add `/mnt/davinci` itself, not `~/DavinciProj`. On the
  data volume, add `~/Data` (a bind mount of the root, so not a link). Keep an
  SSD folder (`~/Videos`) first: Resolve caches to the first location.
- **Path mapping:** in Preferences → System → Media Storage → Mapped Mounts,
  give the `~/Data` (or `/mnt/davinci`) row the Windows letter, `F:\` on the
  data volume, and on Windows give `F:\` the Linux path, so the same media
  path means the same file on both systems. Resolve stores it per storage
  location as `Site.1.FS.<n>.MappedRoot` in `configs/config.dat`; if that is
  empty after **Save**, the mapping was not kept and clips stay offline.
  Relinking by hand works too, but it rewrites the clip paths for the system
  you relink on, so the other one then needs its mapping (or a relink).
  The mapping between the two systems is not yet confirmed from the Windows
  side ([WINDOWS-DATA-DRIVES.md](WINDOWS-DATA-DRIVES.md#8-back-in-nixos)).
- **Project libraries:** on the data volume, one disk-database library per
  area, in `<area>/film/resolve-library/`, with that area's footage in
  `<area>/film/media/`, work-in-progress renders in `<area>/film/renders/`
  and finished videos in `<area>/videos/`; both systems add the same library.
  Before the move, keep one local library per system and move projects by
  exporting `.drp` (or `.dra` archives) to this drive and importing on the
  other side. Sharing the filesystem does not by itself create a shared
  project library.
- **Cache and proxies on the SSD:** point the render cache, optimised media
  and proxy media (Preferences, Media Storage, and the project's Master
  Settings) at a folder on the SSD, not `film/`. They change constantly,
  Resolve can rebuild them, and they are slow on the hard disk. If any land on
  the drive, exclude them from the mirror and the backups.
- **A library already on this drive:** if the Windows project library lives on
  DavinciProj, don't connect NixOS Resolve to it until both systems run the same
  Resolve version and it is backed up. Opening it from a newer Resolve can
  upgrade it beyond what the other side can read.
- **Versions:** match them where possible, and back up a project before
  upgrading.
- **Backup:** keep footage, exports and exported project files on the drive,
  and back up the project libraries as well. Rendered exports are not a backup
  of an editable timeline.

### Moving projects into an area

The existing `Databases/`, `Media/`, `Projects/` and `Renders/` stay at the
volume root until they are moved from inside Resolve, so it keeps track of
every path. Move each project once, on either system, then add the library
on the other:

1. Close every other app using the drive, and back up the existing library
   (from the Project Manager's library list, or a copy of `Databases/` with
   Resolve closed).
2. **Project Manager:** add the area's library, a disk database in
   `<area>/film/resolve-library/`.
3. Move each project into it (export `.drp` from the old library and import
   it into the new one), choosing the area by who it is for.
4. Move its footage into `<area>/film/media/` and **relink** it in the Media
   Pool; renders still needed go to `<area>/film/renders/` or, finished,
   `<area>/videos/`.
5. On the other OS, add the same library (with the mapped mount above), open
   one moved project and check its media is online before moving the next.

Once a root folder is empty in both systems, delete it.

## Backup and encryption

**DavinciProj is not in the pre-NixOS backup.** The rsync copy (taken
2026-10-07, refreshed 2026-10-09) covers the Ubuntu filesystems only, and
BackupDrive is not usable at the moment.

Don't put this NTFS partition through the data-drive LUKS conversion procedure:
Windows can't read LUKS. It is encrypted with VeraCrypt instead, as described in
[SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md). Its step 1 is this drive's
backup: a read-only remount, a copy to the archive drive and a checksum
comparison, before anything is erased.

The earlier plan, a Restic repository on BackupDrive taken from the live
installer before the first NixOS boot, no longer applies: NixOS has been
running on this drive since, and BackupDrive can't be mounted.
