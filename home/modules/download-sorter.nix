{ config, lib, pkgs, osConfig ? {}, ... }:

let
  cfg = config.services.downloadSorter;
  settings = pkgs.writeText "download-sorter.json" (builtins.toJSON {
    inherit (cfg) source minimumAge rules normalizeNames learnedRouting minimumChoices
      maxSignatureAge maxFileSize scanTimeout;
    scanner = "${pkgs.clamav}/bin/clamscan";
    signatureDirectory = "/var/lib/clamav";
    notifier = "${pkgs.libnotify}/bin/notify-send";
    soundPlayer = "${pkgs.pulseaudio}/bin/paplay";
    alertSound = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/dialog-warning.oga";
  });
  sorter = pkgs.writeShellScriptBin "download-sorter" ''
    exec ${pkgs.python3}/bin/python3 ${../../scripts/download-sorter.py} \
      --config ${settings} "$@"
  '';
in
{
  options.services.downloadSorter = {
    enable = lib.mkEnableOption "the configurable download sorter";
    automatic = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically route successfully scanned downloads using explicit rules or eligible recorded choices.";
    };
    automaticRenaming = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically normalise settled download filenames even when automatic routing is disabled.";
    };
    normalizeNames = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Convert download filenames to kebab case, retaining file extensions.";
    };
    learnedRouting = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow deterministic routing from explicitly recorded human choices. Requires automatic routing for timer-driven moves.";
    };
    minimumChoices = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Minimum distinct scanned file contents recorded for a pattern and one consistent destination.";
    };
    maxSignatureAge = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Maximum age in days of the ClamAV signature database before scanning is rejected.";
    };
    maxFileSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1024 * 1024 * 1024;
      description = "Maximum file size in bytes that can be scanned automatically; larger files raise a critical alert.";
    };
    scanTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds allowed for each ClamAV scan before processing stops with an alert.";
    };
    source = lib.mkOption {
      type = lib.types.str;
      default = config.xdg.userDirs.download;
      description = "Download directory; supports $HOME and ~ expansion.";
    };
    minimumAge = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 120;
      description = "Minimum seconds since the file was modified before it can move.";
    };
    rules = lib.mkOption {
      default = [];
      description = "Ordered routing rules; the first matching rule wins. Missing or uncertain destinations raise a critical alert when routing is enabled.";
      type = lib.types.listOf (lib.types.submodule {
        options = {
          patterns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Case-insensitive filename globs, such as invoice-*.pdf or *.jpg.";
          };
          destination = lib.mkOption {
            type = lib.types.str;
            description = "Destination directory; supports $HOME and ~ expansion.";
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = lib.attrByPath [ "services" "clamav" "updater" "enable" ] false osConfig;
      message = "Download automation requires services.clamav.updater.enable in NixOS to maintain antivirus signatures.";
    }];
    home.packages = [ sorter ];
    systemd.user.services.download-sorter = {
      Unit = {
        Description = "Scan, normalise and sort settled downloads";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "infinity"; # Each scan has its own bounded timeout.
        Nice = 10;
        ExecStart = "${sorter}/bin/download-sorter${lib.optionalString (!cfg.automatic)
          (if cfg.automaticRenaming then " --rename-only" else " --scan-only")}";
        UMask = "0077";
      };
    };
    systemd.user.timers.download-sorter = {
      Unit = {
        Description = "Check downloads every minute";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnStartupSec = "1min";
        OnUnitInactiveSec = "1min";
        Unit = "download-sorter.service";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
