{ config, pkgs, ... }:

let
  username = "sam-desktop";
  state = "/var/lib/syntek-calendar";
  calendar = "${state}/calendar";

  readPassword = pkgs.writeShellScript "syntek-calendar-password" ''
    exec ${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/calendar-caldav"
  '';

  # Both clients create private files. Give downloaded events to the desktop
  # user without following symlinks supplied through the editable directory.
  ownEvent = pkgs.writeScript "syntek-calendar-own-event" ''
    #!${pkgs.python3}/bin/python3
    import os
    import pwd
    import stat
    import sys

    user = pwd.getpwnam("${username}")
    fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NOFOLLOW)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise ValueError("Expected a regular calendar file")
        os.fchown(fd, user.pw_uid, user.pw_gid)
        os.fchmod(fd, 0o600)
    finally:
        os.close(fd)
  '';

  syncConfig = pkgs.writeText "syntek-calendar-vdirsyncer.conf" ''
    [general]
    status_path = "${state}/status"

    [pair syntek]
    a = "syntek_remote"
    b = "syntek_local"
    collections = null

    [storage syntek_remote]
    type = "caldav"
    url = "https://sync.infomaniak.com/calendars/SB25145/f09ff832-71de-46f8-9f02-07a463a06607/"
    username = "SB25145"
    password.fetch = ["command", "${readPassword}"]
    auth = "basic"
    verify = true

    [storage syntek_local]
    type = "filesystem"
    path = "${calendar}"
    fileext = ".ics"
    post_hook = "${ownEvent}"
  '';
in
{
  # Root owns the parent and sync history; the user can edit only the events.
  systemd.tmpfiles.rules = [
    "d ${state} 0711 root root -"
    "d ${state}/status 0700 root root -"
    "d ${calendar} 0700 ${username} users -"
  ];

  systemd.services.syntek-calendar-sync = {
    description = "Synchronise the Syntek Infomaniak calendar";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "agenix.service" "systemd-tmpfiles-setup.service" ];
    unitConfig.ConditionPathExists = config.age.secrets.calendar-caldav.path;
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      LoadCredential = "calendar-caldav:${config.age.secrets.calendar-caldav.path}";
      UMask = "0077";
      TimeoutStartSec = "3min";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_DAC_OVERRIDE" "CAP_FOWNER" ];
      InaccessiblePaths = [ "/run/agenix" ];
      ReadWritePaths = [ state ];
    };
    # With collections=null, discover validates only the two explicit endpoints.
    # Keep conflicts as errors rather than silently preferring either copy.
    script = ''
      ${pkgs.vdirsyncer}/bin/vdirsyncer --config ${syncConfig} discover syntek
      ${pkgs.vdirsyncer}/bin/vdirsyncer --config ${syncConfig} sync syntek
    '';
  };

  systemd.timers.syntek-calendar-sync = {
    description = "Synchronise the Syntek calendar every five minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitInactiveSec = "5min";
    };
  };

  home-manager.users.${username} = {
    home.packages = [ pkgs.khal ];
    xdg.configFile."khal/config".text = ''
      [calendars]
      [[syntek]]
      path = ${calendar}
      color = light blue

      [default]
      default_calendar = syntek
      highlight_event_days = True

      [locale]
      timeformat = %H:%M
      dateformat = %d/%m/%Y
      longdateformat = %d/%m/%Y
      datetimeformat = %d/%m/%Y %H:%M
      longdatetimeformat = %d/%m/%Y %H:%M
      firstweekday = 0
      local_timezone = Europe/London
      default_timezone = Europe/London
    '';
  };
}
