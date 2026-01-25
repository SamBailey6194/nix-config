# Secrets Management

This directory contains encrypted secrets managed by [agenix](https://github.com/ryantm/agenix).

## Quick Reference

```bash
# Enter dev shell (provides agenix CLI)
nix develop

# Create/edit a secret
agenix -e secrets/github-ssh-personal.age

# Rekey all secrets (after adding new host keys to secrets.nix)
agenix -r

# List all secrets
ls -la secrets/*.age
```

## Files

- `secrets.nix` - Defines which SSH keys can decrypt which secrets
- `*.age` - Encrypted secret files (SAFE to commit to git)

## Important

✅ **SAFE to commit:** `*.age` files (encrypted)
❌ **NEVER commit:** `*.key`, `*.pem`, decrypted files

Decrypted secrets are automatically placed at boot by NixOS into:
- `/run/agenix/<secret-name>` (root owned, symlinked to final destination)
- User home directories (e.g., `~/.ssh/github-personal`)

See `PHASE-2-SECRETS-SETUP.md` in the repo root for full setup instructions.
