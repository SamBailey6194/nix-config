{ config, lib, ... }:

let
  # Every normal user's browser download folder. The browser policies in
  # modules/security/browser-policies lock downloads to ~/Downloads.
  downloadDirs = lib.mapAttrsToList (_: user: {
    path = "${user.home}/Downloads";
    inherit (user) name group;
  }) (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);
in
{
  # Download automation invokes clamscan directly so every scan can enforce
  # signature freshness, archive limits and encrypted-content alerts. It does
  # not depend on the optional Rust monitor or clamd availability.
  services.clamav.updater.enable = lib.mkDefault true;
  services.clamav.updater.interval = lib.mkDefault "hourly";

  # On-access scanning: clamonacc asks clamd to scan each file in ~/Downloads
  # when it is opened and the kernel (fanotify) refuses the open if ClamAV
  # finds a threat. This closes the minutes before the download sorter's
  # scheduled scan; the sorter still scans subfolders and larger files, and
  # quarantines anything clamonacc blocked.
  services.clamav.daemon.enable = true;
  services.clamav.clamonacc.enable = lib.mkDefault true;
  services.clamav.daemon.settings = lib.mkIf config.services.clamav.clamonacc.enable {
    OnAccessIncludePath = map (dir: dir.path) downloadDirs;
    OnAccessPrevention = true;
    # ClamAV's documented setup for blocking: watch the folder itself, without
    # Dynamic Directory Determination's recursive inotify tree.
    OnAccessDisableDDD = true;
    # ClamAV's default. With prevention clamonacc also asks for a scan on
    # every read() (FAN_ACCESS_PERM), and each request hashes the whole file
    # for clamd's cache, so large limits make reading big files very slow.
    # Larger files open unscanned here; the download sorter scans them in full.
    OnAccessMaxFileSize = "5M";
  };
  # The nixpkgs unit has no restart, and clamonacc exits on some runtime
  # errors. The download sorter alerts while it is down.
  systemd.services.clamav-clamonacc.serviceConfig = lib.mkIf config.services.clamav.clamonacc.enable {
    Restart = "on-failure";
    RestartSec = 10;
  };

  # clamonacc cannot watch a folder that does not exist yet.
  systemd.tmpfiles.rules = lib.mkIf config.services.clamav.clamonacc.enable
    (map (dir: "d ${dir.path} 0755 ${dir.name} ${dir.group} -") downloadDirs);
}
