{ lib, pkgs, osConfig ? { }, ... }:

# Files finished meeting notes from ~/Documents/Meetings (software.meetingNotes)
# into syntek-business-docs' client-docs/<client>/meeting-notes/, every 15
# minutes. The script, its client aliases and the review steps belong to that
# repo (library/workflows/local/01-file-meeting-notes/); it holds no
# credential, so the timer runs the repo's own copy. It never commits.

let
  dir = "%h/Repos/syntek/syntek-business-docs/library/workflows/local/01-file-meeting-notes";
  failureAlert = pkgs.writeShellScript "meeting-notes-filing-failed" ''
    exec ${pkgs.libnotify}/bin/notify-send --app-name=meeting-notes --urgency=critical \
      --hint=string:x-dunst-stack-tag:meeting-notes-filing-failed \
      "Meeting notes filing failed" \
      "Finished meetings are not being filed. Details: journalctl --user -u meeting-notes-filing"
  '';
in
{
  config = lib.mkIf (osConfig.software.meetingNotes.enable or false) {
    systemd.user.services.meeting-notes-filing = {
      Unit = {
        Description = "File finished meeting notes into syntek-business-docs";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        # Skip quietly until the repo is cloned and the first meeting recorded;
        # the script exits 2 (a failure) without either.
        ConditionPathExists = "${dir}/file_meeting_notes.py";
        ConditionPathIsDirectory = "%h/Documents/Meetings";
        OnFailure = [ "meeting-notes-filing-failed.service" ];
      };
      Service = {
        Type = "oneshot";
        # notify-send for --notify; the script uses only the standard library.
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.libnotify ]}" ];
        ExecStart = "${pkgs.python3}/bin/python3 -I ${dir}/file_meeting_notes.py run --notify";
        Nice = 10;
      };
    };
    systemd.user.services.meeting-notes-filing-failed = {
      Unit.Description = "Alert that meeting notes filing failed";
      Service = {
        Type = "oneshot";
        ExecStart = "${failureAlert}";
      };
    };
    systemd.user.timers.meeting-notes-filing = {
      Unit = {
        Description = "File finished meeting notes every 15 minutes";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnStartupSec = "2min";
        OnUnitInactiveSec = "15min";
        Unit = "meeting-notes-filing.service";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
