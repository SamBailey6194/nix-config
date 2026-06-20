{ config, pkgs, lib, inputs, ... }:

{
  # Base configuration shared across ALL devices
  # Device-specific settings go in hosts/{device}/configuration.nix

  # Nixpkgs overlays for additional packages
  nixpkgs.overlays = [
    # Claude Code - always up-to-date native binary
    (final: prev: {
      claude-code = inputs.claude-code-nix.packages.${prev.stdenv.hostPlatform.system}.default;
    })

    # Rust CLI tools from this repository
    (final: prev: import ../../rust/nix { pkgs = final; })
  ];

  imports = [
    ./fonts.nix                    # System fonts
    ../software/browsers.nix       # LibreWolf (managed set via browser-policies)
    ../software/communication.nix  # Discord, Teams, Zoom, Slack, Obsidian
    ../software/media.nix          # VLC, Spotify, image viewers
    ../software/development.nix    # VS Code, Docker, language tools
    ../software/office.nix         # LibreOffice
    ../software/networking.nix     # DNS/TCP/HTTP/packet/load-testing CLI tools
  ];

  # Boot Loader (can be overridden per-device)
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London"; # UK GMT
  i18n.defaultLocale = "en_GB.UTF-8";

  # XDG portal support for home-manager
  # Required when using home-manager via NixOS module with useUserPackages
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  # Base system packages (common to all devices)
  # Note: Most software is now in modules/software/*.nix
  environment.systemPackages = with pkgs; [
    # Core utilities only
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch

    # Audio tools (Wayland/PipeWire specific)
    qpwgraph       # PipeWire graph manager
    pavucontrol    # Volume control
  ];

  # Enable Hyprland (all devices use Hyprland)
  # programs.hyprland = {
  #   enable = true;
  #   package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  # };

  # Sound - PipeWire (all devices)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Base audio config (can be overridden per-device)
    # Defaults — device modules (e.g. go-xlr.nix, which needs lower latency) may
    # override these with their own values via mkForce-free plain definitions.
    extraConfig.pipewire = {
      "context.properties" = {
        "default.clock.rate" = lib.mkDefault 48000;
        "default.clock.quantum" = lib.mkDefault 1024;
        "default.clock.min-quantum" = lib.mkDefault 512;
      };
    };
  };

  # Allow root to use the live nix-config repo in /etc/nixos
  # Required for: sudo git -C /etc/nixos/nix-config pull
  environment.etc."gitconfig".text = ''
    [safe]
      directory = /etc/nixos/nix-config
  '';

  # SSH
  # services.openssh = {
  #   enable = true;
  #   settings = {
  #     PermitRootLogin = "no";
  #     PasswordAuthentication = false;
  #   };
  # };

  # Firewall
  # networking.firewall.enable = true;

  # Affinity Apps (all devices get these)
  # programs.affinity = {
  #   enable = true;
  #   designer = true;
  #   photo = true;
  #   publisher = true;
  # };

  # System State Version
  system.stateVersion = "24.11";
}
