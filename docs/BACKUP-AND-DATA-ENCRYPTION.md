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
| Intel NVMe 256GB (OS) | - | `/`, `/nix`, `/var/log`, `/.snapshots` | `cryptroot` | `@root`, `@nix`, `@log`, `@snapshots` | initrd (already encrypted) |
| Samsung 512GB | `S1X1NYAG302936` | `/home` | `crypthome` | `@home` | initrd (needed for login) |
| Samsung 870 EVO 2TB | `S6PPNX0T910090T` | `/var/lib/docker`, `/var/lib/libvirt/images`, `/srv/clients` | `cryptstore` | `@docker`, `@vm`, `@clients` | after boot, `/etc/crypttab`, `nofail` |

The OS drive keeps the **system** Nix store and every generation. Once `/home`
has moved to the 512GB Samsung and `/var/lib/docker` to the 2TB, the NVMe holds
only the OS; the whole drive uses about 80G today. The old plan, where the 2TB
took over the system `/nix`, is dropped.

The two 4TB drives (WD DavinciProj and the Seagate archive) are **not** LUKS
drives any more. Windows needs them too, so they become a VeraCrypt pair with
NTFS inside, the WD as the working drive and the Seagate as a scheduled mirror
(not RAID1): [SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md). The
`cryptarchive` block in `data-drives.nix` is superseded by that plan; leave
`dataDrives.archive` null.

- **Unlocking:** each drive has its **own LUKS2 container and its own
  passphrase**, plus a TPM2 token, so all of them unlock automatically. If the
  TPM refuses (for example after a firmware or Secure Boot change), you are
  asked for that drive's passphrase: in the initrd for the OS and home drives,
  after boot for the store.
- **Configuration:** `hosts/devtower-intel/data-drives.nix` does the switching.
  A drive changes over when both of its UUIDs are filled in under `dataDrives`
  in `hosts/devtower-intel/disks.nix`. Until then its old Ubuntu filesystem
  stays mounted exactly as before. Filling in only one of the two UUIDs fails
  the build.
- **The old drive ESP goes too:** the Samsung home drive carries an old Ubuntu
  ESP (the 1GB second partition; `sde2` on 13 October, but letters move
  between boots, so go by serial). The whole drive is erased, and
  its firmware boot entry is removed afterwards (home step 11).
- **Always use by-uuid paths** for the OS drive (LUKS UUID
  `3f44cce0-d46f-49ff-bbdf-306ef8a4e7c8`). NVMe numbering can swap with the
  Windows Crucial drive, so `/dev/nvme0n1p2` is not always the Intel disk.

