{ config, lib, pkgs, ... }:

let
  # Set to true once rclone.conf is configured with gdrive-personal and gdrive-business remotes
  enableGdrive = false;
in
lib.mkIf enableGdrive {
  # Ensure Google Drive mount points exist
  home.file."GoogleDrive/Personal/.keep".text = "";
  home.file."GoogleDrive/Business/.keep".text = "";

  # Personal Google Drive mount service
  systemd.user.services.gdrive-personal = {
    Unit = {
      Description = "Mount Personal Google Drive with rclone";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/GoogleDrive/Personal";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount gdrive-personal: %h/GoogleDrive/Personal \
          --vfs-cache-mode full \
          --vfs-cache-max-age 72h \
          --vfs-read-chunk-size 128M \
          --vfs-read-chunk-size-limit 2G \
          --buffer-size 512M \
          --poll-interval 15s \
          --dir-cache-time 72h \
          --log-level INFO
      '';
      ExecStop = "${pkgs.fuse}/bin/fusermount -u %h/GoogleDrive/Personal";
      Restart = "on-failure";
      RestartSec = "10s";

      # Environment
      Environment = [
        "PATH=${pkgs.fuse}/bin:${pkgs.rclone}/bin"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Business Google Drive mount service
  systemd.user.services.gdrive-business = {
    Unit = {
      Description = "Mount Business Google Drive with rclone";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/GoogleDrive/Syntek";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount gdrive-business: %h/GoogleDrive/Syntek \
          --vfs-cache-mode full \
          --vfs-cache-max-age 72h \
          --vfs-read-chunk-size 128M \
          --vfs-read-chunk-size-limit 2G \
          --buffer-size 512M \
          --poll-interval 15s \
          --dir-cache-time 72h \
          --log-level INFO
      '';
      ExecStop = "${pkgs.fuse}/bin/fusermount -u %h/GoogleDrive/Syntek";
      Restart = "on-failure";
      RestartSec = "10s";

      # Environment
      Environment = [
        "PATH=${pkgs.fuse}/bin:${pkgs.rclone}/bin"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
