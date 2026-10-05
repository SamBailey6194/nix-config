# Preserve this physical desktop's Ubuntu admin VPN and accountability setup.
{ config, lib, pkgs, ... }:
let
  secrets = "/var/lib/desktop-secrets";
  graphical = config.programs.hyprland.enable;
  exclusions = pkgs.writeText "arwyn-mullvad-exclusions.nft" ''
    table inet arwyn_mullvad_bypass
    delete table inet arwyn_mullvad_bypass
    table inet arwyn_mullvad_bypass {
      chain output {
        type route hook output priority -100; policy accept;
        # Only the encrypted admin tunnel and SSH inside it bypass Mullvad.
        ip daddr 65.109.70.23 udp dport 51820 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
        ip daddr 10.100.0.1 tcp dport 22 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
      }
    }
  '';
in {
  imports = [ ../../modules/network/wireguard-arwyn.nix ../../modules/security/squid-digest ];

  networking.wireguard-arwyn = {
    enable = true;
    address = "10.100.0.2/32"; # Existing sam-ubuntu-pc server peer: reuse its keys.
    allowedIPs = [ "10.100.0.1/32" ];
    sshIdentityFile = "~/.ssh/id_ed25519_admin"; # Ubuntu's authorised SSH identity.
    privateKeyFile = "${secrets}/arwyn-private.key";
    presharedKeyFile = "${secrets}/arwyn-psk.key";
  };
  environment.systemPackages = [ pkgs.wireguard-tools ];
  systemd.tmpfiles.rules = [ "d ${secrets} 0750 root sam-desktop -" ];

  # Fresh Mullvad state is disconnected. Log in/connect only after renewal.
  # Use the supported app firewall instead of the older custom kill switch.
  services.mullvad-vpn = lib.mkIf graphical {
    enable = true;
    gui.enable = true;
    enableExcludeWrapper = false;
  };
  systemd.services.arwyn-mullvad-bypass = lib.mkIf graphical {
    description = "Allow the admin WireGuard tunnel alongside Mullvad";
    wantedBy = [ "multi-user.target" ];
    before = [ "mullvad-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.nftables}/bin/nft -f ${exclusions}";
      ExecStop = "${pkgs.nftables}/bin/nft delete table inet arwyn_mullvad_bypass";
    };
  };

  services.squidDigest = lib.mkIf graphical {
    enable = true;
    user = "sam-desktop";
    fromName = "Desktop Accountability";
    secretEnvironmentFile = "${secrets}/squid-digest.env";
  };
}
