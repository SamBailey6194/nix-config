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

  # Import raw policies from browser_setup so we can merge search/UI additions
  firefoxBase =
    (lib.importJSON (bs + "/policies/firefox-developer/policies.json")).policies;
  librewolfBase =
    lib.importJSON (bs + "/policies/librewolf/policies.json");
  zenBase =
    lib.importJSON (bs + "/policies/zen/policies.json");
  braveBase =
    lib.importJSON (bs + "/policies/brave/managed/syntek-accountability.json");

  # Shared search engine definitions (Gecko/Firefox policy format)
  braveSearchEngine = {
    Name = "Brave Search";
    URLTemplate = "https://search.brave.com/search?q={searchTerms}";
    IconURL = "https://search.brave.com/favicon.ico";
    Alias = "@brave";
    Description = "Brave Search";
  };
  startpageEngine = {
    Name = "Startpage";
    URLTemplate = "https://www.startpage.com/do/search?q={searchTerms}";
    IconURL = "https://www.startpage.com/favicon.ico";
    Alias = "@sp";
    Description = "Startpage - Private search engine";
  };
  mojeekEngine = {
    Name = "Mojeek";
    URLTemplate = "https://www.mojeek.com/search?q={searchTerms}";
    IconURL = "https://www.mojeek.com/favicon.ico";
    Alias = "@mj";
    Description = "Mojeek - Independent search engine";
  };

  # Helper: Gecko (Firefox-family) search + UI policy overlay
  geckoSearchUI = engines: default: {
    policies = {
      SearchEngines = {
        Default = default;
        Add = engines;
      };
      NoDefaultBookmarks = true;
      DisplayBookmarksToolbar = "never";
    };
  };
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
      "brave/policies/managed/syntek-accountability.json".text =
        builtins.toJSON (lib.recursiveUpdate braveBase {
          DefaultSearchProviderEnabled = true;
          DefaultSearchProviderName = "Brave Search";
          DefaultSearchProviderSearchURL = "https://search.brave.com/search?q={searchTerms}";
          DefaultSearchProviderSuggestURL = "https://search.brave.com/api/suggest?q={searchTerms}";
          BookmarkBarEnabled = false;
        });

      "librewolf/policies/policies.json".text =
        builtins.toJSON (lib.recursiveUpdate librewolfBase
          (geckoSearchUI [ mojeekEngine ] "Mojeek"));

      "zen/policies/policies.json".text =
        builtins.toJSON (lib.recursiveUpdate zenBase
          (geckoSearchUI [ braveSearchEngine startpageEngine ] "Brave Search"));

      # Firefox Developer Edition reads /etc/firefox/policies/policies.json (the
      # standard Linux system policy path). Delivered directly here — not via
      # programs.firefox — so it no longer depends on regular Firefox being
      # installed (it isn't, on this system). Single writer for this path.
      "firefox/policies/policies.json".text = builtins.toJSON {
        policies = lib.recursiveUpdate firefoxBase {
          SearchEngines = {
            Default = "Brave Search";
            Add = [ braveSearchEngine startpageEngine ];
          };
          NoDefaultBookmarks = true;
          DisplayBookmarksToolbar = "never";
        };
      };

      # QUIC backstop rule, loaded by the service below. Hashed by the watcher.
      "nftables.d/squid-quic-block.nft".source =
        bs + "/network/squid-quic-block.nft";
    };

    # Firefox Developer Edition's policies are delivered via environment.etc
    # above ("firefox/policies/policies.json"), NOT via programs.firefox, because
    # regular Firefox is no longer installed on this system.

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
