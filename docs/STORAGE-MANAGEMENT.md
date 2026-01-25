# Storage Management Guide

This guide explains how to configure and manage storage systems (Restic backups, ZFS, RAID) WITHOUT editing Nix configuration files.

## Philosophy

**Separation of Framework and Configuration**

- **NixOS modules** = Framework only (tools, systemd services, monitoring)
- **Runtime config** = User-managed (JSON files, CLI commands, standard tools)
- **Per-device state** = `/var/lib/` and `/etc/`
- **Secrets** = agenix (referenced at runtime, not baked into Nix)

## Restic Backup System

### Overview

Runtime-configurable encrypted backups to multiple destinations.

**Key Features:**
- Per-device configuration in `/var/lib/restic/<hostname>/`
- Multiple repositories (local, B2, S3, SFTP, etc.)
- Automatic scheduling with systemd timers
- Agenix integration for credentials
- No Nix file editing required

### Setup

#### 1. Enable the Module

Add to your device configuration (ONE-TIME):

```nix
# hosts/laptop-intel/configuration.nix
imports = [
  ../../modules/storage/restic.nix
];

services.restic-runtime.enable = true;
```

Rebuild: `just rebuild`

#### 2. Create Repository Password Secret

```bash
# Create encrypted password file
agenix -e restic-password-laptop-intel.age

# Add your Restic repository password
# (Strong random password recommended)
```

Update `secrets/secrets.nix`:

```nix
"restic-password-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
```

Rebuild to deploy secret: `just rebuild`

#### 3. Configure Repositories

Add a local repository:

```bash
restic-manage add-repo local local /mnt/backups/laptop-intel
```

Add a Backblaze B2 repository:

```bash
# First, create B2 credentials secret
agenix -e restic-b2-env-laptop-intel.age

# Add B2 credentials (format: KEY=VALUE, one per line)
# B2_ACCOUNT_ID=your_account_id
# B2_ACCOUNT_KEY=your_key

restic-manage add-repo backblaze b2 b2:bucket-name:/laptop-intel
```

List repositories:

```bash
restic-manage list-repos --verbose
```

#### 4. Initialize Repositories

```bash
restic-manage init-repo local
restic-manage init-repo backblaze
```

#### 5. Configure Backups

Add a backup job:

```bash
restic-manage add-backup home \
  --paths /home \
  --repository local \
  --schedule daily \
  --retention 7d,4w,6m,2y
```

Add multiple paths:

```bash
restic-manage add-backup important \
  --paths "/home,/etc,/var/lib/important" \
  --repository backblaze \
  --schedule "02:00" \
  --retention 30d,8w,12m,5y
```

List backups:

```bash
restic-manage list-backups --verbose
```

#### 6. Enable Systemd Services

```bash
# Generate and validate services
restic-manage generate-services

# Reload systemd
sudo systemctl daemon-reload

# Enable backup timers
sudo systemctl enable --now restic-backup@home.timer
sudo systemctl enable --now restic-backup@important.timer
```

### Daily Operations

#### Check Backup Status

```bash
restic-status
```

#### Run Backup Immediately

```bash
restic-backup-now home
```

#### View Backup Logs

```bash
journalctl -fu restic-backup@home.service
```

#### List Snapshots

```bash
restic-repo local snapshots
```

#### Restore Files

```bash
# List snapshots
restic-repo local snapshots

# Restore latest snapshot
restic-repo local restore latest --target /tmp/restore

# Restore specific snapshot
restic-repo local restore abc123 --target /tmp/restore

# Restore specific file
restic-repo local restore latest --target /tmp/restore --include /home/user/document.pdf
```

#### Check Repository

```bash
restic-repo local check
```

#### Prune Old Snapshots

```bash
restic-repo local forget --keep-daily 7 --keep-weekly 4 --prune
```

### Configuration Reference

Repositories are stored in: `/var/lib/restic/<hostname>/config.json`

Example configuration:

