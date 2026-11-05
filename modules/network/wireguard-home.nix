{
  config,
  lib,
  pkgs,
  ...
}:

# Home WireGuard server (one peer: the phone)
#
# A small WireGuard endpoint on this machine so the phone can reach it from
# anywhere (home Wi-Fi or mobile data) without exposing anything else. Built
# for the weekly photo upload (docs/PHONE-PHOTO-SYNC.md): the phone is the only
# peer, and the only thing it may open through the tunnel is Syncthing
# (TCP 22000 on this end's tunnel address).
#
# Keys are runtime, root-only files on encrypted storage (never Nix strings,
# never the repo), the same model as connectivity.nix's arwyn keys:
#   privateKeyFile          this machine's private key   (wg genkey)
#   phonePresharedKeyFile   PSK shared with the phone     (wg genpsk)
# The phone's PUBLIC key is not secret and is set as phonePublicKey.
#
# Until phonePublicKey and privateKeyFile are set, the interface is left out
# and the rebuild prints a warning instead. If the key files are set but not
# yet on disk, the units are skipped (ConditionPathExists) rather than failed.
#
# Reaching it from outside needs a router UDP port forward of listenPort to
# this machine (and dynamic DNS if the public IP changes). Nothing here
# assumes that exists; without it the tunnel only works on the home LAN.
#
# Firewall: iptables backend only (this host; networking.nftables is off).
#   - listenPort/UDP is opened on every interface (WireGuard answers nothing
#     without a valid key, so the port is silent to scanners)
#   - the tunnel interface is NOT trusted: in mangle PREROUTING (ahead of
#     filter INPUT/FORWARD, Docker's DNAT and Tailscale's chains) everything
#     arriving on it is dropped except replies and new TCP connections from
#     the phone to this end's address on phoneAllowedTCPPorts
#   - with Mullvad, a separate nft table marks this traffic as excluded
#     (split-tunnel marks) so Mullvad's own firewall lets it through

with lib;

let
  cfg = config.networking.wireguard-home;
  iface = cfg.interface;

  peerName = "phone";

  # "10.200.0.1/24" -> "10.200.0.1"; "10.200.0.2/32" -> "10.200.0.2"
  hostOf = cidr: head (splitString "/" cidr);
  serverIP = hostOf cfg.address;
  phoneIP = hostOf cfg.phoneAddress;

  # "10.200.0.1/24" -> "10.200.0.0/24" (only /24 and /32 are needed here)
  subnet =
    let
      parts = splitString "/" cfg.address;
      octets = splitString "." (head parts);
      len = last parts;
    in
    if len == "24" then "${concatStringsSep "." (take 3 octets)}.0/24" else "${head parts}/${len}";

  missing =
    optional (cfg.phonePublicKey == null) "phonePublicKey (the phone's WireGuard public key)"
    ++ optional (cfg.privateKeyFile == null) "privateKeyFile (this machine's private key file)";
  configured = missing == [ ];

  keyFiles = [ cfg.privateKeyFile ] ++ optional (cfg.phonePresharedKeyFile != null) cfg.phonePresharedKeyFile;

  # Mullvad (talpid-core firewall/linux.rs): connections with ct mark 0xf41
  # are accepted by its input/output/forward chains (priority 0), and packets
  # carrying meta mark 0x6d6f6c65 skip its "not fwmark ... lookup 1836018789"
  # policy route. Marking at priority -100 runs before Mullvad's filter
  # chains. Incoming connections need the input hook too: the phone dials in.
  stMark = "0x00000f41";
  fwMark = "0x6d6f6c65";
  bypassTable = "wg_home_mullvad_bypass";
  bypassRules = pkgs.writeText "wg-home-mullvad-bypass.nft" ''
    table inet ${bypassTable}
    delete table inet ${bypassTable}
    table inet ${bypassTable} {
      chain input {
        type filter hook input priority -100; policy accept;
        # Encrypted WireGuard from the phone, on the physical interface.
        udp dport ${toString cfg.listenPort} ct mark set ${stMark} meta mark set ${fwMark}
        # Decrypted traffic from the phone (the iptables mangle rules have
        # already dropped anything other than Syncthing and replies).
        iifname "${iface}" ip saddr ${subnet} ct mark set ${stMark} meta mark set ${fwMark}
      }
      chain output {
        type route hook output priority -100; policy accept;
        # WireGuard's own packets to the phone (handshake replies, data). They
        # already carry fwMark from the interface's socket mark, which ordinary
        # unprivileged sockets cannot set, so another program that happened to
        # use this port could not slip out past Mullvad.
        udp sport ${toString cfg.listenPort} meta mark ${fwMark} ct mark set ${stMark}
        # Traffic to the phone inside the tunnel.
        oifname "${iface}" ip daddr ${subnet} ct mark set ${stMark} meta mark set ${fwMark}
      }
    }
  '';

  ipt = "iptables -w";
  ip6t = "ip6tables -w";
  chain = "wg-home-pre";
  allowRules = concatMapStrings (port: ''
    ${ipt} -t mangle -A ${chain} -s ${phoneIP}/32 -d ${serverIP}/32 -p tcp --dport ${toString port} -m conntrack --ctstate NEW -j RETURN
  '') cfg.phoneAllowedTCPPorts;
  removeRules = ''
    ${ipt} -t mangle -D PREROUTING -i ${iface} -j ${chain} 2>/dev/null || true
    ${ipt} -t mangle -F ${chain} 2>/dev/null || true
    ${ipt} -t mangle -X ${chain} 2>/dev/null || true
    ${optionalString config.networking.enableIPv6 ''
      ${ip6t} -t mangle -D PREROUTING -i ${iface} -j DROP 2>/dev/null || true
    ''}
  '';
