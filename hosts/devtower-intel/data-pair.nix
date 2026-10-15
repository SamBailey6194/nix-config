# The two 4TB hard drives shared with Windows (docs/SHARED-DATA-DRIVES.md):
# each a VeraCrypt volume with NTFS inside, so both OSes can open them.
#
#   data    WD Blue 4TB    cryptdata   -> /mnt/data         the working drive,
#                                         mounted at boot
#   mirror  Seagate 4TB    cryptmirror -> /mnt/data-mirror  written only by the
#                                         nightly one-way mirror job below
#
# Not RAID: the Seagate follows the WD once a day and keeps whatever it
# replaces in .mirror-history/<date> for 30 days.
#
# A volume switches on when its partUuid in ./disks.nix (dataPair) is filled
# in; until then nothing here changes. Filling in data retires /mnt/davinci
# (hardware-configuration.nix), filling in mirror retires the ext4
# /mnt/archive (data-drives.nix). The mirror job and its timer need both.
#
# Passphrases: one root-only file per volume, created by hand before the
# partUuid is filled in (not agenix; the same trust as the TPM2 tokens: whoever
# can unlock the OS disk can read them):
#
#   sudo bash -c 'umask 077; IFS= read -rs -p "Passphrase: " p; echo;
#     printf %s "$p" > /var/lib/desktop-secrets/data.pass'
#   sudo chmod 0400 /var/lib/desktop-secrets/data.pass
#
# (mirror.pass the same way). systemd-cryptsetup reads only the first line of a
# tcrypt passphrase file and drops its line ending (crypttab(5), "tcrypt";
# read_one_line_file in its source), so a trailing newline from an editor does
# no harm, but spaces at either end are part of the passphrase. Don't test it
# with `cryptsetup --key-file`: for tcrypt that means a VeraCrypt keyfile, not
# a passphrase. Test it the way boot uses it, while the volume is closed:
#
#   sudo systemd-cryptsetup attach cryptdata /dev/disk/by-partuuid/<partUuid> \
#     /var/lib/desktop-secrets/data.pass tcrypt-veracrypt
#   sudo systemd-cryptsetup detach cryptdata
#
# At boot a wrong passphrase fails systemd-cryptsetup@cryptdata.service (see
# its journal); a missing file makes it ask instead, which nobody sees once
# the login screen is up (`sudo systemd-tty-ask-password-agent --query`).

{ config, options, lib, pkgs, utils, ... }:

