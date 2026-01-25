# Phase 2: Secrets Management with Agenix + Rust Tooling

## Overview

Agenix encrypts secrets using SSH keys and decrypts them at NixOS boot time. Secrets are stored in git as `.age` files and decrypted to `/run/agenix/` at boot.

**NEW in Phase 2:**
- ✅ **Per-Device Secrets**: Each device has unique SSH keys for all services
- ✅ **Rust Tooling**: Fast, type-safe CLI tools (`secrets-verify`, `agenix-helper`)
- ✅ **Auto-Generated SSH Config**: Per-device keys automatically configured
- ✅ **Two-Tier Security**: GitHub keys (no passphrase) + Server keys (with passphrase)

## Architecture

```
secrets/
├── secrets.nix                              # Defines which keys decrypt which secrets
├── PER-DEVICE-SECRETS.md                    # Comprehensive per-device guide
├── github-ssh-personal-laptop-intel.age     # Per-device GitHub key (laptop)
├── github-ssh-personal-framework.age        # Per-device GitHub key (framework)
├── github-ssh-syntek-laptop-intel.age       # Per-device Syntek key (laptop)
└── server-acme-laptop-intel-key.age         # Per-device server key (example)

modules/core/
├── secrets-laptop.nix              # Laptop-specific secret declarations
├── secrets-desktop.nix             # Desktop-specific secret declarations
└── ssh-config.nix                  # Auto-generated SSH config (per-device keys)

rust/
├── secrets-verify/                 # Verify secrets deployed correctly
└── agenix-helper/                  # Helper CLI for managing secrets
```

Decrypted secrets land in user home directories with **device-specific** names:
- `~/.ssh/github-personal` (mode 0600, unique per device)
- `~/.ssh/github-syntek` (mode 0600, unique per device)
- `~/.ssh/github-missionalgen` (mode 0600, unique per device)

## Prerequisites

1. **NixOS installed and booted** on laptop-intel
2. **This repo cloned** to `/etc/nixos/nix-config` or `~/.config/nix-config`
3. **Agenix CLI available** (already in flake devShell)

## Step 1: Generate Host SSH Keys

After NixOS installation, each host has SSH host keys at `/etc/ssh/ssh_host_*`. We need the **ed25519 public key** for agenix.

```bash
# On laptop-intel (after installation)
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

**Example output:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBw... root@laptop-intel
```

Copy this entire line.

## Step 2: Update secrets/secrets.nix

Edit `secrets/secrets.nix` and replace the placeholder host keys:

```nix
# Replace this placeholder:
laptop-intel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEPLOY_LAPTOP_HOST_KEY_HERE root@laptop-intel";

# With your actual key:
laptop-intel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBw... root@laptop-intel";
```

Do the same for your **personal user SSH key** (used to create/edit secrets):

```bash
# Generate a personal key if you don't have one
ssh-keygen -t ed25519 -C "sam@personal" -f ~/.ssh/id_ed25519_agenix

# Get the public key
cat ~/.ssh/id_ed25519_agenix.pub
```

Update the `sam-personal` key in `secrets/secrets.nix`:

```nix
sam-personal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... sam@personal";
```

## Step 3: Generate Per-Device GitHub SSH Keys

**IMPORTANT**: Each device gets **unique** SSH keys for each GitHub account. This implements zero-trust security.

Get your current hostname first:

```bash
hostname
# Example output: laptop-intel
```

Now generate keys **specific to this device**:

```bash
# Personal GitHub account (SamBailey6194)
ssh-keygen -t ed25519 -C "laptop-intel@github-personal" -f /tmp/github-personal-laptop-intel -N ""

# Syntek GitHub account (syntek-studio)
ssh-keygen -t ed25519 -C "laptop-intel@github-syntek" -f /tmp/github-syntek-laptop-intel -N ""

# Missional Gen GitHub account (sam-missionalgen)
ssh-keygen -t ed25519 -C "laptop-intel@github-missionalgen" -f /tmp/github-missionalgen-laptop-intel -N ""
```

**Replace `laptop-intel` with your actual hostname** (e.g., `framework`, `devtower`).

This creates 6 files in `/tmp/`:
- `github-personal-laptop-intel`, `github-personal-laptop-intel.pub`
- `github-syntek-laptop-intel`, `github-syntek-laptop-intel.pub`
- `github-missionalgen-laptop-intel`, `github-missionalgen-laptop-intel.pub`

**Why per-device keys?**
- Device loss only exposes keys for THAT device
- Independent key rotation per device
- Audit trail: know which device accessed GitHub

## Step 4: Encrypt Per-Device Secrets with Agenix

Enter the dev shell to get agenix CLI and Rust tools:

```bash
cd /home/sam-dev/Repos/personal/nix-config
nix develop
# This will auto-build Rust tools (secrets-verify, agenix-helper)
```

Now encrypt each **per-device** private key using the Rust helper:

