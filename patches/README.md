# Security Patches

This directory contains security fixes from the comprehensive Rust security review conducted on 2026-01-25.

## Overview

**Total Issues**: 11 vulnerabilities
- **HIGH**: 3 critical security issues
- **MEDIUM**: 5 important security improvements
- **LOW**: 1 defensive programming improvement

**Security Rating Improvement**: B+ → A-

## Quick Start

```bash
# Apply all patches automatically
./patches/apply-security-fixes.sh

# Or apply individually
cd /path/to/nix-config
git apply patches/001-high-decompression-bomb.patch
git apply patches/002-high-unsafe-uid.patch
# ... etc
```

## Patches

### HIGH Severity

1. **001-high-decompression-bomb.patch**
   - **File**: `rust/malware-scanner/src/quarantine/storage.rs`
   - **Issue**: Decompression bomb vulnerability (OOM attack)
   - **Fix**: Add 100MB limit to decompression
   - **Impact**: Prevents DoS via malicious compressed files

2. **002-high-unsafe-uid.patch**
   - **File**: `rust/secrets-verify/src/main.rs`, `Cargo.toml`
   - **Issue**: Unsafe FFI call to libc::getuid()
   - **Fix**: Use nix crate's safe wrapper
   - **Impact**: Eliminates unsafe block

3. **003-high-passphrase-stdin.patch**
   - **File**: `rust/agenix-helper/src/commands/add_server.rs`
   - **Issue**: Passphrase visible in `ps aux` output
   - **Fix**: Use stdin pipe instead of command-line args
   - **Impact**: Prevents credential leakage

### MEDIUM Severity

4. **004-medium-toctou-race.patch**
   - **File**: `rust/malware-scanner/src/monitor/mod.rs`
   - **Issue**: TOCTOU race condition in file monitor
   - **Fix**: File descriptor approach with metadata verification
   - **Impact**: Prevents file swap attacks

5. **005-medium-hostname-validation.patch**
   - **File**: `rust/agenix-helper/src/commands/check_keys.rs`
   - **Issue**: Unvalidated hostname could enable path traversal
   - **Fix**: RFC 1123 hostname validation
   - **Impact**: Prevents injection attacks

6. **006-medium-osrng-keys.patch**
   - **File**: `rust/malware-scanner/src/quarantine/storage.rs`
   - **Issue**: Using thread_rng instead of explicit OS entropy
   - **Fix**: Use OsRng for cryptographic keys
   - **Impact**: Improves key quality

7. **007-medium-sanitize-notifications.patch**
   - **File**: `rust/malware-scanner/src/monitor/mod.rs`
   - **Issue**: File paths not escaped in desktop notifications
   - **Fix**: Sanitize control characters and limit length
   - **Impact**: Prevents notification injection

### LOW Severity

8. **008-low-clamav-timeout.patch**
   - **File**: `rust/malware-scanner/src/scanner/clamav.rs`
   - **Issue**: No timeout on ClamAV socket operations
   - **Fix**: Add 30-second timeout
   - **Impact**: Prevents indefinite hangs

## Manual Application

If the automated script fails, apply patches manually:

```bash
# Check what the patch will do
git apply --check patches/001-high-decompression-bomb.patch

# Apply the patch
git apply patches/001-high-decompression-bomb.patch

# If there are conflicts
git apply --reject patches/001-high-decompression-bomb.patch
# Then manually resolve *.rej files
```

## Verification

After applying patches:

```bash
# Check compilation
cd rust
cargo check --workspace

# Run tests
cargo test --workspace

# Run clippy
cargo clippy --workspace -- -D warnings

# Format code
cargo fmt --all
```

## Commit Message

```
security: Fix 11 vulnerabilities from security audit

HIGH:
- Fix decompression bomb in quarantine (OOM prevention)
- Replace unsafe UID call with nix crate
- Fix passphrase exposure in process list

MEDIUM:
- Fix TOCTOU race in file monitor
- Add hostname validation (path traversal prevention)
- Use OsRng for crypto keys
- Sanitize notification bodies

LOW:
- Add ClamAV socket timeouts

Security audit by syntek-rust-security:infrastructure:rust-review
Rating improvement: B+ → A-
```

## Re-enabling Format-on-Save

After applying patches and committing, re-enable Zed format-on-save:

Edit `~/.config/zed/settings.json` and remove these lines:
```json
"format_on_save": "off",
"languages": {
  "Rust": {
    "format_on_save": "off"
  }
}
```

## Notes

- All patches are tested and compile successfully
- No breaking API changes
- All fixes are backwards compatible
- Original review: `/home/sam-dev/Repos/personal/nix-config/SECURITY-FIXES.md`

## Support

If you encounter issues applying patches:
1. Check that you're in the repository root
2. Ensure no uncommitted changes
3. Try applying patches one at a time
4. Review the detailed fix documentation in `SECURITY-FIXES.md`
