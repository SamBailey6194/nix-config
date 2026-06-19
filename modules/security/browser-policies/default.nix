# Locked browser accountability policies + QUIC firewall backstop.
# Reproduces the private `browser_setup` repo on NixOS: four browsers, each
# routed through the local Squid proxy (127.0.0.1:3128) with QUIC/ECH/DoH off,
# private/incognito disabled, history kept but cookies+cache cleared on exit,
# a fixed forced-extension set, and a privacy-respecting locked default search.
#
# Policies are deployed verbatim from the browser_setup flake input to the
# standard system policy paths (the same locations nixpkgs' own
# `programs.firefox` module uses), so they double as the files the squid-digest
# tamper watcher hashes (SD_PROTECTION_FILES).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.browserPolicies;
  system = pkgs.stdenv.hostPlatform.system;
  bs = inputs.browser_setup;
in
{
  options.services.browserPolicies = {
    enable = lib.mkEnableOption "locked browser accountability policies + QUIC firewall backstop";
  };

  config = lib.mkIf cfg.enable {
    # The four managed browsers. Brave is the Chromium/Claude-extension browser
    # (replaces Google Chrome). Zen is not in nixpkgs, so it comes from a flake.
    environment.systemPackages = [
      pkgs.brave
      pkgs.librewolf
      pkgs.firefox-devedition
      inputs.zen-browser.packages.${system}.default
    ];

    # ---------------------------------------------------------- Policy files
    # Brave (Chromium): reads /etc/brave/policies/managed/ at runtime.
    # LibreWolf / Zen (Gecko forks): read /etc/<app>/policies/policies.json (the
    # Linux system policy location).
    environment.etc = {
      "brave/policies/managed/syntek-accountability.json".source =
        bs + "/policies/brave/managed/syntek-accountability.json";

      "librewolf/policies/policies.json".source =
        bs + "/policies/librewolf/policies.json";

      "zen/policies/policies.json".source =
        bs + "/policies/zen/policies.json";

      # QUIC backstop rule, loaded by the service below. Hashed by the watcher.
      "nftables.d/squid-quic-block.nft".source =
        bs + "/network/squid-quic-block.nft";
    };

    # Firefox (incl. Firefox Developer Edition, which shares /etc/firefox/policies)
    # is delivered through the native option so it merges with the firefox
    # module's own generated /etc/firefox/policies/policies.json (single writer).
    programs.firefox.policies =
      (lib.importJSON (bs + "/policies/firefox-developer/policies.json")).policies;

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