> **Configuration status (13 October 2026).** The configuration for every
> step on this page is merged; nothing more needs writing before converting
> the store. It takes effect for the store once `dataDrives.store` is filled
> in:
>
> - `data-drives.nix`: no `/nix` mount and no initrd unlock for the store. It
>   unlocks after boot from `/etc/crypttab`
>   (`tpm2-device=auto,nofail,discard`) and mounts `@docker`, `@vm` and
>   `@clients` with `nofail`; `docker.service` and `libvirtd` have
>   `RequiresMountsFor` on their directories, and `store-quotas.service`
>   re-applies the caps from `storeQuotas` in `disks.nix` at each boot.
> - `secrets/secrets.nix`: `luks-passphrase-devtower-intel-store.age` is
>   declared but commented out until the store is converted (store step 7).
> - `modules/core/nix-gc.nix`: keeps the newest 5 system generations with no
>   age rule, and prunes every user's home-manager profile to the newest 5 too
>   (shared with laptop-intel).
> - `hosts/devtower-intel/client-store.nix`: the `client-store-guard` checks
>   and the weekly `client-store-gc` service and timer (see
>   [the client store](#client-servers-nix-store-clients)).
> - `justfile`: `just deploy-client <name> <host>`, and
>   `just backup-luks-headers <DEVICE>`, which takes the LUKS UUID or its
>   `/dev/disk/by-uuid/` path and refuses `/dev/sdX` or NVMe names. Its copy
>   lands in `/var/lib/luks-backups` inside `cryptroot`, so the off-disk copy
>   in finishing step 5 is still needed.

**What TPM2 auto-unlock does and doesn't protect.** Every enrolment here binds
to PCR 7 (Secure Boot state). Secure Boot is currently **off**, so PCR 7 reads
the same whatever this PC boots, a live USB included.

- **Protected:** a drive taken out of the PC. Its key only exists inside this
  PC's TPM.
- **Not protected:** someone who can boot this PC from their own USB; the TPM
  will release the keys to them too.
- **Prompts:** NixOS rebuilds don't change PCR 7. A firmware update or a
  Secure Boot change does, so every drive then prompts once until you re-enrol
  it (see the end of the common steps).
- **To close that gap:** enable Secure Boot with signed boot files (for example
  lanzaboote, a separate project), then re-enrol every drive. Until then, the
  passphrases are what protect the whole machine.

Without `--tpm2-pcrs=7`, current systemd binds a token to **no** PCRs at all,
so never leave it out.

**Agenix cannot unlock a drive at boot.** Agenix decrypts secrets during
activation, after the root filesystem is mounted, using the host key that
lives on the encrypted OS drive. So the `luks-passphrase-devtower-intel-*.age`
files are **recovery (escrow) copies only**: they let you read a passphrase on
another machine when the TPM refuses and you don't have it to hand. They must
**not** be declared in `age.secrets`, which would leave the plaintext
passphrase in `/run/agenix`. The recipients are `devtowerIntelKeys` only:
devtower-intel is the authority, and `sam-laptop` is deliberately not a
recipient. On this PC, a copy is decrypted with the master editing key
`~/.ssh/id_ed25519_agenix`, which lives in `/home` and is not copied
anywhere. Off this PC, use the recovery key `sam-keys-recovery` on the KEYS
stick (`agenix/id_ed25519_recovery`, passphrase-protected). It is in
`allUsers`, so it opens every secret, and it is used straight from the stick
(`-i /run/media/<user>/KEYS/agenix/id_ed25519_recovery`), never copied onto a
machine or listed in `age.identityPaths`. If the stick is lost, remove the key
from `allUsers`, rekey, and rotate the secrets that matter: the old `.age`
files stay in git history. A second copy of the stick kept elsewhere is
advisable.

**Rebuilding.** Run rebuilds from the repository as `sam-desktop`. Both forms
pick up the `disks.nix` edits:

- `just rebuild-host devtower-intel` switches straight away.
- `just rebuild-host devtower-intel --boot` applies the change at next boot.

### Order of work

1. **OS drive:** TPM2 auto-unlock, the escrow secret and a header backup
   (next section). No configuration change needed.
2. **Home** on the 512GB Samsung, from the running system.
3. **The 4TB pair**, from the running system and Windows, per
   [SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#conversion). Its restore
   source is the old archive drive itself, so the old home copy on it moves
   with it.
4. **Store** on the 2TB, from the running system (its configuration is
   merged; see the status note above).
5. **Remote Docker from laptop-intel**, once the store is in place: a Docker
   context over SSH through a dedicated WireGuard link (see
   [Remote Docker](#remote-docker-from-laptop-intel-planned)).

None of these needs a live USB.

### OS drive (Intel NVMe): TPM2 and escrow secret

The OS drive is already encrypted, so this only adds automatic unlocking and a
recovery copy of its passphrase. Run it on the full stage (`.#devtower-intel`).

1. **Check the existing tokens and keyslots** first, so you don't enrol twice:

   ```sh
   OS=/dev/disk/by-uuid/3f44cce0-d46f-49ff-bbdf-306ef8a4e7c8
   sudo systemd-cryptenroll "$OS"
   ```

2. **Enrol TPM2** (asks for the current passphrase once):

   ```sh
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$OS"
   ```

3. **Create the escrow secret.** `luks-passphrase-devtower-intel-os.age` is
   already declared in `secrets/secrets.nix`. Paste the passphrase on a single
   line:

   ```sh
   just edit-secret luks-passphrase-devtower-intel-os
   ```

   Check that the stored copy really opens the disk. A piped passphrase ends at
   the first newline, so the editor's trailing newline doesn't matter:

   ```sh
   sudo -v                                          # so sudo doesn't prompt mid-pipe
   (cd secrets && agenix -d luks-passphrase-devtower-intel-os.age -i ~/.ssh/id_ed25519_agenix) \
     | sudo cryptsetup open --test-passphrase "$OS" && echo passphrase ok
   ```

   Commit and push the `.age` file.
4. **Back up the header** to USB, as in finishing step 5 below, with
   `NAME=cryptroot` and `<luksUuid>` `3f44cce0-d46f-49ff-bbdf-306ef8a4e7c8`. The automatic backups in `/var/lib/luks-backups` are inside
   `cryptroot` itself, so they are no use if its header is damaged; only the
   off-disk, age-encrypted copy counts.
5. **Reboot** and confirm there is no passphrase prompt.

### Before converting any drive

1. **Be on the full stage** (`.#devtower-intel`), with the OS drive done as
   above.
2. **Know what the drive needs first.**
   - **Home** needs no live USB: the drive is only a data mount
     (`/mnt/ubuntu-home`), not the running `/home`. Nothing in the
     configuration needs it any more: the GitHub keys come from agenix, and
     `home/modules/mcp-sync.py` falls back to the old `.claude.json` only if it
     exists.
   - **Store** needs no live USB either: nothing else depends on it, and it
     isn't needed to boot.

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

Run these in a root shell (`sudo -i`) on the running system. Replace `SERIAL`,
`NAME` (`crypthome`, `cryptstore`) and `LABEL` (`NIXOS_HOME`, `NIXOS_STORE`)
for the drive in hand.

**1. Identify the drive** by its serial:

```sh
nix-shell -p cryptsetup parted btrfs-progs rsync age util-linux
ls /dev/disk/by-id/*SERIAL                            # the whole-disk path (no -partN)
read -r -p 'Whole-disk by-id path: ' DISK
test "$(udevadm info --query=property --property=ID_SERIAL_SHORT --value --name="$DISK")" = SERIAL || exit 1   # lsblk shows no serial for these SATA disks
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
2. **Enrol TPM2** before the first boot that uses the drive, so it never
   prompts. It asks for the drive's passphrase once:

   ```sh
   systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$PART"
   ```

3. **Create the escrow secret** for the drive with `just edit-secret`, and
   check it with `cryptsetup open --test-passphrase`, as in OS step 3. Never
   add it to `age.secrets`.
4. **Commit the `disks.nix` change** (UUIDs are not secret) and the `.age`
   file, and push them, so a fresh clone or another machine builds the same
   layout.
5. **Back up the LUKS header after enrolling**, because enrolment adds a token
   to the header. Encrypt it and keep it off the drive itself, on USB:

   ```sh
   sudo -i
   nix-shell -p age
   cryptsetup luksHeaderBackup /dev/disk/by-uuid/<luksUuid> --header-backup-file /root/NAME-header
   age -p -o /path/to/usb/NAME-header.age /root/NAME-header
   age -d /path/to/usb/NAME-header.age | cmp - /root/NAME-header && shred -u /root/NAME-header
   ```

   Automatic header backups in `/var/lib/luks-backups` live inside `cryptroot`,
   so only this off-disk copy counts.
6. **Reboot once more** and confirm the drive unlocked without a prompt.

After a firmware update, or if you later enable Secure Boot, PCR 7 changes.
Every drive, the OS disk included, then asks for its passphrase until you
re-enrol it, one command per LUKS UUID:

```sh
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<luksUuid>
```

### Home (Samsung 512GB): first, from the running system

The new `@home` must hold the **NixOS** home (now the `@home` subvolume on the
Intel disk), including the repository with its `disks.nix` edit, plus whichever
Ubuntu personal files you still want. The Samsung is only mounted as
`/mnt/ubuntu-home`, so it can be erased while NixOS runs. The final copy is
made from a text console with the desktop logged out, so nothing is writing to
`/home` while it runs. No live USB and no pending configuration are needed;
`data-drives.nix` already unlocks `crypthome` in the initrd with
`tpm2-device=auto` once `dataDrives.home` is filled in.

1. **Refresh the old home's copy.** It is on the archive drive at
   `/mnt/archive/pre-nixos-home/` (the root of the old filesystem, with
   `sam-dev/` inside). Every stage mounts the old home read-write, so make it
   read-only, bring the copy up to date and check it:

   ```sh
   sudo mount -o remount,ro /mnt/ubuntu-home
   sudo rsync -aHAXSx --numeric-ids /mnt/ubuntu-home/ /mnt/archive/pre-nixos-home/
   sudo rsync -aHAXSx --numeric-ids --checksum --dry-run --itemize-changes /mnt/ubuntu-home/ /mnt/archive/pre-nixos-home/
   ```

   The dry run must list nothing. After this step the Seagate holds the
   **only** copy of the Ubuntu home, and the Seagate is later wiped for
   VeraCrypt; [SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md) moves it to the WD
   first. If anything in it is irreplaceable, put a second copy of that
   somewhere else (another disk, or encrypted off-site) before going on.
2. **Commit and push the repository**, so the work in progress is safe
   whatever happens to either disk. If you haven't yet done the browser
   profile import ([BROWSER-MIGRATION.md](BROWSER-MIGRATION.md)), do it now:
   it reads `/mnt/ubuntu-home`, which disappears with this step.
   `~/.ssh/id_ed25519_agenix`, the master editing key for the secrets, moves
   to this drive; it is not copied offline. The recovery key on the KEYS
   stick covers it, so check first that the stick key alone decrypts a
   secret.
3. **Unmount the old home and erase the drive:** in a `sudo -i` root shell,
   `umount /mnt/ubuntu-home`, then run the common steps 1 to 3 with
   `SERIAL=S1X1NYAG302936`, `NAME=crypthome`, `LABEL=NIXOS_HOME`. It stays
   unmounted until the reboot, so nothing recreates it.
4. **Create the subvolume, enrol TPM2 and make the first copy** while still
   logged in. Most of the data crosses now; the final pass only sends what
   changed since. `-x` keeps rsync on the `/home` filesystem, so FUSE or other
   mounts under `~` aren't copied:

   ```sh
   mount /dev/mapper/crypthome /mnt/new
   btrfs subvolume create /mnt/new/@home
   systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$PART"
   rsync -aHAXSx --numeric-ids --delete /home/ /mnt/new/@home/
   exit; exit                                       # leave nix-shell, then the root shell
   ```

   Leave `/mnt/new` mounted and `crypthome` open for step 7.
5. **Create the escrow secret:** uncomment the
   `luks-passphrase-devtower-intel-home.age` entry in `secrets/secrets.nix`,
   then run `just edit-secret luks-passphrase-devtower-intel-home` and check it
   against `/dev/disk/by-uuid/<home luksUuid>` as in OS step 3.
6. **Switch the configuration over:** `whoami` must print `sam-desktop`. Then
   in `~/Repos/personal/nix-config`, fill in `dataDrives.home` with the two UUIDs
   from common step 3, commit it with the secret, and run
   `just rebuild-host devtower-intel --boot`. **Don't reboot yet.**
7. **Final copy from a text console.** Close every app and log out of
   Hyprland. Press Ctrl+Alt+F3 and log in as `sam-desktop`. Stop Docker, and
   check nothing of yours is still running: `KillUserProcesses` is off, so
   tmux, zellij and similar sessions survive logout, and ClamAV watches
   `/home`:

   ```sh
   sudo systemctl stop docker.socket docker.service
   ps -u sam-desktop -o pid,cmd                     # only this console's shell and ps
   # kill anything left over (tmux kill-server, zellij kill-all-sessions, kill <pid>)
   sudo rsync -aHAXSx --numeric-ids --delete /home/ /mnt/new/@home/
   sudo rsync -aHAXSx --numeric-ids --delete --dry-run --itemize-changes /home/ /mnt/new/@home/
   ```

   The dry run should list nothing, or only shell history and state files from
   this console session. Then check that the `disks.nix` edit made it across,
   and reboot:

   ```sh
   grep -A1 'home = {' /mnt/new/@home/sam-desktop/Repos/personal/nix-config/hosts/devtower-intel/disks.nix
   sudo umount /mnt/new && sudo cryptsetup close crypthome
   sudo systemctl reboot
   ```

8. **Check the result.** `crypthome` unlocks through the TPM2 without a prompt.
   `findmnt /home` shows `/dev/mapper/crypthome[/@home]`, and
   `/mnt/ubuntu-home` is gone. A rebuild made from
   `~/Repos/personal/nix-config` must still have `dataDrives.home` filled in.
9. **Bring back Ubuntu files selectively** from
   `/mnt/archive/pre-nixos-home/sam-dev/` into `~/` (the Ubuntu uid is the
   same, 1000). Don't bring back the agent configs, shell histories or `~/.aws`
   that
   [INSTALL-INTEL-MANUALLY.md](INSTALL-INTEL-MANUALLY.md#7-first-boot-and-staged-upgrade)
   lists. The declarative config and agenix already provide them.
10. **Finish:** do finishing steps 4 and 5 (push, header backup with
    `NAME=crypthome`).
11. **Remove the dead Ubuntu boot entry.** Its ESP was the Samsung's second
    partition, now erased:

    ```sh
    nix-shell -p efibootmgr --run 'efibootmgr -v'    # find the ubuntu entry pointing at the old ESP
    sudo nix-shell -p efibootmgr --run 'efibootmgr -b XXXX -B'
    ```

12. **Only later, delete the Intel `@home`.** Older boot entries still mount
    `/home` from it, so first remove the older generations and rebuild
    (`sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +1`,
    then `just rebuild-host devtower-intel --boot`). Until then it is a
    fallback copy of the NixOS home as it was at the switch-over. To delete it,
    mount the btrfs top level:

    ```sh
    sudo mkdir -p /mnt/top
    sudo mount -o subvolid=5 /dev/mapper/cryptroot /mnt/top
    sudo btrfs subvolume delete /mnt/top/@home
    sudo umount /mnt/top
    ```

### Store (Samsung 870 EVO 2TB): from the running system

The configuration is merged (see the status note above). The system `/nix`
stays on the OS drive; nothing on this drive is mounted as `/nix`.

The 2TB (1.82TiB, about 1,863GiB usable) becomes **one** GPT partition with
**one** LUKS2 container, `cryptstore`, labelled `NIXOS_STORE`. Inside is one
btrfs filesystem with three subvolumes, each capped by a btrfs simple quota:

| Subvolume | Mount | Cap | Holds |
| --- | --- | --- | --- |
| `@docker` | `/var/lib/docker` | 950GiB | images, containers, volumes |
| `@vm` | `/var/lib/libvirt/images` | 450GiB | VM disk images, not copy-on-write (`chattr +C`) |
| `@clients` | `/srv/clients` | 400GiB | client servers' Nix store; old generations cleaned weekly |
| free | - | ~60GiB | btrfs metadata and SSD headroom |

One container rather than three partitions means one passphrase, one TPM2
enrolment, one escrow secret and one header backup, and the caps can be
changed while running. The caps live in `storeQuotas` in
`hosts/devtower-intel/disks.nix`; `store-quotas.service`, a oneshot, re-applies
them at each boot (before Docker and libvirtd), so changing one is a single
number and a rebuild. It fails, rather than setting limits, if a path isn't on
a filesystem with simple quotas enabled.

The store isn't needed to boot. It unlocks after boot from `/etc/crypttab`
with `tpm2-device=auto,nofail,discard`, like the archive pattern, and its
three mounts are plain `nofail` mounts (not automounts).
`store-quotas.service`, `docker.service` and `libvirtd` have
`RequiresMountsFor` on their directories, so if the store isn't there they
fail rather than start against an empty directory on the root drive.

If the TPM2 unlock fails, the passphrase prompt can't be seen once the login
screen is up. Unlock it from a terminal, then start the units that pull the
three mounts in:

```sh
sudo systemd-tty-ask-password-agent --query
sudo systemctl start store-quotas.service docker.service libvirtd.service
```

Docker keeps the
`overlay2` storage driver: the `btrfs` driver would make each layer its own
subvolume, outside the `@docker` cap.

The old Ubuntu `/nix` and Docker partitions on this drive are erased. Their
only copy was on BackupDrive (`filesystems/nix`, `filesystems/docker`), which is
not usable, so erasing them accepts that loss. Nothing in them is needed by the
configuration.

1. **Copy out anything you still want** from `/mnt/ubuntu-nix` and
   `/mnt/ubuntu-docker`.
2. **Shut down any running VMs, stop Docker and libvirt, and unmount the old
   partitions:**

   ```sh
   sudo virsh list --all                                  # every VM must be "shut off"
   sudo systemctl stop docker.socket docker.service libvirtd.service
   sudo umount /mnt/ubuntu-nix /mnt/ubuntu-docker
   ```

3. **Erase and format:** in a `sudo -i` root shell, run the common steps 1 to 3
   with `SERIAL=S6PPNX0T910090T`, `NAME=cryptstore`, `LABEL=NIXOS_STORE`.
4. **Enable simple quotas straight away**, before writing any data: a simple
   quota only accounts for extents written after it is enabled (kernel 6.18
   supports it). Then create the subvolumes and caps:

   ```sh
   mount /dev/mapper/cryptstore /mnt/new
   btrfs quota enable --simple /mnt/new
   btrfs subvolume create /mnt/new/@docker
   btrfs subvolume create /mnt/new/@vm
   btrfs subvolume create /mnt/new/@clients
   btrfs qgroup limit 950G /mnt/new/@docker
   btrfs qgroup limit 450G /mnt/new/@vm
   btrfs qgroup limit 400G /mnt/new/@clients
   chattr +C /mnt/new/@vm                            # while empty: new images inherit No_COW
   install -d -o sam-desktop -g users /mnt/new/@clients/nix-root   # plain directory, inside the @clients cap
   touch /mnt/new/@clients/.client-store             # the weekly clean-up refuses without it
   ```

5. **Enrol TPM2** (common finishing step 2):
   `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$PART"`.
6. **Copy the existing Docker data** from the Intel `@docker` through the btrfs
   top level (or skip this and re-pull images later). Move any VM images
   already in `/var/lib/libvirt/images` the same way; rsync writes new files,
   so they pick up No_COW:

   ```sh
   mkdir -p /mnt/top
   mount -o subvolid=5 /dev/mapper/cryptroot /mnt/top
   rsync -aHAXS --numeric-ids /mnt/top/@docker/ /mnt/new/@docker/
   test ! -d /var/lib/libvirt/images || rsync -aHAXS --numeric-ids /var/lib/libvirt/images/ /mnt/new/@vm/
   umount /mnt/top /mnt/new
   exit; exit                                        # leave nix-shell, then the root shell
   ```

7. **Create the escrow secret:** uncomment the
   `luks-passphrase-devtower-intel-store.age` entry in `secrets/secrets.nix`,
   then run `just edit-secret luks-passphrase-devtower-intel-store` and check
   it against `/dev/disk/by-uuid/<store luksUuid>` as in OS step 3.
8. **Switch the configuration over:** as `sam-desktop`, fill in
   `dataDrives.store`, commit it with the secret, and run
   `just rebuild-host devtower-intel --boot`. Don't restart Docker; reboot.
9. **Check the result.** No prompt at boot or after. Then:

   ```sh
   for m in /var/lib/docker /var/lib/libvirt/images /srv/clients; do findmnt "$m"; done
   #   each /dev/mapper/cryptstore[/@...]; one findmnt per path, because with
   #   two or more paths findmnt reads them as source and target, and prints nothing
   sudo btrfs qgroup show -re /var/lib/docker                    # three limits, usage counted
   lsattr -d /var/lib/libvirt/images                             # shows C
   systemctl status store-quotas.service docker.service libvirtd.service
   ```

10. **Finish:** finishing steps 4 and 5 (push, header backup with
    `NAME=cryptstore`).
11. **Only later, delete the Intel `@docker`**, once Docker on the store has
    run for a while: mount `subvolid=5` as in home step 12, then
    `sudo btrfs subvolume delete /mnt/top/@docker`. Any VM images copied in
    step 6 also still sit on `@root`, hidden under the new mount; remove them
    from `/mnt/top/@root/var/lib/libvirt/images/` at the same time.

#### Client servers' Nix store (`@clients`)

Client servers are built into a **separate** Nix store at
`/srv/clients/nix-root`, never the system `/nix`. `nix-root` is a plain
directory inside `@clients`, not a nested subvolume, so the 400GiB cap on
`@clients` covers it. It is never deleted and re-created. Keep it owned by one
account (`sam-desktop`): builds as root would use the nixbld users and root
ownership, which mix badly with builds as the normal user.

Building with a plain `nixos-rebuild --target-host` would put the closure in
the system store on the NVMe instead, where the weekly GC removes it.
`nixos-rebuild` has no `--store` option, and `--store-path` copies from the
host `/nix`, so it can't deploy from this store.

This is implemented in `hosts/devtower-intel/client-store.nix` (imported by
the full stage) and the `deploy-client` recipe in the `justfile`. Neither does
anything until `dataDrives.store` is filled in.

**Deploying.** From the repository, as `sam-desktop` (the owner of
`nix-root`), never with `sudo`:

```sh
just deploy-client <name> <host> [--key FILE | --no-check-sigs]
```

`<name>` is both `nixosConfigurations.<name>` and the server's profile in the
client store; `<host>` is whatever `ssh root@<host>` reaches. Each server's
profile is `/srv/clients/nix-root/nix/var/nix/profiles/clients/<name>`, and
the garbage collector treats every profile there as a root. The recipe always
gives it by its physical path (under `/srv/clients/nix-root`), never as
`/nix/var/nix/profiles/...`, which is the host's own profile directory.

Locally built paths are unsigned, so the server refuses them unless they are
signed with a key it trusts (public key in the clients'
`trusted-public-keys`, which suits the zero-trust model). The recipe signs
with `--key FILE`, or by default with `~/.config/nix/client-store-signing.key`;
if that doesn't exist it stops before building. `--no-check-sigs` copies
unsigned instead, which the server accepts only because the copy runs as
root there. The two options can't be combined.

Before building, the recipe runs `client-store-guard --no-db` (the same
realpath, `findmnt` and marker checks as the weekly clean-up below, without
the `nix/var/nix/db` check, as the first deploy creates the store), so it
never builds onto the root filesystem when `@clients` isn't mounted. It
creates the shared lock `/srv/clients/.client-store.lock` if it is missing
(with `sudo`, owned by `sam-desktop`, mode 0644, as `@clients`' top level
belongs to root) and holds it from the build to the profile switch, waiting
if a clean-up has it. Then:

1. It builds with a pending GC root, so a clean-up can't collect the result:

   ```sh
   S=/srv/clients/nix-root
   nix build --store $S --out-link $S/nix/var/nix/gcroots/clients-pending/<name> \
     .#nixosConfigurations.<name>.config.system.build.toplevel
   ```

2. It signs (unless `--no-check-sigs`), copies to the server and activates
   there:

   ```sh
   P=$(readlink $S/nix/var/nix/gcroots/clients-pending/<name>)
   nix store sign --store $S -k <key> -r "$P"
   nix copy --from $S --to ssh://root@<host> "$P"
   ssh root@<host> nix-env -p /nix/var/nix/profiles/system --set "$P"
   ssh root@<host> systemd-run ... "$P"/bin/switch-to-configuration switch
   ```

   Activation runs on the server under `systemd-run` (unit
   `deploy-client-switch-to-configuration`), as `nixos-rebuild` does, so a
   dropped SSH connection (activation may restart networking, the firewall
   or `sshd`) doesn't kill it part-way. Without `systemd-run` on the server
   it runs `switch-to-configuration` directly.
3. Only on success, it records the generation and drops the pending root:

   ```sh
   nix-env --store $S -p $S/nix/var/nix/profiles/clients/<name> --set "$P"
   rm $S/nix/var/nix/gcroots/clients-pending/<name>
   ```

A deploy that fails part-way leaves the **client-store profile** on the
previous generation; the server itself may already have switched to the new
system (its system profile is set before activation). The pending root keeps
the new build until the next deploy of that server replaces it.

If you ever use `nix build --profile` by hand instead, add `--no-link`:
otherwise it also writes `./result` links and registers them as GC roots.

**Rollback lives on each server.** The server's own
`/nix/var/nix/profiles/system` keeps its generations and boot entries, so
rolling a server back happens on the server. The client store only keeps what
is needed to deploy each server's current system.

**The guard.** `client-store-guard` (on the system path) holds every safety
check in one place, so the clean-up and `deploy-client` never drift apart. It
refuses unless all of these hold:

- `realpath -e /srv/clients/nix-root` exists and is not `/`, `/nix` or
  anything under `/nix/`;
- `findmnt -no SOURCE /srv/clients` is `/dev/mapper/cryptstore[/@clients]`;
- the marker `/srv/clients/.client-store` exists;
- `/srv/clients/nix-root/nix/var/nix/db` exists (`--store` on a missing
  directory silently creates a new, empty store); `--no-db` skips only this.

**Weekly clean-up.** `client-store-gc.service`, started weekly by its timer
(`Persistent=true`, so a missed run catches up), keeps each server's current
generation and removes the rest. It has `RequiresMountsFor=/srv/clients`, so
a catch-up run at boot waits for the store to unlock. Its `ExecStartPre` runs
as root: it runs the guard, then creates `/srv/clients/.client-store.lock` if
it is missing (owned by `sam-desktop`, group `users`, mode 0644), never on the
root filesystem because the guard has passed. The main step runs as
`sam-desktop` at low CPU and I/O priority: the guard again, then the shared
lock (`flock`, also held by `deploy-client` from the build to the profile
switch), then, always with an explicit `--store`:

```sh
for p in "$S"/nix/var/nix/profiles/clients/*; do
  case "$p" in *-link) continue ;; esac     # skip the <name>-N-link generations
  [ -L "$p" ] || continue                   # also skips an unmatched glob
  nix profile wipe-history --store "$S" --profile "$p"
done
nix store gc --store "$S"
```

`wipe-history` deletes every generation of a profile except the current one;
the GC then removes everything unrooted in the client store only. It never
uses `nix-collect-garbage -d`, which looks for the host's profiles, and it
never touches the system `/nix`. No `fuser` check is needed: the GC uses the
client store's own lock and temporary roots, and a GC during a build is safe.

Two side effects, neither of which deletes too much: runtime roots are read
from the host's `/proc`, so a store path that some host process is using
(the nixpkgs source, for example) is kept; and Nix's automatic low-space GC
(`min-free`) also runs on this store, but measures the free space of the
whole btrfs filesystem, probably not the `@clients` cap (not tested).

NixOS VMs don't use this: each keeps its own store inside its disk image in
`@vm`.

#### Generations and garbage collection

`modules/core/nix-gc.nix` (shared with laptop-intel) keeps the newest 5
system generations, matching the 5-entry boot menu, with no age rule, and
prunes every user's home-manager profile to the newest 5 too, as that profile's
owner. The weekly GC still removes
anything without a GC root, which is why client builds that do land in the
system store don't accumulate.

### Remote Docker from laptop-intel (planned)

After the store is in place, laptop-intel can use Docker on this PC through a
Docker context over SSH:

```sh
docker context create devtower --docker host=ssh://sam-desktop@<tunnel IP>
```

- **Link:** a new dedicated WireGuard tunnel between the laptop and devtower
  (for example `wg-lan`, `10.200.0.0/24`), keys in agenix, with a Mullvad
  bypass on devtower. Containers run on devtower and use `/var/lib/docker` on
  the store.
- **Source files:** bind mounts and compose volumes resolve on devtower, so the
  source must live there. Edit it with Zed's SSH remote, or mount a Samba share
  at the same absolute path on the laptop. Samba listens on `wg-lan` only,
  SMB3 with encryption required.
- **Never** share `/var/lib/docker` itself over Samba, and never expose
  `tcp://2375`.
- **Prerequisites:** `sshd` key-only and only on `wg-lan`, and Docker-published
  ports bound to `127.0.0.1` or the tunnel IP. Published ports bypass the
  NixOS firewall today.

### What a LUKS header backup is not

A LUKS header is not a backup of the data. Mounting an unencrypted drive from
NixOS does not encrypt it. The rsync copy on BackupDrive is plaintext; keep it
physically secure, and don't format BackupDrive while it holds the only copy of
anything. The two 4TB drives use VeraCrypt instead of LUKS so Windows can
read them ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md)).
