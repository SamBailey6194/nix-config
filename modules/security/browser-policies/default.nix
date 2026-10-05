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
  '';
  # Zen loads policies beside its actual binary, not the Firefox wrapper.
  zenUnwrapped = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped.override {
    policies = zenPolicies;
    enablePrivateDesktopEntry = false;
  };
  zen = pkgs.wrapFirefox (zenUnwrapped // { version = zenUnwrapped.firefoxVersion; }) {
    pname = "zen-beta";
    icon = "zen-browser";
    extraPolicies = zenPolicies;
    extraPrefs = ''pref("zen.view.sidebar-expanded", false);'';
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
