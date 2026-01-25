# Per-Device Secrets Architecture

## Overview

This NixOS configuration implements a **zero-trust, per-device secrets model** where each device has unique credentials for every service. Device compromise only exposes secrets for that specific device, not all devices.

## Security Model

### Two-Tier Approach

1. **GitHub SSH Keys (NO Passphrases)**
   - Per-device keys for convenience
   - Auto git push/pull without passphrase prompts
   - Lower risk: GitHub already has 2FA and key revocation

2. **Server/VPN/VM SSH Keys (WITH Passphrases)**
   - Per-device keys with strong passphrases for security
   - Higher risk: Direct server access
   - Passphrase stored encrypted in agenix

### Benefits

- ✅ **Zero-Trust**: Each device gets unique credentials
- ✅ **Blast Radius Containment**: Device loss/theft only exposes that device's keys
- ✅ **Independent Rotation**: Rotate keys per device without affecting others
- ✅ **Audit Trail**: Know which device accessed which server
- ✅ **Gradual Rollout**: Add devices incrementally without resharing all secrets

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     secrets/secrets.nix                         │
│  Defines which keys can decrypt which secrets                   │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
          ┌────────────────────────────────────┐
          │    Encrypted .age Files (Git)      │
          │  github-ssh-personal-laptop.age    │
          │  github-ssh-personal-framework.age │
          │  server-acme-laptop-key.age        │
          └────────────────────────────────────┘
                               │
                               ▼
          ┌────────────────────────────────────┐
          │   Agenix Decryption at Boot        │
          │   Uses host SSH key at:            │
          │   /etc/ssh/ssh_host_ed25519_key    │
          └────────────────────────────────────┘
                               │
                               ▼
          ┌────────────────────────────────────┐
          │   Decrypted Secrets                │
          │   /run/agenix/github-personal      │
          │   /run/agenix/server-acme-key      │
          └────────────────────────────────────┘
                               │
                               ▼
          ┌────────────────────────────────────┐
          │   Symlinks to User Home            │
          │   ~/.ssh/github-personal           │
          │   ~/.ssh/server-acme-laptop-key    │
          └────────────────────────────────────┘
                               │
                               ▼
          ┌────────────────────────────────────┐
          │   Auto-Generated SSH Config        │
          │   (modules/core/ssh-config.nix)    │
          │   Uses per-device keys             │
          └────────────────────────────────────┘
```

## Naming Convention

### GitHub Keys (No Passphrases)

```
github-ssh-<account>-<device>.age

Examples:
- github-ssh-personal-laptop-intel.age
- github-ssh-syntek-framework.age
- github-ssh-missionalgen-devtower.age
```

Deployed to: `~/.ssh/github-<device>-<account>`

### Server Keys (With Passphrases)

```
server-<name>-<device>-key.age         (private key)
server-<name>-<device>-passphrase.age  (passphrase)

Examples:
- server-acme-laptop-intel-key.age
- server-acme-laptop-intel-passphrase.age
- server-staging-framework-key.age
- server-staging-framework-passphrase.age
```

Deployed to:
- `~/.ssh/server-<name>-<device>-key` (private key)
- Passphrase stored in agenix, used by ssh-agent

## Example: secrets/secrets.nix

```nix
let
  # User keys
  sam-personal = "ssh-ed25519 AAAA... sam@personal";

  # Host keys (extracted from /etc/ssh/ssh_host_ed25519_key.pub)
  laptop-intel = "ssh-ed25519 AAAA... root@laptop-intel";
  framework = "ssh-ed25519 AAAA... root@framework";
  devtower = "ssh-ed25519 AAAA... root@devtower";

  # Key groups
  allUsers = [ sam-personal ];
  allHosts = [ laptop-intel framework devtower ];
  allKeys = allUsers ++ allHosts;