```json
{
  "repositories": {
    "local": {
      "type": "local",
      "path": "/mnt/backups/laptop-intel"
    },
    "backblaze": {
      "type": "b2",
      "path": "b2:bucket-name:/laptop-intel"
    }
  },
  "backups": {
    "home": {
      "paths": ["/home"],
      "repository": "local",
      "schedule": "daily",
      "retention": "7d,4w,6m,2y",
      "exclude": []
    }
  }
}
```

### Troubleshooting

**Backup not running?**

Check timer status:
```bash
systemctl status restic-backup@home.timer
```

Check service status:
```bash
systemctl status restic-backup@home.service
```

**Password errors?**

Verify secret deployed:
```bash
ls -la /run/agenix/restic-password-*
cat /run/agenix/restic-password-laptop-intel  # Should show password
```

**B2 credentials not working?**

Check environment file:
```bash
cat /run/agenix/restic-b2-env-laptop-intel
```

Should contain:
```
B2_ACCOUNT_ID=your_id
B2_ACCOUNT_KEY=your_key
```

---

## ZFS Storage Management

### Overview

Runtime ZFS pool and dataset management with automatic snapshots and scrubbing.

**Key Features:**
- Standard `zpool` and `zfs` commands work normally
- Helper tools for common operations
- Automatic health monitoring
- Snapshot scheduling via external config
- Pool configs persist in ZFS metadata (not Nix)

### Setup

#### 1. Enable the Module

Add to your device configuration (ONE-TIME):

```nix
# hosts/devtower/configuration.nix
imports = [
  ../../modules/storage/zfs.nix
];

services.zfs-runtime = {
  enable = true;
  enableAutoScrub = true;
  scrubInterval = "monthly";
  enableMonitoring = true;
};
```

Rebuild: `just rebuild`

#### 2. Create ZFS Pools

Create a mirrored pool:

```bash
zfs-manage create-pool tank mirror /dev/sda /dev/sdb
```

Create a raidz pool:

```bash
zfs-manage create-pool storage raidz /dev/sdc /dev/sdd /dev/sde /dev/sdf
```

Or use standard `zpool create`:

```bash
sudo zpool create backup /dev/sdg
```

#### 3. Create Datasets

Create a dataset:

```bash
zfs-manage create-dataset tank/data \
  --mountpoint /data \
  --compression lz4
```

Or use standard `zfs create`:

```bash
sudo zfs create -o compression=zstd -o mountpoint=/backups tank/backups
```

#### 4. Setup Automatic Snapshots

Configure hourly snapshots (keep 24):

```bash
zfs-manage setup-snapshots tank/data --frequency hourly --retention 24
```

Configure daily snapshots (keep 30):

```bash
zfs-manage setup-snapshots tank/data --frequency daily --retention 30
```

List snapshot schedules:

```bash
zfs-manage list-schedules
```

### Daily Operations

#### Check Pool Status

```bash
zfs-status
```

Or use standard command:

```bash
zpool status
```

#### Check Pool Health

```bash
zfs-manage health
```

#### List Datasets

```bash
zfs-manage list
```

Or:

```bash
zfs list
```

#### List Snapshots

```bash
zfs-manage snapshots tank/data
```

Or:

```bash
zfs list -t snapshot tank/data
```

#### Take Manual Snapshot

```bash
zfs-manage snapshot tank/data --name backup-before-upgrade
```

Or:

```bash
zfs snapshot tank/data@backup-before-upgrade
```

#### Restore from Snapshot

```bash
# Rollback to latest snapshot
zfs rollback tank/data@auto-daily-2024-01-25

# Clone snapshot to new dataset
zfs clone tank/data@backup-before-upgrade tank/data-restored
```

#### Scrub Pools

Automatic scrubbing is enabled (monthly by default).

Manual scrub:

```bash
sudo zpool scrub tank
```

Check scrub progress:

```bash
zpool status tank
```

#### View ARC Stats

```bash
zfs-manage arc-stats
```

### Snapshot Schedule Configuration

Schedules are stored in: `/etc/zfs/snapshot-schedule.conf`

Format: `dataset:frequency:retention`

Example:

