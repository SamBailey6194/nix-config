{ config, pkgs, lib, ... }:

{
  # Tailscale VPN for secure mesh networking
  # Allows remote access to client computers from anywhere
  # Used with Remmina for VNC/RDP connections

  services.tailscale = {
    enable = true;

    # Use Mullvad exit nodes when available (optional)
    # useRoutingFeatures = "both";  # Enable subnet routing and exit nodes
  };

  # Open firewall for Tailscale
  networking.firewall = {
    # Allow Tailscale traffic
    trustedInterfaces = [ "tailscale0" ];

    # Allow incoming connections from Tailscale network
    # This allows VNC/RDP connections from other Tailscale devices
    allowedUDPPorts = [
      config.services.tailscale.port  # Tailscale default: 41641
    ];

    # Allow Tailscale to configure firewall rules
    checkReversePath = "loose";
  };

  # Ensure Tailscale starts after network is ready
  systemd.services.tailscaled = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # Environment packages for Tailscale CLI
  environment.systemPackages = with pkgs; [
    tailscale  # CLI tool for managing Tailscale
  ];
}
