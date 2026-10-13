# Linux data drives: the old Ubuntu filesystems until each one is converted,
# then that drive's own LUKS2 container (own passphrase, plus a TPM2 token so it
# unlocks automatically). Converted one at a time after installation:
# docs/BACKUP-AND-DATA-ENCRYPTION.md#encrypt-one-drive-at-a-time.
#
# A drive switches over when both of its UUIDs in ./disks.nix (dataDrives) are
# filled in. Until then nothing here changes for it.
#
#   home    Samsung 512GB   -> /home (replaces the Intel @home subvolume)
#   store   Samsung 870 EVO -> /var/lib/docker (replaces the Intel @docker),
#                              /var/lib/libvirt/images and /srv/clients; the
#                              system /nix stays on the OS drive
#   archive Seagate 4TB     -> /mnt/archive (superseded: it becomes the VeraCrypt
#                              mirror of the WD 4TB, docs/SHARED-DATA-DRIVES.md;
#                              leave dataDrives.archive null)
#
# home unlocks in the initrd like cryptroot, because the system needs it to
# boot; without a TPM2 token (or if the TPM refuses) the initrd asks for its
# passphrase. store and archive aren't needed to boot: they unlock after boot
# from /etc/crypttab with nofail, so a missing or failing drive never holds up
# boot. Their passphrase prompt can't be seen once the login screen is up, so
# if a TPM2 token fails, unlock from a terminal
# (`sudo systemd-tty-ask-password-agent --query`). The archive automount then
# picks it up on the next access to /mnt/archive; for the store, start
# store-quotas.service, docker.service and libvirtd.service again, which pull
# its three mounts in.
# TPM2 tokens are enrolled per drive with systemd-cryptenroll --tpm2-pcrs=7.

{ config, lib, pkgs, ... }:

let
  disks = import ./disks.nix;
  drives = disks.dataDrives;
  byUuid = uuid: "/dev/disk/by-uuid/${uuid}";

  converted = name: drives.${name}.luksUuid != null && drives.${name}.fsUuid != null;
  halfFilled = name: (drives.${name}.luksUuid == null) != (drives.${name}.fsUuid == null);

  subvol = name: sv: extra: {
    device = byUuid drives.${name}.fsUuid;
    fsType = "btrfs";
    options = [ "subvol=${sv}" "compress=zstd:1" "noatime" ] ++ extra;
  };

  # After-boot unlock (crypttab), so allow for the device to appear late.
  storeMountOpts = [ "nofail" "x-systemd.device-timeout=30s" ];
  storeQuotaList = [
    { path = "/var/lib/docker"; limit = disks.storeQuotas.docker; }
    { path = "/var/lib/libvirt/images"; limit = disks.storeQuotas.vm; }
    { path = "/srv/clients"; limit = disks.storeQuotas.clients; }
  ];

  initrdLuks = name: {
    device = byUuid drives.${name}.luksUuid;
    allowDiscards = true;
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };
in
{
  config = lib.mkMerge [
    {
      assertions = map (name: {
        assertion = !(halfFilled name);
        message = "devtower-intel: disks.nix dataDrives.${name} needs both luksUuid and fsUuid (or neither).";
      }) (builtins.attrNames drives);
    }

    # ── home: Samsung 512GB ──────────────────────────────────────────────
    (lib.mkIf (!converted "home") {
      fileSystems."/mnt/ubuntu-home" = {
        device = byUuid disks.ubuntuHomeUuid;
        fsType = "ext4";
        options = [ "nofail" "noatime" ];
      };
    })
    (lib.mkIf (converted "home") {
      boot.initrd.luks.devices.crypthome = initrdLuks "home";
      fileSystems."/home" = lib.mkForce (subvol "home" "@home" [ ]);
      # A separate filesystem now, so scrub it in its own right.
      services.btrfs.autoScrub.fileSystems = [ "/home" ];
    })

    # ── store: Samsung 870 EVO 2TB ───────────────────────────────────────
    # Keep the old store and Docker data intact for recovery until this drive
    # is converted. Do not start a second daemon against old Docker data.
    (lib.mkIf (!converted "store") {
      fileSystems."/mnt/ubuntu-nix" = {
        device = byUuid disks.ubuntuNixUuid;
        fsType = "ext4";
        options = [ "ro" "nofail" "noatime" ];
      };
      fileSystems."/mnt/ubuntu-docker" = {
        device = byUuid disks.ubuntuDockerUuid;
        fsType = "ext4";
        options = [ "ro" "nofail" "noatime" ];
      };
    })
    (lib.mkIf (converted "store") {
      # discard passes TRIM through, as allowDiscards does for the other SSDs.
      environment.etc.crypttab.text = ''
        cryptstore UUID=${drives.store.luksUuid} - tpm2-device=auto,nofail,discard,x-systemd.device-timeout=10s
      '';
      # Plain nofail mounts, not automounts: docker, libvirtd and the quota
      # oneshot below need RequiresMountsFor, which starts the mount itself
      # anyway, and the client-store checks (findmnt /srv/clients) want a real
      # mount. If the device isn't there in time the mount fails rather than
      # retrying, so the services that need it fail too instead of writing to
      # the root drive. /var/lib/docker overrides the Intel @docker.
      fileSystems."/var/lib/docker" = lib.mkForce (subvol "store" "@docker" storeMountOpts);
      fileSystems."/var/lib/libvirt/images" = subvol "store" "@vm" storeMountOpts;
      fileSystems."/srv/clients" = subvol "store" "@clients" storeMountOpts;

      systemd.services.docker = lib.mkIf config.virtualisation.docker.enable {
        unitConfig.RequiresMountsFor = [ "/var/lib/docker" ];
      };
      systemd.services.libvirtd = lib.mkIf config.virtualisation.libvirtd.enable {
        unitConfig.RequiresMountsFor = [ "/var/lib/libvirt/images" ];
      };

      # Re-apply the caps from disks.nix (storeQuotas) at every boot, so
      # changing one is a single number and a rebuild. Setting the same limit
      # again is a no-op. Fails if a path isn't on a filesystem with simple
      # quotas (the store not mounted, or quotas never enabled), rather than
      # setting full-accounting limits or limits on the root drive.
      systemd.services.store-quotas = {
        description = "Apply btrfs simple-quota caps on the store subvolumes";
        wantedBy = [ "multi-user.target" ];
        before = [ "docker.service" "libvirtd.service" ];
        unitConfig.RequiresMountsFor = map (q: q.path) storeQuotaList;
        path = [ pkgs.btrfs-progs pkgs.gnugrep ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${lib.concatMapStrings (q: ''
            if ! btrfs quota status ${q.path} | grep -Eq '^ *Mode: +squota '; then
              echo "store-quotas: simple quotas are not enabled on ${q.path}" >&2
              btrfs quota status ${q.path} >&2 || true
              exit 1
            fi
            btrfs qgroup limit ${q.limit} ${q.path}
          '') storeQuotaList}
        '';
      };

      # One btrfs filesystem behind all three mounts: scrub it once.
      services.btrfs.autoScrub.fileSystems = [ "/srv/clients" ];
    })

    # ── archive: Seagate ST4000DM004 4TB ─────────────────────────────────
    (lib.mkIf (!converted "archive") {
      fileSystems."/mnt/archive" = {
        device = byUuid disks.archiveUuid;
        fsType = "ext4";
        options = [ "nofail" "noatime" ];
      };
    })
    (lib.mkIf (converted "archive") {
      environment.etc.crypttab.text = ''
        cryptarchive UUID=${drives.archive.luksUuid} - tpm2-device=auto,nofail,x-systemd.device-timeout=10s
      '';
      # automount: mounted on first access whenever the device is unlocked, so a
      # late (passphrase) unlock still works; a plain nofail mount would give up
      # after its device timeout and not retry.
      fileSystems."/mnt/archive" = subvol "archive" "@archive" [
        "nofail"
        "x-systemd.automount"
        "x-systemd.device-timeout=10s"
      ];
      # Scrubbing is what catches silent corruption on a long-term archive.
      # If the drive is absent that month's scrub unit fails visibly.
      services.btrfs.autoScrub.fileSystems = [ "/mnt/archive" ];
    })
  ];
}
