# agenix-helper

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
Rust-based CLI helper for managing agenix secrets in NixOS configurations.

## Features

- 🔐 Edit encrypted secrets with automatic validation
- 🔄 Rekey all secrets after adding new hosts
- 📋 List all secrets and their authorized keys
- 🖥️ Generate per-device SSH keys for servers (WITH passphrases)
- 🚀 Initialize secrets for new devices
- ✅ Verify host keys match secrets.nix

## Commands

### Edit a Secret

```bash
# Edit an existing secret
agenix-helper edit github-ssh-personal.age

# .age extension is optional
agenix-helper edit github-ssh-personal
```

### Rekey All Secrets

After adding a new host key to `secrets/secrets.nix`, rekey all secrets:

```bash
agenix-helper rekey
```

### List All Secrets

```bash
# List all encrypted secrets
agenix-helper list

# Show verbose output with public keys
agenix-helper list --verbose
```

### Add Server with Per-Device Keys

Generate unique SSH keys for each device to access a server:

```bash
# Generate keys for all devices (default)
agenix-helper add-server client-acme

# Generate keys for specific devices only
agenix-helper add-server client-acme --devices laptop-intel,framework
```

This creates:
- Per-device SSH key pairs (WITH passphrases for security)
- Encrypted private keys: `server-acme-{device}-key.age`
- Encrypted passphrases: `server-acme-{device}-passphrase.age`
- Outputs public keys to add to server's `authorized_keys`

### Initialize New Device

Get instructions for setting up secrets on a new device:

```bash
agenix-helper init laptop-intel
```

### Check Host Keys

Verify current system's host key:

```bash
agenix-helper check-keys
```

## Per-Device Security Model

### GitHub SSH Keys (NO Passphrases)

Each device gets its own GitHub SSH key for convenience:

```bash
# Keys are automatically deployed by agenix
~/.ssh/github-personal  (device-specific, no passphrase)
~/.ssh/github-syntek    (device-specific, no passphrase)
~/.ssh/github-missionalgen  (device-specific, no passphrase)
```

**Benefits:**
- Git push/pull works without passphrase prompts
- Device compromise only exposes keys for THAT device
- Independent key rotation per device

### Server SSH Keys (WITH Passphrases)

Server keys have strong passphrases for security:

```bash
# Generate keys for a client server
agenix-helper add-server client-acme

# Deploys to:
~/.ssh/client-acme-laptop-intel-key  (WITH passphrase)
~/.ssh/client-acme-framework-key     (WITH passphrase)
~/.ssh/client-acme-devtower-key      (WITH passphrase)
```

**Benefits:**
- Higher security for production server access
- Each device has unique credentials
- Passphrase stored encrypted in agenix
- Device loss doesn't compromise other devices

## Workflow Example

### Adding a New Client Server

```bash
# 1. Generate per-device SSH keys
agenix-helper add-server client-acme

# 2. Add public keys to server
# (Output shows keys to add to server:/root/.ssh/authorized_keys)

# 3. Uncomment entries in secrets/secrets.nix
# "server-acme-laptop-intel-key.age".publicKeys = allUsers ++ [ laptop-intel ];
# ...

# 4. Rekey secrets
agenix-helper rekey

# 5. Update secrets module to deploy keys
# Edit modules/core/secrets-laptop.nix

# 6. Rebuild
sudo nixos-rebuild switch
```

### Adding a New Device

```bash
# 1. Install NixOS on new device

# 2. Get host key
agenix-helper check-keys

# 3. Add key to secrets/secrets.nix

# 4. Rekey all secrets
agenix-helper rekey

# 5. Rebuild on new device
sudo nixos-rebuild switch --flake .#new-device
```

## Integration

Add to `justfile`:

```justfile
# Edit a secret
edit-secret SECRET:
    agenix-helper edit {{SECRET}}

# Rekey all secrets
rekey-secrets:
    agenix-helper rekey

# List all secrets
list-secrets:
    agenix-helper list --verbose
```
