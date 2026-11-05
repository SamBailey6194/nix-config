# Weekly Pixel 8 Pro photo upload over the home WireGuard tunnel
# (docs/PHONE-PHOTO-SYNC.md).
#
#   phone (Syncthing-Fork, send-only)  --wg-home-->  this PC (Syncthing,
#   /sdcard/DCIM, Pictures, Movies                   receive-only)
#                                                    ~/Data/personal/photos/pixel-8-pro/
#
# Syncthing does not run all the time: photo-sync.timer starts it every Sunday
# at 02:00 (or at the next boot if the PC was off), and photo-sync-stop.timer
# stops it 6 hours after any start, scheduled or manual
# (`sudo systemctl start syncthing`). It listens only on the tunnel address,
# with discovery, relays and NAT traversal off, so it is reachable from
# nothing but the phone through wg-home.
#
# The archive keeps everything: the folders are receive-only with ignoreDelete,
# so deleting photos on the phone to free space never deletes them here. Files
# Syncthing would otherwise remove or overwrite (a phone edit, a reused name
# such as 1.jpg, or "Revert Local Changes" in the GUI) are moved into the
# folder's .stversions/ first and never cleaned out automatically.
{ config, lib, pkgs, ... }:
let
  phoneSyncthingId = config.photoSync.phoneSyncthingId;

  # Literals, not config.users.users.*: syncthing's module defines users.users,
  # so reading it back here is infinite recursion.
  user = { name = "sam-desktop"; group = "users"; home = "/home/sam-desktop"; };
  photos = "${user.home}/Data/personal/photos/pixel-8-pro";
  wg = config.networking.wireguard-home;
  serverIP = lib.head (lib.splitString "/" wg.address);
  phoneIP = lib.head (lib.splitString "/" wg.phoneAddress);
  device = "pixel-8-pro";

  # Folder IDs must match the phone's exactly.
  folder = name: {
    id = "${device}-${lib.toLower name}";
    label = "Pixel 8 Pro ${name}";
    path = "${photos}/${name}";
    type = "receiveonly";
    devices = lib.optional (phoneSyncthingId != null) device;
    # Phone deletions are not applied here (archive, not mirror).
    ignoreDelete = true;
    # ignoreDelete does not cover overwrites or a GUI revert (which deletes
    # every file the phone does not have): keep those in .stversions/.
    # cleanoutDays = 0 means never expire; keep is versions per file.
    versioning = {
      type = "simple";
      params = { keep = "10"; cleanoutDays = "0"; };
    };
    # NTFS-3G (~/Data) cannot store Unix permissions anyway.
    ignorePerms = true;
    # Defence in depth: the phone's own ignores should already skip these.
    ignorePatterns = [ ".thumbnails" ".trashed-*" ".pending-*" ];
  };
in
{
  imports = [ ../../modules/network/wireguard-home.nix ];

  options.photoSync.phoneSyncthingId = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "ABCDEFG-HIJKLMN-OPQRSTU-VWXYZ23-4567ABC-DEFGHIJ-KLMNOPQ-RSTUVWX";
    description = ''
      The phone's Syncthing device ID (Syncthing-Fork: menu > Show device ID).
      While null, no device is configured and the folders are not shared.
    '';
  };

  config = {
    # Fill these two in during setup (docs/PHONE-PHOTO-SYNC.md). Both are public
    # identifiers, not secrets. While either is null nothing breaks: the missing
    # part is left out and the rebuild prints a warning.
    photoSync.phoneSyncthingId = null; # e.g. "ABCDEFG-..." from Syncthing-Fork

    networking.wireguard-home = {
      enable = true;
      phonePublicKey = null; # e.g. "abc...=" from the WireGuard app
      # Defaults: wg-home, UDP 51821, 10.200.0.1/24, phone 10.200.0.2/32, keys in
      # /var/lib/desktop-secrets/home-wg-{private,phone-psk}.key, Syncthing only.
    };

    warnings = lib.optional (phoneSyncthingId == null) ''
      photo-sync: the phone's Syncthing device ID is not set in
      hosts/devtower-intel/photo-sync.nix, so the photo folders are not shared
      with any device yet (docs/PHONE-PHOTO-SYNC.md).
    '';

    services.syncthing = {
      enable = true;
      user = user.name;
      group = user.group;
      dataDir = user.home;
      configDir = "${user.home}/.config/syncthing";
      guiAddress = "127.0.0.1:8384";
      openDefaultPorts = false; # wireguard-home allows 22000 on wg-home only
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        options = {
          listenAddresses = [ "tcp://${serverIP}:22000" ];
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
          urAccepted = -1;
          crashReportingEnabled = false;
        };

        devices = lib.optionalAttrs (phoneSyncthingId != null) {
          ${device} = {
            id = phoneSyncthingId;
            # Either side may dial; both directions stay inside the tunnel.
            addresses = [ "tcp://${phoneIP}:22000" ];
            autoAcceptFolders = false;
          };
        };

        folders = {
          "${device}-dcim" = folder "DCIM";
          "${device}-pictures" = folder "Pictures";
          "${device}-movies" = folder "Movies";
        };
      };
    };

    systemd.services.syncthing = {
      # Not at boot: only photo-sync.timer or a manual start runs it.
      wantedBy = lib.mkForce [ ];
      # No ~/Sync default folder on the first start (overrideFolders would drop
      # it from the config but leave the directory behind).
      environment.STNODEFAULTFOLDER = "yes";
      # Apply the declarative config, and arm the auto-stop, on every start.
      wants = [ "syncthing-init.service" "photo-sync-stop.timer" ];
      after = [ "wireguard-${wg.interface}.service" ];
      # Never write into the empty ~/Data mountpoint when the WD is not mounted.
      unitConfig.RequiresMountsFor = [ photos ];
    };
    # Upstream pulls this (and, via Requires=, syncthing) in at boot.
    systemd.services.syncthing-init.wantedBy = lib.mkForce [ ];

    systemd.timers.photo-sync = {
      description = "Weekly Pixel 8 Pro photo upload window";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun *-*-* 02:00:00";
        Persistent = true;
        Unit = "syncthing.service";
      };
    };

    # Armed by syncthing.service (Wants=), so it bounds manual starts too. BindsTo
    # disarms it whenever syncthing stops for any reason, and PartOf re-arms it
    # on restart, so every run gets a fresh 6 hours. To keep a manual run going
    # longer: sudo systemctl stop photo-sync-stop.timer
    systemd.timers.photo-sync-stop = {
      description = "Stop Syncthing 6 hours after it starts";
      bindsTo = [ "syncthing.service" ];
      partOf = [ "syncthing.service" ];
      after = [ "syncthing.service" ];
      timerConfig = {
        OnActiveSec = "6h";
        Unit = "photo-sync-stop.service";
      };
    };

    # An explicit stop, not RuntimeMaxSec: a runtime timeout counts as a failure,
    # which syncthing's Restart=on-failure would answer by starting it again.
    systemd.services.photo-sync-stop = {
      description = "End the Syncthing photo upload window";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.systemd.package}/bin/systemctl stop syncthing.service";
      };
    };
  };
}
