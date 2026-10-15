# Windows: setting up the VeraCrypt data drives

**Written**: 15/10/2026. The checklist for the one Windows visit after both
4TB drives became VeraCrypt volumes on NixOS
([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md), step 8). It also covers
moving the Resolve projects into the new folders
([DAVINCI-SHARED-DRIVE.md](DAVINCI-SHARED-DRIVE.md#moving-projects-into-an-area)).

| Drive | Serial | What Windows does with it |
| --- | --- | --- |
| WD Blue 4TB | `WD-WCC7K0FU5LY2` | **Mount** with VeraCrypt at DavinciProj's old letter, every logon |
| Seagate 4TB | `ZFN2J51Q` | **Never mount.** It is the mirror, written only by NixOS |

Both look like **unformatted (RAW) partitions** to Windows. That is correct:
they are encrypted.

## Before you start

- Passphrases: the WD's (and the Seagate's only if you ever need it) from
  your password manager. They are the VeraCrypt passphrases, not new ones.
- The header backups are already on the KEYS stick
  (`veracrypt/wd-data-header.bin`, `veracrypt/seagate-mirror-header.bin`);
  nothing to back up here.
- NixOS was shut down normally, so nothing holds the drives.

## 1. The rule that matters most: never format

When Windows first sees the two encrypted partitions it may say **"You need
to format the disk in drive X: before you can use it"**. Always choose
**Cancel**. Formatting destroys the encrypted volume and everything on it.

Then remove the letters Windows gave the raw partitions, so the prompt can't
come back: **Disk Management** (`Win+X` → Disk Management) → right-click each
3.64TB RAW partition → **Change Drive Letter and Paths** → **Remove**. Do not
initialise, format or delete anything there.

## 2. Check Windows settings

- **Fast Startup off**: Control Panel → Power Options → *Choose what the power
  buttons do* → *Change settings that are currently unavailable* → untick
  **Turn on fast startup**. With it on, Windows hibernates instead of shutting
  down, leaves the NTFS volume "dirty", and NixOS then refuses to mount it
  read-write (`norecover`) until Windows is shut down properly.
- Always use **Shut down**, never hibernate or sleep, before booting NixOS.

## 3. Install VeraCrypt

Download it from the official site (veracrypt.io → Downloads → Windows
installer; 1.26 or newer) and install with the defaults. NixOS created the
volumes with VeraCrypt 1.26.29 (AES, SHA-512, default PIM, NTFS inside), all
of which Windows VeraCrypt opens.

## 4. Mount the WD at DavinciProj's letter

1. Note the letter DavinciProj used to have (for example `E:`). Resolve,
   Affinity and the Craft apps stored their paths with it, so the same letter
   keeps old links working. **Write it down**: NixOS needs it too (step 8).
2. In VeraCrypt choose that letter in the list, then **Select Device…** and
   pick the WD's partition: `\Device\HarddiskN\Partition1`, **3.64TB**. If
   both 3.64TB disks are listed, the WD is the one on the WD40EZRZ disk (Disk
   Management → right-click the disk → Properties shows the model). Never
   pick the Seagate (ST4000DM004).
3. **Mount**, enter the WD's passphrase, leave PIM empty and no keyfiles.
4. Check Explorer shows the drive with `archive`, `business`, `personal`,
   `Databases`, `Media` and `.data-primary` (hidden) at its root.

## 5. Mount it at every logon

With the WD mounted: **Favorites → Add Mounted Volume to Favorites…** →
label `Data`, tick **Mount selected volume upon logon**, OK. At each Windows
logon VeraCrypt then asks for the WD's passphrase once and mounts it at the
same letter. Do **not** add the Seagate.

## 6. Update DaVinci Resolve to 21.1

NixOS runs Resolve **21.1**. Update Windows Resolve to the same version
before opening any project: a newer Resolve upgrades a project library, and an
older one then cannot open it. Do this before step 7.

## 7. Move the Resolve projects into the areas

The old library is at `<letter>:\Databases`, its footage in
`<letter>:\Media`. Close Resolve, then:

1. **Back up the library**: copy `<letter>:\Databases` to
   `<letter>:\archive\resolve-databases-2026-10-15\`.
2. Open Resolve. In the Project Manager's project libraries, **add** two
   libraries: **Business** at `<letter>:\business\film\resolve-library` and
   **Personal** at `<letter>:\personal\film\resolve-library`.
3. For each project in the old library: **export** it (`.drp`), then switch to
   Business or Personal and **import** it.
4. Move its footage from `<letter>:\Media\<project>` to
   `<letter>:\<area>\film\media\<project>`, open the project and **relink**
   the offline clips to the new folder.
5. Set the project's **render location** to `<letter>:\<area>\film\renders\`.
   Keep the render cache and optimised media on the SSD (Resolve's default
   cache location), not on this drive.
6. When every project opens and plays: remove the old library from Resolve's
   list, then delete `<letter>:\Databases` and `<letter>:\Media` (the copy in
   `archive\` stays, and the NixOS mirror keeps 30 days of history).

## 8. Back in NixOS

- Tell Claude (or set it yourself) the letter from step 4: it goes in
  `davinciDriveLetter` in `home/devtower-intel.nix`, so Affinity under Wine
  sees the drive at the same letter, then rebuild.
- In Resolve on NixOS, add the same two libraries at
  `~/Data/business/film/resolve-library` and
  `~/Data/personal/film/resolve-library`, and set the mapped mount
  (`<letter>:\` on Windows equals `~/Data` on Linux) so media paths resolve.
- `findmnt /mnt/data` should show it mounted read-write. If it is read-only
  or missing, Windows was hibernated or not shut down cleanly: boot Windows,
  shut down properly, and try again.

## Day-to-day rules

- Work on the WD from either system; the Seagate is NixOS's.
- Shut Windows down fully before booting NixOS.
- Whatever changes in Windows reaches the mirror at the next NixOS mirror run
  (03:30 nightly, caught up at the next boot if missed).
- If Windows ever offers to format either drive: **Cancel**.
