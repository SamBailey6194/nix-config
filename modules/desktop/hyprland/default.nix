{ config, pkgs, inputs, ... }:

{
  # Hyprland Wayland Compositor Configuration

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    xwayland.enable = true;
  };

  # XDG Portal configuration
  # NOTE: programs.hyprland.enable already sets up xdg-desktop-portal-hyprland
  # We just need to add GTK portal and configure the portal selection
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  # Required packages for Hyprland ecosystem
  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wayland
    wayland-protocols
    wayland-utils
    wl-clipboard

    # Hyprland ecosystem
    hyprpaper           # Wallpaper daemon
    hypridle            # Idle daemon
    hyprlock            # Screen locker
    hyprpicker          # Color picker

    # Screenshot tools
    grim                # Screenshot tool
    slurp               # Region selector
    swappy              # Screenshot editor

    # Status bar
    waybar

    # Application launcher
    wofi

    # Notification daemon
    dunst

    # Terminal emulator
    kitty

    # File manager
    thunar

    # Image viewer
    imv

    # PDF viewer
    zathura

    # Web browser
    firefox

    # Network management
    networkmanagerapplet

    # Audio control
    pavucontrol

    # Bluetooth
    blueman
  ];

  # Enable required services
  services.dbus.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # Polkit (for privilege escalation)
  security.polkit.enable = true;

  # Enable sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];

  # Session variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Hint electron apps to use Wayland
    WLR_NO_HARDWARE_CURSORS = "1"; # Fix cursor rendering on some hardware
  };
}
