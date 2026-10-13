# Client servers' Nix store on the 870 EVO's @clients subvolume
# (docs/BACKUP-AND-DATA-ENCRYPTION.md#client-servers-nix-store-clients).
#
# Client servers are built into /srv/clients/nix-root, never the system /nix,
# and deployed with `just deploy-client`. This module adds:
#   client-store-guard   the safety checks, shared by the weekly clean-up and
#                        the justfile, so the two never drift apart
#   client-store-gc      weekly: keep each server's current generation, delete
#                        the rest, then GC the client store only
#
# Nothing here takes effect until dataDrives.store in ./disks.nix is filled in.

{ lib, pkgs, ... }:

let
  disks = import ./disks.nix;
  drive = disks.dataDrives.store;
  converted = drive.luksUuid != null && drive.fsUuid != null;

  user = "sam-desktop"; # owns nix-root; never build or GC there as root

  # Every check the doc lists, in one place. `--no-db` is for deploy-client:
  # the first deploy is what creates nix/var/nix/db.
  guard = pkgs.writeShellApplication {
    name = "client-store-guard";
    text = ''
      check_db=1
      case "''${1:-}" in
        "") ;;
        --no-db) check_db=0 ;;
        *) echo "Usage: client-store-guard [--no-db]" >&2; exit 2 ;;
      esac

      refuse() {
        echo "client-store-guard: refusing: $*" >&2
        exit 1
      }

      # --store on the wrong directory would build onto (or collect) the root
      # filesystem or the system store
      real=$(${pkgs.coreutils}/bin/realpath -e /srv/clients/nix-root) \
        || refuse "/srv/clients/nix-root does not exist"
      case "$real" in
        / | /nix | /nix/*) refuse "/srv/clients/nix-root resolves to $real" ;;
      esac

      source=$(${pkgs.util-linux}/bin/findmnt -no SOURCE /srv/clients || true)
      [ "$source" = "/dev/mapper/cryptstore[/@clients]" ] \
        || refuse "/srv/clients is not the @clients subvolume of cryptstore (findmnt: ''${source:-not mounted})"

      [ -e /srv/clients/.client-store ] \
        || refuse "marker /srv/clients/.client-store is missing"

      # --store on a missing directory silently creates a new, empty store
      if [ "$check_db" = 1 ]; then
        [ -d /srv/clients/nix-root/nix/var/nix/db ] \
          || refuse "/srv/clients/nix-root/nix/var/nix/db is missing"
      fi
    '';
  };

  # Root, before the clean-up: @clients' top level belongs to root, so the
  # owner of nix-root can't create the shared lock file itself. Created only
  # once the guard has passed, so never on the root filesystem.
  prepareLock = pkgs.writeShellScript "client-store-lock.sh" ''
    set -eu
    ${guard}/bin/client-store-guard
    lock=/srv/clients/.client-store.lock
    [ -e "$lock" ] \
      || ${pkgs.coreutils}/bin/install -m 0644 -o ${user} -g users /dev/null "$lock"
  '';

  cleanup = pkgs.writeShellScript "client-store-gc.sh" ''
    set -euo pipefail
    ${guard}/bin/client-store-guard
    S=/srv/clients/nix-root

    # Shared with deploy-client, which holds it from the build to the profile
    # switch. Read-only open: the lock file belongs to root's directory.
    exec 9</srv/clients/.client-store.lock
    ${pkgs.util-linux}/bin/flock 9

    for p in "$S"/nix/var/nix/profiles/clients/*; do
      case "$p" in *-link) continue ;; esac     # skip the <name>-N-link generations
      [ -L "$p" ] || continue                   # also skips an unmatched glob
      ${pkgs.nix}/bin/nix profile wipe-history --store "$S" --profile "$p"
    done
    ${pkgs.nix}/bin/nix store gc --store "$S"
  '';
in
{
  config = lib.mkIf converted {
    environment.systemPackages = [ guard ];

    systemd.services.client-store-gc = {
      description = "Clean up the client servers' Nix store";
      # The store unlocks after boot (nofail): wait for @clients rather than
      # let a catch-up run at boot refuse before it is mounted
      unitConfig.RequiresMountsFor = [ "/srv/clients" ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = "users";
        ExecStartPre = "+${prepareLock}";
        ExecStart = cleanup;
        Nice = 10;
        IOSchedulingClass = "idle";
      };
      startAt = "weekly";
    };
    systemd.timers.client-store-gc.timerConfig.Persistent = true;
  };
}
