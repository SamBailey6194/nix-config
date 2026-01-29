# Secrets Management with Agenix

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## Overview

This NixOS configuration implements a **zero-trust, per-device secrets model** using Agenix. Each device has unique credentials for every service, so device compromise only exposes secrets for that specific device.

**Key Features**:
- ✅ Per-device SSH keys for GitHub and servers
- ✅ Per-device secrets management (not shared across devices)
- ✅ Agenix encrypts secrets using SSH keys
- ✅ Secrets decrypted at boot time to `/run/agenix/`
- ✅ Automatic SSH config generation with per-device keys
- ✅ Rust CLI tools for safe secret management (`agenix-helper`)

**Architecture**:
```
Encrypted .age files (in git)
    ↓
Agenix decrypts at boot using host SSH key
    ↓
Decrypted secrets in /run/agenix/
    ↓
Symlinked to user home (~/.ssh/)
    ↓
Auto-configured SSH client
```

---

## Security Model

### Two-Tier Approach

#### 1. GitHub SSH Keys (NO Passphrases)

**Purpose**: Convenience for automated git operations

**Characteristics**:
- Per-device keys (unique per device)
- No passphrases (automatic git pull/push)
- Lower risk: GitHub has 2FA and key revocation
- Deployed to: `~/.ssh/github-<account>`

**Naming**: `github-ssh-<account>-<device>.age`

Examples:
- `github-ssh-personal-laptop-intel.age`
- `github-ssh-syntek-framework.age`

#### 2. Server/VPN SSH Keys (WITH Passphrases)

**Purpose**: High-security access to production servers

**Characteristics**:
- Per-device keys (unique per device)
- Strong passphrases (encrypted in agenix)
- Higher risk: Direct server access
- Deployed to: `~/.ssh/server-<name>-<device>-key`

**Naming**: `server-<name>-<device>-key.age` + `server-<name>-<device>-passphrase.age`

Examples:
- `server-acme-laptop-intel-key.age`
- `server-acme-laptop-intel-passphrase.age`
- `server-production-framework-key.age`

### Benefits

- ✅ **Zero-Trust**: Each device gets unique credentials
- ✅ **Blast Radius Containment**: Device loss/theft only exposes that device's keys
- ✅ **Independent Rotation**: Rotate keys per device without affecting others
- ✅ **Audit Trail**: Know which device accessed which server
- ✅ **Gradual Rollout**: Add devices incrementally without resharing all secrets

---

## Architecture

### Decryption Flow

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

### File Structure

```
secrets/
├── secrets.nix                              # Key authorization matrix
├── github-ssh-personal-laptop-intel.age     # Per-device GitHub key
├── github-ssh-personal-framework.age        # Per-device GitHub key
├── github-ssh-syntek-laptop-intel.age       # Per-device GitHub key
└── server-acme-laptop-intel-key.age         # Per-device server key

modules/core/
├── secrets-laptop.nix              # Laptop-specific secret declarations
├── secrets-desktop.nix             # Desktop-specific secret declarations
└── ssh-config.nix                  # Auto-generated SSH config (per-device keys)

rust/
├── secrets-verify/                 # Verify secrets deployed correctly
└── agenix-helper/                  # Helper CLI for managing secrets
```

---

## Quick Start

**Time**: 15-20 minutes

### Prerequisites

1. ✅ NixOS installed and booted on your device
2. ✅ This repo cloned to `/etc/nixos/nix-config`
3. ✅ You have GitHub accounts set up

### 5-Minute Setup

```bash
# 1. Get your host SSH key
sudo cat /etc/ssh/ssh_host_ed25519_key.pub

# 2. Update secrets/secrets.nix with the key (replace PLACEHOLDER)

# 3. Generate per-device GitHub SSH keys
cd /etc/nixos/nix-config
hostname  # Remember this output

# Generate keys (replace HOSTNAME with output from above)
ssh-keygen -t ed25519 -C "HOSTNAME@github-personal" -f /tmp/github-personal-HOSTNAME -N ""
ssh-keygen -t ed25519 -C "HOSTNAME@github-syntek" -f /tmp/github-syntek-HOSTNAME -N ""

# 4. Encrypt keys with agenix
nix develop
agenix-helper edit github-ssh-personal-HOSTNAME
# Paste private key from /tmp/github-personal-HOSTNAME

agenix-helper edit github-ssh-syntek-HOSTNAME
# Paste private key from /tmp/github-syntek-HOSTNAME

# 5. Add public keys to GitHub
# Go to https://github.com/settings/keys
# Add /tmp/github-personal-HOSTNAME.pub

# 6. Clean up
rm /tmp/github-personal-* /tmp/github-syntek-*

# 7. Rebuild system
sudo nixos-rebuild switch --flake .#HOSTNAME
```

