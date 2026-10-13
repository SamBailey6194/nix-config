# Preserving this desktop during migration

Inventory first observed on 2026-10-05 and rechecked on 2026-10-08. Usage was
checked again on 2026-10-09: only `/nix` had changed materially, and the other
figures still hold. Device letters can change: verify model, serial, size and
UUID from a live installer before selecting any target. No disk has been
formatted or installation started by these configuration edits.

Read alongside:

- [Manual Intel installation](INSTALL-INTEL-MANUALLY.md): the step-by-step
  procedure this page plans for.
- [The live-backup review](LIVE-BACKUP-SCRIPT.md): how the rsync copy you took
  is verified and used during installation.
- [The shared DavinciProj drive](DAVINCI-SHARED-DRIVE.md): DaVinci Resolve and
  Affinity files shared with Windows.

| Drive / serial | Current use | Filesystem UUID |
| --- | --- | --- |
| Intel 256GB / PHHH93710CN8256B | Ubuntu root (ext4), ~41GiB used | `e9605dca-3609-4cd7-be0b-cfac0661111e` |
| Same Intel | Ubuntu EFI | `27BE-92E7` |
| Same Intel | Ubuntu swap | `6b9a7bb1-febe-475f-9c98-5dfda3e97d4d` |
| Samsung 512GB / S1X1NYAG302936 | Ubuntu `/home`, ~282GiB used | `8eaacce9-a3bd-4e95-924c-feb9e2d050b4` |
| Samsung 870 EVO 2TB / S6PPNX0T910090T | Ubuntu `/nix`, ~109GiB used (grows with builds) | `af95812e-4174-4c02-94fd-a142a7981165` |
| Same Samsung 870 EVO | Docker, ~9GiB used | `0bb16801-79b4-435d-b8f6-646e3e12b38c` |
| Seagate ST4000DM004 4TB / ZFN2J51Q | Archive, ~123GiB used | `9f544f15-8e9a-45de-9951-d84f51b62e57` |
| WD WD40EZRZ 4TB / WD-WCC7K0FU5LY2 | DavinciProj (NTFS, shared with Windows) | `34201009200FD0B2` |

The `/nix` and Docker figures dropped from ~716GiB and ~444GiB after the
deliberate clean-up on 2026-10-06. `/nix` has since grown back with new builds:
~57GiB on 2026-10-08 and ~109GiB on 2026-10-09.

The independent **BackupDrive** is a separate Seagate: Backup+ Hub BK, serial
`NA9R0S9H`, 10TB (9.1TiB), ext4 UUID `883736aa-556a-4e5e-b42f-e58bd40f5668`.
Don't confuse it with the Seagate archive drive above, which was a backup
**source**. Its device letter changes each time it is attached.

Other drives contain Windows, games and recovery data. Preserve them too:

- Crucial P3 1TB: Windows EFI `8C32-B143`, Windows `FAC43471C434326D`,
  Windows recovery `FA2CEE802CEE3773`, Games_1 `CC64454F64453E08`.
- Samsung 860 QVO 1TB: Games_2 `E87AFC317AFBF9E0`.
- Old Ubuntu ESPs: Samsung home EFI `244E-5B6F` and archive EFI `2537-6BE7`.

## Backup status

The pre-NixOS backup is **taken; only the offline comparison is outstanding**.

- **What:** the unencrypted rsync copy made by `~/backup-before-nixos.sh`, not
  the encrypted Restic repository the installation guide's section 2 describes.
  No Restic repository exists.
