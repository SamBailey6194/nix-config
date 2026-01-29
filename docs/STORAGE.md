# Storage Management: Restic, ZFS, and RAID

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## Quick Start

**Time**: 10-15 minutes per system

### Restic Backups (Encrypted Backups to Multiple Destinations)

```bash
# 1. Enable module (one-time)
# Edit hosts/laptop-intel/configuration.nix
# Add to imports: ../../modules/storage/restic.nix
# Add: services.restic-runtime.enable = true;
# Rebuild: sudo nixos-rebuild switch

# 2. Create password secret
agenix -e restic-password-laptop-intel.age
# Enter strong password

# 3. Add password to secrets/secrets.nix
# "restic-password-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];

# 4. Configure repository
restic-manage add-repo local local /mnt/backups

# 5. Initialize repository
restic-manage init-repo local

# 6. Add backup job
restic-manage add-backup home \
  --paths /home \
  --repository local \
  --schedule daily

# 7. Enable backup timer
sudo systemctl enable --now restic-backup@home.timer

# 8. Run first backup
restic-backup-now home
```

### ZFS Storage (Enterprise-Grade Filesystem)

```bash
# 1. Enable module
# Same as Restic: add to imports, set enable = true

# 2. Create pool
zfs-manage create-pool tank mirror /dev/sda /dev/sdb

# 3. Create dataset
zfs-manage create-dataset tank/data --mountpoint /data

# 4. Setup snapshots
zfs-manage setup-snapshots tank/data --frequency daily --retention 30

# 5. Check status
zfs-status
```

### RAID Management (Hardware RAID)

```bash
# 1. Enable module
# Same as Restic: add to imports, set enable = true

# 2. Create array
raid-manage create 1 /dev/md0 /dev/sda /dev/sdb

# 3. Format and mount
sudo mkfs.ext4 /dev/md0
sudo mount /dev/md0 /mnt/raid

# 4. Enable monitoring
raid-manage monitor --enable

# 5. Check status
raid-status
```

---

## Philosophy

### Separation of Framework and Configuration

**Framework (NixOS modules)**:
- Provides tools and systemd services
- Sets up monitoring and scheduling
- Immutable, declarative configuration
- Lives in git

**Configuration (Runtime state)**:
- User-managed JSON files and CLI commands
- Per-device configuration in `/var/lib/` and `/etc/`
- No Nix editing required after module enable
- Uses standard tools (restic, zfs, mdadm)

**Benefits**:
- ✅ No need to rebuild system for configuration changes
- ✅ Use standard tools (familiar to operators)
- ✅ Configuration lives in `/var/lib/`, not in Nix
- ✅ Secrets via agenix (referenced at runtime)
- ✅ Easy to migrate to another system

---

## Restic Backups

### Overview

Restic provides encrypted, deduplicated backups to multiple destinations:
- Local filesystem
- Backblaze B2 (cloud storage)
- Amazon S3 (or S3-compatible)
- SFTP (remote server)
- REST server

**Key Features**:
- Client-side encryption (your keys, your data)
- Automatic deduplication (save space)
- Per-repository configuration
- Systemd timer scheduling
- Automatic pruning of old snapshots

### Setup

#### 1. Enable Module (One-Time)

Edit `hosts/laptop-intel/configuration.nix`:

```nix
imports = [
  ../../modules/storage/restic.nix
];

services.restic-runtime.enable = true;
```

Rebuild: `sudo nixos-rebuild switch`

#### 2. Create Repository Password

```bash
# Create encrypted password
agenix -e restic-password-laptop-intel.age

# Enter strong password (e.g., 32+ characters)
```

#### 3. Add to secrets/secrets.nix

```nix
"restic-password-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
```

Rebuild: `sudo nixos-rebuild switch`

#### 4. Add Repository

**Local Backup**:
```bash
restic-manage add-repo local local /mnt/backups
```

**Backblaze B2**:
```bash
restic-manage add-repo b2 b2 b2:bucket:/path
```

**Amazon S3**:
```bash
restic-manage add-repo s3 s3 s3:bucket-name/path
```

**SFTP**:
```bash
restic-manage add-repo sftp sftp sftp:user@server:/path
```

