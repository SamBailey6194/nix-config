# Declarative NetworkManager Wi-Fi profiles
#
# Passphrases are never written into the Nix store or committed in the clear.
# They live in the agenix secret `wifi-passwords` (secrets/wifi-passwords.age),
# decrypted at activation to /run/agenix/wifi-passwords in systemd
# EnvironmentFile format:
#
#   PCC_PUBLIC_PSK=...
#
# The NetworkManager-ensure-profiles unit reads that file, runs envsubst over
# the generated keyfiles, and writes the results to
# /run/NetworkManager/system-connections (tmpfs, umask 0177) - so the
# passphrase never touches persistent storage.
#
# Adding an SSID: add a KEY=value line to the secret, then a profile below
# referencing "$KEY". Nothing else needs to change.

{ config, lib, ... }:

{
  # Inert until a host also imports secrets-laptop.nix / secrets-desktop.nix,
  # so framework and devtower can carry the import before they are installed.
  config = lib.mkIf (config.age.secrets ? wifi-passwords) {

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.age.secrets.wifi-passwords.path ];

      profiles = {
        # ====================================================================
        # PCC-Public - untrusted guest network
        #
        # WPA2/WPA3 transition mode, but the PSK is handed out to every guest,
        # so any other client on the network can derive our session keys and
        # read our traffic. Treated as hostile: manual connect only, fresh MAC
        # each time, and it must never outrank a known network.
        # ====================================================================
        PCC-Public = {
          connection = {
            id = "PCC-Public";
            type = "wifi";
            # Never join on its own - connecting is always a deliberate act.
            autoconnect = false;
            # Belt and braces: if something does trigger it, it loses to
            # every ordinary profile (which default to priority 0).
            autoconnect-priority = -999;
            permissions = "";
          };

          wifi = {
            mode = "infrastructure";
            ssid = "PCC-Public";
            # New random MAC on every activation: the site cannot correlate
            # visits, and our real hardware address is never broadcast.
            cloned-mac-address = "random";
            mac-address-blacklist = "";
          };

          wifi-security = {
            key-mgmt = "wpa-psk";
            auth-alg = "open";
            psk = "$PCC_PUBLIC_PSK";
            # Pin the RSN/CCMP suite so a rogue AP cannot negotiate us down
            # to TKIP or WEP. Safe for both WPA2 and WPA3-Personal.
            proto = "rsn";
            pairwise = "ccmp";
            group = "ccmp";
            # 2 = optional. Uses management-frame protection where the AP
            # offers it; 3 (required) would break the WPA2 half of the
            # transition-mode deployment.
            pmf = 2;
          };

          ipv4 = {
            method = "auto";
            dns-search = "";
          };

          ipv6 = {
            method = "auto";
            # No EUI-64: never leak the MAC into the IPv6 address.
            addr-gen-mode = "stable-privacy";
            dns-search = "";
          };
        };
      };
    };
  };
}
