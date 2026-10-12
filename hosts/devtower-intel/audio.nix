{ config, ... }:

{
  # DEVTOWER-INTEL audio, every graphical stage (see mkDevtowerIntel in flake.nix).

  # GoXLR Mini (1220:8fe4): it stays silent until goxlr-daemon has initialised
  # it, so the daemon starts with the session from the desktop stage onward.
  # Deduplicated with the creative/full stages' own import.
  imports = [ ../../modules/hardware/go-xlr.nix ];

  # Package udev rules (uaccess). XDG autostart is off: Hyprland here never
  # reaches xdg-desktop-autostart.target, and enabling it would also start
  # blueman, gnome-keyring and a second nm-applet.
  services.goxlr-utility = {
    enable = true;
    autoStart.xdg = false;
  };

  systemd.user.services.goxlr-daemon = {
    description = "GoXLR Utility daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "pipewire.service" ];
    serviceConfig = {
      ExecStart = "${config.services.goxlr-utility.package}/bin/goxlr-daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # RTX 2080 Ti HDMI/DP audio: PipeWire opens one output per profile, so pick
  # the centre AOC AG271QG4 (DP-2, ELD pin 0x5, route hdmi-output-1) and make
  # it the default sink, above the GoXLR sinks (priority.session 1100).
  # Profile names follow the codec pin, so re-check with `pw-dump <card-id>`
  # (EnumRoute device.product.name) if the monitor cables are moved.
  #
  # A profile WirePlumber has stored (~/.local/state/wireplumber/default-profile)
  # wins over these rules, so after the first switch run once (card id from
  # `wpctl status`, profile 2 = output:hdmi-stereo-extra1):
  #   wpctl set-profile <card-id> 2
  # A sink chosen by hand (pavucontrol, wpctl set-default) also wins over the
  # priority below.
  services.pipewire.wireplumber.extraConfig."51-devtower-intel-hdmi-centre" = {
    "device.profile.priority.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_01_00.1"; } ];
        actions.update-props.priorities = [
          "output:hdmi-stereo-extra1" # AG271QG4, centre
          "output:hdmi-stereo" # 27G2WG3, right (fallback)
        ];
      }
    ];
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1"; } ];
        actions.update-props = {
          "priority.session" = 1500;
          "priority.driver" = 1500;
        };
      }
    ];
  };
}