#### 5. Initialize Repository

```bash
restic-manage init-repo local
```

#### 6. Configure Backup Job

```bash
# Backup entire home directory daily
restic-manage add-backup home \
  --paths /home \
  --repository local \
  --schedule daily

# Backup specific directory
restic-manage add-backup projects \
  --paths /home/user/Projects \
  --repository local \
  --schedule weekly
```

#### 7. Enable Backup Timer

```bash
# Start backup now
restic-backup-now home

# Enable automatic daily backups
sudo systemctl enable --now restic-backup@home.timer
```

### Daily Usage

```bash
# Check backup status
restic-status

# Run backup now
restic-backup-now home

# List all snapshots
restic-repo local snapshots

# List files in latest snapshot
restic-repo local ls latest

# Restore latest snapshot
restic-repo local restore latest --target /tmp/restore

# Restore specific snapshot
restic-repo local restore abc123de --target /tmp/restore

# Show backup progress
journalctl -u restic-backup@home.service -f
```

### Configuration Files

- Repository config: `/var/lib/restic/<hostname>/config.json`
- Backup schedule: `/var/lib/restic/<hostname>/backups.json`
- Credentials: `/run/agenix/restic-password-*`

### Best Practices

1. **Test Restores**: Periodically test restore to verify backups work
2. **Monitor Backups**: Check systemd journal for backup errors
3. **Multiple Repositories**: Back up to both local and cloud
4. **Verify Encryption**: Ensure password is stored securely
5. **Document Restoration**: Keep restore procedures documented

---

## ZFS Storage

### Overview

ZFS provides enterprise-grade storage with:
- Filesystem-level redundancy (mirror, RAIDZ)
- Automatic snapshots and rollback
- Data compression (lz4, gzip)
- Automatic scrubbing (data integrity checks)

**Use Cases**:
- NAS (network storage)
- Large datasets with high availability
- Boot environment snapshots
- Development environments

### Setup

#### 1. Enable Module (One-Time)

Edit `hosts/laptop-intel/configuration.nix`:

```nix
imports = [
  ../../modules/storage/zfs.nix
];

services.zfs-runtime.enable = true;
```

Rebuild: `sudo nixos-rebuild switch`

#### 2. Create Pool

**Mirror Pool** (RAID1 - 2 disks):
```bash
zfs-manage create-pool tank mirror /dev/sda /dev/sdb
```

**RAIDZ Pool** (RAID5 - 3+ disks, 1 failure tolerance):
```bash
zfs-manage create-pool storage raidz /dev/sdc /dev/sdd /dev/sde
```

**RAIDZ2 Pool** (RAID6 - 4+ disks, 2 failure tolerance):
```bash
zfs-manage create-pool archive raidz2 /dev/sdf /dev/sdg /dev/sdh /dev/sdi
```

#### 3. Create Dataset

```bash
# Simple dataset
zfs-manage create-dataset tank/data --mountpoint /data

# Dataset with compression
zfs-manage create-dataset tank/media \
  --mountpoint /media \
  --compression lz4

# Read-only snapshot dataset
zfs-manage create-dataset tank/backups \
  --mountpoint /backups \
  --readonly
```

#### 4. Setup Automatic Snapshots

```bash
# Daily snapshots, keep 30 days
zfs-manage setup-snapshots tank/data \
  --frequency daily \
  --retention 30

# Hourly snapshots, keep 48 hours
zfs-manage setup-snapshots tank/live \
  --frequency hourly \
  --retention 48
```

### Daily Usage

```bash
# Check pool status
zfs-status

# List pools and datasets
zfs list

# Check dataset properties
zfs get all tank/data

# Manual snapshot
zfs-manage snapshot tank/data

# List snapshots
zfs list -t snapshot

# Restore from snapshot
zfs rollback tank/data@snapshot-name

# Clone snapshot to new dataset
zfs clone tank/data@snapshot-name tank/data-restore
```

### Configuration Files

- Snapshot schedule: `/etc/zfs/snapshot-schedule.conf`
- Pool config: `/etc/zfs/zpool.cache`
- Import hooks: `/etc/zfs/zfs-list.cache`

