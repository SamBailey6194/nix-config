# Agenix secrets configuration
# This file defines which secrets exist and which machines can decrypt them
#
# Per-Device Security Model:
#   - User keys: Per-device keys for agenix encrypt/decrypt during development
#   - Host keys: Machine SSH keys for decryption during nixos-rebuild
#   - GitHub keys: Per-device keys WITHOUT passphrases (convenience)
#   - Server/VPN/VM keys: Per-device keys WITH passphrases (security)
#   - Device compromise only exposes keys for THAT device
#
# Setup per device:
#   1. Generate a dedicated agenix user key:
#      ssh-keygen -t ed25519 -C "sam@<device>" -f ~/.ssh/id_ed25519_agenix
#   2. Paste the public key below for that device
#   3. After rekeying, that device can encrypt/decrypt secrets:
#      agenix -i ~/.ssh/id_ed25519_agenix -e <secret>.age

let
  # ============================================================================
  # User keys (per-device, for encrypting/decrypting secrets during development)
  # These let YOU run `agenix -e` on each machine you edit secrets from.
  # Generate with: ssh-keygen -t ed25519 -C "sam@<device>" -f ~/.ssh/id_ed25519_agenix
  # Get public key: cat ~/.ssh/id_ed25519_agenix.pub
  # ============================================================================
  sam-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDDdE+EkEkG7BtvLb5mDPC6bPbs0vzw1yq6xcfmv+hao sam@laptop-intel";
  # Ubuntu dev PC (SamLinPC) — where this repo is edited. Deliberately NOT in
  # allUsers: it is a recipient for the aws-config secret only, so the zero-trust
  # model for GitHub keys, LUKS passphrases, VPN and the rest is unchanged.
  sam-ubuntu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPskJivc4/qcwMb4XCNT4bK7GcIXeQn/rsya5IkKBvO sam-dev@SamLinPC";

  # ============================================================================
  # Host keys (machine SSH host keys - extracted after NixOS installation)
  # Each NixOS machine generates these during installation at /etc/ssh/ssh_host_ed25519_key.pub
  # Get them with: ssh-keyscan <hostname> or cat /etc/ssh/ssh_host_ed25519_key.pub
  # ============================================================================
  laptop-intel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHXF52LZvZybhGO0LJGl8UU/SV8t1dODetofFo5CDU4W root@laptop-intel";
  # framework = "ssh-ed25519 REPLACE_WITH_FRAMEWORK_HOST_KEY root@framework";
  # devtower = "ssh-ed25519 REPLACE_WITH_DEVTOWER_HOST_KEY root@devtower";
  # devtower-intel = "ssh-ed25519 <verified host public key> root@devtower-intel";

  # Bootstrap the Intel desktop secrets with the existing recovery/editor key.
  # After installation, add its real host key above and append devtower-intel
  # here, then re-encrypt these secrets (docs/INSTALL-INTEL-MANUALLY.md, section 8). Until then the desktop cannot decrypt
  # them automatically. WireGuard public keys are NOT age recipients.
  devtowerIntelKeys = [ sam-laptop ];

  # Key groups for easy management (only include keys with real values)
  allUsers = [ sam-laptop ];
  allHosts = [ laptop-intel ];
  allKeys = allUsers ++ allHosts;

  # Specific device groups (uncomment when devices are set up)
  # laptops = [ laptop-intel framework ];
  # desktops = [ devtower ];