let
  disks = import ./disks.nix;
  pair = disks.dataPair;
  converted = name: pair.${name}.partUuid != null;

  dataOn = converted "data";
  mirrorOn = converted "mirror";

  # The DavinciProj NTFS-3G options (/mnt/davinci in hardware-configuration.nix):
  # owned by sam-desktop (uid 1000, users), no execute bits on files, Windows
  # file name rules, and norecover so a volume Windows didn't close cleanly is
  # never "repaired" by clearing its journal. A hibernated or Fast Startup
  # volume is forced read-only by NTFS-3G (ntfs-3g(8)).
  #
  # By /dev/mapper name, not the NTFS UUID: the mapper name is ours (crypttab),
  # known now and unchanged if a volume is ever re-created, while the NTFS
  # serial only exists once VeraCrypt has formatted the volume and would be a second
  # identifier to keep in step. Mounting the mapper device also pulls in its
  # unlock: systemd-cryptsetup-generator makes dev-mapper-<name>.device require
  # systemd-cryptsetup@<name>.service.
  #
  # The device timeout covers VeraCrypt's deliberately slow key derivation as
  # well as the drive appearing; the mount gives up after it, without retrying.
  #
  # Each mount also requires its own systemd-cryptsetup@<name>.service
  # (x-systemd.requires=, which adds Requires= and After=, systemd.mount(5)):
  # stopping the unlock then stops the mount first, in the same transaction,
  # and at shutdown the mount is gone before the volume is closed. The
  # generators order both through blockdev@dev-mapper-<name>.target, but
  # that template is not installed here (LoadState=not-found), so that
  # ordering never happens: without this a close can run alongside the unmount.
  ntfsOpts = [
    "nofail"
    "noatime"
    "norecover"
    "uid=1000"
    "gid=100"
    "fmask=0133"
    "dmask=0022"
    "windows_names"
    "x-systemd.device-timeout=1min"
  ];

  unlockedBy = mapper: "x-systemd.requires=systemd-cryptsetup@${mapper}.service";

  passFile = name: "/var/lib/desktop-secrets/${name}.pass";

  # By partition, not UUID=: a VeraCrypt volume has no LUKS UUID, and crypttab(5)
  # documents only UUID= and device paths for the second field.
  cryptLine = mapper: name: extra:
    "${mapper} /dev/disk/by-partuuid/${pair.${name}.partUuid} ${passFile name} tcrypt-veracrypt,nofail,${extra}x-systemd.device-timeout=10s\n";

  mirrorMount = "${utils.escapeSystemdPath "/mnt/data-mirror"}.mount";

  # ~/Data: /mnt/data bound into the home directory (docs/SHARED-DATA-DRIVES.md,
  # "~/Data"), so media projects on the WD sit inside the home directory that
  # the ElevenLabs MCP and syntek-media's `check --setup` accept as their base
  # path. Both resolve symlinks, so a link would land back in /mnt/data; a bind
  # mount has no link to resolve. One copy of the data, two paths to it.
  user = config.users.users.sam-desktop;
  dataHome = "${user.home}/Data";
  dataHomeMount = "${utils.escapeSystemdPath dataHome}.mount";

  # Refuses unless both volumes are mounted, read-write, from their own mapper
  # devices, and the working drive (and only it) carries .data-primary. So an
  # unmounted, empty or swapped drive can never make --delete empty the mirror.
  #
  # NTFS-3G records the canonical device (/dev/dm-N), not the path it was
  # mounted from (findmnt shows /dev/sdc1 for /mnt/davinci's by-uuid device),
  # so the device numbers are compared rather than the SOURCE string.
  #
  # Read-only on either side means Windows left that volume hibernated or not
  # shut down cleanly (NTFS-3G with norecover, ntfs-3g(8)): its on-disk state
  # may be stale, so stop rather than mirror it. A volume NTFS-3G refuses
  # outright fails the mount, and with it this unit (ExecStartPre below).
  #
  # Runs with "+" (outside the sandbox below), so it sees the real mount flags,
  # not the read-only view ProtectSystem gives the copy.
  mirrorGuard = pkgs.writeShellScript "data-mirror-guard" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.util-linux ]}

    refuse() { echo "data-mirror: refusing to run: $*" >&2; exit 1; }

    check_mount() {
      local dir=$1 mapper=$2 dev fstype vfs fs
      read -r dev fstype vfs fs < <(findmnt -n -o MAJ:MIN,FSTYPE,VFS-OPTIONS,FS-OPTIONS --mountpoint "$dir") \
        || refuse "$dir is not mounted"
      [ -b "$mapper" ] || refuse "$mapper does not exist (volume not unlocked)"
      [ "$dev" = "$(stat -L -c '%Hr:%Lr' "$mapper")" ] || refuse "$dir is not mounted from $mapper"
      [ "$fstype" = fuseblk ] || refuse "$dir is $fstype, not NTFS-3G"
      case ",$vfs,$fs," in
        *,ro,*) refuse "$dir is mounted read-only: Windows hibernated, Fast Startup or not shut down cleanly? Shut Windows down fully, then start this again" ;;
      esac
      case ",$vfs," in
        *,rw,*) ;;
        *) refuse "$dir is not mounted read-write ($vfs)" ;;
      esac
    }

    check_mount /mnt/data /dev/mapper/cryptdata
    check_mount /mnt/data-mirror /dev/mapper/cryptmirror

    [ -f /mnt/data/.data-primary ] && [ ! -L /mnt/data/.data-primary ] \
      || refuse "/mnt/data/.data-primary is missing: not the working drive, or it is empty"
    if [ -e /mnt/data-mirror/.data-primary ] || [ -L /mnt/data-mirror/.data-primary ]; then
      refuse "/mnt/data-mirror has .data-primary: it looks like the working drive"
    fi
    if [ -L /mnt/data-mirror/.mirror-history ]; then
      refuse "/mnt/data-mirror/.mirror-history is a link"
    fi
  '';