- **Where:** `pre-nixos-2026-10-05/` on BackupDrive (`/media/backup` in the live
  installer). On Ubuntu the script needs it at `/mnt/backup`, but Ubuntu has no
  fstab entry for it and automounts it at `/media/sam-dev/BackupDrive` instead
  ([mounting it](LIVE-BACKUP-SCRIPT.md#before-running-it)).
- **When:** unit `pre-nixos-backup`, 2026-10-07 07:13 to 11:51. It reported
  `COPY FINISHED`, with no vanished-file or `INCOMPLETE` warnings. The same
  script refreshed the copy in place on 2026-10-09, 10:37 to 11:41 (run
  directly with `sudo`, not as a unit), again ending `COPY FINISHED` with no
  warnings.
- **Contents (2026-10-09):** root 46.2G (including `/etc/nixos-migration`),
  archive 122.5G, home 336.0G, Nix 118.2G, Docker 9.4G, Ubuntu EFI, plus images
  of the two other Ubuntu ESPs. rsync ran without `--delete`, so files deleted
  on Ubuntu between the two runs are still in the copy.
- **Not included:** DavinciProj, Windows and the games drives.
- **Databases not preserved:** MariaDB and PostgreSQL were running during the
  copy, so their data directories in it may be inconsistent. That is accepted:
  the development databases are recreated from scratch after the repositories
  are recloned, so no dumps are taken.
- **Sensitive:** it is plaintext. It holds every Ubuntu SSH private key, the
  three devtower-intel GitHub keys, the WireGuard keys and the accountability
  export. Keep the drive physically secure.

Decided or done as of 2026-10-09:

- The backup is taken, and was refreshed on 2026-10-09 (above).
- Databases are skipped (above).
- The laptop's agenix key opens all 11 devtower-intel secrets
  ([below](#agenix-and-the-laptop)).
- Restore tests are limited to `.env` files, which the comparison covers.
- The backup script's root exclusions are confirmed and written into the root
  comparison command
  ([LIVE-BACKUP-SCRIPT.md](LIVE-BACKUP-SCRIPT.md#encryption-and-verification)),
  so they no longer need recording before Ubuntu shuts down.
- **DavinciProj is deferred.** It is not in the backup, and every stage mounts
  it read-write (with `norecover` and `windows_names`). It is copied to the
  archive drive as the first step of its VeraCrypt conversion
  ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#1-copy-davinciproj-to-the-archive-drive-nixos)).

Still to do before erasing anything:

1. **Run the offline checksum comparison on the desktop**, booted from the live
   installer after a clean Ubuntu shutdown
   ([commands](LIVE-BACKUP-SCRIPT.md#encryption-and-verification)). It compares
   the backup with the originals on the desktop's internal drives, so it cannot
   run on the laptop with only BackupDrive attached. `COPY FINISHED` alone is
   not verification. Database files, the `snap/` mount-point lines, and `/nix`
   and Docker differences can be ignored.
2. In the **same live session**, before the guide's section 3, stage the
   credentials into `/tmp/restore-check` with the
   [rsync adaptation](LIVE-BACKUP-SCRIPT.md#using-this-backup-with-the-manual-installer).
   Section 5 reads them from there, and `/tmp` lives in RAM, so a reboot
   loses it.
3. Before unplugging BackupDrive for partitioning, unmount it
   (`sync; umount /media/backup`). On the rsync route nothing needs to write to
   it, so mount it `ro,noload` in the live session.

## Today's safe sequence

1. **Choose the installation target explicitly.** The configured target is the
   Intel 256GB disk, serial `PHHH93710CN8256B`, only. Replacing it removes
   Ubuntu's root, EFI and swap. Keeping the other drives does not preserve a
   bootable Ubuntu installation. There is no empty drive in this inventory. The
   hardware module is a layout specification, not an automatic partitioning
   script.
2. **Verify the backup** (above) **before changing partitions.** Preserve
   `/etc`, personal files, Git work including untracked changes, SSH/GPG keys,
   age identity keys, credentials, browser profiles and application configs. A
   NixOS generation rollback cannot restore a formatted Ubuntu filesystem. Keep
   a working live USB and the encryption recovery material.
3. **The laptop's agenix key is checked** (2026-10-09; see
   [Agenix and the laptop](#agenix-and-the-laptop)). It was then the only key
   that could open the devtower-intel secrets, and it is not in the backup.
4. **Verify the target from the installer** with
   `lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,UUID,MOUNTPOINTS` and `blkid`.
   Disconnect non-target drives, BackupDrive included, during partitioning where
   practical. Only then create the EFI and LUKS2/btrfs layout, with subvolumes
   `@root`, `@nix`, `@snapshots`, `@log`, `@home`, `@docker`. Reconnect retained
   drives before validating their mounts. Never format the Windows ESP or any
   other drive's ESP.
5. **Fill in `hosts/devtower-intel/disks.nix`** with the **new** EFI, LUKS
   container and inner btrfs UUIDs. Every evaluation warns until you do. The
   Ubuntu root and swap UUIDs are inventory only. Evaluate and build the stage
   before installing. New untracked files need `path:` (the guide's
   `prepare-nix-source.py` does this).
6. **Install the minimal stage first** (`devtower-intel-minimal`), then move up
   through `-desktop`, `-dev`, `-productivity` and `-creative` to the full
   `devtower-intel`.
   - Installing needs no GitHub SSH key (the public inputs still download over
     HTTPS, so use a network connection).
   - From the desktop stage on, the private flake inputs `browser_setup` and
     `accountability_script` are fetched over SSH. The guide's section 7 gives
     the one-off bridge.
   - Only the full stage needs agenix secrets.
   - DaVinci Resolve Studio and the Affinity apps arrive with the creative
     stage.
   - Confirm boot, LUKS unlocking, NVIDIA, network, backups and retained mounts
     before enabling more workloads.
7. **Restore selected personal files** into the new home. The uid is already
   1000, so only the group changes (Ubuntu's 1000 becomes `users`, gid 100;
   the guide runs `chown -R 1000:100`). Don't copy Ubuntu's user, database or
   agent config files over NixOS settings wholesale.

**Boot order after the erase.** Firmware currently boots `Boot0004 "Ubuntu"`
from the Intel ESP that is about to be erased. Next in line is `Boot0003`,
Windows Boot Manager. NixOS sets `canTouchEfiVariables = false`, so it adds no
NVRAM entry, and the PC will boot Windows by default. Pick the Intel disk's
fallback loader (`EFI/BOOT/BOOTX64.EFI`) from the firmware boot menu, or set it
first in firmware setup. Every stage installs systemd-boot there; the full
stage adds the themed rEFInd menu (`modules/boot/refind`) as an extra
systemd-boot entry, which also chainloads Windows from the Crucial disk's ESP.
The stale `Boot0006`/`Boot0007` "ubuntu" entries point at the old Samsung and
archive ESPs. Secure Boot is currently disabled (Setup Mode).

**Space.** The Intel disk cannot hold all your existing data: Ubuntu home alone
(282GiB) is larger than its entire capacity. The new encrypted `/home`, `/nix`
and Docker subvolumes start fresh on it. `/home` and Docker move to the larger
drives as those are encrypted; the system `/nix` stays on the Intel disk.
Retained data stays reachable on the old drives. Download only the models you
use: the seven candidates in [LOCAL-LLM.md](LOCAL-LLM.md) total roughly
100GiB, and builds need free space too. The configuration starts automatic
store garbage collection below 5GiB free and aims for 15GiB. It reclaims only
unreferenced store data, not rooted generations or model files. Use the
guide's source-copy helper to avoid archiving multi-gigabyte Rust build
directories.

## Agenix and the laptop

- **Who can decrypt today:** all 11 `*-devtower-intel*.age` files are encrypted
  to one recipient, the laptop's agenix user key `sam-laptop`
  (`secrets/secrets.nix`, `devtowerIntelKeys = [ sam-laptop ]`). Ubuntu's own
  agenix key cannot open them, and neither can the laptop's host key.
- **What uses them:** only the full stage. It decrypts 7 of them with the PC's
  SSH host key: the three GitHub keys, `claude-secrets`, `aws-config`,
  `aws-credentials` and `typesafe-api-key`. Every earlier stage declares no
  secrets.
- **Logging in doesn't depend on agenix:** the `sam-desktop` password is set
  with `passwd` during installation, and root is locked. **If that step is
  skipped, you cannot log in.**

**On laptop-intel, before Ubuntu is wiped** (done on 2026-10-09: all 11 opened):

```sh
cd ~/Repos/personal/nix-config && git pull
ssh-keygen -y -f ~/.ssh/id_ed25519_agenix   # must print the sam-laptop key in secrets/secrets.nix (...+hao)
cd secrets
for f in *-devtower-intel*.age; do
  agenix -d "$f" -i ~/.ssh/id_ed25519_agenix >/dev/null && echo "ok $f" || echo "FAIL $f"
done
```

- All 11 lines must say `ok`.
- The laptop keeps its own key; no offline copy of it is kept (the old one on
  the KEYS stick was deleted on 2026-10-13). Offline recovery now uses the
  agenix recovery key on the KEYS stick, which opens every secret
  ([SECRETS.md](SECRETS.md#recovery-key-on-the-keys-stick)).
- Losing the laptop key would not lose the secrets themselves: their plaintext
  sources are in the backup (and on the old Ubuntu home until that drive is
  encrypted). But you would have to re-encrypt every one of them by hand.

**On install day:** follow the guide's section 8. In short:

1. Create the PC's SSH host key on first boot. It can be done before the desktop
   stage, so the laptop can rekey while later stages build.
2. On the laptop, add that public key to `secrets/secrets.nix` and set
   `devtowerIntelKeys = [ sam-laptop devtower-intel ]`. Keep `sam-laptop`, or
   the laptop can no longer edit these secrets. Don't add the PC to `allHosts`.
3. Rekey on the laptop and push straight away.
   - Expect all 31 files to be rewritten, plus 4 `wasn't created.` warnings for
     declared rules that have no file yet. Both are normal.
   - The `.age` files are binary and cannot be merged, so don't let the rekey
     sit unpushed.
4. On the PC, pull with the one-off GitHub key bridge, then switch to the full
   stage.

After the rekey the PC can also decrypt its own secrets, so the laptop key is no
longer the only way back in.

## Keeping the other drives and encryption

NixOS can mount existing ext4 and NTFS filesystems without reformatting them.
Every devtower-intel stage, minimal included, mounts:

| Mount | Filesystem | Notes |
| --- | --- | --- |
| `/mnt/archive` | Seagate archive, ext4 | read-write |
| `/mnt/ubuntu-home` | old Ubuntu home, ext4 | read-write |
| `/mnt/ubuntu-nix` | old Ubuntu `/nix`, ext4 | read-only |
| `/mnt/ubuntu-docker` | old Docker data, ext4 | read-only |
| `/mnt/davinci` | DavinciProj, NTFS (ntfs-3g) | read-write for `sam-desktop`; mounted at boot with `norecover`. See [its page](DAVINCI-SHARED-DRIVE.md) |
| `/mnt/backup` | BackupDrive, ext4 | read-write, on demand when attached |

All use `nofail`, so a missing drive never blocks boot. The first four are the
old Ubuntu filesystems. `/mnt/ubuntu-home` goes when the home drive is
encrypted, and `/mnt/ubuntu-nix` and `/mnt/ubuntu-docker` when the store drive
is (below). Copy anything still wanted out of them first: BackupDrive is
unusable, so erasing them accepts that loss.
`/mnt/archive` and `/mnt/davinci` are replaced by `/mnt/data` and
`/mnt/data-mirror`, the VeraCrypt pair ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md)).

- **Not reused:** the configuration doesn't reuse the Ubuntu store, and doesn't
  start Docker against the old data directory.
- **Swap:** Ubuntu's swap is not enabled; zram replaces it.
- **BackupDrive:** not usable at the moment
  ([status](BACKUP-AND-DATA-ENCRYPTION.md#backup-destination-identified-on-5-october-2026)).
  The Ubuntu home copy is at `/mnt/archive/pre-nixos-home/`, and later
  `Archive/pre-nixos-home.tar.zst` on the shared data drive.
- **Windows:** always shut down completely before switching systems. Disable
  Windows Fast Startup and hibernation before writing to its NTFS volumes.

LUKS on the OS drive encrypts only files stored within that encrypted device.
Plaintext home, archive, Docker partitions and backups remain readable if their
drives are removed, and mounting them from encrypted NixOS does not encrypt
them.

**The plan: once NixOS works, wipe and encrypt every data drive, one at a
time.**

- **Intel NVMe (OS)**, already encrypted and not wiped, keeps `/`, the system
  `/nix` and its generations, `/var/log` and `/.snapshots`. It gains TPM2
  auto-unlock (PCR 7) and an escrow secret first.
- **Samsung 512GB** becomes `/home` (LUKS2 `crypthome`, own passphrase, TPM2
  unlock in the initrd).
- **Samsung 870 EVO** becomes one LUKS2 container, `cryptstore`, with three
  btrfs subvolumes under simple-quota caps: `@docker` at `/var/lib/docker`
  (950 GiB), `@vm` at `/var/lib/libvirt/images` (450 GiB) and `@clients` at
  `/srv/clients` (400 GiB, a Nix store for client servers whose old
  generations are cleaned up weekly), with about 60 GiB left unallocated. It
  is not needed to boot: it unlocks after boot from `/etc/crypttab` (TPM2,
  `nofail`), and Docker and libvirtd wait for their mounts.
- **The two 4TB drives** (DavinciProj and the Seagate archive) become a
  VeraCrypt pair with NTFS inside, so Windows can read them too: the WD as the
  working drive, the Seagate as a scheduled mirror
  ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md)).

`hosts/devtower-intel/data-drives.nix` switches the home drive over as soon as
its two new UUIDs are filled in. The store drive's configuration is still
pending: today the file mounts the 870 EVO as `/nix` and unlocks it in the
initrd, so the new mounts, after-boot unlock and quota caps must be merged
before that drive is converted. The step-by-step procedure (order: OS drive
TPM2 and escrow secret, home, the 4TB pair, store) is in
[BACKUP-AND-DATA-ENCRYPTION.md](BACKUP-AND-DATA-ENCRYPTION.md#encrypt-one-drive-at-a-time).
In-place conversion is not used. Remote Docker from the laptop comes after the
drives ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#later)).

For now, retain the data drives and protect new credentials in the encrypted
NixOS home. The EFI partition remains unencrypted; verified boot is a separate
concern from data-at-rest encryption. Filesystem snapshots share a failure
domain with their disk and do not replace an independent backup.

See the [NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation)
and [cryptsetup documentation](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home)
for installation and LUKS recovery procedures.
