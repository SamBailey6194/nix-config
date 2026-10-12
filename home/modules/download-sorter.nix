{ config, lib, pkgs, osConfig ? {}, ... }:

let
  cfg = config.services.downloadSorter;
  settings = pkgs.writeText "download-sorter.json" (builtins.toJSON {
    inherit (cfg) source minimumAge rules normalizeNames learnedRouting minimumChoices
      maxSignatureAge maxFileSize scanTimeout scanTimeoutPerGiB autoScanCap chunkSize chunkOverlap
      maxExtractionDepth maxExtractedMembers extractionRatio freeSpaceMargin;
    scanner = "${pkgs.clamav}/bin/clamscan";
    # Read-only extractors for layered scans; nothing unpacked is executed.
    bsdtar = "${pkgs.libarchive}/bin/bsdtar";
    unsquashfs = "${pkgs.squashfsTools}/bin/unsquashfs";
    signatureDirectory = "/var/lib/clamav";
    notifier = "${pkgs.libnotify}/bin/notify-send";
    soundPlayer = "${pkgs.pulseaudio}/bin/paplay";
    alertSound = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/dialog-warning.oga";
  });
  gib = 1024 * 1024 * 1024;
  mib = 1024 * 1024;
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
      type = lib.types.ints.between 1 2147483647;
      # ClamAV cannot scan any single file over 2 GiB - 1 byte; keep 1 MiB spare.
      default = 2047 * mib;
      description = "ClamAV per-file limit in bytes. Larger downloads, up to autoScanCap, are unpacked and their members scanned; members still larger, and containers that cannot be shown to be unpacked byte for byte (anything but a well-formed ZIP), are also chunk-scanned and held.";
    };
    autoScanCap = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50 * gib;
      description = "Largest download in bytes scanned automatically in layers. Larger downloads are held unscanned until approved with download-sorter --approve.";
    };
    chunkSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = gib;
      description = "Bytes per chunk when a file that cannot be unpacked exceeds maxFileSize; at most one chunk is kept in staging.";
    };
    chunkOverlap = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 16 * mib;
      description = "Bytes shared by consecutive chunks; longer than any ClamAV byte-pattern signature, so matches spanning a boundary are found.";
    };
    maxExtractionDepth = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Maximum nested archive layers unpacked for oversized files; deeper nesting is held as a possible archive bomb.";
    };
    maxExtractedMembers = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100000;
      description = "Maximum entries unpacked from one download before it is held as a possible archive bomb.";
    };
    extractionRatio = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Maximum unpacked bytes as a multiple of the download size (also bounded by free space minus freeSpaceMargin).";
    };
    freeSpaceMargin = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 10 * gib;
      description = "Free bytes always left in the staging filesystem while unpacking.";
    };
    scanTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Base seconds allowed for each ClamAV scan or unpacking step before processing stops with an alert.";
    };
    scanTimeoutPerGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Additional seconds per GiB of input for each ClamAV scan or unpacking step.";
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
    } {
      assertion = cfg.chunkOverlap < cfg.chunkSize && cfg.chunkSize <= cfg.maxFileSize && cfg.maxFileSize <= cfg.autoScanCap;
      message = "services.downloadSorter needs chunkOverlap < chunkSize <= maxFileSize <= autoScanCap.";
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