in
{
  options.networking.wireguard-home = {
    enable = mkEnableOption "the home WireGuard server with the phone as its only peer";

    interface = mkOption {
      type = types.str;
      default = "wg-home";
      description = "WireGuard interface name";
    };

    listenPort = mkOption {
      type = types.port;
      default = 51821;
      description = "UDP port WireGuard listens on (51820 is left to the arwyn client tunnel). The router forwards this port here.";
    };

    address = mkOption {
      type = types.str;
      default = "10.200.0.1/24";
      description = "This machine's tunnel address (CIDR). Only /24 or /32 prefixes are supported.";
    };

    privateKeyFile = mkOption {
      type = types.nullOr types.str;
      default = "/var/lib/desktop-secrets/home-wg-private.key";
      description = "Root-only runtime file holding this machine's WireGuard private key (wg genkey). Never a Nix path.";
    };

    phonePublicKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
      description = "The phone's WireGuard public key (shown in the WireGuard Android app). The interface is left out while this is null.";
    };

    phonePresharedKeyFile = mkOption {
      type = types.nullOr types.str;
      default = "/var/lib/desktop-secrets/home-wg-phone-psk.key";
      description = "Root-only runtime file with the PSK shared with the phone (wg genpsk); null for no PSK.";
    };

    phoneAddress = mkOption {
      type = types.str;
      default = "10.200.0.2/32";
      description = "The phone's tunnel address; WireGuard only accepts packets from it with this source.";
    };

    phoneAllowedTCPPorts = mkOption {
      type = types.listOf types.port;
      default = [ 22000 ];
      description = "TCP ports the phone may open on this machine's tunnel address (default: Syncthing). Everything else from the tunnel is dropped.";
    };

    mullvadBypass = mkOption {
      type = types.bool;
      default = config.services.mullvad-vpn.enable;
      defaultText = literalExpression "config.services.mullvad-vpn.enable";
      description = "Mark the tunnel's traffic as excluded from Mullvad so its firewall and routing leave it alone.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      warnings =
        optional (!configured) ''
          networking.wireguard-home: ${iface} is NOT configured; missing:
          ${concatMapStrings (m: "  - ${m}\n") missing}See docs/PHONE-PHOTO-SYNC.md, then rebuild.
        ''
        ++ optional (configured && config.networking.nftables.enable) ''
          networking.wireguard-home: nftables is enabled, so the iptables rules that
          restrict ${iface} to Syncthing are not applied. Do not use the tunnel until
          equivalent nftables rules exist.
        '';
    }

    (mkIf configured {
      environment.systemPackages = [ pkgs.wireguard-tools ];

      networking.wireguard.interfaces.${iface} = {
        ips = [ cfg.address ];
        inherit (cfg) listenPort privateKeyFile;
        # WireGuard's outer packets carry Mullvad's exclusion mark, so they are
        # routed by the main table (out of the LAN interface) instead of into
        # mullvad's tunnel - the same trick Mullvad uses for its own tunnel.
        fwMark = mkIf cfg.mullvadBypass fwMark;
        peers = [
          {
            name = peerName;
            publicKey = cfg.phonePublicKey;
            presharedKeyFile = cfg.phonePresharedKeyFile;
            allowedIPs = [ cfg.phoneAddress ];
            # No endpoint: the phone roams and always dials in; WireGuard
            # learns its current address from each authenticated packet.
          }
        ];
      };

      # Skip, not fail, while the runtime key files are missing. The peer unit
      # needs the same condition: a skipped Requires= does not stop it.
      systemd.services."wireguard-${iface}".unitConfig.ConditionPathExists = keyFiles;
      systemd.services."wireguard-${iface}-peer-${peerName}".unitConfig.ConditionPathExists = keyFiles;

      networking.firewall.allowedUDPPorts = [ cfg.listenPort ];

      # listenPort is inside the kernel's ephemeral range (32768-60999). Reserve
      # it so no outgoing socket (wg-arwyn, DNS, QUIC, ...) is ever given it by
      # chance: that would stop wg-home binding it, and with Mullvad its traffic
      # would match the bypass rules below.
      boot.kernel.sysctl."net.ipv4.ip_local_reserved_ports" = toString cfg.listenPort;
      # nixos-fw's per-interface allow-list; the mangle chain below narrows it
      # to the phone's source and this end's address.
      networking.firewall.interfaces.${iface}.allowedTCPPorts = cfg.phoneAllowedTCPPorts;

      networking.firewall.extraCommands = mkIf (!config.networking.nftables.enable) ''
        ${removeRules}
        ${ipt} -t mangle -N ${chain}
        ${ipt} -t mangle -A ${chain} -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        ${allowRules}
        ${ipt} -t mangle -A ${chain} -j DROP
        ${ipt} -t mangle -I PREROUTING -i ${iface} -j ${chain}
        ${optionalString config.networking.enableIPv6 ''
          ${ip6t} -t mangle -I PREROUTING -i ${iface} -j DROP
        ''}
      '';
      networking.firewall.extraStopCommands = mkIf (!config.networking.nftables.enable) removeRules;

      # wireguard-<iface> owns this interface; keep NetworkManager off it.
      networking.networkmanager.unmanaged = [ "interface-name:${iface}" ];

      # The exclusion only exists while wg-home is up and holds listenPort:
      # started with it, stopped (table deleted) with it, skipped with it.
      # Load order relative to mullvad-daemon does not matter: the tables are
      # independent and nft hook priorities decide which runs first.
      systemd.services.wg-home-mullvad-bypass = mkIf cfg.mullvadBypass {
        description = "Exclude the home WireGuard tunnel from Mullvad";
        wantedBy = [ "wireguard-${iface}.service" ];
        bindsTo = [ "wireguard-${iface}.service" ];
        partOf = [ "wireguard-${iface}.service" ];
        after = [ "wireguard-${iface}.service" ];
        unitConfig.ConditionPathExists = keyFiles;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.nftables}/bin/nft -f ${bypassRules}";
          ExecStop = "${pkgs.nftables}/bin/nft delete table inet ${bypassTable}";
        };
      };
    })
  ]);
}
