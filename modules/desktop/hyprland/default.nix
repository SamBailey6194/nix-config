{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../software/transcription.nix
    ../../software/browsers.nix
    ../../security/download-antivirus.nix
  ];

  # Hyprland Wayland Compositor Configuration

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    xwayland.enable = true;
  };

  # Display Manager (graphical login screen)
  # Using greetd with tuigreet - lightweight and Wayland-native
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  # Secret Service for the session, so agy, Codex, gh and Brave keep sign-ins
  # in the keyring rather than plaintext fallback files. The module enables
  # pam_gnome_keyring for `login`, which greetd's PAM stack includes, so the
  # keyring unlocks with the login password. Its gcr SSH agent stays off:
  # modules/core/ssh-config.nix already runs the OpenSSH agent.
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;

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
    # GSettings schemas (fixes "does not exist" warnings for cursor-theme/cursor-size)
    gsettings-desktop-schemas
    glib

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

  # PAM stack for hyprlock.
  #
  # hyprlock authenticates against the PAM service named "hyprlock". Without an
  # /etc/pam.d/hyprlock, PAM falls through to /etc/pam.d/other, which on NixOS
  # is pam_deny for auth - so the lock screen would come up and then reject the
  # correct password, with no way back into the session except a TTY. An empty
  # attrset gets the NixOS default stack (pam_unix), matching what the swaylock
  # module generates.
  #
  # Deliberately not programs.hyprlock.enable: that also flips on
  # services.hypridle, whose system-level user unit would shadow (and be
  # shadowed by) the one home-manager already writes to ~/.config/systemd/user.
  # The package is in environment.systemPackages above; PAM is the only piece
  # that has to come from the system side.
  security.pam.services.hyprlock = { };

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