in
{
  # ============================================================================
  # GitHub SSH Keys (Per-Device, NO Passphrases)
  # ============================================================================

  # Personal GitHub - per-device keys
  "github-ssh-personal-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "github-ssh-personal-framework.age".publicKeys = allUsers ++ [ framework ];
  "github-ssh-personal-devtower.age".publicKeys = allUsers ++ [ devtower ];

  # Syntek GitHub - per-device keys
  "github-ssh-syntek-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "github-ssh-syntek-framework.age".publicKeys = allUsers ++ [ framework ];
  "github-ssh-syntek-devtower.age".publicKeys = allUsers ++ [ devtower ];

  # ============================================================================
  # Server SSH Keys (Per-Device, WITH Passphrases)
  # ============================================================================

  # Client ACME server - per-device SSH keys
  "server-acme-laptop-intel-key.age".publicKeys = allUsers ++ [ laptop-intel ];
  "server-acme-laptop-intel-passphrase.age".publicKeys = allUsers ++ [ laptop-intel ];

  "server-acme-framework-key.age".publicKeys = allUsers ++ [ framework ];
  "server-acme-framework-passphrase.age".publicKeys = allUsers ++ [ framework ];

  "server-acme-devtower-key.age".publicKeys = allUsers ++ [ devtower ];
  "server-acme-devtower-passphrase.age".publicKeys = allUsers ++ [ devtower ];
}
```

## Example: Secrets Module (modules/core/secrets-laptop.nix)

```nix
{ config, ... }:

let
  hostname = config.networking.hostName;  # "laptop-intel"
  username = "sam-laptop";
in
{
  # GitHub SSH keys (per-device, no passphrases)
  age.secrets."github-${hostname}-personal" = {
    file = ../../secrets/github-ssh-personal-${hostname}.age;
    path = "/home/${username}/.ssh/github-personal";
    owner = username;
    group = "users";
    mode = "0600";
  };

  age.secrets."github-${hostname}-syntek" = {
    file = ../../secrets/github-ssh-syntek-${hostname}.age;
    path = "/home/${username}/.ssh/github-syntek";
    owner = username;
    group = "users";
    mode = "0600";
  };

  # Server SSH keys (per-device, with passphrases)
  age.secrets."server-acme-${hostname}-key" = {
    file = ../../secrets/server-acme-${hostname}-key.age;
    path = "/home/${username}/.ssh/server-acme-${hostname}-key";
    owner = username;
    group = "users";
    mode = "0600";
  };

  age.secrets."server-acme-${hostname}-passphrase" = {
    file = ../../secrets/server-acme-${hostname}-passphrase.age;
    path = "/run/agenix/server-acme-${hostname}-passphrase";
    owner = username;
    group = "users";
    mode = "0400";  # Read-only
  };
}
```

## Example: SSH Config (Auto-Generated)

The `modules/core/ssh-config.nix` module automatically generates SSH config using the current hostname:

```ssh-config
# GitHub personal account
Host github-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/github-laptop-intel-personal
  IdentitiesOnly yes

# Client ACME Server
Host client-acme
  HostName acme.example.com
  User root
  IdentityFile ~/.ssh/server-acme-laptop-intel-key
  IdentitiesOnly yes
```

Each device gets its own unique keys automatically!

## Workflow: Adding a New Server

### 1. Generate Per-Device SSH Keys

```bash
nix develop
agenix-helper add-server client-acme
```

This generates:
- SSH key pair for each device (WITH passphrases)
- Encrypts private keys and passphrases separately
- Outputs public keys to add to server

### 2. Add Public Keys to Server

```bash
# SSH to the server
ssh root@acme.example.com

# Add public keys to authorized_keys
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAA... laptop-intel@client-acme
ssh-ed25519 AAAA... framework@client-acme
ssh-ed25519 AAAA... devtower@client-acme
EOF
```

### 3. Uncomment Entries in secrets.nix

Edit `secrets/secrets.nix` and uncomment the server entries:

```nix
# Uncomment these lines
"server-acme-laptop-intel-key.age".publicKeys = allUsers ++ [ laptop-intel ];
"server-acme-laptop-intel-passphrase.age".publicKeys = allUsers ++ [ laptop-intel ];
# ... (repeat for other devices)
```

### 4. Rekey Secrets

```bash
agenix-helper rekey
```

### 5. Update Secrets Modules

Edit `modules/core/secrets-laptop.nix` to deploy the keys:

```nix
age.secrets."server-acme-${hostname}-key" = {
  file = ../../secrets/server-acme-${hostname}-key.age;
  path = "/home/${username}/.ssh/server-acme-${hostname}-key";
  owner = username;
  mode = "0600";
};
```

### 6. Rebuild

```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

