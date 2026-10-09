# Managed policies shared with the Ubuntu browser_setup repository.
{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.services.browserPolicies;
  bs = inputs.browser_setup;
  firefoxPolicies = (lib.importJSON (bs + "/policies/firefox-developer/policies.json")).policies;
  librewolfPolicies = (lib.importJSON (bs + "/policies/librewolf/policies.json")).policies;
  zenPolicies = (lib.importJSON (bs + "/policies/zen/policies.json")).policies;
  bravePolicies = (lib.importJSON (bs + "/policies/brave/managed/syntek-accountability.json")) // {
    # Additional local development bypasses present on the Ubuntu desktop.
    ProxyBypassList = "localhost;127.0.0.1;::1;<local>;*.ddev.site;*.localhost";
  };
  # These are Ubuntu's observed user preferences, rather than extra locks.
  geckoPrefs = ''
    pref("sidebar.verticalTabs", true);
    pref("sidebar.revamp", true);
    pref("browser.toolbars.bookmarks.visibility", "never");
    // Collapsed launcher, as on Ubuntu. With vertical tabs on, Firefox expands
    // the launcher unless sidebar.backupState says otherwise.
    pref("sidebar.backupState", "{\"launcherExpanded\":false,\"launcherVisible\":true}");
    // Profiles last used with horizontal tabs keep "hide-on-close", a
    // horizontal-only mode that leaves the vertical tab launcher hidden.
    pref("sidebar.visibility", "always-show");
  '';
  # Ubuntu's layout: collapsed left sidebar with the URL bar in a top toolbar.
  # Zen ships use-single-toolbar = true, which moves the URL bar into the
  # sidebar; Firefox's default nav-bar springs then centre it at the top.
  zenPrefs = ''
    // First line must be a comment
    pref("zen.view.sidebar-expanded", false);
    pref("zen.view.use-single-toolbar", false);
    pref("zen.view.compact.enable-at-startup", false);
  '';
  # Zen loads policies and AutoConfig beside its actual binary, not the
  # Firefox wrapper: bin/zen-beta is a symlink into the unwrapped package, so
  # Gecko takes that as its install directory (compatibility.ini records it as
  # LastPlatformDir) and never reads the wrapper's mozilla.cfg. The prefs are
  # therefore installed into the unwrapped package, as the policies are. The
  # files are not named autoconfig.js/mozilla.cfg because wrapFirefox writes
  # those through its symlinks into this package and would hit read-only files.
  zenUnwrapped = (inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped.override {
    policies = zenPolicies;
    enablePrivateDesktopEntry = false;
  }).overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      for zenLib in "$out"/lib/zen-bin-*; do
        # Copied read-only from the release tarball.
        chmod u+w "$zenLib"
        if [ -d "$zenLib/defaults" ]; then chmod -R u+w "$zenLib/defaults"; fi
        install -Dm444 ${pkgs.writeText "zen-layout-autoconfig.js" ''
          pref("general.config.filename", "zen-layout.cfg");
          pref("general.config.obscure_value", 0);
        ''} "$zenLib/defaults/pref/zen-layout-autoconfig.js"
        install -Dm444 ${pkgs.writeText "zen-layout.cfg" zenPrefs} "$zenLib/zen-layout.cfg"
      done
    '';
  });
  zen = pkgs.wrapFirefox (zenUnwrapped // { version = zenUnwrapped.firefoxVersion; }) {
    pname = "zen-beta";
    icon = "zen-browser";
    extraPolicies = zenPolicies;
  };
in {
  options.services.browserPolicies.enable = lib.mkEnableOption "shared managed browser policies and local proxy";

  config = lib.mkIf cfg.enable {
    # Every reference to these packages, including Home Manager and launchers,
    # receives the same policies. Avoid installing an unmanaged second wrapper.
    nixpkgs.overlays = [ (final: prev: {
      librewolf = prev.librewolf.override {
        extraPolicies = librewolfPolicies;
        extraPrefs = geckoPrefs;
      };
      firefox-devedition = prev.firefox-devedition.override {
        extraPolicies = firefoxPolicies;
        extraPrefs = geckoPrefs;
      };
    }) ];
    environment.systemPackages = [ pkgs.brave pkgs.librewolf pkgs.firefox-devedition zen ];

    # The source policies require this proxy even before digest secrets exist.
    services.squid = {
      enable = true;
      proxyAddress = "127.0.0.1";
      proxyPort = 3128;
    };

    services.logrotate.settings.squid = lib.mkDefault {
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

    # Keep inspectable copies for the accountability policy watcher. Gecko's
    # package policies above are authoritative for the launched binaries.
    environment.etc = {
      "brave/policies/managed/syntek-accountability.json".text = builtins.toJSON bravePolicies;
      "librewolf/policies/policies.json".text = builtins.toJSON { policies = librewolfPolicies; };
      "firefox/policies/policies.json".text = builtins.toJSON { policies = firefoxPolicies; };
      "zen/policies/policies.json".text = builtins.toJSON { policies = zenPolicies; };
      "nftables.d/squid-quic-block.nft".source = bs + "/network/squid-quic-block.nft";
    };

    # --------------------------------------------------- QUIC firewall backstop
    # Reject outbound UDP/443 so QUIC/HTTP-3 fails fast and every browser falls
    # back to TCP/443 through Squid (where it is logged). Loaded as a standalone
    # `inet squid_quic_block` table WITHOUT networking.nftables.enable, which
    # would blacklist ip_tables and break the existing iptables Mullvad kill
    # switch. The table's declare-then-delete pair makes reloads idempotent and
    # it coexists with the iptables rules.
    systemd.services.squid-quic-block = {
      description = "Reject QUIC (UDP/443) so browsers fall back to TCP through Squid";
      after = [ "network-pre.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.nftables}/bin/nft -f /etc/nftables.d/squid-quic-block.nft";
        ExecStop = "${pkgs.nftables}/bin/nft delete table inet squid_quic_block";
      };
    };
  };
}
