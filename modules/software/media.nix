{ config, pkgs, ... }:

{
  # Media playback and viewing
  # Video players, image viewers, music players

  environment.systemPackages = with pkgs; [
    # Video players
    vlc                # VLC media player
    mpv                # Lightweight video player

    # Image viewers
    imv                # Wayland image viewer
    # feh              # X11 image viewer
    # gwenview         # KDE image viewer

    # Image editors (lightweight)
    gimp               # GNU Image Manipulation Program
    # inkscape         # Vector graphics editor

    # PDF viewers
    zathura            # Lightweight PDF viewer
    # evince           # GNOME PDF viewer

    # Music players
    spotify            # Spotify music streaming
    # rhythmbox        # GNOME music player
    # clementine       # Qt music player

    # Audio tools
    audacity           # Audio editing
    # ardour           # Digital audio workstation

    # Screenshot tools (already in base, but noted here)
    # grim, slurp, swappy are in desktop/hyprland
  ];
}