in
{
  # ============================================================================
  # GitHub SSH Keys (Per-Device, NO Passphrases)
  # Each device has its own key for each GitHub account
  # Benefits: Device compromise only exposes that device's keys
  # ============================================================================

  # Personal GitHub (SamBailey6194)
  "github-ssh-personal-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "github-ssh-personal-framework.age".publicKeys = allUsers ++ [ framework ];
  # "github-ssh-personal-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "github-ssh-personal-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # Syntek GitHub (syntek-studio)
  "github-ssh-syntek-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "github-ssh-syntek-framework.age".publicKeys = allUsers ++ [ framework ];
  # "github-ssh-syntek-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "github-ssh-syntek-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # Missional Gen GitHub (sam-missional-gen)
  "github-ssh-missionalgen-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "github-ssh-missionalgen-framework.age".publicKeys = allUsers ++ [ framework ];
  # "github-ssh-missionalgen-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "github-ssh-missionalgen-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # Mullvad WireGuard VPN (Per-Device Configuration)
  # Phase 6: Multi-hop VPN with split tunneling and automatic rotation
  # Each device has: private key, account number, config, cache, route history
  # Intel desktop currently uses the official Mullvad app; its custom-helper
  # declarations stay commented unless that VPN implementation is selected.
  # ============================================================================

  # Wireguard private keys (generated by wireguard-helper init)
  "wireguard-laptop-intel-private.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "wireguard-framework-private.age".publicKeys = allUsers ++ [ framework ];
  # "wireguard-devtower-private.age".publicKeys = allUsers ++ [ devtower ];
  # "wireguard-devtower-intel-private.age".publicKeys = devtowerIntelKeys;

  # Mullvad account numbers (from mullvad.net)
  "mullvad-account-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "mullvad-account-framework.age".publicKeys = allUsers ++ [ framework ];
  # "mullvad-account-devtower.age".publicKeys = allUsers ++ [ devtower ];
  # "mullvad-account-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # Generated multi-hop configs (rotated by wireguard-helper)
  "mullvad-wg-config-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "mullvad-wg-config-framework.age".publicKeys = allUsers ++ [ framework ];
  # "mullvad-wg-config-devtower.age".publicKeys = allUsers ++ [ devtower ];
  # "mullvad-wg-config-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # API cache and route history (avoid reusing servers)
  "mullvad-relay-cache-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "mullvad-relay-cache-framework.age".publicKeys = allUsers ++ [ framework ];
  # "mullvad-relay-cache-devtower.age".publicKeys = allUsers ++ [ devtower ];
  # "mullvad-relay-cache-devtower-intel.age".publicKeys = devtowerIntelKeys;

  "mullvad-route-history-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "mullvad-route-history-framework.age".publicKeys = allUsers ++ [ framework ];
  # "mullvad-route-history-devtower.age".publicKeys = allUsers ++ [ devtower ];
  # "mullvad-route-history-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # arwyn-1 Admin VPN (Per-Device)
  # Split-tunnel WireGuard link to arwyn-1 (modules/network/wireguard-arwyn.nix).
  # The server holds this device's public key and its own copy of the PSK
  # (i-had-dad-deployment: wireguard-psk-sam-laptop.age — the two must match).
  # laptop-intel's key pair was generated on SamLinPC into RAM (25/09/2026),
  # encrypted straight to these recipients and shredded. SamLinPC is not a
  # recipient, so it cannot read either file back.
  # ============================================================================

  "wireguard-arwyn-laptop-intel-private.age".publicKeys = allUsers ++ [ laptop-intel ];
  "wireguard-arwyn-laptop-intel-psk.age".publicKeys = allUsers ++ [ laptop-intel ];
  "wireguard-arwyn-devtower-intel-private.age".publicKeys = devtowerIntelKeys;
  "wireguard-arwyn-devtower-intel-psk.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # Malware Scanner Quarantine Encryption Keys (Per-Device)
  # Phase 7: Malware detection and threat protection
  # Each device has its own encryption key for quarantine storage
  # 256-bit AES-GCM keys for encrypting quarantined malware samples
  # ============================================================================

  "malware-scanner-quarantine-key-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "malware-scanner-quarantine-key-framework.age".publicKeys = allUsers ++ [ framework ];
  # "malware-scanner-quarantine-key-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "malware-scanner-quarantine-key-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # squid-digest Environment (Per-Device)
  # Accountability digest secrets: Gmail app password, recipient email, and the
  # off-machine heartbeat URL. Non-secret SD_* config lives in Nix
  # (/etc/squid-digest/defaults.env), so only these credentials are encrypted.
  # ============================================================================

  "squid-digest-env-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "squid-digest-env-framework.age".publicKeys = allUsers ++ [ framework ];
  # "squid-digest-env-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "squid-digest-env-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # Claude Code Secrets (Per-Device)
  # Env file consumed by home/modules/claude.nix and the shared MCP launcher:
  # CLAUDE_MONITOR_TOKEN (monitor hook auth), CONTEXT7_API_KEY (Context7 MCP),
  # ELEVENLABS_API_KEY + ELEVENLABS_MCP_BASE_PATH (ElevenLabs MCP).
  # Edit per device on first use.
  # ============================================================================

  "claude-secrets-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "claude-secrets-framework.age".publicKeys = allUsers ++ [ framework ];
  # "claude-secrets-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "claude-secrets-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # AWS CLI Config (Per-Device)
  # ~/.aws/config for `aws sso login`: SSO start URL, session, account IDs, role
  # names and regions. Not long-lived credentials (SSO tokens are cached under
  # ~/.aws/sso/cache at login), but the account topology is not repo-public.
  # ============================================================================

  "aws-config-laptop-intel.age".publicKeys = allUsers ++ [
    sam-ubuntu
    laptop-intel
  ];
  # "aws-config-framework.age".publicKeys = allUsers ++ [ framework ];
  # "aws-config-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "aws-config-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ~/.aws/credentials: static IAM access keys ([default], [mg]), carried over
  # from Ubuntu. Long-lived credentials — rotate them after the migration.
  "aws-credentials-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # LUKS Encryption Passphrases (Per-Device Fallback Recovery)
  # These are fallback passphrases when TPM2 auto-unlock fails
  # DevTower has separate passphrases for OS, home, and media drives
  # ============================================================================

  # Laptop LUKS passphrases (single drive)
  "luks-passphrase-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "luks-passphrase-framework.age".publicKeys = allUsers ++ [ framework ];

  # DevTower LUKS passphrases (3 separate drives)
  # "luks-passphrase-devtower-os.age".publicKeys = allUsers ++ [ devtower ];      # /dev/nvme1n1p2 (OS)
  # "luks-passphrase-devtower-home.age".publicKeys = allUsers ++ [ devtower ];    # /dev/sdd1 (Home)
  # "luks-passphrase-devtower-media.age".publicKeys = allUsers ++ [ devtower ];   # /dev/sdc1 (Media)

  # Intel desktop: separate recovery passphrases for each future LUKS container.
  # Only the OS container is currently configured. Additional drives are migrated
  # individually after backup verification and a successful OS installation.
  # Names do not encrypt disks or configure mounts; new UUIDs are needed first.
  # If Nix and Docker retain separate LUKS containers, give each its own secret.
  # DavinciProj stays shared NTFS; it is not a Linux-only LUKS media container.
  "luks-passphrase-devtower-intel-os.age".publicKeys = devtowerIntelKeys;
  # "luks-passphrase-devtower-intel-home.age".publicKeys = devtowerIntelKeys;    # Samsung 512 GB
  # "luks-passphrase-devtower-intel-data.age".publicKeys = devtowerIntelKeys;    # Samsung 870 EVO: Nix/Docker
  # "luks-passphrase-devtower-intel-archive.age".publicKeys = devtowerIntelKeys; # Seagate archive

  # ============================================================================
  # Per-Folder Encryption Master Keys (gocryptfs)
  # Optional master keys for vault recovery (users can also use passwords only)
  # ============================================================================

  "vault-master-key-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "vault-master-key-framework.age".publicKeys = allUsers ++ [ framework ];
  # "vault-master-key-devtower.age".publicKeys = allUsers ++ [ devtower ];
  "vault-master-key-devtower-intel.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # Server SSH Keys (Per-Device, WITH Passphrases)
  # Example: Client ACME server - each device has unique credentials
  # Format: server-<name>-<device>-key.age (private key)
  #         server-<name>-<device>-passphrase.age (passphrase)
  # ============================================================================

  # Example: Uncomment when adding your first client server
  "server-acme-laptop-intel-key.age".publicKeys = allUsers ++ [ laptop-intel ];
  "server-acme-laptop-intel-passphrase.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "server-acme-framework-key.age".publicKeys = allUsers ++ [ framework ];
  # "server-acme-framework-passphrase.age".publicKeys = allUsers ++ [ framework ];
  # "server-acme-devtower-key.age".publicKeys = allUsers ++ [ devtower ];
  # "server-acme-devtower-passphrase.age".publicKeys = allUsers ++ [ devtower ];
  # Legacy example consumed by secrets-desktop.nix in the full stage.
  "server-acme-devtower-intel-key.age".publicKeys = devtowerIntelKeys;
  "server-acme-devtower-intel-passphrase.age".publicKeys = devtowerIntelKeys;

  # ============================================================================
  # Shared Secrets (All Devices Can Decrypt)
  # Use sparingly - prefer per-device secrets for zero-trust
  # ============================================================================

  # Example: Uncomment when needed
  "wifi-passwords.age".publicKeys = allKeys;
  # "api-tokens-read-only.age".publicKeys = allKeys;
  # "restic-backup-password.age".publicKeys = allKeys;

  # ============================================================================
  # Device-Specific Secrets (Only One Device)
  # Example: Production database credentials only on devtower
  # ============================================================================

  # Example: Uncomment when needed
  # "production-db-password.age".publicKeys = allUsers ++ [ devtower ];
  # "staging-api-key.age".publicKeys = allUsers ++ laptops;
}
