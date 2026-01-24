{ config, pkgs, inputs, ... }:

{
  # Base configuration shared across ALL devices
  # Device-specific settings go in hosts/{device}/configuration.nix

  # Boot Loader (can be overridden per-device)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London"; # UK GMT
  i18n.defaultLocale = "en_GB.UTF-8";

  # Base system packages (common to all devices)
  environment.systemPackages = with pkgs; [
    # Core utilities
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch

    # Browsers
    librewolf      # Personal - hardened security
    firefox        # Dev testing
    google-chrome  # Claude Chrome extension

    # Audio tools
    qpwgraph       # PipeWire graph manager
    pavucontrol    # Volume control
  ];

  # Enable Hyprland (all devices use Hyprland)
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  # Sound - PipeWire (all devices)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Base audio config (can be overridden per-device)
    extraConfig.pipewire = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 512;
      };
    };
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Firewall
  networking.firewall.enable = true;

  # Affinity Apps (all devices get these)
  programs.affinity = {
    enable = true;
    designer = true;
    photo = true;
    publisher = true;
  };

  # System State Version
  system.stateVersion = "24.11";
}
