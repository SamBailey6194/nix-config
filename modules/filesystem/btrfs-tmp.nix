# /tmp on its own btrfs subvolume (@tmp), emptied on every boot
#
# Why not leave /tmp on @root: snapper snapshots / on a timeline, so every
# scratch file in /tmp was copied into those snapshots and kept its disk
# space for up to six months after deletion. btrfs snapshots stop at
# subvolume boundaries, so a separate @tmp is never snapshotted.
#
# Why not tmpfs: multi-GB scratch files would compete with the desktop for
# RAM (devtower-intel has 32GB and already uses zram swap). Nix builds do not
# need /tmp either; they use /nix/var/nix/builds.
#
# Nothing to do by hand: btrfs-tmp-subvolume.service creates @tmp on the root
# filesystem before tmp.mount, so this also works on a fresh install and on
# hosts that never had the subvolume. It also empties the old /tmp directory
# on @root that the mount now hides, freeing that space once existing
# snapshots expire.
#
# First apply with `just rebuild --boot` and reboot. switch-to-configuration
# starts local-fs.target for new fstab entries, which would mount the empty
# @tmp over the /tmp running programs use; the service refuses outside boot,
# so until that reboot every live switch reports btrfs-tmp-subvolume.service
# as failed (exit status 4) while /tmp stays untouched.
#
# /var/tmp stays on @root and survives reboots, as the FHS requires;
# systemd's tmp.conf still deletes its files after 30 days (and /tmp's after 10).
#
# Imported from each host's hardware-configuration.nix so every install
# stage gets it.

{ config, lib, pkgs, ... }:

let
  cfg = config.filesystem.btrfsTmp;
  root = config.fileSystems."/";
  # Same device and tuning (compress, noatime, ...) as /, other subvolume.
  # Drop x-initrd.mount (NixOS adds it to /): /tmp must mount in stage 2,
  # after btrfs-tmp-subvolume.service has created @tmp.
  rootOptions = lib.filter
    (o: !(lib.hasPrefix "subvol=" o || lib.hasPrefix "subvolid=" o || o == "x-initrd.mount"))
    root.options;
  # @root's name on the top level (from subvol=@root), so the old /tmp
  # directory it holds can be emptied; null if / is the top level itself
  rootSubvolOpt = lib.findFirst (lib.hasPrefix "subvol=") null root.options;
  rootSubvol =
    if rootSubvolOpt == null then null
    else lib.removePrefix "/" (lib.removePrefix "subvol=" rootSubvolOpt);
  sv = lib.escapeShellArg cfg.subvolume;
in
{
  options.filesystem.btrfsTmp = {
    enable = lib.mkEnableOption "/tmp on its own btrfs subvolume, emptied on boot" // {
      default = true;
    };

    subvolume = lib.mkOption {
      type = lib.types.str;
      default = "@tmp";
      description = "Top-level btrfs subvolume (on the root filesystem) mounted at /tmp.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = root.fsType == "btrfs";
      message = "filesystem.btrfsTmp needs a btrfs root filesystem; set filesystem.btrfsTmp.enable = false on this host.";
    }];

    fileSystems."/tmp" = {
      device = root.device;
      fsType = "btrfs";
      options = rootOptions ++ [
        "subvol=${cfg.subvolume}"
        "nosuid"
        "nodev"
        "x-systemd.requires=btrfs-tmp-subvolume.service"
        # nofail: if @tmp cannot be set up, boot carries on with /tmp on @root
        # instead of local-fs.target failing into emergency mode. nofail also
        # drops the Before=local-fs.target ordering, so restore it: tmpfiles
        # (`D! /tmp`) and every normal service must see the mounted @tmp.
        "nofail"
        "x-systemd.before=local-fs.target"
      ];
    };

    # tmpfiles `D! /tmp`: empty the mounted @tmp at every boot
    boot.tmp.cleanOnBoot = true;

    systemd.services.btrfs-tmp-subvolume = {
      description = "Create the ${cfg.subvolume} btrfs subvolume for /tmp";
      after = [ "-.mount" ];
      before = [ "tmp.mount" ];
      unitConfig = {
        DefaultDependencies = false;
        # tmp.mount Requires this unit, so stopping or restarting it would
        # unmount /tmp under running programs. switch-to-configuration also
        # skips units with RefuseManualStop.
        RefuseManualStop = true;
        # Isolating e.g. emergency.target would otherwise stop it (and so
        # unmount /tmp through Requires=)
        IgnoreOnIsolate = true;
      };
      restartIfChanged = false;
      stopIfChanged = false;
      path = [ pkgs.util-linux pkgs.btrfs-progs pkgs.findutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Helper mounts live in a private namespace and vanish with the unit
        PrivateMounts = true;
      };
      script = ''
        set -eu

        # Booting: this unit is ordered before tmp.mount, hence before
        # local-fs.target and sysinit.target. On a running system sysinit.target
        # is always active; then refuse, so a live `nixos-rebuild switch` does not
        # mount an empty @tmp over the /tmp running programs use (the failure
        # stops tmp.mount; nofail keeps local-fs.target out of it).
        if [ "$(systemctl show -P ActiveState sysinit.target)" = active ]; then
          if mountpoint -q /tmp; then
            exit 0
          fi
          echo "Not booting: /tmp moves to ${cfg.subvolume} at the next boot (use nixos-rebuild boot)" >&2
          exit 1
        fi

        work=$(mktemp -d /run/btrfs-tmp.XXXXXX)
        mkdir "$work/top"
        # Never delete recursively here: $work/top is the whole filesystem.
        # rmdir only removes empty, unmounted directories.
        cleanup() {
          umount "$work/top" || umount -l "$work/top" || true
          rmdir "$work/top" "$work" || true
        }
        trap cleanup EXIT

        # Top level of the root filesystem (subvolid 5) holds @root, @nix, ...
        mount -t btrfs -o subvolid=5 ${lib.escapeShellArg root.device} "$work/top"

        target="$work/top/"${sv}
        if [ -e "$target" ] && ! btrfs subvolume show "$target" >/dev/null 2>&1; then
          echo "$target exists but is not a btrfs subvolume; not mounting it at /tmp" >&2
          exit 1
        fi
        if [ ! -e "$target" ]; then
          btrfs subvolume create "$target"
        fi
        chmod 1777 "$target"
      '' + lib.optionalString (rootSubvol != null) ''

        # Empty @root's own /tmp directory, which the @tmp mount hides, so its
        # stale files stop holding space. -xdev stays inside @root (nested
        # subvolumes have their own device number).
        old="$work/top/"${lib.escapeShellArg rootSubvol}/tmp
        if [ -d "$old" ] && [ ! -L "$old" ]; then
          find "$old" -xdev -mindepth 1 -delete || true
          chmod 1777 "$old"
        fi
      '';
    };
  };
}
