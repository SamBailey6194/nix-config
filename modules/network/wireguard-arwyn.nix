{
  config,
  lib,
  pkgs,
  ...
}:

# arwyn-1 Admin VPN (split tunnel)
#
# WireGuard link from this device to the arwyn-1 server managed in the
# i-had-dad-deployment repo. arwyn-1's sshd binds only to 10.100.0.1:22, so this
# tunnel is the only way to reach it (including `just deploy`).
#
# Server side (peer block, PSK copy, SSH keys) lives in i-had-dad-deployment —
# see how-to/src/12-LAPTOP-INTEL-WIREGUARD.md there. Only this device's half is
# declared here.
#
# Secrets (both per-device, root-only, decrypted by agenix at activation):
#   secrets/wireguard-arwyn-<device>-private.age  - this device's private key
#   secrets/wireguard-arwyn-<device>-psk.age      - PSK shared with the server
#
# Until BOTH files exist and are git-tracked, the tunnel is left out and the
# rebuild prints a warning instead of failing evaluation, so enabling this for a
# device before its secrets are created does not break its rebuilds.

with lib;

let
  cfg = config.networking.wireguard-arwyn;

  interface = "wg-arwyn";

  privateKeyFile = ../../secrets + "/wireguard-arwyn-${cfg.device}-private.age";
  pskFile = ../../secrets + "/wireguard-arwyn-${cfg.device}-psk.age";

  # Flakes only see git-tracked files, so an encrypted-but-unstaged secret
  # counts as missing here too.
  missingSecrets =
    optional (!builtins.pathExists privateKeyFile) {
      name = "wireguard-arwyn-${cfg.device}-private.age";
      source = "private.key";
    }
    ++ optional (!builtins.pathExists pskFile) {
      name = "wireguard-arwyn-${cfg.device}-psk.age";
      source = "psk.key";
    };

  secretsPresent = missingSecrets == [ ];

  # "65.109.70.23:51820" -> "65.109.70.23"; null for hostname/IPv6 endpoints
  endpointHost =
    let
      m = builtins.match "([0-9.]+):[0-9]+" cfg.endpoint;
    in
    if m == null then null else head m;

  ip = "${pkgs.iproute2}/bin/ip";
  endpointRule = "to ${endpointHost} lookup main priority 50";

  # iptables backend only (this host); nftables would need its own rule
  dropInbound = "INPUT -i ${interface} -m conntrack --ctstate NEW -j DROP";