---

## Setup Guide

### Step 1: Get Host SSH Key

After NixOS installation, your system has host SSH keys at `/etc/ssh/ssh_host_*`. We need the **ed25519 public key** for agenix.

```bash
# On your newly installed system
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

**Example output**:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBw... root@laptop-intel
```

Copy this entire line (including the key type and comment).

### Step 2: Update secrets/secrets.nix with Host Key

Edit `/etc/nixos/nix-config/secrets/secrets.nix`:

```nix
let
  # User keys
  sam-personal = "ssh-ed25519 AAAAC3... sam@personal";

  # Host keys (from /etc/ssh/ssh_host_ed25519_key.pub)
  laptop-intel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBw... root@laptop-intel";
  # Replace AAAAC3... with your actual key from Step 1

  allUsers = [ sam-personal ];
  allHosts = [ laptop-intel ];
  allKeys = allUsers ++ allHosts;
in
{ ... }
```

### Step 3: Generate Personal SSH Key (First Time Only)

This key is used to create and edit secrets from your personal machine:

```bash
# On your personal development machine (not the NixOS system)
ssh-keygen -t ed25519 -C "sam@personal" -f ~/.ssh/id_ed25519_agenix -N ""

# Get the public key
cat ~/.ssh/id_ed25519_agenix.pub
```

Copy the output and add to `secrets/secrets.nix`:

```nix
sam-personal = "ssh-ed25519 AAAAC3... sam@personal";
```

### Step 4: Generate Per-Device GitHub SSH Keys

**IMPORTANT**: Each device gets **unique** SSH keys for each GitHub account. This implements zero-trust security.

Get your current hostname first:

```bash
hostname
# Example output: laptop-intel
```

Generate **per-device** keys:

```bash
HOSTNAME=$(hostname)

# Personal GitHub account (SamBailey6194)
ssh-keygen -t ed25519 -C "$HOSTNAME@github-personal" -f /tmp/github-personal-$HOSTNAME -N ""

# Syntek GitHub account (syntek-studio)
ssh-keygen -t ed25519 -C "$HOSTNAME@github-syntek" -f /tmp/github-syntek-$HOSTNAME -N ""

# Missional Gen GitHub account (sam-missionalgen)
ssh-keygen -t ed25519 -C "$HOSTNAME@github-missionalgen" -f /tmp/github-missionalgen-$HOSTNAME -N ""
```

This creates 6 files in `/tmp/`:
- `github-personal-$HOSTNAME`, `github-personal-$HOSTNAME.pub`
- `github-syntek-$HOSTNAME`, `github-syntek-$HOSTNAME.pub`
- `github-missionalgen-$HOSTNAME`, `github-missionalgen-$HOSTNAME.pub`

**Why per-device keys?**
- Device loss only exposes keys for THAT device
- Independent key rotation per device
- Audit trail: know which device accessed GitHub

### Step 5: Encrypt Keys with Agenix

Enter the dev shell:

```bash
cd /etc/nixos/nix-config
nix develop
```

This auto-builds the Rust tools: `secrets-verify`, `agenix-helper`, etc.

Encrypt each **per-device** private key:

```bash
HOSTNAME=$(hostname)

# Encrypt personal GitHub SSH key
agenix-helper edit github-ssh-personal-$HOSTNAME
# Paste contents of /tmp/github-personal-$HOSTNAME (private key)
# Save and exit (Ctrl+D in nano)

# Encrypt syntek GitHub SSH key
agenix-helper edit github-ssh-syntek-$HOSTNAME
# Paste contents of /tmp/github-syntek-$HOSTNAME (private key)
# Save and exit

# Encrypt missionalgen GitHub SSH key
agenix-helper edit github-ssh-missionalgen-$HOSTNAME
# Paste contents of /tmp/github-missionalgen-$HOSTNAME (private key)
# Save and exit
```

