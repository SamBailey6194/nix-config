# Squid accountability proxy + squid-digest (weekly adult-domain report and
# tamper watchers). Reproduces the Ubuntu setup from the private
# `accountability_script` repo declaratively on NixOS.
#
# What this module wires up when `services.squidDigest.enable = true`:
#   - Squid on 127.0.0.1:3128 with the accountability log format (domains only).
#   - logrotate keeping >= 8 days so the weekly 7-day digest has history.
#   - A blocklist refresh service/timer that rebuilds /var/lib/squid-digest/
#     adult-domains.txt from the upstream Block List Project list + the repo's
#     custom-blocklist.txt.
#   - The squid-digest binary (built from the accountability_script flake input).
#   - systemd units: weekly digest (root), tamper watch (root), per-user GNOME
#     proxy watch (watch-proxy).
#   - Non-secret config in /etc/squid-digest/defaults.env; secrets (Gmail creds,
#     recipient, heartbeat URL) from the agenix `squid-digest-env` secret, which
#     must be declared by the host's secrets module (see modules/core/secrets-*).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.squidDigest;

  squid-digest = pkgs.callPackage ./package.nix {
    accountability_script = inputs.accountability_script;
  };

  stateDir = "/var/lib/squid-digest";
  blocklistFile = "${stateDir}/adult-domains.txt";
  hashStateFile = "${stateDir}/conf-hashes.txt";

  # The accountability squid snippet — fed to squid AND written to the store so
  # the tamper watcher has a stable file to hash (squid's real config is
  # immutable in the Nix store and can't be edited at runtime on NixOS).
  acctSquidConf = ''
    # Parser-friendly log: epoch, client IP, method, host:port/URL, status, result
    logformat acct %ts.%03tu %>a %rm %ru %>Hs %Ss
    access_log daemon:/var/log/squid/access.log acct

    # Keep full hostnames (don't strip), but drop query terms for privacy.
    strip_query_terms on

    # DNS resilience — make name resolution independent of the VPN.
    # Squid reads its nameservers once at startup; NetworkManager/wg-quick then
    # rewrite /etc/resolv.conf afterwards (e.g. when the Mullvad VPN goes up or
    # down), leaving Squid querying dead servers — so every hostname CONNECT
    # times out while raw-IP requests still succeed. Pinning explicit public
    # resolvers makes resolution work whether the VPN is up or down, and on any
    # network (mobile/multi-homed friendly). dns_v4_first avoids stalls when
    # IPv6 egress is unavailable.
    dns_nameservers 1.1.1.1 1.0.0.1 9.9.9.9
    dns_v4_first on
  '';
  acctSquidConfFile = pkgs.writeText "squid-accountability.conf" acctSquidConf;

  customBlocklist = inputs.accountability_script + "/squid-digest/custom-blocklist.txt";

  # Browser/firewall policy files the root watcher hashes for tamper detection.
  # These are the /etc paths the browser-policies module deploys; missing paths
  # are skipped safely, so listing all of them here is harmless when that module
  # is not enabled. Keep in sync with modules/security/browser-policies.
  protectionFiles = [
    "/etc/brave/policies/managed/syntek-accountability.json"
    "/etc/firefox/policies/policies.json" # also covers Firefox Developer Edition
    "/etc/librewolf/policies/policies.json"
    "/etc/zen/policies/policies.json"
    "/etc/nftables.d/squid-quic-block.nft"
  ];

  # The secret EnvironmentFile lives wherever agenix decrypts it. Declared by the
  # host secrets module as age.secrets.squid-digest-env.
  secretEnv = config.age.secrets.squid-digest-env.path;
  defaultsEnv = "/etc/squid-digest/defaults.env";

  # Order matters: systemd lets a later EnvironmentFile override an earlier one
  # for the same key. defaults.env (Nix-managed, non-secret) is loaded first and
  # the agenix secret last, so the secret WINS on any key it defines. Today the
  # secret only sets the four credentials; its non-secret SD_* lines are commented
  # out, so Nix's declarative values apply. To move a value into agenix instead,
  # uncomment it in the secret and it overrides defaults.env — no module change.
  envFiles = [ defaultsEnv secretEnv ];
