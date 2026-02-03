{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.encryptionTools;
in
{
  options.security.encryptionTools = {
    enable = mkEnableOption "Encryption and security tools suite";

    enableGPG = mkOption {
      type = types.bool;
      default = true;
      description = "Install GPG for email and file encryption";
    };

    enableVeraCrypt = mkOption {
      type = types.bool;
      default = true;
      description = "Install VeraCrypt for USB/external drive encryption";
    };

    enable7Zip = mkOption {
      type = types.bool;
      default = true;
      description = "Install 7-Zip for encrypted archives";
    };

    enableGocryptfs = mkOption {
      type = types.bool;
      default = true;
      description = "Install gocryptfs for per-folder encryption";
    };

    enableAge = mkOption {
      type = types.bool;
      default = true;
      description = "Install age for modern file encryption";
    };

    enableYubikey = mkOption {
      type = types.bool;
      default = false;
      description = "Install YubiKey tools for hardware security keys";
    };

    gpg = {
      pinentryFlavor = mkOption {
        type = types.enum [ "curses" "gtk2" "qt" "gnome3" ];
        default = "curses";
        description = "Pinentry interface for GPG passphrase entry";
      };

      enableSSHSupport = mkOption {
        type = types.bool;
        default = false;
        description = "Use GPG agent for SSH authentication";
      };

      defaultKeyLength = mkOption {
        type = types.int;
        default = 4096;
        description = "Default key length for GPG key generation";
      };
    };
  };

  config = mkIf cfg.enable {
    # Core encryption tools
    environment.systemPackages = with pkgs; [
      # LUKS management
      cryptsetup

      # GPG suite
      (mkIf cfg.enableGPG gnupg)
      (mkIf cfg.enableGPG paperkey)  # GPG key backup to paper

      # Archive encryption
      (mkIf cfg.enable7Zip p7zip)

      # Container encryption
      (mkIf cfg.enableVeraCrypt veracrypt)

      # Per-folder encryption
      (mkIf cfg.enableGocryptfs gocryptfs)

      # Modern encryption
      (mkIf cfg.enableAge age)

      # Additional tools
      tomb  # Encrypted storage wrapper

      # Hardware security
      (mkIf cfg.enableYubikey yubikey-manager)
      (mkIf cfg.enableYubikey yubikey-personalization)
    ];

    # GPG agent configuration
    programs.gnupg.agent = mkIf cfg.enableGPG {
      enable = true;
      enableSSHSupport = cfg.gpg.enableSSHSupport;
      pinentryPackage = pkgs."pinentry-${cfg.gpg.pinentryFlavor}";
    };

    # GPG configuration file
    environment.etc."skel/.gnupg/gpg.conf" = mkIf cfg.enableGPG {
      text = ''
        # Modern GPG configuration
        # Use AES256 for symmetric encryption
        personal-cipher-preferences AES256 AES192 AES

        # Use SHA512 for hashing
        personal-digest-preferences SHA512 SHA384 SHA256

        # Use ZLIB for compression
        personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed

        # Default key length
        default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed

        # Show key fingerprints
        keyid-format 0xlong
        with-fingerprint

        # Use UTF-8
        charset utf-8

        # No version in output
        no-emit-version

        # No comments in signatures
        no-comments

        # Cross-certify subkeys
        require-cross-certification

        # Use strong key server
        keyserver hkps://keys.openpgp.org
      '';
    };

    # GPG agent configuration
    environment.etc."skel/.gnupg/gpg-agent.conf" = mkIf cfg.enableGPG {
      text = ''
        # Cache passphrase for 1 hour
        default-cache-ttl 3600
        max-cache-ttl 7200

        # Pinentry program
        pinentry-program ${pkgs."pinentry-${cfg.gpg.pinentryFlavor}"}/bin/pinentry-${cfg.gpg.pinentryFlavor}

        # Enable SSH support if requested
        ${optionalString cfg.gpg.enableSSHSupport "enable-ssh-support"}
      '';
    };

    # VeraCrypt kernel modules
    boot.kernelModules = mkIf cfg.enableVeraCrypt [ "fuse" ];

    # FUSE support for gocryptfs and VeraCrypt
    programs.fuse.userAllowOther = mkIf (cfg.enableGocryptfs || cfg.enableVeraCrypt) true;

    # YubiKey udev rules
    services.udev.packages = mkIf cfg.enableYubikey [ pkgs.yubikey-personalization ];

    # PCSCD service for YubiKey
    services.pcscd.enable = mkIf cfg.enableYubikey true;

    # Create GPG directory for new users
    systemd.tmpfiles.rules = mkIf cfg.enableGPG [
      "d /home/%u/.gnupg 0700 %u users - -"
    ];
  };
}