**What agenix does**:
1. Looks up `secrets/secrets.nix` to find which keys can decrypt this secret
2. Opens your `$EDITOR` (vim/nano) to enter the secret
3. Encrypts the file with all authorized public keys
4. Saves as `.age` file in `secrets/`

**Note**: The `.age` files are safe to commit to git - they're encrypted!

### Step 6: Add Public Keys to GitHub

Add the **public keys** (`.pub` files) to your GitHub accounts:

#### Personal Account (SamBailey6194)

1. Go to: https://github.com/settings/keys
2. Click "New SSH key"
3. Title: `laptop-intel` (or current hostname)
4. Key: Paste contents of `/tmp/github-personal-$HOSTNAME.pub`
5. Click "Add SSH key"

#### Syntek Account (syntek-studio)

1. Switch to syntek-studio account
2. Go to: https://github.com/settings/keys
3. Click "New SSH key"
4. Title: `laptop-intel` (or current hostname)
5. Key: Paste contents of `/tmp/github-syntek-$HOSTNAME.pub`
6. Click "Add SSH key"

#### Missional Gen Account (sam-missionalgen)

1. Switch to sam-missionalgen account
2. Go to: https://github.com/settings/keys
3. Click "New SSH key"
4. Title: `laptop-intel` (or current hostname)
5. Key: Paste contents of `/tmp/github-missionalgen-$HOSTNAME.pub`
6. Click "Add SSH key"

### Step 7: Update secrets/secrets.nix with New Secrets

Edit `secrets/secrets.nix` and add entries for your new encrypted secrets:

```nix
{
  # GitHub SSH Keys (Per-Device, NO Passphrases)
  "github-ssh-personal-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "github-ssh-syntek-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "github-ssh-missionalgen-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
}
```

### Step 8: Clean Up Temporary Files

```bash
# Delete unencrypted private keys from /tmp
rm /tmp/github-personal-$HOSTNAME
rm /tmp/github-syntek-$HOSTNAME
rm /tmp/github-missionalgen-$HOSTNAME
```

### Step 9: Rebuild System

```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

Agenix will:
1. Decrypt secrets using host SSH key
2. Place decrypted files in `/run/agenix/`
3. Create symlinks in `~/.ssh/`
4. Configure SSH client with per-device keys

### Step 10: Verify Secrets Deployed

```bash
# Enter dev shell for Rust tools
nix develop

# Verify secrets
secrets-verify

# Test GitHub SSH connection
secrets-verify --test-github
```

---

## Naming Conventions

### GitHub Keys (No Passphrases)

```
github-ssh-<account>-<device>.age

Examples:
- github-ssh-personal-laptop-intel.age
- github-ssh-syntek-framework.age
- github-ssh-missionalgen-devtower.age
```

Deployed to: `~/.ssh/github-<account>`

### Server Keys (With Passphrases)

```
server-<name>-<device>-key.age         (private key)
server-<name>-<device>-passphrase.age  (passphrase)

Examples:
- server-acme-laptop-intel-key.age
- server-acme-laptop-intel-passphrase.age
- server-staging-framework-key.age
- server-production-devtower-key.age
```

Deployed to:
- Private key: `~/.ssh/server-<name>-<device>-key`
- Passphrase: `/run/agenix/server-<name>-<device>-passphrase`

---

## Examples

### Example: secrets/secrets.nix

```nix
let
  # User keys
  sam-personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... sam@personal";

  # Host keys (from /etc/ssh/ssh_host_ed25519_key.pub)
  laptop-intel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... root@laptop-intel";
  framework = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... root@framework";
  devtower = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... root@devtower";

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

  # Client ACME server
  "server-acme-laptop-intel-key.age".publicKeys = allUsers ++ [ laptop-intel ];
  "server-acme-laptop-intel-passphrase.age".publicKeys = allUsers ++ [ laptop-intel ];

  "server-acme-framework-key.age".publicKeys = allUsers ++ [ framework ];
  "server-acme-framework-passphrase.age".publicKeys = allUsers ++ [ framework ];

  "server-acme-devtower-key.age".publicKeys = allUsers ++ [ devtower ];
  "server-acme-devtower-passphrase.age".publicKeys = allUsers ++ [ devtower ];
}
```

### Example: Secrets Module (modules/core/secrets-laptop.nix)

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

---

## Troubleshooting

### "Permission denied" When Editing Secrets

**Problem**: `agenix-helper edit` fails with permission error

**Solution**:
```bash
# Make sure secrets/secrets.nix has your key
cat secrets/secrets.nix | grep sam-personal

