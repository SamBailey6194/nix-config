{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # FULL CONFIGURATION (framework)
  # Comprehensive configuration after all staged installations complete
  # This is the primary configuration used by .#framework

  imports = [
    # Hardware
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/base-configuration.nix
    ../../modules/core/common.nix
    ../../modules/core/nix-settings.nix

    # Secrets management (agenix decrypts at boot)
    # TODO: Uncomment once framework is installed — needs its host key in
    # secrets/secrets.nix and per-device .age secrets to exist (none yet, so
    # importing this fails eval: agenix references non-existent *.age files).
    # ../../modules/core/secrets-laptop.nix

    # SSH configuration (per-device keys for GitHub + servers)
    ../../modules/core/ssh-config.nix

    # Hardware-specific
    ../../modules/hardware/amd-laptop.nix

    # Desktop environment
    ../../modules/desktop/hyprland

    # Software suites
    ../../modules/software/browsers.nix
    ../../modules/software/development.nix
    ../../modules/software/office.nix
    ../../modules/software/communication.nix
    ../../modules/software/media.nix
    ../../modules/software/creative.nix # DaVinci Resolve Studio + Blender

    # Network
    # TODO: Uncomment when Mullvad keypairs are registered for this device
    # ../../modules/network/wireguard-mullvad.nix

    # Tailscale: Temporary - will be replaced by Defguard + RustDesk (Syntek Infra repo)
    ../../modules/network/tailscale.nix
    ../../modules/network/remote-desktop.nix

    # Malware scanner with real-time protection
    ../../modules/security/malware-scanner.nix

    # Security tools (Phase 9 - Encryption & Hardening)
    ../../modules/security/luks-encryption.nix

    # Filesystem
    ../../modules/filesystem/btrfs-layouts.nix # BTRFS subvolume management + snapshots
    ../../modules/filesystem/zram.nix          # Compressed swap in RAM

    # Browser accountability posture (locked policies + QUIC backstop)
    ../../modules/security/browser-policies
    # Squid accountability proxy + squid-digest (enabled once agenix is wired)
    ../../modules/security/squid-digest

    # User
    ../../modules/users/framework.nix
  ];

  # Enable SSH to generate host keys for agenix
  services.openssh.enable = true;

  # Device identity
  networking.hostName = "framework";

  # Malware scanner with real-time file monitoring
  # NOTE: boot scan and real-time monitoring disabled until malware-scanner
  # Rust binary is built and deployed on this system. Enabling these without
  # the binary causes systemd to block greetd (display-manager.service),
  # stalling boot at the login screen.
  security.malwareScanner = {
    enable = true;
    realTimeMonitoring.enable = false;
    bootScan.enable = false;
  };

  # TODO: Mullvad WireGuard VPN with multi-hop rotation
  # Uncomment wireguard-mullvad.nix import above and configure once Mullvad
  # keypairs are registered for this device. Follow laptop-intel as reference.
  # IMPORTANT: Set enableKillSwitch = false initially (blocks ALL networking
  # if VPN can't connect).

  # LUKS encryption with TPM2 auto-unlock
  # After rebuilding, run: just enroll-tpm2 /dev/nvme0n1p2
  security.luksEncryption = {
    enable = true;
    devices.cryptroot = {
      device = "/dev/disk/by-uuid/REPLACE-WITH-LUKS-PARTITION-UUID";
      name = "cryptroot";
      allowDiscards = true; # TRIM for SSD
      preLVM = true;
      fallbackToPassword = true;
      tpm2Device = "auto";
    };
  };

  # TPM2 user-space support (udev rules, tools access)
  security.tpm2 = {
    enable = true;
    abrmd.enable = true; # TPM2 access broker for concurrent access
  };

  # BTRFS subvolume layout (compression, scrub, snapper snapshots)
  # Mounts are merged with hardware-configuration.nix — /boot is preserved.
  filesystem.btrfsLayouts = {
    layout = "laptop";
    rootDevice = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-FILESYSTEM-UUID";
  };

  # Zram compressed swap (50% of 64GB RAM, zstd compression)
  filesystem.zram.enable = true;
  # Browser accountability policies + QUIC firewall backstop (no secrets needed)
  services.browserPolicies.enable = true;

  # squid-digest needs the agenix squid-digest-env secret. Enable once framework
  # is installed, its host key is in secrets/secrets.nix, secrets-laptop.nix is
  # imported, and secrets/squid-digest-env-framework.age is created.
  # services.squidDigest = {
  #   enable = true;
  #   user = "sam-framework";
  #   fromName = "Framework Accountability";
  # };

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # System packages + creative tools (AMD GPU - full support)
  environment.systemPackages =
    with pkgs;
    [
      # Core utilities
      vim
      wget
      git
      htop
      tree
      btop
      fastfetch

      # Creative tools (AMD GPU - full acceleration)
      gimp # Image editing
      inkscape # Vector graphics
      krita # Digital painting

      # Claude Code Nix Package
      claude-code
    ]
    ++ [
      # Affinity Apps (via overlay — see nix-settings.nix)
      affinity-designer
      affinity-photo
      affinity-publisher
    ];

  # Enable zsh
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