```bash
# Get your hostname
HOSTNAME=$(hostname)

# Encrypt personal GitHub SSH key (per-device)
agenix-helper edit github-ssh-personal-${HOSTNAME}
# Paste contents of /tmp/github-personal-${HOSTNAME} (private key), save and exit

# Encrypt syntek GitHub SSH key (per-device)
agenix-helper edit github-ssh-syntek-${HOSTNAME}
# Paste contents of /tmp/github-syntek-${HOSTNAME} (private key), save and exit

# Encrypt missionalgen GitHub SSH key (per-device)
agenix-helper edit github-ssh-missionalgen-${HOSTNAME}
# Paste contents of /tmp/github-missionalgen-${HOSTNAME} (private key), save and exit
```

**Alternatively, use raw agenix:**

```bash
agenix -e secrets/github-ssh-personal-laptop-intel.age
# Replace laptop-intel with your hostname
```

**Agenix will:**
1. Look up `secrets/secrets.nix` to find which keys can decrypt this secret
2. Open your `$EDITOR` (vim/nano) to enter the secret
3. Encrypt the file with all authorized public keys
4. Save as `.age` file

**Note**: Each device has its own encrypted secret file. On `framework`, you'd create:
- `github-ssh-personal-framework.age`
- `github-ssh-syntek-framework.age`
- etc.

## Step 5: Add Public Keys to GitHub

Add the **public keys** (`.pub` files) to your GitHub accounts:

### Personal Account (SamBailey6194)
1. Go to: https://github.com/settings/keys
2. Click "New SSH key"
3. Title: `laptop-intel` (or current hostname)
4. Key: Paste contents of `/tmp/github-personal.pub`
5. Click "Add SSH key"

### Syntek Account (syntek-studio)
1. Switch to syntek-studio account
2. Go to: https://github.com/settings/keys
3. Add `/tmp/github-syntek.pub`

### Missional Gen Account (sam-missionalgen)
1. Switch to sam-missionalgen account
2. Go to: https://github.com/settings/keys
3. Add `/tmp/github-missionalgen.pub`

## Step 6: Clean Up Temporary Files

```bash
# Delete unencrypted private keys from /tmp
rm /tmp/github-personal /tmp/github-personal.pub
rm /tmp/github-syntek /tmp/github-syntek.pub
rm /tmp/github-missionalgen /tmp/github-missionalgen.pub
```

## Step 7: Rebuild NixOS

```bash
sudo nixos-rebuild switch --flake /etc/nixos/nix-config#laptop-intel
```

**What happens:**
1. Agenix module reads `secrets/secrets.nix`
2. Decrypts `.age` files using host SSH key at `/etc/ssh/ssh_host_ed25519_key`
3. Writes decrypted secrets to `/run/agenix/`
4. Creates symlinks to user home directories with correct ownership and permissions

## Step 8: Verify Secrets Deployed (Using Rust Tool)

Use the built-in Rust verification tool:

```bash
# Enter dev shell (if not already)
nix develop

# Verify all secrets
secrets-verify

# Expected output:
# 🔒 Agenix Secrets Verification
#
# GitHub SSH Keys:
#   ✅ github-personal (600)
#   ✅ github-syntek (600)
#   ✅ github-missionalgen (600)
#
# ✅ All critical secrets verified successfully!
```

**Or manually check:**

```bash
# Check secrets are decrypted and in place
ls -la ~/.ssh/github-*

# Expected output:
# -rw------- 1 sam-laptop users 411 Jan 24 12:00 /home/sam-laptop/.ssh/github-personal
# -rw------- 1 sam-laptop users 411 Jan 24 12:00 /home/sam-laptop/.ssh/github-syntek
# -rw------- 1 sam-laptop users 411 Jan 24 12:00 /home/sam-laptop/.ssh/github-missionalgen

# Verify SSH key format
head -n1 ~/.ssh/github-personal
# Should show: -----BEGIN OPENSSH PRIVATE KEY-----
```

## Step 9: Test Multi-Account Git

Your git config uses conditional includes based on directory:

```bash
# Test personal account
cd ~/Repos/personal/
git config user.email
# Should show: sam.bailey@sambailey.dev

# Test Syntek account
cd ~/Repos/syntek/
git config user.email
# Should show: sam@syntek.studio

# Test Missional Gen account
cd ~/Repos/missional-gen/
git config user.email
# Should show: sam.bailey@missionalgen.org
```

## Step 10: Test SSH to GitHub (Using Rust Tool)

Use the built-in Rust verification tool to test all connections:

```bash
# Test all GitHub SSH connections
secrets-verify --test-github

# Expected output:
# 🔒 Agenix Secrets Verification
#
# GitHub SSH Keys:
#   ✅ github-personal (600)
#   ✅ github-syntek (600)
#   ✅ github-missionalgen (600)
#
# Testing GitHub SSH Connections:
#   Testing github-personal... ✅ Success
#   Testing github-syntek... ✅ Success
#   Testing github-missionalgen... ✅ Success
#
# ✅ All critical secrets verified successfully!
```

**Or manually test:**