in
{
  options.networking.wireguard-arwyn = {
    enable = mkEnableOption "split-tunnel WireGuard link to the arwyn-1 admin VPN";

    device = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = literalExpression "config.networking.hostName";
      description = "Device name used in the secret file names";
    };

    address = mkOption {
      type = types.str;
      example = "10.100.0.7/24";
      description = "This device's VPN address (must match its /32 in the server's peer list)";
    };

    serverPublicKey = mkOption {
      type = types.str;
      default = "Gkrr+dIpIsUfqFcKKYodW8mi1yaAVv+QuhJ8ea7oBRk=";
      description = "arwyn-1's WireGuard public key (`sudo wg show wg0 public-key` on the server)";
    };

    endpoint = mkOption {
      type = types.str;
      default = "65.109.70.23:51820";
      description = "arwyn-1's public WireGuard endpoint";
    };

    serverAddress = mkOption {
      type = types.str;
      default = "10.100.0.1";
      description = "arwyn-1's address inside the VPN (where sshd listens)";
    };

    allowedIPs = mkOption {
      type = types.listOf types.str;
      default = [ "10.100.0.0/24" ];
      description = "Routed through the tunnel. The default is a split tunnel: VPN subnet only";
    };

    autostart = mkOption {
      type = types.bool;
      default = true;
      description = "Bring the tunnel up at boot (otherwise: systemctl start wg-quick-${interface})";
    };

    serverHostKey = mkOption {
      type = types.str;
      # = the arwyn1 recipient in i-had-dad-deployment's secrets.nix (agenix
      # uses the host key), cross-checked against SamLinPC's known_hosts.
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIPf5UQ4ttqXkE+csVml0GOh3vyY27jW05eiQKDClndb";
      description = "arwyn-1's SSH host key, pinned so the first login is not trust-on-first-use";
    };

    sshIdentityFile = mkOption {
      type = types.str;
      default = "~/.ssh/syntek";
      description = "Key authorised for admin@ and sam@ on arwyn-1, used by the `arwyn-1` SSH alias";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      warnings =
        optional (secretsPresent && config.networking.nftables.enable) ''
          networking.wireguard-arwyn: nftables is enabled, so the iptables rule that
          drops new inbound connections on ${interface} is not applied.
        ''
        ++ optional (!secretsPresent) ''
        networking.wireguard-arwyn: ${interface} is NOT configured — missing or untracked secret(s).
        From the dev shell (agenix reads stdin when it is not a terminal):
          cd secrets
        ${concatMapStrings (s: "  agenix -e ${s.name} < ${s.source}\n") missingSecrets}  git add ${concatMapStringsSep " " (s: s.name) missingSecrets}
        then rebuild.
      '';
    }

    (mkIf secretsPresent {
      age.secrets = {
        wireguard-arwyn-private = {
          file = privateKeyFile;
          mode = "0400";
        };

        wireguard-arwyn-psk = {
          file = pskFile;
          mode = "0400";
        };
      };

      # No DNS entry on purpose: wg-quick would hand it to resolvconf and
      # repoint system DNS at arwyn-1's Unbound, which is unreachable whenever
      # the tunnel is down. Reach the server by IP or the SSH alias below.
      networking.wg-quick.interfaces.${interface} = {
        address = [ cfg.address ];
        privateKeyFile = config.age.secrets.wireguard-arwyn-private.path;
        inherit (cfg) autostart;

        peers = [
          {
            publicKey = cfg.serverPublicKey;
            presharedKeyFile = config.age.secrets.wireguard-arwyn-psk.path;
            inherit (cfg) allowedIPs endpoint;
            # Required behind NAT — keeps the mapping open for the server.
            persistentKeepalive = 25;
          }
        ];

        # Send the handshake to the endpoint via the main table, so a
        # full-tunnel interface (mullvad0's 0.0.0.0/0 policy routing) never
        # carries it — WireGuard-in-WireGuard, outer packets over the MTU.
        # This lives here because mullvad0 uses configFile, which makes wg-quick
        # ignore that module's postUp (so its bypassIPs rules never run).
        postUp = optionalString (endpointHost != null) ''
          ${ip} rule del ${endpointRule} 2>/dev/null || true
          ${ip} rule add ${endpointRule}
        '';
        postDown = optionalString (endpointHost != null) ''
          ${ip} rule del ${endpointRule} 2>/dev/null || true
        '';
      };

      # Unit text only names /run/agenix paths, so re-encrypting a secret would
      # not otherwise restart the tunnel. Hash the contents: the paths
      # themselves sit in the whole-flake source, which changes on every commit.
      systemd.services."wg-quick-${interface}".restartTriggers = map (builtins.hashFile "sha256") [
        privateKeyFile
        pskFile
      ];

      # Outbound only: arwyn-1 must not be able to open connections into this
      # machine (e.g. its sshd) through the tunnel. Inserted at the top of
      # INPUT so it also beats the Mullvad kill switch's 10.0.0.0/8 ACCEPT,
      # which is appended ahead of nixos-fw. Replies stay ESTABLISHED.
      networking.firewall = mkIf (!config.networking.nftables.enable) {
        extraCommands = ''
          iptables -D ${dropInbound} 2>/dev/null || true
          iptables -I ${dropInbound}
        '';
        extraStopCommands = ''
          iptables -D ${dropInbound} 2>/dev/null || true
        '';
      };

      # Same reason as mullvad0: NetworkManager must not manage (and rewrite
      # routes on) an interface wg-quick owns.
      networking.networkmanager.unmanaged = [ "interface-name:${interface}" ];

      # `just deploy` in i-had-dad-deployment targets admin@arwyn-1. Goes in
      # the NixOS-generated ssh_config itself: it does not Include
      # /etc/ssh/ssh_config.d/*. mkAfter keeps this Host block after any
      # top-level Include lines other modules put in extraConfig.
      # arwyn-1 has no xterm-kitty terminfo, so kitty's TERM breaks clear, less
      # and friends there; SetEnv TERM needs no AcceptEnv on the server.
      programs.ssh.extraConfig = mkAfter ''
        # arwyn-1 over the ${interface} admin VPN
        Host arwyn-1
          HostName ${cfg.serverAddress}
          User admin
          IdentityFile ${cfg.sshIdentityFile}
          IdentitiesOnly yes
          SetEnv TERM=xterm-256color
      '';

      programs.ssh.knownHosts.arwyn-1 = {
        hostNames = [
          "arwyn-1"
          cfg.serverAddress
        ];
        publicKey = cfg.serverHostKey;
      };
    })
  ]);
}
