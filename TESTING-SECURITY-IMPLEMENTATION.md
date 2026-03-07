# Testing the Security Implementation

**Date**: 2026-02-03
**Status**: Ready for Testing
**Estimated Test Time**: 30-60 minutes

---

## Quick Start

### 1. Enter Development Shell

```bash
cd ~/Repos/personal/nix-config
nix develop
```

This will:
- Build all Rust tools automatically
- Add them to your PATH
- Provide all required dependencies

### 2. Verify Tools Are Available

```bash
# Check Rust CLIs are built
luks-manage --help
btrfs-manage --help
vault-manage --help
tpm-manage --help

# Check NixOS modules exist
ls modules/security/
ls modules/filesystem/
```

### 3. Review Documentation

```bash
# Main encryption guide (1000+ lines)
less docs/ENCRYPTION-GUIDE.md

# Implementation summary
less SECURITY-IMPLEMENTATION-SUMMARY.md
```

---

## Testing Without Installation

You can test most functionality without installing NixOS:

### Test 1: Vault Management (No Root Required)

```bash
# Create test vault
vault-manage create test-vault

# Mount it (will prompt for password)
vault-manage mount test-vault

# Write test file
echo "Secret data" > ~/mnt/test-vault/secret.txt

# List vaults
vault-manage list

# Show mounted vaults
vault-manage status

# Unmount
vault-manage unmount test-vault

# Verify encryption (should see encrypted gibberish)
cat ~/vaults/test-vault/gocryptfs.diriv
```

### Test 2: Justfile Commands

```bash
# List all available tasks
just --list

# Test individual commands (note: some require root)
just list-vaults
just vault-status

# LUKS commands (will fail without LUKS devices)
just luks-status
```

### Test 3: Rust Tool Help Output

```bash
# View all subcommands
luks-manage --help
btrfs-manage --help
vault-manage --help
tpm-manage --help
```

---

## Testing With Root (Post-Installation)

After NixOS is installed with LUKS:

### Test 4: LUKS Management

```bash
# Show LUKS device status
sudo just luks-status

# Test passphrase (will prompt for LUKS passphrase)
sudo just test-luks-passphrase /dev/nvme0n1p2

# Backup LUKS headers
sudo just backup-luks-headers

# View backup
ls -lh /var/lib/luks-backups/
```

### Test 5: TPM2 Management

```bash
# Show TPM2 status
sudo just tpm-status

# List enrolled devices
sudo just tpm-enrolled

# Verify TPM2 working
sudo just tpm-verify

# Enroll TPM2 (ONLY after LUKS is set up)
sudo just enroll-tpm2 /dev/nvme0n1p2
```

### Test 6: BTRFS Management

```bash
# Show filesystem usage
just btrfs-usage

# List snapshots
just list-snapshots

# Create snapshot
sudo just snapshot / "test-snapshot"

# Cleanup old snapshots (dry run)
sudo btrfs-manage cleanup --keep 7 --dry-run
```

---

## Module Testing (Before Installation)

### Test 7: Check Module Syntax

```bash
# Verify NixOS module syntax
nix flake check

# Build test configuration (won't switch)
sudo nixos-rebuild build --flake .
```

### Test 8: Review Module Configuration

```bash
# LUKS encryption module
cat modules/security/luks-encryption.nix

# BTRFS filesystem module
cat modules/filesystem/btrfs.nix

# SSH hardening module
cat modules/security/ssh-daemon.nix

# Per-folder encryption module
cat modules/security/folder-encryption.nix
```

---

## Integration Testing (After Full Installation)

### Test 9: End-to-End Security Stack

```bash
# 1. Verify LUKS is active
sudo cryptsetup status cryptroot

# 2. Check BTRFS subvolumes
sudo btrfs subvolume list /

# 3. Verify TPM2 enrollment
sudo systemd-cryptenroll --tpm2-device=list

# 4. Test vault creation and usage
vault-manage create secure
vault-manage mount secure
echo "test" > ~/mnt/secure/test.txt
vault-manage unmount secure

# 5. Verify SSH hardening
ssh -vvv localhost 2>&1 | grep -i "cipher\|kex\|mac"

# 6. Check Zram swap
swapon --show
zramctl

# 7. Run BTRFS scrub
sudo btrfs-manage scrub /

# 8. Create and list snapshots
sudo btrfs-manage snapshot / --name "test-$(date +%Y%m%d)"
sudo btrfs-manage list-snapshots
```

### Test 10: Disaster Recovery Procedures

```bash
# Retrieve LUKS passphrase from agenix
sudo cat /run/agenix/luks-passphrase-laptop-intel

# Test TPM2 re-enrollment
sudo tpm-manage clear-device /dev/nvme0n1p2
sudo tpm-manage re-enroll /dev/nvme0n1p2

# Verify LUKS header backups exist
ls -lh /var/lib/luks-backups/

# Test vault password change
vault-manage change-password test-vault
```

---

## Performance Testing

### Test 11: Encryption Performance