### Best Practices

1. **Redundancy**: Always use mirror or RAIDZ (not single disk)
2. **Monitoring**: Check pool health weekly: `zpool status`
3. **Scrubbing**: Run monthly scrub: `zpool scrub tank`
4. **Snapshots**: Take regular snapshots for disaster recovery
5. **Capacity**: Keep pools <80% full for performance

---

## RAID Management

### Overview

RAID provides hardware-level redundancy:
- RAID0 (stripe): Fast but no redundancy
- RAID1 (mirror): 2 disks, 1 failure tolerance
- RAID5: 3+ disks, 1 failure tolerance
- RAID6: 4+ disks, 2 failure tolerance
- RAID10: Combination of stripe and mirror

**Use Cases**:
- Legacy RAID controllers
- Direct-attached storage (DAS)
- High-performance requirements

### Setup

#### 1. Enable Module (One-Time)

Edit `hosts/laptop-intel/configuration.nix`:

```nix
imports = [
  ../../modules/storage/raid.nix
];

services.raid-runtime.enable = true;
```

Rebuild: `sudo nixos-rebuild switch`

#### 2. Create RAID Array

**RAID1** (Mirror, 2 disks):
```bash
raid-manage create 1 /dev/md0 /dev/sda /dev/sdb
```

**RAID5** (3+ disks, 1 failure):
```bash
raid-manage create 5 /dev/md0 /dev/sdc /dev/sdd /dev/sde
```

**RAID6** (4+ disks, 2 failures):
```bash
raid-manage create 6 /dev/md0 /dev/sdf /dev/sdg /dev/sdh /dev/sdi
```

#### 3. Format and Mount

```bash
# Format array
sudo mkfs.ext4 /dev/md0

# Mount
sudo mount /dev/md0 /mnt/raid

# Add to fstab for automatic mount
echo "/dev/md0 /mnt/raid ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

#### 4. Enable Monitoring

```bash
# Start monitoring
raid-manage monitor --enable

# Check status
raid-status

# View detailed health
raid-manage health
```

### Daily Usage

```bash
# Check array status
raid-status

# Monitor rebuild progress
raid-manage progress

# Add disk to array (expansion)
raid-manage add /dev/md0 /dev/sdf

# Remove failed disk
raid-manage remove /dev/md0 /dev/sdd

# Manual check
cat /proc/mdstat
```

### Failure Recovery

**If a disk fails**:

```bash
# 1. Identify failed disk
cat /proc/mdstat
lsblk | grep md

# 2. Remove failed disk
raid-manage remove /dev/md0 /dev/sdd

# 3. Physical disk replacement (offline)

# 4. Add new disk
raid-manage add /dev/md0 /dev/sde

# 5. Monitor rebuild
watch cat /proc/mdstat
```

### Configuration Files

- Array config: `/etc/mdadm.conf`
- Monitoring: `/var/lib/mdadm/`

---

## Configuration

### Enable Multiple Storage Systems

Edit `hosts/laptop-intel/configuration.nix`:

```nix
imports = [
  ../../modules/storage/restic.nix
  ../../modules/storage/zfs.nix
  ../../modules/storage/raid.nix
];

# Restic backups
services.restic-runtime.enable = true;

# ZFS storage
services.zfs-runtime.enable = true;

# RAID arrays
services.raid-runtime.enable = true;
```

### Create Backup to Cloud

**Example: Back up to Backblaze B2**

```bash
# 1. Enable Restic module
# 2. Create B2 account at backblaze.com
# 3. Get B2 credentials
# 4. Add repository
restic-manage add-repo b2 b2 b2:my-bucket:/backups

# 5. Configure backup
restic-manage add-backup home \
  --paths /home \
  --repository b2 \
  --schedule daily

# 6. Enable timer
sudo systemctl enable --now restic-backup@home.timer
```

### Mirror Local and Cloud

```bash
# Local backup (daily)
restic-manage add-backup home-local \
  --paths /home \
  --repository local \
  --schedule daily

# Cloud backup (weekly)
restic-manage add-backup home-cloud \
  --paths /home \
  --repository b2 \
  --schedule weekly
