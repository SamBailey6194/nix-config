# Agenix secrets configuration
# This file defines which secrets exist and which machines can decrypt them
#
# Per-Device Security Model:
#   - GitHub keys: Per-device keys WITHOUT passphrases (convenience)
#   - Server/VPN/VM keys: Per-device keys WITH passphrases (security)
#   - Device compromise only exposes keys for THAT device
#
# Usage:
#   1. Generate host SSH keys: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_agenix
#   2. Add public keys to this file
#   3. Create encrypted secrets: agenix -e github-ssh-personal.age
#   4. Reference secrets in NixOS configs via age.secrets

let
  # User keys (for initial secret creation and management)
  # These are YOUR personal SSH keys used to encrypt/decrypt secrets during development
  sam-personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEPLOY_YOUR_PERSONAL_KEY_HERE sam@personal";

  # Host keys (machine SSH host keys - extracted after NixOS installation)
  # Each NixOS machine generates these during installation at /etc/ssh/ssh_host_ed25519_key.pub
  # Get them with: ssh-keyscan <hostname> or cat /etc/ssh/ssh_host_ed25519_key.pub
  laptop-intel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEPLOY_LAPTOP_HOST_KEY_HERE root@laptop-intel";
  framework = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEPLOY_FRAMEWORK_HOST_KEY_HERE root@framework";
  devtower = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEPLOY_DEVTOWER_HOST_KEY_HERE root@devtower";

  # Key groups for easy management
  allUsers = [ sam-personal ];
  allHosts = [ laptop-intel framework devtower ];
  allKeys = allUsers ++ allHosts;

  # Specific device groups
  laptops = [ laptop-intel framework ];
  desktops = [ devtower ];
in
{
  # ============================================================================
  # GitHub SSH Keys (Per-Device, NO Passphrases)
  # Each device has its own key for each GitHub account
  # Benefits: Device compromise only exposes that device's keys
  # ============================================================================

  # Personal GitHub (SamBailey6194)
  "github-ssh-personal-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "github-ssh-personal-framework.age".publicKeys = allUsers ++ [ framework ];
  "github-ssh-personal-devtower.age".publicKeys = allUsers ++ [ devtower ];

  # Syntek GitHub (syntek-studio)
  "github-ssh-syntek-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "github-ssh-syntek-framework.age".publicKeys = allUsers ++ [ framework ];
  "github-ssh-syntek-devtower.age".publicKeys = allUsers ++ [ devtower ];

  # Missional Gen GitHub (sam-missionalgen)
  "github-ssh-missionalgen-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "github-ssh-missionalgen-framework.age".publicKeys = allUsers ++ [ framework ];
  "github-ssh-missionalgen-devtower.age".publicKeys = allUsers ++ [ devtower ];

  # ============================================================================
  # Wireguard VPN Keys (Per-Device Private Keys)
  # Future - Phase 12
  # ============================================================================
  "wireguard-laptop-intel-private.age".publicKeys = allUsers ++ [ laptop-intel ];
  "wireguard-framework-private.age".publicKeys = allUsers ++ [ framework ];
  "wireguard-devtower-private.age".publicKeys = allUsers ++ [ devtower ];

  # ============================================================================
  # Server SSH Keys (Per-Device, WITH Passphrases)
  # Example: Client ACME server - each device has unique credentials
  # Format: server-<name>-<device>-key.age (private key)
  #         server-<name>-<device>-passphrase.age (passphrase)
  # ============================================================================

  # Example: Uncomment when adding your first client server
  # "server-acme-laptop-intel-key.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "server-acme-laptop-intel-passphrase.age".publicKeys = allUsers ++ [ laptop-intel ];
  # "server-acme-framework-key.age".publicKeys = allUsers ++ [ framework ];
  # "server-acme-framework-passphrase.age".publicKeys = allUsers ++ [ framework ];
  # "server-acme-devtower-key.age".publicKeys = allUsers ++ [ devtower ];
  # "server-acme-devtower-passphrase.age".publicKeys = allUsers ++ [ devtower ];

  # ============================================================================
  # Shared Secrets (All Devices Can Decrypt)
  # Use sparingly - prefer per-device secrets for zero-trust
  # ============================================================================

  # Example: Uncomment when needed
  # "wifi-passwords.age".publicKeys = allKeys;
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
