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
  # networking.firewall = {
  #   # Only allow VNC from Tailscale interface
  #   interfaces.tailscale0.allowedTCPPorts = [ 5900 ];
  #
  #   # DO NOT open VNC to the public internet
  #   # allowedTCPPorts = [ 5900 ];  # DANGEROUS - don't do this!
  # };
}
