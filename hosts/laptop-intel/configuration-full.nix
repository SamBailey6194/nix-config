{
  config,
  pkgs,
  inputs,
  ...
}:

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

    # Secrets management (agenix decrypts at boot)
    ../../modules/core/secrets-laptop.nix

    # SSH configuration (per-device keys for GitHub + servers)
    ../../modules/core/ssh-config.nix

    # Hardware-specific
    ../../modules/hardware/intel-laptop.nix
    ../../modules/hardware/openrgb.nix # RGB control for keyboard/mouse

    # Desktop environment
    ../../modules/desktop/hyprland

    # Software suites
    ../../modules/software/browsers.nix
    ../../modules/software/development.nix
    ../../modules/software/office.nix
    ../../modules/software/communication.nix
    ../../modules/software/media.nix

    # Network
    # Mullvad VPN with multi-hop rotation via wireguard-helper
    ../../modules/network/wireguard-mullvad.nix

    # Tailscale: Temporary - will be replaced by Defguard + RustDesk (Syntek Infra repo)
    ../../modules/network/tailscale.nix
    ../../modules/network/remote-desktop.nix
    # Malware scanner with real-time protection
    ../../modules/security/malware-scanner.nix

    # Browser accountability posture: locked enterprise policies for Brave,
    # LibreWolf, Firefox Developer Edition, Zen + a QUIC-blocking nftables rule
    ../../modules/security/browser-policies

    # Squid accountability proxy + squid-digest (weekly adult-domain digest +
    # tamper watchers). Reproduces the browser_setup/accountability_script repos.
    ../../modules/security/squid-digest

    # Security tools (Phase 9 - Encryption & Hardening)
    # Uncomment to enable encryption tools suite
    # ../../modules/security/encryption-tools.nix
    # ../../modules/security/folder-encryption.nix
    ../../modules/security/luks-encryption.nix
    # ../../modules/security/ssh-daemon.nix

    # Filesystem
    ../../modules/filesystem/btrfs-layouts.nix # BTRFS subvolume management + snapshots
    ../../modules/filesystem/zram.nix          # Compressed swap in RAM

    # User
    ../../modules/users/laptop.nix
  ];

  # Enable SSH to generate host keys for agenix
  services.openssh.enable = true;

  # Device identity
  networking.hostName = "laptop-intel";

  # Browser accountability policies (4 locked browsers) + QUIC firewall backstop
  services.browserPolicies.enable = true;

  # Squid accountability proxy + squid-digest digest/watchers.
  # Requires the agenix squid-digest-env secret (Gmail creds, recipient,
  # heartbeat URL) — create it with: agenix -e secrets/squid-digest-env-laptop-intel.age
  services.squidDigest = {
    enable = true;
    user = "sam-laptop";
    fromName = "Laptop Accountability";
  };

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

  # Mullvad WireGuard VPN with multi-hop rotation
  # STATUS (2026-08-18): DISABLED until the Mullvad subscription is renewed.
  # While enabled-but-down, wg-quick-mullvad0 starts on every rebuild/boot and
  # points /etc/resolv.conf at Mullvad's in-tunnel resolver, which is
  # unreachable without a live tunnel — so all DNS resolution breaks. Flip
  # `enable = true` to restore once the subscription is paid.
  #
  # The kill switch (iptables -A OUTPUT -j REJECT) blocks ALL networking if the
  # VPN can't connect, which makes the system unusable. Enable incrementally:
  #   1. First: enable = true, enableKillSwitch = false (test VPN connects)
  #   2. Then: enableKillSwitch = true (once VPN is confirmed working)
  networking.wireguard-mullvad = {
    enable = false;
    device = "laptop-intel";

    # Mullvad-assigned addresses for "sharp oyster" (laptop-intel public key).
    # Static — only change if the keypair is regenerated (don't regenerate).
    deviceAddress = "10.64.107.64/32";
    deviceAddress6 = "fc00:bbbb:bbbb:bb01::1:6b3f/128";

    # Production servers that bypass VPN (for audit trail)
    bypassIPs = [
      # "203.0.113.5"
    ];

    # Kill switch - KEEP DISABLED until VPN is confirmed working on first boot
    enableKillSwitch = false;

    # Per-app VPN routing via cgroups — every browser goes through the VPN.
    # These are the launch-command names the vpn-app wrapper wraps; verify the
    # zen / firefox-devedition binary names if a browser ever escapes the tunnel.
    cgroupApps = [
      "brave"
      "librewolf"
      "zen"
      "transmission"
    ];

    # Automatic weekly server rotation (entry → UK exit multi-hop)
    autoRotate = {
      enable = true;
      schedule = "Sun *-*-* 03:00:00";
    };

    # VPN metrics logging
    metricsLogging = {
      enable = true;
      interval = "5min";
      logFile = "/var/log/vpn-logs.txt";
    };
  };

  # LUKS encryption with TPM2 auto-unlock
  # After rebuilding, run: just enroll-tpm2 /dev/nvme0n1p2
  security.luksEncryption = {
    enable = true;
    devices.cryptroot = {
      device = "/dev/disk/by-uuid/4cf4afe8-4076-4249-b963-9d29bd918458";
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
    rootDevice = "/dev/disk/by-uuid/fc7428cf-f919-46b8-aaae-1a99d927aa93";
  };

  # Zram compressed swap (50% of 32GB RAM, zstd compression)
  filesystem.zram.enable = true;

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # System packages + creative tools (Intel GPU - limited)
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

      # Creative tools (Intel GPU compatible)
      # blender              # 3D creation
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