```bash
# Benchmark LUKS encryption
sudo luks-manage benchmark /dev/nvme0n1p2

# Check BTRFS compression ratio
sudo compsize /
sudo compsize /home
sudo compsize /nix

# Check Zram compression
zramctl
```

### Test 12: Boot Time

```bash
# Measure boot time before TPM2 enrollment
systemd-analyze

# Enroll TPM2
sudo luks-manage enroll-tpm2 /dev/nvme0n1p2

# Reboot and measure again
sudo reboot
# After reboot:
systemd-analyze
```

---

## Security Auditing

### Test 13: SSH Security

```bash
# Check SSH daemon configuration
sudo sshd -T | grep -E "passwordauth|pubkeyauth|permitroot|ciphers|macs|kexalgorithms"

# View SSH logs
sudo journalctl -u sshd -n 50

# Test fail2ban
sudo fail2ban-client status sshd
```

### Test 14: Encryption Key Management

```bash
# List agenix secrets
agenix-helper list

# Verify secrets deployed correctly
secrets-verify --test-all

# Check LUKS key slots
sudo cryptsetup luksDump /dev/nvme0n1p2
```

---

## Checklist: Pre-Installation Testing

Before installing NixOS on physical hardware:

- [ ] ✅ Rust tools build successfully (`cargo build --workspace --release`)
- [ ] ✅ All tools have `--help` output
- [ ] ✅ `nix flake check` passes
- [ ] ✅ Vault encryption works (create, mount, unmount)
- [ ] ✅ Justfile tasks execute without syntax errors
- [ ] ✅ Documentation is comprehensive
- [ ] ✅ Secrets configuration includes LUKS passphrases
- [ ] ✅ Dev shell builds and activates tools

## Checklist: Post-Installation Testing

After NixOS is installed:

- [ ] LUKS devices unlock successfully
- [ ] TPM2 enrollment works
- [ ] Auto-unlock on reboot works (TPM2)
- [ ] Passphrase fallback works (when TPM2 disabled)
- [ ] BTRFS subvolumes mounted correctly
- [ ] Zram swap is active
- [ ] Snapshots can be created
- [ ] Vaults can be created and mounted
- [ ] SSH daemon is hardened (no password auth)
- [ ] Fail2ban is active
- [ ] LUKS headers backed up automatically
- [ ] All Rust CLIs work with `sudo`

---

## Troubleshooting

### Issue: Rust tools not found in PATH

```bash
# Rebuild in dev shell
cd rust
cargo build --release
export PATH="$PWD/target/release:$PATH"
```

### Issue: Permission denied on vault operations

```bash
# Check vault permissions
ls -ld ~/vaults ~/mnt

# Should be owned by your user
chown -R $USER:users ~/vaults ~/mnt
```

### Issue: TPM2 enrollment fails

```bash
# Check TPM2 is available
ls -l /dev/tpm*

# Check systemd-cryptenroll exists
which systemd-cryptenroll

# Verify LUKS device
sudo cryptsetup isLuks /dev/nvme0n1p2
```

### Issue: BTRFS commands fail

```bash
# Verify BTRFS filesystem
mount | grep btrfs

# Check filesystem type
stat -f -c %T /
```

---

## Expected Results

### Pre-Installation

- All Rust tools compile without errors
- Vault encryption works on any Linux system
- Module syntax validates with `nix flake check`
- Documentation is clear and comprehensive

### Post-Installation

- **Boot time**: +2-5 seconds with LUKS, automatic with TPM2
- **Disk usage**: 20-40% space savings with zstd:1 compression
- **Encryption overhead**: ~5-10% (hardware AES-NI acceleration)
- **Zram latency**: <1ms (vs 5-10ms for SSD swap)

---

## Next Steps After Testing

1. ✅ Verify all tests pass
2. ⬜ Create `docs/LUKS-INSTALLATION.md` with exact partition commands
3. ⬜ Prepare NixOS installer USB
4. ⬜ Follow Stage 0 LUKS setup during installation
5. ⬜ Complete Stages 1-6 as documented
6. ⬜ Enroll TPM2 after first boot
7. ⬜ Create encrypted vaults for sensitive data
8. ⬜ Test disaster recovery procedures

---

## Getting Help

- **Documentation**: See `docs/ENCRYPTION-GUIDE.md`
- **Summary**: See `SECURITY-IMPLEMENTATION-SUMMARY.md`
- **Tool help**: Run `<tool-name> --help`
- **Module code**: Check `modules/security/` and `modules/filesystem/`

---

## Success Criteria

✅ **Functional**:
- All Rust tools execute without errors
- Vaults encrypt/decrypt correctly
- Modules validate with Nix
- Documentation is complete

✅ **Security**:
- LUKS uses AES-256-XTS
- TPM2 binds to PCR 7
- SSH uses modern algorithms only
- No plaintext secrets in configs

✅ **Performance**:
- Boot time acceptable (<30s total)
- Compression saves 20-40% space
- Encryption overhead <10%
- Zram faster than disk swap

Good luck with testing! 🔒🚀
