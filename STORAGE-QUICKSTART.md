# Storage Management Quick Start

Runtime-configurable storage systems without editing Nix files.

## Key Concept

**Framework vs Configuration:**
- NixOS modules = Framework (tools, services, monitoring)
- Runtime config = User-managed (JSON, CLI, standard tools)
- No Nix editing needed after initial setup

## Restic Backups

### 1. Enable (ONE-TIME)

```nix
# hosts/<device>/configuration.nix
services.restic-runtime.enable = true;
```

Rebuild: `just rebuild`

### 2. Create Password Secret

```bash
agenix -e restic-password-laptop-intel.age
# Enter strong password

# Add to secrets/secrets.nix
"restic-password-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];

just rebuild
```

### 3. Configure Repository

```bash
# Local backup
restic-manage add-repo local local /mnt/backups

# Backblaze B2
restic-manage add-repo b2 b2 b2:bucket:/path

# Initialize
restic-manage init-repo local
```

### 4. Configure Backup

```bash
restic-manage add-backup home \
  --paths /home \
  --repository local \
  --schedule daily
```

### 5. Enable

```bash
restic-manage generate-services
sudo systemctl enable --now restic-backup@home.timer
```

### Daily Use

```bash
restic-status                           # Check status
restic-backup-now home                  # Run now
restic-repo local snapshots             # List snapshots
restic-repo local restore latest --target /tmp/restore
```

## ZFS Storage

### 1. Enable (ONE-TIME)

```nix
# hosts/<device>/configuration.nix
services.zfs-runtime.enable = true;
```

Rebuild: `just rebuild`

### 2. Create Pool

```bash
# Mirror
zfs-manage create-pool tank mirror /dev/sda /dev/sdb

# RAIDZ
zfs-manage create-pool storage raidz /dev/sdc /dev/sdd /dev/sde
```

### 3. Create Dataset

```bash
zfs-manage create-dataset tank/data \
  --mountpoint /data \
  --compression lz4
```

### 4. Setup Snapshots

```bash
zfs-manage setup-snapshots tank/data \
  --frequency daily \
  --retention 30
```

### Daily Use

```bash
zfs-status                              # Pool status
zfs-manage health                       # Health check
zfs-manage snapshot tank/data           # Manual snapshot
zfs list -t snapshot                    # List snapshots
zfs rollback tank/data@snapshot         # Restore
```

## RAID Management

### 1. Enable (ONE-TIME)

```nix
# hosts/<device>/configuration.nix
services.raid-runtime.enable = true;
```

Rebuild: `just rebuild`

### 2. Create Array

```bash
# RAID1
raid-manage create 1 /dev/md0 /dev/sda /dev/sdb

# RAID5
raid-manage create 5 /dev/md1 /dev/sdc /dev/sdd /dev/sde
```

### 3. Format and Mount

```bash
sudo mkfs.ext4 /dev/md0
sudo mount /dev/md0 /mnt/raid
```

### 4. Enable Monitoring

```bash
raid-manage monitor --enable
```

### Daily Use

```bash
raid-status                             # Array status
raid-manage health                      # Health check
raid-manage progress                    # Rebuild progress
raid-manage add /dev/md0 /dev/sdf       # Add disk
```

## Just Commands

### Restic

```bash
just restic-add-repo local local /mnt/backups
just restic-add-backup home /home local
just backup-now home
just restic-snapshots local
```

### ZFS

```bash
just zfs-pool tank mirror "/dev/sda /dev/sdb"
just zfs-dataset tank/data
just zfs-snapshots tank/data daily
just zfs-status
```

### RAID

```bash
just raid-create 1 /dev/md0 "/dev/sda /dev/sdb"
just raid-status
just raid-health
```

## Configuration Locations

- Restic: `/var/lib/restic/<hostname>/config.json`
- ZFS: `/etc/zfs/snapshot-schedule.conf`
- RAID: `/etc/mdadm.conf`

## Documentation

Full guide: `/home/sam-dev/Repos/personal/nix-config/docs/STORAGE-MANAGEMENT.md`

## Key Features

- **No Nix editing** after initial module enable
- **Per-device config** in `/var/lib/` and `/etc/`
- **Standard tools work** (restic, zpool, zfs, mdadm)
- **Secrets via agenix** (passwords, credentials)
- **Automatic monitoring** and health checks
- **Systemd integration** for scheduling

## Troubleshooting

Check logs:
```bash
journalctl -u restic-backup@home.service
journalctl -u mdmonitor
systemctl status zfs-health-check
```

Check configs:
```bash
cat /var/lib/restic/<hostname>/config.json
cat /etc/zfs/snapshot-schedule.conf
cat /etc/mdadm.conf
```

Check secrets:
```bash
ls -la /run/agenix/restic-*
```