in
{
  options.services.squidDigest = {
    enable = lib.mkEnableOption "Squid accountability proxy + squid-digest watchers";

    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        Primary desktop user. Used for SD_USERS and granted group-read of the
        env secret so the per-user watch-proxy service can read it.
      '';
    };

    fromName = lib.mkOption {
      type = lib.types.str;
      default = "Home Accountability";
      example = "Laptop Accountability";
      description = "Display name on the From: line of digest/alert emails (SD_MAIL_FROM_NAME).";
    };

    blocklistUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://raw.githubusercontent.com/blocklistproject/Lists/master/porn.txt";
      description = "Upstream adult-domain blocklist URL (Block List Project porn list).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ squid-digest ];

    # ------------------------------------------------------------------ Squid
    services.squid = {
      enable = true;
      proxyPort = 3128;
      extraConfig = acctSquidConf;
    };

    # Keep >= 8 days of rotations (incl. .gz) so the weekly digest sees a full
    # 7 days. NixOS's squid module ships no logrotate of its own.
    services.logrotate.settings.squid = {
      files = "/var/log/squid/*.log";
      frequency = "daily";
      rotate = 14;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      su = "squid squid";
      postrotate = "${pkgs.systemd}/bin/systemctl reload squid.service 2>/dev/null || true";
    };

    # ------------------------------------------------- Non-secret config (/etc)
    environment.etc."squid-digest/defaults.env".text = ''
      # Generated by modules/security/squid-digest — non-secret config only.
      # Secrets (SD_SMTP_USER/PASS, SD_MAIL_TO, SD_HEARTBEAT_URL) come from the
      # agenix squid-digest-env secret, loaded as a second EnvironmentFile.
      SD_SMTP_HOST=smtp.gmail.com
      SD_SMTP_PORT=587
      SD_MAIL_FROM_NAME=${cfg.fromName}
      SD_LOG_DIR=/var/log/squid
      SD_LOG_BASENAME=access.log
      SD_BLOCKLIST=${blocklistFile}
      SD_SQUID_CONF=${acctSquidConfFile}
      SD_PROTECTION_FILES=${lib.concatStringsSep "," protectionFiles}
      SD_HASH_STATE=${hashStateFile}
      SD_USERS=${cfg.user}
    '';

    # ----------------------------------------------------- Blocklist assembly
    systemd.services.squid-digest-blocklist = {
      description = "Fetch + assemble the adult-domains blocklist";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "squid-digest";
        StateDirectoryMode = "0755";
        ExecStart = pkgs.writeShellScript "squid-digest-fetch-blocklist" ''
          set -euo pipefail
          tmp="$(${pkgs.coreutils}/bin/mktemp)"
          trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
          # Upstream list (~10MB). The parser accepts both hosts (0.0.0.0 ...)
          # and plain-domain formats. Append our tracked additions afterwards;
          # squid-digest de-duplicates on load.
          ${pkgs.curl}/bin/curl -fsSL ${lib.escapeShellArg cfg.blocklistUrl} -o "$tmp"
          ${pkgs.coreutils}/bin/cat "$tmp" ${customBlocklist} > ${blocklistFile}
        '';
      };
    };
    systemd.timers.squid-digest-blocklist = {
      description = "Refresh the adult-domains blocklist weekly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1w";
        Persistent = true;
      };
    };

    # ----------------------------------------------------- Weekly digest (root)
    systemd.services.squid-digest-weekly = {
      description = "Weekly accountability digest email";
      after = [ "network-online.target" "squid-digest-blocklist.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${squid-digest}/bin/squid-digest weekly";
        EnvironmentFile = envFiles;
        StateDirectory = "squid-digest";
        User = "root";
      };
    };
    systemd.timers.squid-digest-weekly = {
      description = "Run the weekly accountability digest";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 18:00";
        Persistent = true;
      };
    };

    # ------------------------------------------------------ Tamper watch (root)
    systemd.services.squid-digest-watch = {
      description = "Accountability tamper watcher (squid/config/policies)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ]; # the watch pings the off-machine heartbeat
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${squid-digest}/bin/squid-digest watch";
        EnvironmentFile = envFiles;
        StateDirectory = "squid-digest";
        User = "root";
      };
    };
    systemd.timers.squid-digest-watch = {
      description = "Run the tamper watcher frequently";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
      };
    };

    # --------------------------------------------- Per-user GNOME proxy watcher
    # The GNOME proxy is per-user; root can't read it correctly, so this runs as
    # the desktop user via systemctl --user.
    systemd.user.services.squid-digest-watch-proxy = {
      description = "Per-user GNOME proxy watcher (still -> squid)";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${squid-digest}/bin/squid-digest watch-proxy";
        EnvironmentFile = envFiles;
      };
    };
    systemd.user.timers.squid-digest-watch-proxy = {
      description = "Run the per-user proxy watcher frequently";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnStartupSec = "2min";
        OnUnitActiveSec = "5min";
      };
    };
  };
}