```

---

## Monitoring

### Check Backup Status

```bash
# Restic backups
journalctl -u restic-backup@home.service

# Scheduled backups
systemctl list-timers | grep restic
```

### Check ZFS Pool Health

```bash
# Pool status
zpool status tank

# Errors and warnings
zpool events

# List all pools
zpool list
```

### Check RAID Array Health

```bash
# Array status
cat /proc/mdstat

# Detailed health
raid-manage health

# Monitor in real-time
watch cat /proc/mdstat
```

### Alerts and Notifications

Create alerting for failures:

```bash
# Email alerts on backup failure
systemctl status restic-backup@home.service

# Slack/PagerDuty integration (future)
# Configure in ~/scripts/alert.sh
```

---

## Troubleshooting

### Restic Backup Fails

**Problem**: Backup job fails or doesn't start

**Solution**:
```bash
# Check if timer is active
systemctl list-timers restic-backup@home.timer

# Check service logs
journalctl -u restic-backup@home.service -n 50

# Verify password is available
cat /run/agenix/restic-password-laptop-intel

# Test backup manually
restic-backup-now home

# Check repository
restic-repo local snapshots
```

### ZFS Pool Not Mounting

**Problem**: ZFS pool not mounted after reboot

**Solution**:
```bash
# List pools
zpool list

# Import pool manually
sudo zpool import tank

# Add to auto-import on boot
zpool set cachefile=/etc/zfs/zpool.cache tank
```

### RAID Array Degraded

**Problem**: One disk failed, array is degraded

**Solution**:
```bash
# Check status
cat /proc/mdstat

# Identify failed disk
lsblk | grep md

# Add spare disk
raid-manage add /dev/md0 /dev/sde

# Monitor rebuild
watch cat /proc/mdstat
```

---

## Reference

### Just Commands

| Command | Purpose |
|---------|---------|
| `just restic-add-repo local local /mnt/backups` | Add local backup |
| `just restic-add-backup home /home local` | Add backup job |
| `just backup-now home` | Run backup immediately |
| `just restic-snapshots local` | List snapshots |
| `just zfs-pool tank mirror /dev/sda /dev/sdb` | Create ZFS pool |
| `just zfs-dataset tank/data` | Create dataset |
| `just zfs-snapshots tank/data daily` | Setup snapshots |
| `just zfs-status` | Check pool status |
| `just raid-create 1 /dev/md0 "/dev/sda /dev/sdb"` | Create RAID1 |
| `just raid-status` | Check RAID status |
| `just raid-health` | Check RAID health |

### File Locations

| Path | Purpose |
|------|---------|
| `/var/lib/restic/<hostname>/config.json` | Restic config |
| `/var/lib/restic/<hostname>/backups.json` | Backup schedule |
| `/run/agenix/restic-password-*` | Encrypted password |
| `/etc/zfs/snapshot-schedule.conf` | ZFS snapshots |
| `/etc/zfs/zpool.cache` | ZFS pool cache |
| `/etc/mdadm.conf` | RAID configuration |
| `/proc/mdstat` | RAID status |

### Systemd Services/Timers

| Service | Purpose |
|---------|---------|
| `restic-backup@home.service` | Restic backup job |
| `restic-backup@home.timer` | Restic schedule |
| `zfs-auto-scrub.timer` | ZFS data checks |
| `mdmonitor.service` | RAID monitoring |

---

## Next Steps

1. **Choose Storage Strategy**: Backup, ZFS, or RAID based on your needs
2. **Enable Module**: Follow setup guide for chosen system
3. **Configure Jobs**: Create backups/pools/arrays
4. **Test**: Verify backup restores work
5. **Monitor**: Check health regularly
6. **Multi-Device**: Repeat setup for other devices

## Best Practices

**Backups**:
- Test restores quarterly
- Keep offsite backup (cloud)
- Encrypt sensitive backups
- Monitor backup logs

**ZFS**:
- Use mirror or RAIDZ (redundancy)
- Keep pools <80% full
- Scrub monthly
- Monitor zpool status

**RAID**:
- Use RAID5/RAID6 for redundancy
- Keep spare disk available
- Monitor rebuild progress
- Document failure procedures