```
# Dataset snapshots
tank/data:hourly:24
tank/data:daily:30
tank/backups:weekly:12
storage/media:monthly:6
```

### Advanced Operations

#### Send/Receive (Replication)

```bash
# Send snapshot to file
zfs send tank/data@snapshot > /tmp/snapshot.zfs

# Send incremental
zfs send -i tank/data@old tank/data@new > /tmp/incremental.zfs

# Receive snapshot
zfs receive backup/data < /tmp/snapshot.zfs

# Replicate to remote
zfs send tank/data@snapshot | ssh remote zfs receive backup/data
```

#### Performance Tuning

```bash
# Adjust ARC size (edit /etc/nixos/configuration.nix)
boot.kernelParams = [
  "zfs.zfs_arc_max=${toString (1024 * 1024 * 1024 * 16)}"  # 16GB
];
```

### Troubleshooting

**Pool won't import?**

```bash
# Force import
sudo zpool import -f tank

# Import by ID
sudo zpool import -d /dev/disk/by-id
```

**Degraded pool?**

```bash
# Check status
zpool status tank

# Replace failed disk
sudo zpool replace tank /dev/old-disk /dev/new-disk
```

**Snapshot taking too much space?**

```bash
# Show space used by snapshots
zfs list -t snapshot -o name,used,referenced

# Delete old snapshots
zfs destroy tank/data@old-snapshot

# Delete range
zfs destroy tank/data@snapshot1%snapshot10
```

---

## RAID Management (mdadm)

### Overview

Runtime Linux software RAID management with health monitoring.

**Key Features:**
- Standard `mdadm` commands work normally
- Helper tools for common operations
- Automatic health checks and alerts
- Email notifications on failures
- Config persists in `/etc/mdadm.conf`

### Setup

#### 1. Enable the Module

Add to your device configuration (ONE-TIME):

```nix
# hosts/nas/configuration.nix
imports = [
  ../../modules/storage/raid.nix
];

services.raid-runtime = {
  enable = true;
  enableMonitoring = true;
  enableAutoScrub = true;
  scrubInterval = "monthly";
  emailOnFailure = "admin@example.com";  # Optional
};
```

Rebuild: `just rebuild`

#### 2. Create RAID Arrays

Create RAID1 (mirror):

```bash
raid-manage create 1 /dev/md0 /dev/sda /dev/sdb
```

Create RAID5:

```bash
raid-manage create 5 /dev/md1 /dev/sdc /dev/sdd /dev/sde /dev/sdf
```

Create RAID10:

```bash
raid-manage create 10 /dev/md2 /dev/sdg /dev/sdh /dev/sdi /dev/sdj
```

Or use standard `mdadm create`:

```bash
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sda /dev/sdb
```

#### 3. Format and Mount

```bash
# Create filesystem
sudo mkfs.ext4 /dev/md0

# Mount
sudo mount /dev/md0 /mnt/raid

# Add to /etc/fstab for auto-mount
echo "/dev/md0 /mnt/raid ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

### Daily Operations

#### Check Array Status

```bash
raid-status
```

Or:

```bash
cat /proc/mdstat
```

Or detailed:

```bash
raid-manage status /dev/md0
```

#### Check Health

```bash
raid-manage health
```

#### Monitor Rebuild Progress

```bash
raid-manage progress
```

Or:

```bash
cat /proc/mdstat
```

#### Add Spare Disk

```bash
raid-manage add /dev/md0 /dev/sdc
```

#### Replace Failed Disk

```bash
# Mark disk as failed
raid-manage fail /dev/md0 /dev/sda

# Remove failed disk
raid-manage remove /dev/md0 /dev/sda

# Add new disk
raid-manage add /dev/md0 /dev/sdz

# Rebuild starts automatically
raid-manage progress
```

### Configuration

RAID configuration is stored in: `/etc/mdadm.conf`

Update after changes:

```bash
raid-manage update-config
```

### Monitoring

Enable monitoring daemon:

```bash
raid-manage monitor --enable
```

Check monitoring status:

```bash
raid-manage monitor
```

View logs:

```bash
journalctl -fu mdmonitor
```

### Troubleshooting

**Array won't start?**

```bash
# Force assembly
raid-manage assemble /dev/md0

