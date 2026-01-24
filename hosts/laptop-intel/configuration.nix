{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/common.nix
    ../../modules/core/users.nix
    ../../modules/core/nix-settings.nix
    ../../modules/desktop/hyprland
  ];

  # System Identity
  networking.hostName = "laptop-intel";

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Intel CPU Microcode
  hardware.cpu.intel.updateMicrocode = true;

  # Intel Graphics (UHD Graphics CML GT2)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver  # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver  # LIBVA_DRIVER_NAME=i965 (older but sometimes better)
    ];
  };

  # Laptop-specific: Power Management
  services.thermald.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    };
  };

  # Laptop-specific: Backlight Control
  programs.light.enable = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone
  time.timeZone = "Australia/Melbourne";

  # Locale
  i18n.defaultLocale = "en_AU.UTF-8";

  # System Packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tree
    btop
    fastfetch
  ];

  # Enable Hyprland (via module)
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  # Sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
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

  # System State Version (DO NOT CHANGE after installation)
  system.stateVersion = "24.11";
}
