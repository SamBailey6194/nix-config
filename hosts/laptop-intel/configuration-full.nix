{ config, pkgs, inputs, ... }:

{
  # FULL CONFIGURATION (laptop-intel)
  # Comprehensive configuration after all staged installations complete
  # This is the primary configuration used by .#laptop-intel

  imports = [
    # Hardware
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/base-configuration.nix
    ../../modules/core/common.nix
    ../../modules/core/nix-settings.nix

    # Secrets management (commented until SSH keys are set up)
    # ../../modules/core/secrets-laptop.nix

    # SSH configuration (commented until secrets are ready)
    # ../../modules/core/ssh-config.nix

    # Hardware-specific
    ../../modules/hardware/intel-laptop.nix
    ../../modules/hardware/openrgb.nix  # RGB control for keyboard/mouse

    # Desktop environment
    ../../modules/desktop/hyprland

    # Software suites
    ../../modules/software/browsers.nix
    ../../modules/software/development.nix
    ../../modules/software/office.nix
    ../../modules/software/communication.nix
    ../../modules/software/media.nix

    # Network and security (Phase 6+)
    # TODO: Enable after VPN secrets are created
    # ../../modules/network/wireguard-mullvad.nix
    ../../modules/network/tailscale.nix
    ../../modules/network/remote-desktop.nix
    # TODO: Enable after malware scanner is configured
    # ../../modules/security/malware-scanner.nix

    # User
    ../../modules/users/laptop.nix
  ];

  # Enable SSH to generate host keys for agenix
  services.openssh.enable = true;

  # Device identity
  networking.hostName = "laptop-intel";

  # Mullvad WireGuard VPN Configuration (Phase 6)
  # TODO: Uncomment after creating VPN secrets (see Option 2 below)
  # networking.wireguard-mullvad = {
  #   enable = true;
  #   device = "laptop-intel";
  #
  #   # Production servers that bypass VPN (for audit trail)
  #   bypassIPs = [
  #     # Add production server IPs here
  #     # "203.0.113.5"
  #   ];
  #
  #   # Kill switch enabled
  #   enableKillSwitch = true;
  #
  #   # Per-app VPN routing via cgroups
  #   cgroupApps = [
  #     "firefox"       # Browser through VPN
  #     "librewolf"     # Browser through VPN
  #     "google-chrome" # Browser through VPN (or use "chromium")
  #     "transmission"  # Torrents through VPN
  #   ];
  #
  #   # Current exit location (uk/us/eu)
  #   currentExit = "uk";
  #
  #   # Minimum hop count for multi-hop
  #   minHops = 5;
  #
  #   # Enable automatic weekly rotation
  #   autoRotate = {
  #     enable = true;
  #     schedule = "Sun *-*-* 03:00:00";  # Sunday 3 AM
  #   };
  #
  #   # Enable metrics logging
  #   metricsLogging = {
  #     enable = true;
  #     interval = "5min";
  #     logFile = "/var/log/vpn-logs.txt";
  #   };
  # };

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # System packages + creative tools (Intel GPU - limited)
  environment.systemPackages = with pkgs; [
    # Core utilities
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch

    # Creative tools (Intel GPU compatible)
    # blender              # 3D creation
    gimp                 # Image editing
    inkscape             # Vector graphics
    krita                # Digital painting
  ] ++ [
    # Affinity Apps (via Wine - from affinity-nix flake)
    inputs.affinity-nix.packages.${pkgs.system}.designer
    inputs.affinity-nix.packages.${pkgs.system}.photo
    inputs.affinity-nix.packages.${pkgs.system}.publisher
  ];

  # Enable zsh
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