# Or manually
sudo mdadm --assemble --force /dev/md0
```

**Degraded array?**

```bash
# Check which disk failed
raid-manage status /dev/md0

# Replace as shown above
```

**Slow rebuild?**

Check speed limits:

```bash
cat /proc/sys/dev/raid/speed_limit_max
cat /proc/sys/dev/raid/speed_limit_min
```

Adjust in module config (edit Nix once):

```nix
services.raid-runtime.checkSpeed = 500000;  # 500MB/s
```

---

## Integration with Secrets

All storage systems integrate with agenix for credential management.

### Restic Secrets

```bash
# Repository password
agenix -e restic-password-<hostname>.age

# B2 credentials
agenix -e restic-b2-env-<hostname>.age

# S3 credentials
agenix -e restic-s3-env-<hostname>.age
```

### Adding to secrets.nix

```nix
# Restic passwords (per-device)
"restic-password-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
"restic-password-devtower.age".publicKeys = allUsers ++ [ devtower ];

# B2 credentials (per-device)
"restic-b2-env-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
"restic-b2-env-devtower.age".publicKeys = allUsers ++ [ devtower ];
```

---

## Quick Reference

### Restic Commands

```bash
restic-manage add-repo <name> <type> <path>
restic-manage list-repos
restic-manage add-backup <name> --paths <paths> --repository <repo>
restic-manage list-backups
restic-backup-now <name>
restic-repo <repo> snapshots
restic-repo <repo> restore latest --target /tmp/restore
```

### ZFS Commands

```bash
zfs-manage create-pool <name> <type> <devices...>
zfs-manage create-dataset <path>
zfs-manage setup-snapshots <dataset> --frequency <freq>
zfs-status
zfs-manage health
zfs-manage snapshot <dataset>
```

### RAID Commands

```bash
raid-manage create <level> <device> <devices...>
raid-manage status
raid-manage health
raid-manage add <array> <device>
raid-manage fail <array> <device>
raid-manage progress
raid-status
```

---

## Best Practices

### Backups

1. **3-2-1 Rule**: 3 copies, 2 different media, 1 offsite
2. **Test restores** regularly
3. **Monitor backup jobs** via systemd
4. **Rotate credentials** annually
5. **Use different passwords** for each repository

### ZFS

1. **Use mirrors or raidz** for redundancy
2. **Enable compression** (lz4 or zstd)
3. **Regular scrubs** (monthly recommended)
4. **Monitor pool health** daily
5. **Keep 10-20% free space** for performance
6. **Use proper ARC size** (leave RAM for apps)

### RAID

1. **Use enterprise drives** for 24/7 operation
2. **Regular scrubs** prevent silent corruption
3. **Replace disks proactively** when SMART warnings appear
4. **Test rebuilds** periodically
5. **Monitor via email** for early warnings
6. **Keep spare disks** on hand

---

## Migrating Existing Storage

### From Manual Restic Setup

1. Copy existing repository config to `/var/lib/restic/<hostname>/config.json`
2. Move credentials to agenix
3. Enable module and rebuild
4. Test with `restic-repo <name> snapshots`

### From Hardcoded NixOS Restic

1. Extract repository URLs and paths
2. Add via `restic-manage add-repo`
3. Add backups via `restic-manage add-backup`
4. Remove old NixOS config
5. Rebuild

### ZFS Pools

ZFS pools automatically import. Just enable the module.

### RAID Arrays

Existing arrays auto-assemble. Run `raid-manage update-config` to update mdadm.conf.

---

## Support

For issues or questions:

1. Check logs: `journalctl -u <service-name>`
2. Verify configs: `cat /var/lib/restic/<hostname>/config.json`
3. Test commands manually
4. Check secrets deployed: `ls -la /run/agenix/`

See also:
- [Restic Documentation](https://restic.readthedocs.io/)
- [ZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [mdadm Manual](https://raid.wiki.kernel.org/)