### 7. Test Connection

```bash
# SSH using the per-device key
ssh client-acme
# Passphrase is retrieved from agenix automatically
```

## Workflow: Adding a New Device

### 1. Install NixOS on New Device

Follow Phase 1 installation instructions.

### 2. Get Host SSH Key

```bash
# On the new device
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

### 3. Update secrets.nix

Add the new host key:

```nix
new-device = "ssh-ed25519 AAAA... root@new-device";

# Add to allHosts
allHosts = [ laptop-intel framework devtower new-device ];
```

### 4. Generate Per-Device GitHub Keys

```bash
# On your existing device
nix develop

# Generate GitHub keys for new device
ssh-keygen -t ed25519 -C "new-device@github-personal" -f /tmp/github-personal-new -N ""
ssh-keygen -t ed25519 -C "new-device@github-syntek" -f /tmp/github-syntek-new -N ""
ssh-keygen -t ed25519 -C "new-device@github-missionalgen" -f /tmp/github-missionalgen-new -N ""
```

### 5. Encrypt Keys for New Device

```bash
# Encrypt each private key
agenix-helper edit github-ssh-personal-new-device.age
# Paste contents of /tmp/github-personal-new, save, exit

# Repeat for other accounts
```

### 6. Add Public Keys to GitHub

Add the `.pub` files to the respective GitHub accounts.

### 7. Rekey All Secrets

```bash
agenix-helper rekey
```

This re-encrypts all existing secrets to include the new device.

### 8. Rebuild on New Device

```bash
sudo nixos-rebuild switch --flake .#new-device
```

## Key Rotation

### Rotate a Single Device's Keys

```bash
# 1. Generate new key
ssh-keygen -t ed25519 -C "laptop-intel@github-personal" -f /tmp/new-key -N ""

# 2. Update encrypted secret
agenix-helper edit github-ssh-personal-laptop-intel.age
# Paste new private key, save

# 3. Add new public key to GitHub
cat /tmp/new-key.pub
# Add to GitHub settings

# 4. Rebuild
sudo nixos-rebuild switch --flake .#laptop-intel

# 5. Remove old key from GitHub
# Go to GitHub settings and delete the old key

# 6. Clean up temp files
rm /tmp/new-key /tmp/new-key.pub
```

### Rotate All Devices' Keys for a Service

```bash
# Repeat the above process for each device
# This ensures independent key rotation
```

## Security Best Practices

1. **Never commit unencrypted keys** - Only `.age` files go in git
2. **Rotate keys regularly** - At least annually, or after device loss
3. **Use passphrases for servers** - GitHub can be passphrase-free
4. **Monitor access logs** - Know which device accessed which server
5. **Revoke immediately** - On device loss, revoke only that device's keys
6. **Separate devices** - Don't share keys between devices even temporarily
7. **Backup encrypted secrets** - `.age` files are safe to backup anywhere

## Troubleshooting

### Secret Won't Decrypt

1. Check host key matches:
   ```bash
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub
   # Compare with secrets/secrets.nix
   ```

2. Verify secret is encrypted with correct keys:
   ```bash
   agenix-helper list
   # Check publicKeys list
   ```

3. Rekey the specific secret:
   ```bash
   agenix-helper edit <secret>.age
   # Save without changes to re-encrypt
   ```

### Wrong Key Being Used

Check SSH config:

```bash
cat ~/.ssh/config
# Verify IdentityFile points to correct per-device key
```

Check which key is being used:

```bash
ssh -v client-acme 2>&1 | grep "identity file"
```

## Future Enhancements

- **Automatic key rotation** - Rust tool to rotate keys on schedule
- **Audit logging** - Track which device accessed which secret when
- **Key expiry** - Secrets that auto-expire after N days
- **Hardware keys** - Yubikey support for high-security secrets
- **Remote attestation** - Verify device integrity before decrypting