# Check your personal SSH key exists
ls ~/.ssh/id_ed25519_agenix*

# Try again
agenix-helper edit github-ssh-personal-laptop-intel
```

### Secrets Not Decrypted After Boot

**Problem**: Files don't appear in `~/.ssh/`

**Solution**:
```bash
# Check agenix module is imported
grep agenix hosts/laptop-intel/configuration.nix

# Check system log
journalctl -b | grep -i agenix

# Verify host key is correct in secrets/secrets.nix
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
# Compare with secrets/secrets.nix entry

# Force rebuild
sudo nixos-rebuild switch --flake .#laptop-intel
```

### "Decryption Failed" Error

**Problem**: Agenix can't decrypt secrets

**Solution**:
```bash
# Check host SSH key matches
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
# Should match the key in secrets/secrets.nix

# If keys don't match:
# 1. Update secrets/secrets.nix with correct key
# 2. Reencrypt all secrets: agenix-helper rekey
# 3. Rebuild: sudo nixos-rebuild switch
```

### Git Push Fails with "Permission denied"

**Problem**: Can't push to GitHub with SSH

**Solution**:
```bash
# Verify SSH key is deployed
ls -la ~/.ssh/github-personal

# Test SSH connection
ssh -i ~/.ssh/github-personal -T git@github.com

# Check SSH config
cat ~/.ssh/config | grep -A 5 github-personal

# Verify public key is added to GitHub
curl https://api.github.com/user/keys | jq
```

---

## Reference

### Rust Tools

```bash
# Enter dev shell (builds tools automatically)
nix develop

# Available tools:
secrets-verify                # Verify secrets deployed correctly
secrets-verify --test-github  # Test GitHub SSH connections

agenix-helper edit <secret>   # Edit encrypted secret
agenix-helper list            # List all secrets
agenix-helper rekey           # Rekey all secrets
agenix-helper check-keys      # Verify host keys
```

### File Locations

| Path | Purpose |
|------|---------|
| `secrets/secrets.nix` | Key authorization matrix |
| `secrets/*.age` | Encrypted secrets (safe in git) |
| `/etc/ssh/ssh_host_ed25519_key.pub` | Host public key |
| `/run/agenix/` | Decrypted secrets at boot |
| `~/.ssh/github-*` | Symlinked SSH keys |
| `~/.ssh/config` | Auto-generated SSH config |

### Common Commands

```bash
# Create/edit a secret
agenix -e secrets/github-ssh-personal-laptop-intel.age

# View encryption status
agenix list

# Rekey after adding a new host
agenix rekey

# Verify deployment
secrets-verify
```

### SSH Config Auto-Generation

SSH config is automatically generated at `/home/user/.ssh/config` with entries like:

```
Host github-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/github-personal
  IdentitiesOnly yes

Host github-syntek
  HostName github.com
  User git
  IdentityFile ~/.ssh/github-syntek
  IdentitiesOnly yes
```

---

## Next Steps

1. **Complete Setup**: Follow the 10-step setup guide above
2. **Test Connection**: Run `secrets-verify --test-github`
3. **Add More Secrets**: Follow same process for server keys
4. **Multi-Device**: Repeat for framework, devtower with device-specific keys
5. **Rotate Keys** (annual): Generate new keys, update GitHub, reencrypt

For detailed architecture, see the previous sections or `secrets/secrets.nix` comments.
