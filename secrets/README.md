# Secrets Management

**Last Updated**: 06/10/2026
**Version**: 0.8.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
This directory contains encrypted secrets managed by [agenix](https://github.com/ryantm/agenix).
Secrets are per device: each file is named `<secret>-<host>.age` and is encrypted
only to the keys listed for it in `secrets.nix`.

## Quick Reference

```bash
# Enter dev shell (provides agenix and agenix-helper)
nix develop

# Create/edit a secret (uses ~/.ssh/id_ed25519_agenix)
just edit-secret github-ssh-personal-laptop-intel

# Re-encrypt all secrets (after adding a host key to secrets.nix)
just rekey-secrets

# List all secrets and their recipients
just list-secrets
```

## Files

- `secrets.nix` - Defines which SSH keys can decrypt which secrets
- `*.age` - Encrypted secret files (SAFE to commit to git)

## Important

✅ **SAFE to commit:** `*.age` files (encrypted)
❌ **NEVER commit:** `*.key`, `*.pem`, private keys, decrypted files

Decrypted secrets are placed at activation by NixOS into:
- `/run/agenix/<secret-name>` (e.g. `claude-secrets`, `aws-config`)
- Per-device GitHub keys at `~/.ssh/github-<host>-<account>`

The host modules that declare them are `modules/core/secrets-laptop.nix`,
`modules/core/secrets-desktop.nix` and `hosts/devtower-intel/secrets.nix`.
See [docs/SECRETS.md](../docs/SECRETS.md) for the full procedure, and
[docs/INSTALL-INTEL-MANUALLY.md](../docs/INSTALL-INTEL-MANUALLY.md) section 8 for
enabling a newly installed host.
