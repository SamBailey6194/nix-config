# Sharing DavinciProj between Windows and NixOS

Keep the existing NTFS filesystem on the WD 4TB drive, serial
`WD-WCC7K0FU5LY2`, label `DavinciProj`, UUID `34201009200FD0B2`.
The current partition name is `sdc1`; the NixOS configuration uses its UUID.
It mounts on demand at `/mnt/davinci` using NTFS-3G, with read/write ownership
for UID 1000 (`sam-desktop`). Windows continues using its existing drive letter.
No partitioning, formatting or filesystem conversion is required.

The mount uses `windows_names` to prevent Linux from creating names incompatible
with Windows, and `nofail` so an unavailable drive does not block boot. It does
not use a force-mount or hibernation-removal option.

## Before switching operating systems

Close Resolve and other programs using the drive, then fully shut down Windows.
Disable Windows Fast Startup in its power settings. Alternatively, running
`powercfg /h off` in an administrator terminal disables both hibernation and
Fast Startup; use this only if you also want hibernation disabled.
[NTFS-3G's manual](https://github.com/tuxera/ntfs-3g/wiki/Manual) explains why
hibernated Windows volumes must not be written from Linux.
If Linux refuses a read/write mount, boot Windows, check the drive there and
shut it down cleanly. Do not force the Linux mount.

On NixOS, after rebuilding:

```sh
ls /mnt/davinci
findmnt /mnt/davinci
stat -c '%U %G %a' /mnt/davinci
```

Confirm the existing folders appear and the mount is writable by `sam-desktop`.
Check a small disposable file from each operating system before using the drive
for active work. Do not rename existing media folders during the initial test.
No mount or read/write test has been performed on the current Ubuntu host.

## Resolve projects and media

Add `/mnt/davinci` to Resolve's media storage locations on NixOS. Windows paths
use a drive letter and Linux paths use this mount directory, so relink media
or set appropriate path mappings when opening transferred projects. Match the
Resolve versions where possible and back up a project before a version upgrade.

Keep footage, exports, proxies and exported `.drp` project files on the shared
drive. Export/import projects through Resolve when transferring between local
project libraries. Sharing the filesystem alone does not establish a shared
Resolve project library or automatically reconcile Windows and Linux paths.
Back up the actual project library as well as the media drive: exported renders
are not a backup of your editable timeline.

## Backup and encryption

Do not put this NTFS partition through the Ubuntu data-drive LUKS conversion
procedure if Windows needs native access. The shared drive remains unencrypted
under the current plan. Encrypting the OS and other data drives does not change
that; cross-platform encryption would require its own selected setup.

You can back up this drive to the encrypted Restic repository on BackupDrive.
After a clean Windows shutdown, mount it **read-only** in the live installer:

```sh
nix-shell -p ntfs3g restic
mkdir -p /media/davinci
mount -t ntfs-3g -o ro /dev/disk/by-uuid/34201009200FD0B2 /media/davinci
export RESTIC_REPOSITORY=/media/backup/ubuntu-before-nixos-restic
restic backup --one-file-system --tag davinci-before-nixos /media/davinci
restic check --read-data
```

Confirm `/media/backup` is the independently identified BackupDrive first; a
plain unmounted directory is not a backup destination. Record this snapshot ID
separately from the Ubuntu snapshot. Test restoring representative media and
project exports. The maximum size of this 3.6TiB filesystem plus the observed
1.55TiB Ubuntu data fits within BackupDrive's observed 8.6TiB free, but recheck
space as backups accumulate.