in
{
  config = lib.mkMerge [
    # ── data: WD Blue WD40EZRZ 4TB, the working drive ────────────────────
    # Unlocked after boot from /etc/crypttab (not the initrd: nothing needs it
    # to boot), nofail so a missing drive or a wrong passphrase file never
    # holds up boot. Mounted at boot rather than automounted: Affinity's Wine
    # sandbox (own mount namespace) and Wine's drive-letter scan need it
    # mounted already. If it gave up (drive late, unlock failed), fix that and
    # `sudo systemctl start mnt-data.mount`.
    (lib.mkIf dataOn {
      environment.etc.crypttab.text = cryptLine "cryptdata" "data" "";
      fileSystems."/mnt/data" = {
        device = "/dev/mapper/cryptdata";
        fsType = "ntfs-3g";
        options = ntfsOpts ++ [ (unlockedBy "cryptdata") ];
      };

      # ~/Data (see dataHome above). depends adds RequiresMountsFor=/mnt/data
      # (Requires= and After= its mount unit, systemd.unit(5)): if the WD isn't
      # mounted, nothing is bound and ~/Data stays an empty folder; stopping
      # /mnt/data stops this first; at shutdown this unmounts before /mnt/data
      # (and /home, its parent). nofail: wanted by local-fs.target at boot
      # without holding it up. After tmpfiles: the empty folder is created
      # sam-desktop's (below) before anything is mounted on it, not root's.
      fileSystems.${dataHome} = {
        device = "/mnt/data";
        fsType = "none";
        depends = [ "/mnt/data" ];
        options = [ "bind" "nofail" "x-systemd.after=systemd-tmpfiles-setup.service" ];
      };
      # Starting /mnt/data by hand later (see above) binds ~/Data too. Not
      # x-systemd.wanted-by= on ~/Data: that drops the local-fs.target link and
      # makes nofail meaningless (systemd.mount(5); the generator warns).
      systemd.units."mnt-data.mount" = {
        overrideStrategy = "asDropin";
        text = ''
          [Unit]
          Wants=${dataHomeMount}
        '';
      };
      # The empty mountpoint is sam-desktop's but 0555: with the WD absent
      # (nofail), writes into ~/Data fail loudly instead of landing on /home,
      # where the bind would later hide them (/mnt/data is root's, so it has
      # no such gap). Mounted, the folder shows the NTFS root, sam-desktop's
      # 0755 (uid=1000, gid=100, dmask=0022 above): a later tmpfiles run (each
      # switch) chmods it, and NTFS-3G ignores chmod without error (silent, on
      # by default with no permissions option or user mapping, ntfs-3g(8)).
      systemd.tmpfiles.rules = [ "d ${dataHome} 0555 ${user.name} ${user.group} -" ];
    })

    # Everything that walks /home skips ~/Data: the same files are already on
    # /mnt/data, 4TB that would otherwise be read twice. The scanner (only in
    # the full stage) checks exclusions by path prefix, for scans (the boot
    # scan's /home) and for the on-access monitor. Its defaults are kept: a
    # definition here replaces an option's default rather than adding to it.
    # Restic and snapper need nothing: no backup job is declared (restic.nix
    # takes its jobs at run time and none exists; restic-backup.nix, unused,
    # passes --one-file-system), and btrfs snapshots stop at mount points.
    (lib.optionalAttrs (options ? security.malwareScanner) (lib.mkIf dataOn {
      security.malwareScanner = {
        excludePaths = options.security.malwareScanner.excludePaths.default ++ [ dataHome ];
        realTimeMonitoring.excludePaths =
          options.security.malwareScanner.realTimeMonitoring.excludePaths.default ++ [ dataHome ];
      };
    }))

    # ── mirror: Seagate ST4000DM004 4TB, written only by the mirror job ──
    # noauto: not unlocked at boot. Only the mirror job pulls it in, through
    # its start of the noauto mount -> dev-mapper-cryptmirror.device,
    # which the cryptsetup generator makes require systemd-cryptsetup@cryptmirror
    # even for noauto lines (crypttab(5), "noauto": "if the device is used for
    # a mount point, it'll be unlocked automatically ... unless the mount point
    # itself is also disabled with noauto" - here the job starts the mount).
    # Locked the rest of the day, so a slip on the running system can't change
    # or delete the mirror between runs, and the SMR drive sits idle.
    (lib.mkIf mirrorOn {
      environment.etc.crypttab.text = cryptLine "cryptmirror" "mirror" "noauto,";
      fileSystems."/mnt/data-mirror" = {
        device = "/dev/mapper/cryptmirror";
        fsType = "ntfs-3g";
        options = [ "noauto" ] ++ ntfsOpts ++ [ (unlockedBy "cryptmirror") ];
      };
      # NTFS-3G is a FUSE daemon: the disk writes come from it, not from rsync,
      # and it runs in the mount unit. mq-deadline honours I/O priorities.
      systemd.units.${mirrorMount} = {
        overrideStrategy = "asDropin";
        text = ''
          [Mount]
          Nice=19
          IOSchedulingClass=idle
        '';
      };
    })

    # ── health: both drives, as each is converted ────────────────────────
    # Nothing else in the repository configures smartd. Only the listed drives
    # (autodetect off); smartd fails visibly if one is missing at start.
    # -n standby,q: never spin a sleeping drive up just to poll it.
    # Short self-test daily at 02:00, long (several hours) monthly on the 1st.
    (lib.mkIf (dataOn || mirrorOn) {
      services.smartd = {
        enable = true;
        autodetect = lib.mkDefault false;
        devices = map (name: {
          device = "/dev/disk/by-id/${pair.${name}.byId}";
          options = "-a -o on -S on -n standby,q -s (S/../.././02|L/../01/./03) -W 4,45,55";
        }) (builtins.filter converted [ "data" "mirror" ]);
      };
    })

    # ── the mirror job: needs both volumes ───────────────────────────────
    # rsync -rt: NTFS keeps no Unix owners or permissions worth copying. Each
    # run's replaced and deleted files go to .mirror-history/<date> (relative
    # to the mirror root, rsync(1) --backup-dir); excluding it protects it from
    # --delete. Windows' own per-volume folders are excluded too: they belong to
    # each volume, not to the data. Failures show in `systemctl --failed`.
    (lib.mkIf (dataOn && mirrorOn) {
      systemd.services.data-mirror = {
        description = "One-way mirror of /mnt/data to /mnt/data-mirror";
        # Both mounts (the mirror's unlock with them) are started by the first
        # ExecStartPre, not RequiresMountsFor: a dependency that fails stops
        # this unit before it runs, so its ExecStopPost never would and the
        # mirror would stay unlocked. A failed ExecStartPre still runs it
        # (systemd.service(5)). After=: shutdown stops the copy before the
        # unmounts.
        after = [ "mnt-data.mount" mirrorMount ];
        path = [ pkgs.coreutils pkgs.findutils pkgs.rsync ];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = [
            "+${config.systemd.package}/bin/systemctl start /mnt/data /mnt/data-mirror"
            "+${mirrorGuard}"
          ];
          # Lock the mirror again afterwards, whatever the result. Stopping the
          # unlock is enough: the mount requires it (unlockedBy above), so the
          # same transaction unmounts first and closes after. --no-block: when
          # this unit is itself being stopped (shutdown), the unmount waits
          # for it. No "-": with --no-block this fails only if the stop can't
          # even be queued (a configuration error, which should fail the unit);
          # whether the unmount and close then succeed shows on those units
          # (`systemctl --failed`), not here, so this unit's result stays the
          # copy's.
          ExecStopPost = "+${config.systemd.package}/bin/systemctl --no-block stop systemd-cryptsetup@cryptmirror.service";
          Nice = 19;
          CPUSchedulingPolicy = "batch";
          IOSchedulingClass = "idle";
          # The copy can only write to the mirror: /mnt/data is read-only here.
          ProtectSystem = "strict";
          ReadWritePaths = [ "/mnt/data-mirror" ];
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
        script = ''
          set -euo pipefail
          today=$(date +%F)

          # Drop history folders more than 30 days old, judged by the date in
          # the name, before the copy: the cutoff doesn't depend on how the
          # copy goes, and a copy that fills the mirror must not stop the
          # space being freed. Anything not named exactly YYYY-MM-DD (a real
          # date), or not a plain folder, is left alone.
          hist=/mnt/data-mirror/.mirror-history
          if [ -d "$hist" ]; then
            cutoff=$(date -d "$today - 30 days" +%F)
            while IFS= read -r -d "" entry; do
              name=''${entry##*/}
              if [[ ! $name =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
                || [ "$(date -d "$name" +%F 2>/dev/null)" != "$name" ] \
                || [ -L "$entry" ] || [ ! -d "$entry" ]; then
                echo "data-mirror: leaving $entry alone (not a dated history folder)" >&2
                continue
              fi
              if [[ $name < $cutoff ]]; then
                echo "data-mirror: removing $entry"
                rm -rf --one-file-system -- "$entry"
              fi
            done < <(find "$hist" -mindepth 1 -maxdepth 1 -print0)
          fi

          status=0
          rsync -rtS --delete --backup --backup-dir=".mirror-history/$today" \
            --exclude=/.mirror-history --exclude=/.data-primary \
            --exclude='/System Volume Information' --exclude='/$RECYCLE.BIN' \
            /mnt/data/ /mnt/data-mirror/ || status=$?
          case $status in
            0) ;;
            24) echo "data-mirror: some files vanished during the copy (in use); the next run picks them up" >&2 ;;
            *)
              echo "data-mirror: rsync failed (status $status)" >&2
              df -h /mnt/data /mnt/data-mirror >&2 || true
              exit "$status"
              ;;
          esac
        '';
      };

      # Persistent: a day spent in Windows (or switched off) is caught up at the
      # next boot, after the random delay (systemd.timer(5)).
      systemd.timers.data-mirror = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 03:30:00";
          Persistent = true;
          RandomizedDelaySec = "30min";
        };
      };
    })
  ];
}
