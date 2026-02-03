# Comprehensive Encryption Guide

**Last Updated**: 2026-02-03
**Version**: 1.0.0
**Target Systems**: laptop-intel, framework, devtower

---

## Table of Contents

1. [Overview](#overview)
2. [Security Architecture](#security-architecture)
3. [LUKS Full Disk Encryption](#luks-full-disk-encryption)
4. [BTRFS Filesystem](#btrfs-filesystem)
5. [TPM2 Auto-Unlock](#tpm2-auto-unlock)
6. [Per-Folder Encryption](#per-folder-encryption)
7. [SSH Hardening](#ssh-hardening)
8. [Encryption Tools](#encryption-tools)
9. [Management CLIs](#management-clis)
10. [Disaster Recovery](#disaster-recovery)
11. [Best Practices](#best-practices)

---

## Overview

This configuration implements a multi-layered security architecture:

```
┌─────────────────────────────────────────────────────────┐
│  Layer 4: Application Encryption (GPG, 7-Zip, VeraCrypt)│
├─────────────────────────────────────────────────────────┤
│  Layer 3: Per-Folder Encryption (gocryptfs vaults)      │
├─────────────────────────────────────────────────────────┤
│  Layer 2: Filesystem (BTRFS with zstd compression)      │
├─────────────────────────────────────────────────────────┤
│  Layer 1: Full Disk Encryption (LUKS2 with TPM2)        │
└─────────────────────────────────────────────────────────┘
```

### Key Features

- **Full Disk Encryption**: LUKS2 with AES-256-XTS
- **TPM2 Auto-Unlock**: Boot without entering password (with fallback)
- **BTRFS Compression**: zstd:1 for ~30% space savings
- **Zram Swap**: No disk swap (encrypted in RAM)
- **Per-Folder Encryption**: Additional protection for sensitive data
- **Hardened SSH**: Modern algorithms only, no password auth
- **Zero-Trust Model**: Per-device encryption keys

---

## Security Architecture

### Threat Model

| Threat | Mitigation |
|--------|------------|
| **Physical theft** | LUKS encryption + TPM2 binding to hardware |
| **Cold boot attack** | No disk swap, Zram only (volatile) |
| **Evil maid attack** | TPM2 PCR binding detects boot tampering |
| **Malware/ransomware** | Per-folder encryption isolates sensitive data |
| **SSH brute force** | Key-only auth, fail2ban, modern algorithms |
| **Insider threat** | Per-device keys, audit logging |

### Encryption Hierarchy

```
/dev/nvme0n1p2 (LUKS2 encrypted, TPM2 auto-unlock)
  └── /dev/mapper/cryptroot (BTRFS filesystem, zstd compressed)
      ├── / (@root subvolume)
      ├── /home (@home subvolume)
      │   └── ~/vaults/ (gocryptfs encrypted folders)
      │       ├── secure/ (password-protected vault)
      │       ├── projects/ (password-protected vault)
      │       └── personal/ (password-protected vault)
      ├── /nix (@nix subvolume)
      └── /.snapshots (@snapshots subvolume)
```

---

## LUKS Full Disk Encryption

### What is LUKS?

LUKS (Linux Unified Key Setup) provides full disk encryption:
- **Master key** encrypts the entire disk (never changes)
- **Key slots** (0-7) store wrapped versions of the master key
- Each slot can have a different passphrase or key
- TPM2 uses a dedicated slot for automatic unlocking

### Encryption Specifications

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Version** | LUKS2 | Modern format with better security |
| **Cipher** | AES-XTS-Plain64 | Industry standard, hardware accelerated |
| **Key size** | 512-bit | Maximum security (2x256-bit for XTS) |
| **Hash** | SHA-512 | Strong hash for key derivation |
| **PBKDF** | Argon2id | Memory-hard, resistant to GPU attacks |

### Device Layout

#### Laptop-Intel & Framework (Single Drive)

```
/dev/nvme0n1
├── p1: 512MB    EFI System (vfat, unencrypted)
│   └── /boot
└── p2: Rest     LUKS container "cryptroot"
    └── BTRFS filesystem with subvolumes
```

#### DevTower (Multi-Drive Setup)

**Current Hardware:**
```
/dev/nvme1n1 (238GB NVMe SSD - OS)
├── p1: 1GB      EFI System (vfat, unencrypted)
└── p2: ~237GB   LUKS container "cryptroot"

/dev/sdd (476GB SSD - Home)
└── p1: Full     LUKS container "crypthome"

/dev/sdc (3.6TB HDD - Media)
└── p1: Full     LUKS container "cryptmedia"
```

**Future Expansion:**
- **Phase 2**: 2TB NVMe for /home, repurpose /dev/sdd for creative files
- **Phase 3**: Dedicated creative drive (3rd NVMe)
- **Phase 4**: 2x8TB HDDs in ZFS mirror for backups

### LUKS Management

#### View Device Status

```bash
# Show all LUKS devices
sudo luks-manage status

# Check specific device
sudo cryptsetup luksDump /dev/nvme0n1p2
```

#### Key Slot Management

```bash
# Add new passphrase to slot 1
sudo luks-manage add-passphrase /dev/nvme0n1p2 --slot 1

# Remove key from slot 2
sudo luks-manage remove-key /dev/nvme0n1p2 2

# Test if passphrase works
sudo luks-manage test-unlock /dev/nvme0n1p2
```

#### Backup LUKS Headers

**CRITICAL**: Always backup LUKS headers before making changes!

```bash
# Backup all LUKS headers
just backup-luks-headers

# Manual backup to specific location
sudo luks-manage backup-header /dev/nvme0n1p2 --output /backup/location

# Backups stored at: /var/lib/luks-backups/
# Format: <device>-header-<timestamp>.img
```

#### Restore LUKS Header

```bash
# Restore from backup (DANGEROUS - will destroy data!)
sudo luks-manage restore-header /dev/nvme0n1p2 /var/lib/luks-backups/nvme0n1p2-header-20260203-143022.img
```

#### Rotate Master Key

```bash
# Rotate LUKS master key (re-encrypts header)
sudo luks-manage rotate-key /dev/nvme0n1p2
```

#### Benchmark Performance

```bash
# Test encryption speed
sudo luks-manage benchmark /dev/nvme0n1p2
```

---

## BTRFS Filesystem

### Why BTRFS?

- **Snapshots**: Instant filesystem snapshots for rollback
- **Compression**: Transparent compression (zstd) saves ~30% space
- **Checksums**: Data integrity verification (scrubbing)
- **Subvolumes**: Independent mount points with different options
- **Copy-on-Write**: Efficient space usage for snapshots

### Subvolume Layout

```
BTRFS Filesystem (@root)
├── @root       -> /              (OS root, snapshotted before updates)
├── @home       -> /home          (User data, daily snapshots)
├── @nix        -> /nix           (Nix store, independent snapshots)
├── @snapshots  -> /.snapshots    (Snapshot storage)
└── @log        -> /var/log       (Logs, nocow for performance)
```

### Mount Options

```nix
compress=zstd:1      # Compression (level 1 = fast, good ratio)
noatime              # Don't update access times (SSD optimization)
space_cache=v2       # Modern space cache algorithm
nodatacow            # Disable COW for /var/log (database-like writes)
```

### Snapshot Management

#### Create Snapshots

```bash
# Create snapshot of root
sudo btrfs-manage snapshot / --name "before-update"

# Create read-only snapshot
sudo btrfs-manage snapshot / --readonly --name "stable-20260203"

# Snapshot home directory
sudo btrfs-manage snapshot /home --name "home-backup"
```

#### List Snapshots

```bash
# List all snapshots
just list-snapshots

# Or directly
sudo btrfs-manage list-snapshots
```

#### Rollback to Snapshot

```bash
# Rollback (requires reboot from live system)
sudo btrfs-manage rollback /.snapshots/root-20260203-143022 --target /
```

**Manual Rollback Procedure:**
1. Boot into live system or single-user mode
2. Mount BTRFS filesystem: `mount /dev/mapper/cryptroot /mnt`
3. Delete or rename current @root: `btrfs subvolume delete /mnt/@root`
4. Create new @root from snapshot: `btrfs subvolume snapshot /mnt/.snapshots/root-20260203-143022 /mnt/@root`
5. Reboot

#### Cleanup Old Snapshots

```bash
# Delete snapshots older than 7 days (keeps 7 newest)
just cleanup-snapshots 7

# Dry run to see what would be deleted
sudo btrfs-manage cleanup --keep 7 --dry-run
```

### Filesystem Maintenance

#### Scrub (Data Integrity Check)

```bash
# Run scrub (check all data against checksums)
just scrub /

# Check scrub status
sudo btrfs-manage scrub / --status
```

**Recommendation**: Run monthly via systemd timer (enabled by default)

#### Balance (Redistribute Data)

```bash
# Balance with usage threshold (only chunks <80% full)
sudo btrfs-manage balance / --usage 80

# Balance data only
sudo btrfs-manage balance / --data --usage 80

# Balance metadata only
sudo btrfs-manage balance / --metadata --usage 80
```

**Warning**: Balancing can be I/O intensive. Run during low-activity periods.

#### Defragmentation

```bash
# Defragment single file
sudo btrfs-manage defrag /path/to/file

# Recursive defragmentation
sudo btrfs-manage defrag /home --recursive

# Defrag and compress
sudo btrfs-manage defrag / --recursive --compress zstd
```

#### Check Space Usage

```bash
# Show detailed usage
just btrfs-usage

# Or directly
sudo btrfs-manage usage /

# Check compression ratio
sudo compsize /
```

---

## TPM2 Auto-Unlock

### What is TPM2?

Trusted Platform Module 2.0 provides:
- **Hardware-bound encryption keys**: Keys never leave TPM chip
- **PCR binding**: Detects boot tampering (Secure Boot, bootloader, kernel)
- **Measured boot**: Verifies system integrity before unlocking

### How It Works

```
Boot Sequence:
1. UEFI firmware → TPM extends PCR 0-7
2. Bootloader (GRUB) → TPM extends PCR 4
3. Kernel → TPM extends PCR 5
4. systemd-cryptenroll checks PCRs
5. If PCRs match expected values → TPM releases LUKS key
6. If PCRs don't match → Fall back to passphrase prompt
```

### TPM2 Management

#### Check TPM Status

```bash
# Show TPM status and capabilities
just tpm-status

# Or directly
sudo tpm-manage status

# Verify TPM is working
just tpm-verify
```

#### List Enrolled Devices

```bash
# Show which devices have TPM2 enrolled
just tpm-enrolled

# Or directly
sudo tpm-manage enrolled-devices
```

#### Enroll TPM2 for Device

```bash
# Enroll single drive (laptop-intel, framework)
just enroll-tpm2 /dev/nvme0n1p2

# DevTower: Enroll all three drives
just enroll-tpm2 /dev/nvme1n1p2  # OS drive
just enroll-tpm2 /dev/sdd1        # Home drive
just enroll-tpm2 /dev/sdc1        # Media drive
```

**PCR Banks**: By default, PCR 7 (Secure Boot state) is used. You can specify custom PCRs:

```bash
sudo luks-manage enroll-tpm2 /dev/nvme0n1p2 --pcr "0+2+4+7"
```

Common PCR values:
- **PCR 0**: UEFI firmware
- **PCR 2**: Boot configuration
- **PCR 4**: Bootloader
- **PCR 5**: Bootloader configuration
- **PCR 7**: Secure Boot state

#### Re-enroll After System Changes

If you update firmware or change Secure Boot settings:

```bash
# Clear existing TPM2 enrollment
sudo tpm-manage clear-device /dev/nvme0n1p2

# Re-enroll with new PCR values
sudo tpm-manage re-enroll /dev/nvme0n1p2
```

### Fallback to Passphrase

If TPM2 auto-unlock fails (hardware replacement, PCR mismatch):
1. System will prompt for LUKS passphrase
2. Enter passphrase stored in agenix
3. Boot normally
4. Re-enroll TPM2 if needed

Retrieve passphrase:
```bash
# Laptop-Intel
sudo cat /run/agenix/luks-passphrase-laptop-intel

# DevTower (3 separate passphrases)
sudo cat /run/agenix/luks-passphrase-devtower-os
sudo cat /run/agenix/luks-passphrase-devtower-home
sudo cat /run/agenix/luks-passphrase-devtower-media
```

---

## Per-Folder Encryption

### Why Per-Folder Encryption?

LUKS encrypts the entire disk, but:
- **Sensitive files** may need additional protection
- **Malware/ransomware** could access decrypted files after boot
- **Selective access**: Only mount specific vaults when needed

gocryptfs provides:
- **Per-folder encryption**: Each vault has its own password
- **FUSE-based**: User-space mounting (no root required)
- **Transparent**: Files automatically encrypted/decrypted
- **Fast**: Stream cipher (no padding overhead)

### Vault Management

#### Create Encrypted Vault

```bash
# Create new vault
just create-vault secure

# Or directly
vault-manage create secure

# Custom locations
vault-manage create projects --vaults-dir ~/encrypted --mount-dir ~/decrypted
```

This creates:
- `~/vaults/secure/` - Encrypted storage
- `~/mnt/secure/` - Mount point for decrypted access

#### Mount Vault

```bash
# Mount vault (prompts for password)
just mount-vault secure

# Or directly
vault-manage mount secure
```

Once mounted, access decrypted files at `~/mnt/secure/`

#### Unmount Vault

```bash
# Unmount specific vault
just unmount-vault secure

# Unmount all vaults
vault-manage unmount-all
```

**Auto-unmount**: Vaults automatically unmount on logout.

#### List Vaults

```bash
# List all vaults
just list-vaults

# Show mounted vaults
just vault-status
```

#### Change Vault Password

```bash
# Change password
vault-manage change-password secure
```

#### Remove Vault

```bash
# Delete vault (IRREVERSIBLE)
vault-manage remove secure
```

**Warning**: This permanently deletes all encrypted data!

### Vault Best Practices

1. **Organize by sensitivity**:
   - `~/vaults/secure/` - SSH keys, GPG keys, passwords
   - `~/vaults/projects/` - Client work, contracts
   - `~/vaults/personal/` - Financial documents, medical records

2. **Mount only when needed**: Don't keep vaults mounted 24/7

3. **Use strong passwords**: gocryptfs only as secure as your password

4. **Backup encrypted folders**: `~/vaults/*` are safe to backup (encrypted at rest)

5. **Never backup mount points**: `~/mnt/*` contain decrypted data!

### Vault Recovery

If you forget the vault password:
- **No master key**: gocryptfs uses the password directly (no recovery)
- **Optional**: Store master key in agenix for emergency recovery

To enable master key backup:
```bash
# Extract master key (before you forget password!)
gocryptfs -masterkey ~/vaults/secure

# Store in agenix
agenix -e vault-master-key-laptop-intel.age
# Paste the master key

# Recover with master key
gocryptfs -masterkey <key> ~/vaults/secure ~/mnt/secure
```

---

## SSH Hardening

### Security Configuration

The SSH daemon is hardened with:

```nix
services.openssh = {
  enable = true;
  settings = {
    # Authentication
    PasswordAuthentication = false;      # Keys only
    PermitRootLogin = "no";               # No root SSH
    PubkeyAuthentication = true;          # ED25519 keys only

    # Modern cryptography
    Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com";
    MACs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com";
    KexAlgorithms = "curve25519-sha256,diffie-hellman-group18-sha512";

    # Connection limits
    MaxAuthTries = 3;                     # 3 attempts per connection
    MaxSessions = 10;                     # 10 concurrent sessions
    LoginGraceTime = 30;                  # 30s to authenticate

    # Idle timeout (5 minutes)
    ClientAliveInterval = 300;
    ClientAliveCountMax = 2;

    # Disable dangerous features
    AllowAgentForwarding = false;
    AllowTcpForwarding = false;
    X11Forwarding = false;
    PermitTunnel = false;
  };
};
```

### SSH Key Policy

| Key Type | Passphrase Required? | Use Case |
|----------|---------------------|----------|
| **GitHub SSH keys** | NO | GitHub has 2FA + key revocation |
| **Server SSH keys** | YES | Servers lack 2FA, need passphrase |
| **Personal SSH keys** | RECOMMENDED | For interactive use |

### Generate SSH Keys

```bash
# Personal SSH key (with passphrase)
ssh-keygen -t ed25519 -C "sam@laptop-intel-personal" -f ~/.ssh/id_ed25519

# Server SSH key (with passphrase)
ssh-keygen -t ed25519 -C "sam@client-server" -f ~/.ssh/server_acme

# GitHub SSH key (no passphrase for convenience)
ssh-keygen -t ed25519 -C "github-personal" -f ~/.ssh/github_personal -N ""
```

### Fail2ban Protection

The configuration includes fail2ban to ban IPs after failed attempts:

```nix
services.fail2ban = {
  enable = true;
  maxretry = 3;
  bantime = "1h";
};
```

### Audit Logging

SSH authentication attempts are logged:

```bash
# View SSH logs
sudo journalctl -u sshd -n 50

# View authentication logs
sudo tail -f /var/log/auth.log | grep ssh
```

---

## Encryption Tools

### GPG (GNU Privacy Guard)

**Use cases**: Email encryption, file signing, password manager

```bash
# Generate GPG key
gpg --full-generate-key

# Encrypt file
gpg --encrypt --recipient sam@example.com document.txt

# Decrypt file
gpg --decrypt document.txt.gpg > document.txt

# Sign file
gpg --sign document.txt

# Verify signature
gpg --verify document.txt.gpg
```

**Backup GPG keys**:
```bash
# Export private key
gpg --export-secret-keys --armor sam@example.com > private-key.asc

# Export to paper (for recovery)
paperkey --secret-key private-key.asc --output paper-key.txt
```

### 7-Zip (Encrypted Archives)

**Use cases**: Encrypted file archives, password-protected backups

```bash
# Create encrypted archive
7z a -p -mhe=on encrypted.7z files/

# Extract archive
7z x encrypted.7z
```

Options:
- `-p`: Prompt for password
- `-mhe=on`: Encrypt file names (not just contents)

### VeraCrypt (External Drive Encryption)

**Use cases**: Encrypted USB drives, external HDDs

```bash
# Create encrypted container
veracrypt --create /dev/sdX

# Mount container
veracrypt --mount /dev/sdX /mnt/veracrypt

# Unmount
veracrypt --dismount /dev/sdX
```

**GUI**: VeraCrypt also has a graphical interface.

---

## Management CLIs

All Rust-based management CLIs are available in the dev shell:

```bash
# Enter dev shell
nix develop

# Or use system-wide if installed
```

### luks-manage

```bash
luks-manage status                    # Show LUKS devices
luks-manage enroll-tpm2 <device>      # Enroll TPM2
luks-manage add-passphrase <device>   # Add passphrase
luks-manage backup-header <device>    # Backup LUKS header
luks-manage test-unlock <device>      # Test passphrase
luks-manage benchmark <device>        # Benchmark performance
```

### btrfs-manage

```bash
btrfs-manage snapshot <subvol>        # Create snapshot
btrfs-manage list-snapshots           # List snapshots
btrfs-manage rollback <snapshot>      # Rollback to snapshot
btrfs-manage cleanup                  # Delete old snapshots
btrfs-manage scrub                    # Data integrity check
btrfs-manage usage                    # Show space usage
```

### vault-manage

```bash
vault-manage create <name>            # Create vault
vault-manage mount <name>             # Mount vault
vault-manage unmount <name>           # Unmount vault
vault-manage list                     # List vaults
vault-manage change-password <name>   # Change password
```

### tpm-manage

```bash
tpm-manage status                     # Show TPM status
tpm-manage enrolled-devices           # List enrolled devices
tpm-manage verify                     # Verify TPM working
tpm-manage clear-device <device>      # Remove TPM enrollment
tpm-manage re-enroll <device>         # Re-enroll TPM2
```

---

## Disaster Recovery

### Scenario 1: Forgotten LUKS Passphrase

**Solution**: Retrieve from agenix

```bash
# Laptop-Intel
sudo cat /run/agenix/luks-passphrase-laptop-intel

# DevTower
sudo cat /run/agenix/luks-passphrase-devtower-os
```

If system won't boot:
1. Boot into NixOS installer (USB)
2. Mount agenix secrets (requires host SSH key)
3. Retrieve passphrase
4. Manually unlock LUKS: `cryptsetup luksOpen /dev/nvme0n1p2 cryptroot`

### Scenario 2: TPM2 Failure

**Solution**: Use passphrase fallback

1. Boot system (will prompt for passphrase)
2. Enter passphrase from agenix
3. System boots normally
4. Re-enroll TPM2: `sudo tpm-manage re-enroll /dev/nvme0n1p2`

### Scenario 3: Corrupted LUKS Header

**Solution**: Restore from backup

```bash
# Restore header (WARNING: verify backup is correct!)
sudo luks-manage restore-header /dev/nvme0n1p2 /var/lib/luks-backups/nvme0n1p2-header-20260203.img
```

**Prevention**: Regular header backups (automated via systemd timer)

### Scenario 4: Corrupted Filesystem

**Solution**: Rollback to BTRFS snapshot

1. Boot into live system
2. Mount BTRFS: `mount /dev/mapper/cryptroot /mnt`
3. List snapshots: `ls /mnt/.snapshots/`
4. Rollback:
   ```bash
   btrfs subvolume delete /mnt/@root
   btrfs subvolume snapshot /mnt/.snapshots/root-20260203 /mnt/@root
   ```
5. Reboot

### Scenario 5: Lost Vault Password

**Solution**: Use master key (if backed up)

```bash
# Mount with master key
gocryptfs -masterkey <key-from-agenix> ~/vaults/secure ~/mnt/secure
```

If no master key backup: **Data is unrecoverable** (by design).

---

## Best Practices

### Security

1. **Strong passphrases**:
   - Min 20 characters for LUKS
   - Min 15 characters for vaults
   - Use diceware or password manager

2. **Backup LUKS headers**:
   - Automatic backups enabled
   - Store off-site (encrypted USB drive)

3. **Test disaster recovery**:
   - Verify passphrase works
   - Test header restoration
   - Practice snapshot rollback

4. **Monitor logs**:
   ```bash
   sudo journalctl -u sshd -f
   sudo journalctl -u systemd-cryptsetup@cryptroot -f
   ```

5. **Keep software updated**:
   ```bash
   just update
   just rebuild
   ```

### Performance

1. **SSD optimization**:
   - LUKS with `--allow-discards` (TRIM support)
   - BTRFS with `noatime` (no access time updates)
   - Zram swap (no disk writes)

2. **Compression tuning**:
   - `zstd:1` for balanced performance (default)
   - `zstd:3` for better compression (slower)
   - `lzo` for fastest (lower ratio)

3. **Scrub during low activity**:
   - Monthly scrub via systemd timer
   - Runs overnight (low I/O impact)

4. **Balance periodically**:
   ```bash
   sudo btrfs-manage balance / --usage 80
   ```

### Backup Strategy

```
┌──────────────────────────────────────────────┐
│  Layer 1: Local Snapshots (/.snapshots/)    │  ← Instant recovery
├──────────────────────────────────────────────┤
│  Layer 2: External Drive (LUKS + VeraCrypt) │  ← Offline backup
├──────────────────────────────────────────────┤
│  Layer 3: Restic Remote (encrypted)         │  ← Cloud backup
└──────────────────────────────────────────────┘
```

**What to backup**:
- ✅ LUKS headers (`/var/lib/luks-backups/`)
- ✅ Encrypted vaults (`~/vaults/*`)
- ✅ SSH keys (`~/.ssh/`)
- ✅ GPG keys (`~/.gnupg/`)
- ✅ NixOS config (`/etc/nixos/`)
- ❌ Decrypted mount points (`~/mnt/*`)
- ❌ Temporary files (`/tmp/`)

---

## Conclusion

This encryption architecture provides:

✅ **Full disk encryption** with TPM2 convenience
✅ **Per-folder encryption** for sensitive data
✅ **Hardened SSH** with modern cryptography
✅ **Comprehensive tooling** for management
✅ **Disaster recovery** procedures
✅ **Zero-trust model** with per-device keys

**Next steps**:
1. Complete Stage 0 LUKS setup during installation
2. Enroll TPM2 after first boot
3. Create encrypted vaults for sensitive data
4. Test disaster recovery procedures
5. Schedule regular LUKS header backups

For installation instructions, see [LUKS-INSTALLATION.md](LUKS-INSTALLATION.md).
