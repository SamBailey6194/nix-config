{ config, pkgs, lib, ... }:

{
  # Remote desktop configuration
  # Includes Remmina client for connecting to client computers
  # Optional x11vnc server for incoming connections

  # Remmina remote desktop client
  environment.systemPackages = with pkgs; [
    remmina              # Remote desktop client (VNC, RDP, SSH)

    # Remmina plugins
    # These are usually included with remmina package, but listed explicitly for clarity
    # remmina.override {
    #   withVNC = true;
    #   withRDP = true;
    #   withSSH = true;
    # }
  ];

  # Optional: x11vnc server (uncomment if you want to allow remote access TO this machine)
  # environment.systemPackages = with pkgs; [
  #   x11vnc
  # ];

  # Optional: Enable VNC server (x11vnc) as a systemd service
  # Uncomment the block below to allow remote access to this machine
  #
  # systemd.user.services.x11vnc = {
  #   description = "X11VNC Server";
  #   after = [ "graphical-session.target" ];
  #   wantedBy = [ "graphical-session.target" ];
  #
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display :0 -auth guess -forever -loop -noxdamage -repeat -rfbauth /home/%u/.vnc/passwd -rfbport 5900 -shared";
  #     Restart = "on-failure";
  #     RestartSec = "5s";
  #   };
  # };

  # Optional: Firewall rules for VNC server (port 5900)
  # Only allow VNC connections from Tailscale network for security
  # Uncomment if you enable x11vnc server above
  #
  networking.firewall = {
    # Only allow VNC from Tailscale interface
    interfaces.tailscale0.allowedTCPPorts = [ 5900 ];

    # DO NOT open VNC to the public internet
    # allowedTCPPorts = [ 5900 ];  # DANGEROUS - don't do this!
  };

  # ============================================================================
  # FUTURE: Wireguard + Defguard + RustDesk Remote Desktop Setup
  # ============================================================================
  # This will replace Tailscale + Remmina + x11vnc when ready
  # To enable:
  # 1. Uncomment the sections below
  # 2. Configure Defguard server (separate deployment)
  # 3. Add RustDesk relay server details to secrets
  # 4. Comment out Tailscale sections above
  # 5. Run: sudo nixos-rebuild switch
  #
  # Architecture:
  # - Wireguard: Secure VPN tunnel (already configured in wireguard-mullvad.nix)
  # - Defguard: 2FA authentication gateway before VPN access
  # - RustDesk: Open-source remote desktop server/client
  # ============================================================================

  # # RustDesk client and server
  # environment.systemPackages = with pkgs; [
  #   rustdesk           # Open-source remote desktop client
  # ];

  # # RustDesk server (for incoming connections)
  # systemd.services.rustdesk-server = {
  #   description = "RustDesk Server";
  #   after = [ "network.target" "wireguard-wg0.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.rustdesk}/bin/rustdesk-server";
  #     Restart = "on-failure";
  #     RestartSec = "10s";
  #
  #     # Security hardening
  #     DynamicUser = true;
  #     PrivateTmp = true;
  #     ProtectSystem = "strict";
  #     ProtectHome = true;
  #     NoNewPrivileges = true;
  #
  #     # Network access only via Wireguard
  #     RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
  #   };
  # };

  # # Defguard client for 2FA authentication
  # # Note: Defguard server must be deployed separately
  # # See: https://github.com/DefGuard/defguard
  # environment.systemPackages = with pkgs; [
  #   # defguard-client    # Uncomment when available in nixpkgs
  # ];

  # # Defguard systemd service
  # # Handles 2FA before Wireguard connection
  # # systemd.services.defguard = {
  # #   description = "Defguard 2FA Client";
  # #   after = [ "network.target" ];
  # #   before = [ "wireguard-wg0.service" ];
  # #   wantedBy = [ "multi-user.target" ];
  # #
  # #   serviceConfig = {
  # #     Type = "simple";
  # #     ExecStart = "${pkgs.defguard-client}/bin/defguard-client";
  # #     Restart = "on-failure";
  # #     RestartSec = "10s";
  # #
  # #     # Load 2FA secrets from agenix
  # #     EnvironmentFile = config.age.secrets.defguard-2fa.path;
  # #   };
  # # };

  # # Firewall rules for RustDesk
  # # ONLY allow connections via Wireguard interface
  # networking.firewall = {
  #   # RustDesk ports (TCP 21115-21119, UDP 21116)
  #   interfaces.wg0 = {
  #     allowedTCPPorts = [ 21115 21116 21117 21118 21119 ];
  #     allowedUDPPorts = [ 21116 ];
  #   };
  #
  #   # Block RustDesk from public internet
  #   # allowedTCPPorts = [];  # Do NOT open these ports globally
  #   # allowedUDPPorts = [];
  # };

  # # Secrets for Defguard 2FA and RustDesk relay
  # # Add to secrets/secrets.nix:
  # #
  # # defguard-2fa-laptop-intel.age = {
  # #   publicKeys = [ laptop-intel-key user-key ];
  # # };
  # #
  # # rustdesk-relay-config-laptop-intel.age = {
  # #   publicKeys = [ laptop-intel-key user-key ];
  # # };
  # #
  # # Then create the secrets:
  # # agenix-helper edit defguard-2fa-laptop-intel
  # # agenix-helper edit rustdesk-relay-config-laptop-intel

  # # Age secret declarations (uncomment when secrets exist)
  # # age.secrets.defguard-2fa = {
  # #   file = ../secrets/defguard-2fa-${config.networking.hostName}.age;
  # #   mode = "0400";
  # #   owner = "root";
  # # };
  # #
  # # age.secrets.rustdesk-relay = {
  # #   file = ../secrets/rustdesk-relay-config-${config.networking.hostName}.age;
  # #   mode = "0400";
  # #   owner = "rustdesk";
  # # };
}
