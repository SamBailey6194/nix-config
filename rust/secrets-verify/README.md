# secrets-verify

Rust-based tool to verify that agenix secrets are deployed correctly on NixOS systems.

## Features

- ✅ Verifies SSH keys exist and have correct permissions (0600)
- ✅ Checks SSH key format validity
- ✅ Tests GitHub SSH connections
- ✅ Fast compiled binary (no script overhead)
- ✅ Colored terminal output for clear status

## Usage

```bash
# Basic verification
secrets-verify

# Test GitHub SSH connections
secrets-verify --test-github

# Verbose output (shows all secrets)
secrets-verify --verbose

# Custom secrets directory
secrets-verify --secrets-dir /custom/path
```

## Expected Output

```
🔒 Agenix Secrets Verification

GitHub SSH Keys:
  ✅ github-personal (600)
  ✅ github-syntek (600)
  ✅ github-missionalgen (600)

Testing GitHub SSH Connections:
  Testing github-personal... ✅ Success
  Testing github-syntek... ✅ Success
  Testing github-missionalgen... ✅ Success

✅ All critical secrets verified successfully!
```

## Exit Codes

- `0`: All secrets verified successfully
- `1`: Some secrets missing or have incorrect permissions

## Integration

Add to `justfile` for easy access:

```justfile
# Verify secrets are deployed correctly
verify-secrets:
    secrets-verify --test-github
```
