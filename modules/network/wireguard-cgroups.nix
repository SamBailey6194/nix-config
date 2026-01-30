{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking.wireguard-cgroups;
in
{
  options.networking.wireguard-cgroups = {
    enable = mkEnableOption "per-app VPN routing via cgroups";

    apps = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Applications to route through VPN (e.g., firefox, transmission)";
      example = [ "firefox" "transmission" ];
    };
  };

  config = mkIf cfg.enable {
    # Cgroup accounting is enabled by default in NixOS 24.11+
    # No explicit enablement needed

    # Create cgroup slice for VPN apps
    systemd.slices.vpn-apps = {
      description = "Slice for applications routed through VPN";
      sliceConfig = {
        # Net classid for routing (0x1 = VPN routing table)
        NetClass = "0x1";
      };
    };

    # Create wrapper script for launching apps through VPN
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "vpn-app" ''
        #!/usr/bin/env bash
        set -euo pipefail

        if [ $# -eq 0 ]; then
          echo "Usage: vpn-app <command> [args...]"
          echo "Launch application through VPN using cgroup routing"
          echo ""
          echo "Examples:"
          echo "  vpn-app firefox"
          echo "  vpn-app transmission-gtk"
          echo "  vpn-app docker pull ubuntu:latest"
          exit 1
        fi

        # Launch app in VPN cgroup slice
        systemd-run \
          --user \
          --scope \
          --slice=vpn-apps \
          --description="VPN-routed: $*" \
          "$@"
      '')

      # Create desktop entries for configured apps
    ] ++ (map (app:
      pkgs.writeShellScriptBin "vpn-${app}" ''
        #!/usr/bin/env bash
        exec vpn-app ${app} "$@"
      ''
    ) cfg.apps);

    # Routing rule for cgroup classid (fwmark 0x1 → table 1000)
    # This is handled by wireguard-mullvad.nix postUp script
    # No additional configuration needed here

    # Note: Systemd user services for specific apps should be created manually
    # per-device as needed, using the vpn-app wrapper script.
    # Auto-generating services is problematic because:
    # - Package names don't always match binary names
    # - Not all apps need persistent services
    # Example manual service in home-manager:
    #   systemd.user.services.vpn-firefox = {
    #     description = "VPN-routed Firefox";
    #     serviceConfig = {
    #       ExecStart = "${pkgs.vpn-app}/bin/vpn-app firefox";
    #       Slice = "vpn-apps.slice";
    #     };
    #   };
  };
}
