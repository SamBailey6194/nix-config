{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # FULL CONFIGURATION (devtower)
  # Comprehensive configuration after all staged installations complete
  # This is the primary configuration used by .#devtower

  imports = [
    # Hardware
    ./hardware-configuration.nix

    # Core modules
    ../../modules/core/base-configuration.nix
    ../../modules/core/common.nix
    ../../modules/core/nix-settings.nix

    # Secrets management (agenix decrypts at boot)
    ../../modules/core/secrets-desktop.nix

    # SSH configuration (per-device keys for GitHub + servers)
    ../../modules/core/ssh-config.nix

    # Hardware-specific
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/go-xlr.nix   # Go XLR audio interface
    ../../modules/hardware/openrgb.nix  # RGB keyboard/peripherals

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

    # Storage (HDD ZFS pool for media - runtime-configured)
    ../../modules/storage/zfs.nix

    # User
    ../../modules/users/devtower.nix
  ];

  # Enable SSH to generate host keys for agenix
  services.openssh.enable = true;

  # Device identity
  networking.hostName = "devtower";

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

  # LUKS encryption with TPM2 auto-unlock (NVMe OS drive only)
  # After rebuilding, run: just enroll-tpm2 /dev/nvme0n1p2
  security.luksEncryption = {
    enable = true;
    devices.cryptroot = {
      device = "/dev/disk/by-uuid/REPLACE-WITH-LUKS-PARTITION-UUID";
      name = "cryptroot";
      allowDiscards = true; # TRIM for NVMe
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

  # BTRFS subvolume layout for NVMe OS drive (no @home — home is on separate SSD)
  # Mounts are merged with hardware-configuration.nix — /boot is preserved.
  filesystem.btrfsLayouts = {
    layout = "devtower-os";
    rootDevice = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-OS-FILESYSTEM-UUID";
  };

  # ZFS pool for HDD media storage (runtime-configured via zfs-manage)
  # Pool creation: zfs-manage create-pool media /dev/sdX
  # The ZFS module provides the kernel modules and tools; pool management is runtime.

  # Zram compressed swap (50% of 64GB RAM, zstd compression)
  filesystem.zram.enable = true;

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # System packages + creative tools (AMD GPU - full acceleration)
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
      # Affinity Apps (via Wine - from affinity-nix flake)
      inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.designer
      inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.photo
      inputs.affinity-nix.packages.${pkgs.stdenv.hostPlatform.system}.publisher
    ];

  # Enable zsh
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