```bash
# Test personal account SSH
ssh -T git@github-personal
# Should show: Hi SamBailey6194! You've successfully authenticated...

# Test Syntek account SSH
ssh -T git@github-syntek
# Should show: Hi syntek-studio! You've successfully authenticated...

# Test Missional Gen account SSH
ssh -T git@github-missionalgen
# Should show: Hi sam-missionalgen! You've successfully authenticated...
```

## Commit Encrypted Secrets

Encrypted `.age` files are SAFE to commit to git:

```bash
git add secrets/*.age
git add secrets/secrets.nix
git add modules/core/secrets-*.nix
git commit -m "feat(secrets): Add agenix encrypted GitHub SSH keys"
git push
```

## Rust Tooling Reference

### secrets-verify

Verify secrets are deployed correctly:

```bash
secrets-verify                  # Basic verification
secrets-verify --test-github    # Test GitHub connections
secrets-verify --verbose        # Show all secrets
```

### agenix-helper

Manage agenix secrets:

```bash
# Edit a secret
agenix-helper edit github-ssh-personal-laptop-intel

# List all secrets
agenix-helper list
agenix-helper list --verbose

# Rekey all secrets (after adding new host keys)
agenix-helper rekey

# Add a new server with per-device SSH keys
agenix-helper add-server client-acme

# Initialize secrets for a new device
agenix-helper init framework

# Check host keys match secrets.nix
agenix-helper check-keys
```

See `rust/agenix-helper/README.md` for full documentation.

## Future: Adding New Secrets

### Shared Secrets (All Devices)

To add a shared secret (e.g., WiFi passwords):

1. **Add to secrets.nix:**
   ```nix
   "wifi-passwords.age".publicKeys = allKeys;
   ```

2. **Encrypt the secret:**
   ```bash
   nix develop
   agenix-helper edit wifi-passwords
   # Enter password, save, exit
   ```

3. **Declare in host config:**
   ```nix
   age.secrets.wifi-passwords = {
     file = ../../secrets/wifi-passwords.age;
     path = "/etc/NetworkManager/system-connections/wifi.nmconnection";
     owner = "root";
     group = "root";
     mode = "0600";
   };
   ```

4. **Rebuild:**
   ```bash
   sudo nixos-rebuild switch --flake ~/.config/nix-config#laptop-intel
   ```

### Per-Device Secrets (Server SSH Keys)

To add a new server with per-device SSH keys:

1. **Generate keys:**
   ```bash
   nix develop
   agenix-helper add-server client-acme
   # Generates per-device keys WITH passphrases
   # Outputs public keys to add to server
   ```

2. **Add public keys to server:**
   ```bash
   ssh root@acme.example.com
   # Add public keys to ~/.ssh/authorized_keys
   ```

3. **Uncomment entries in secrets.nix** and rekey:
   ```bash
   agenix-helper rekey
   ```

4. **Update secrets module** and rebuild

See `secrets/PER-DEVICE-SECRETS.md` for complete workflows.

## Troubleshooting

### "agenix: command not found"
Run `nix develop` first to enter the dev shell.

### "age-plugin-yubikey: No such file or directory"
Ignore this warning - we're using SSH keys, not Yubikey.

### Secrets not decrypting
1. Check host key is correct: `sudo cat /etc/ssh/ssh_host_ed25519_key.pub`
2. Verify it matches `secrets/secrets.nix`
3. Re-encrypt secrets: `agenix -r` (rekeys all secrets)

### Permission denied on decrypted secrets
Check ownership/mode in secrets module:
```nix
owner = "sam-laptop";  # Must match actual username
mode = "0600";         # Must be restrictive for SSH keys
```

## Security Notes

- ✅ **SAFE to commit:** `*.age` files (encrypted)
- ❌ **NEVER commit:** `*.key`, `*.pem`, decrypted files
- ✅ Encrypted secrets are useless without host SSH private key
- ✅ Host SSH private key never leaves the machine (`/etc/ssh/ssh_host_ed25519_key`)
- ✅ Personal SSH key should be in password-protected KeePassXC or hardware key

## Per-Device Security Benefits

✅ **Zero-Trust Architecture**: Each device has unique credentials
✅ **Blast Radius Containment**: Device loss only exposes that device's keys
✅ **Independent Key Rotation**: Rotate keys per device without affecting others
✅ **Audit Trail**: Know which device accessed which service
✅ **Gradual Rollout**: Add devices incrementally without resharing all secrets

## Key Documentation

- `secrets/PER-DEVICE-SECRETS.md` - Comprehensive per-device architecture guide
- `rust/secrets-verify/README.md` - Secrets verification tool docs
- `rust/agenix-helper/README.md` - Agenix helper CLI docs
- `modules/core/ssh-config.nix` - Auto-generated SSH config module

## Next Phase

**Phase 3**: Multi-Device Sync
- Install NixOS on framework and devtower
- Extract their host keys with `agenix-helper check-keys`
- Update `secrets/secrets.nix` with new host keys
- Generate per-device GitHub keys for each new device
- Re-encrypt secrets to include new hosts: `agenix-helper rekey`
- Secrets now decrypt on all devices (each with unique keys!)
