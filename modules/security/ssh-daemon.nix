{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.sshDaemon;
in
{
  options.security.sshDaemon = {
    enable = mkEnableOption "Hardened SSH daemon configuration";

    port = mkOption {
      type = types.int;
      default = 22;
      description = "SSH port to listen on";
    };

    allowUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of users allowed to SSH (empty = all users)";
    };

    idleTimeout = mkOption {
      type = types.int;
      default = 300;
      description = "Idle timeout in seconds (default: 5 minutes)";
    };

    maxAuthTries = mkOption {
      type = types.int;
      default = 3;
      description = "Maximum authentication attempts per connection";
    };

    firewallLocalOnly = mkOption {
      type = types.bool;
      default = false;
      description = "Only allow SSH from local network (192.168.0.0/16, 10.0.0.0/8)";
    };
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports = [ cfg.port ];

      settings = {
        # ============ Authentication ============
        # No password authentication - keys only
        PasswordAuthentication = false;
        ChallengeResponseAuthentication = false;
        KbdInteractiveAuthentication = false;

        # Public key authentication only
        PubkeyAuthentication = true;

        # No root login
        PermitRootLogin = "no";

        # No empty passwords
        PermitEmptyPasswords = false;

        # ============ Modern Cryptography ============
        # Only ED25519 keys accepted
        PubkeyAcceptedAlgorithms = "ssh-ed25519,ssh-ed25519-cert-v01@openssh.com";

        # Only ED25519 host keys
        HostKeyAlgorithms = "ssh-ed25519,ssh-ed25519-cert-v01@openssh.com";

        # Modern ciphers only (ChaCha20 for non-AES-NI, AES-GCM for Intel/AMD)
        Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com";

        # Modern MACs only (Encrypt-then-MAC mode)
        MACs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com";

        # Modern key exchange algorithms
        KexAlgorithms = "curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group16-sha512";

        # ============ Connection Limits ============
        # Maximum authentication attempts
        MaxAuthTries = cfg.maxAuthTries;

        # Maximum concurrent sessions per connection
        MaxSessions = 10;

        # Connection rate limiting (start:rate:full)
        # Allow 10 unauthenticated connections, then 30% success rate, max 60
        MaxStartups = "10:30:60";

        # Login grace period
        LoginGraceTime = 30;

        # ============ Idle Timeout ============
        # Send keepalive every 5 minutes
        ClientAliveInterval = cfg.idleTimeout;

        # Disconnect after 2 missed keepalives
        ClientAliveCountMax = 2;

        # ============ Security Features ============
        # Verbose logging for security audits
        LogLevel = "VERBOSE";

        # Disable dangerous features
        AllowAgentForwarding = false;
        AllowTcpForwarding = false;
        X11Forwarding = false;
        PermitTunnel = false;
        PermitUserEnvironment = false;

        # No streaming compression (prevents some attacks)
        Compression = false;

        # Use privilege separation
        UsePrivilegeSeparation = "sandbox";

        # Strict mode (check permissions on key files)
        StrictModes = true;

        # ============ User Restrictions ============
        AllowUsers = mkIf (cfg.allowUsers != []) cfg.allowUsers;
      };

      # Only ED25519 host key
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      # Banner (optional - can be disabled)
      banner = ''
        ┌─────────────────────────────────────────┐
        │  Authorized Access Only                 │
        │  All connections are monitored & logged │
        └─────────────────────────────────────────┘
      '';
    };

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];

      # Local network only (optional)
      extraCommands = mkIf cfg.firewallLocalOnly ''
        # Allow SSH only from local networks
        iptables -A nixos-fw -p tcp --dport ${toString cfg.port} -s 192.168.0.0/16 -j ACCEPT
        iptables -A nixos-fw -p tcp --dport ${toString cfg.port} -s 10.0.0.0/8 -j ACCEPT
        iptables -A nixos-fw -p tcp --dport ${toString cfg.port} -j DROP
      '';
    };

    # Fail2ban integration for additional protection (optional)
    services.fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";

      jails.sshd = ''
        enabled = true
        port = ${toString cfg.port}
        filter = sshd
        logpath = /var/log/auth.log
        maxretry = ${toString cfg.maxAuthTries}
        bantime = 3600
      '';
    };

    # Audit logging
    security.audit = {
      enable = true;
      rules = [
        # Log all SSH authentication attempts
        "-w /var/log/auth.log -p wa -k ssh_auth"
        "-w /etc/ssh/sshd_config -p wa -k sshd_config"
      ];
    };

    # Remove obsolete host keys on system activation
    system.activationScripts.removeObsoleteHostKeys = ''
      echo "Cleaning up obsolete SSH host keys..."
      rm -f /etc/ssh/ssh_host_dsa_key* 2>/dev/null || true
      rm -f /etc/ssh/ssh_host_rsa_key* 2>/dev/null || true
      rm -f /etc/ssh/ssh_host_ecdsa_key* 2>/dev/null || true
    '';
  };
}
