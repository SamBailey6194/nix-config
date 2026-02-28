# NixOS Configuration Management
# Run with: just <command>
# List all commands: just --list

# Repo-level paths (used by sudo commands that lose $HOME)
export NIX_CONFIG_SECRETS_DIR := justfile_directory() / "secrets"

# Default recipe shows help
default:
    @just --list

# ============================================================================
# Secrets Management (Phase 2)
# ============================================================================

# Verify all secrets are deployed correctly
verify-secrets:
    secrets-verify --test-github

# Edit an encrypted secret
edit-secret SECRET:
    agenix-helper edit {{SECRET}}

# List all secrets and their authorized keys
list-secrets:
    agenix-helper list --verbose

# Rekey all secrets (after adding new host keys)
rekey-secrets:
    agenix-helper rekey

# Add a new server with per-device SSH keys
add-server SERVER:
    agenix-helper add-server {{SERVER}}

# Initialize secrets for a new device
init-device DEVICE:
    agenix-helper init {{DEVICE}}

# Check host keys match secrets.nix
check-keys:
    agenix-helper check-keys

# ============================================================================
# Encryption Management
# ============================================================================

# Full TPM2 setup: verify hardware, show LUKS devices, enroll, and confirm
setup-tpm2 DEVICE:
    @echo "=== Step 1: Verify TPM2 hardware ==="
    sudo tpm-manage verify
    @echo ""
    @echo "=== Step 2: Show LUKS devices ==="
    sudo luks-manage status
    @echo ""
    @echo "=== Step 3: Enroll TPM2 for auto-unlock ==="
    sudo luks-manage enroll-tpm2 {{DEVICE}}
    @echo ""
    @echo "=== Step 4: Verify enrolment ==="
    sudo tpm-manage enrolled-devices

# Show LUKS device status
luks-status:
    sudo luks-manage status

# Enroll TPM2 for auto-unlock
enroll-tpm2 DEVICE:
    sudo luks-manage enroll-tpm2 {{DEVICE}}

# Backup LUKS headers
backup-luks-headers:
    sudo luks-manage backup-header /dev/nvme0n1p2

# Test LUKS passphrase
test-luks-passphrase DEVICE:
    sudo luks-manage test-unlock {{DEVICE}}

# Show BTRFS filesystem usage
btrfs-usage:
    sudo btrfs-manage usage /

# List BTRFS snapshots
list-snapshots:
    sudo btrfs-manage list-snapshots

# Create BTRFS snapshot
snapshot SUBVOL NAME="":
    sudo btrfs-manage snapshot {{SUBVOL}} --name {{NAME}}

# Cleanup old snapshots (keep last 7)
cleanup-snapshots KEEP="7":
    sudo btrfs-manage cleanup --keep {{KEEP}}

# Run BTRFS scrub (data integrity check)
scrub PATH="/":
    sudo btrfs-manage scrub {{PATH}}

# Show TPM2 status
tpm-status:
    sudo tpm-manage status

# List TPM2-enrolled devices
tpm-enrolled:
    sudo tpm-manage enrolled-devices

# Verify TPM2 is working
tpm-verify:
    sudo tpm-manage verify

# Create encrypted vault
create-vault NAME:
    vault-manage create {{NAME}}

# Mount encrypted vault
mount-vault NAME:
    vault-manage mount {{NAME}}

# Unmount encrypted vault
unmount-vault NAME:
    vault-manage unmount {{NAME}}

# List all vaults
list-vaults:
    vault-manage list

# Show mounted vaults
vault-status:
    vault-manage status

# ============================================================================
# NixOS System Management
# ============================================================================

# Rebuild current system configuration
rebuild:
    sudo nixos-rebuild switch --flake .

# Rebuild specific host
rebuild-host HOST:
    sudo nixos-rebuild switch --flake .#{{HOST}}

# Build without switching (test configuration)
build:
    sudo nixos-rebuild build --flake .

# Test configuration syntax without building
check:
    nix flake check

# Update flake inputs (nixpkgs, home-manager, etc.)
update:
    nix flake update

# Show system configuration changes (diff)
diff:
    sudo nixos-rebuild build --flake .
    nix store diff-closures /run/current-system ./result

# ============================================================================
# Development
# ============================================================================

# Build Rust tools
build-rust:
    cd rust && cargo build --release

# Test Rust tools
test-rust:
    cd rust && cargo test

# Lint Rust code
lint-rust:
    cd rust && cargo clippy

# Format Rust code
format-rust:
    cd rust && cargo fmt

# Enter nix dev shell with Rust tools
dev:
    nix develop

# ============================================================================
# Fuzzing (Security Testing)
# ============================================================================

# Run all fuzz targets (quick 1-minute test)
fuzz-quick:
    cd rust/fuzz && \
    for target in fuzz_targets/*.rs; do \
        name=$(basename "$target" .rs); \
        echo "Fuzzing $name..."; \
        cargo +nightly fuzz run "$name" -- -max_total_time=60 || exit 1; \
    done

# Run specific fuzz target
fuzz TARGET TIME="300":
    cd rust/fuzz && cargo +nightly fuzz run {{TARGET}} -- -max_total_time={{TIME}}

# Run fuzzing with AddressSanitizer
fuzz-asan TARGET TIME="300":
    cd rust/fuzz && cargo +nightly fuzz run {{TARGET}} --sanitizer address -- -max_total_time={{TIME}}

# Run fuzzing with MemorySanitizer
fuzz-msan TARGET TIME="300":
    cd rust/fuzz && cargo +nightly fuzz run {{TARGET}} --sanitizer memory -- -max_total_time={{TIME}}

# Run fuzzing with UndefinedBehaviorSanitizer
fuzz-ubsan TARGET TIME="300":
    cd rust/fuzz && cargo +nightly fuzz run {{TARGET}} --sanitizer undefined -- -max_total_time={{TIME}}

# Minimize corpus for all targets
fuzz-cmin:
    cd rust/fuzz && \
    for target in fuzz_targets/*.rs; do \
        name=$(basename "$target" .rs); \
        echo "Minimizing corpus for $name..."; \
        cargo +nightly fuzz cmin "$name"; \
    done

# List all fuzz targets
fuzz-list:
    @ls rust/fuzz/fuzz_targets/*.rs | xargs -n1 basename -s .rs

# Check for fuzzing crashes
fuzz-check:
    #!/usr/bin/env bash
    set -euo pipefail
    crashes=$(find rust/fuzz/artifacts -type f 2>/dev/null | wc -l)
    if [ "$crashes" -gt 0 ]; then
        echo "⚠️  Fuzzing crashes found:"
        find rust/fuzz/artifacts -type f -exec echo "  - {}" \;
        exit 1
    else
        echo "✅ No fuzzing crashes found"
    fi

# Clean fuzzing artifacts (crashes and corpus)
fuzz-clean:
    rm -rf rust/fuzz/artifacts
    rm -rf rust/fuzz/target

# ============================================================================
# Linting and Formatting
# ============================================================================

# Run all linters
lint: lint-rust lint-nix

# Lint Nix files
lint-nix:
    @echo "Checking Nix syntax..."
    @find . -name "*.nix" -not -path "*/.*" -exec nix-instantiate --parse {} \; > /dev/null

# Format all code
format: format-rust format-nix

# Format Nix files
format-nix:
    @echo "Formatting Nix files..."
    @find . -name "*.nix" -not -path "*/.*" -exec nixpkgs-fmt {} \;

# ============================================================================
# Git and Version Control
# ============================================================================

# Commit with conventional commit message
commit MESSAGE:
    git add -A
    git commit -m "{{MESSAGE}}"

# Create a new feature branch
branch NAME:
    git checkout -b {{NAME}}

# Push current branch to origin
push:
    git push origin $(git branch --show-current)

# Pull latest changes
pull:
    git pull origin $(git branch --show-current)

# ============================================================================
# Cleanup
# ============================================================================

# Clean up old generations (keep last 3)
clean-generations:
    sudo nix-collect-garbage --delete-older-than 30d
    sudo nixos-rebuild boot

# Clean up Rust build artifacts
clean-rust:
    cd rust && cargo clean

# Full cleanup (generations + Rust)
clean-all: clean-rust clean-generations

# ============================================================================
# Information
# ============================================================================

# Show current system generation
show-generation:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Show installed packages
show-packages:
    nix-env -q

# Show system info
info:
    @echo "Hostname: $(hostname)"
    @echo "NixOS Version: $(nixos-version)"
    @echo "Kernel: $(uname -r)"
    @echo "Flake: $(nix flake metadata . --json | jq -r '.url')"

# Show flake inputs
show-inputs:
    nix flake metadata . --json | jq '.locks.nodes'

# ============================================================================
# VPN Management (Phase 6: Wireguard + Mullvad)
# ============================================================================

# Initialize WireGuard for a device
vpn-init DEVICE:
    sudo NIX_CONFIG_SECRETS_DIR="{{justfile_directory()}}/secrets" wireguard-helper init {{DEVICE}}

# Rotate Mullvad multi-hop servers (entry → UK exit). Keys are never rotated.
# Device addresses are read from /etc/wireguard/device-addresses (written by NixOS module).
vpn-rotate DEVICE="laptop-intel":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f /etc/wireguard/device-addresses ]; then
        echo "ERROR: /etc/wireguard/device-addresses not found."
        echo "Ensure networking.wireguard-mullvad.deviceAddress is set in your NixOS config and rebuild."
        exit 1
    fi
    source /etc/wireguard/device-addresses
    sudo NIX_CONFIG_SECRETS_DIR="{{justfile_directory()}}/secrets" \
        wireguard-helper rotate {{DEVICE}} \
        --address "$DEVICE_ADDRESS" \
        --address6 "$DEVICE_ADDRESS6"
    echo "Run 'just rebuild && just vpn-restart' to apply new configuration"

# Verify VPN connection and exit location
vpn-verify:
    wireguard-helper verify

# Show VPN status
vpn-status:
    wireguard-helper status

# View VPN metrics
vpn-metrics:
    wireguard-helper metrics --tail --lines 20

# Start VPN
vpn-up:
    sudo systemctl start wg-quick-mullvad0

# Stop VPN
vpn-down:
    sudo systemctl stop wg-quick-mullvad0

# Restart VPN
vpn-restart:
    sudo systemctl restart wg-quick-mullvad0

# Kill VPN completely (stop tunnel + disable kill switch firewall)
vpn-kill:
    sudo systemctl stop wg-quick-mullvad0 || true
    sudo systemctl stop firewall || true
    @echo "VPN tunnel stopped and kill switch firewall disabled"

# Launch app through VPN (via cgroup routing)
vpn-app COMMAND:
    wireguard-helper vpn-app {{COMMAND}}

# ============================================================================
# Malware Scanner (Phase 7)
# ============================================================================

# Scan a file or directory for malware
scan PATH:
    malware-scanner scan {{PATH}}

# Scan with auto-quarantine
scan-quarantine PATH:
    malware-scanner scan {{PATH}} --quarantine

# Run EICAR test to verify scanner is working
test-scanner:
    malware-scanner test

# Perform manual boot scan
boot-scan:
    sudo malware-scanner boot-scan

# Show malware scanner statistics
scanner-stats:
    malware-scanner stats

# List quarantined files
quarantine-list:
    malware-scanner quarantine list

# Show quarantine size
quarantine-size:
    malware-scanner quarantine size

# Restore file from quarantine
quarantine-restore ID PATH:
    malware-scanner quarantine restore {{ID}} {{PATH}}

# Delete quarantined file permanently
quarantine-delete ID:
    malware-scanner quarantine delete {{ID}}

# Cleanup old quarantine entries
quarantine-cleanup:
    malware-scanner quarantine cleanup

# Show recent threat detections
threats-recent:
    malware-scanner database recent --limit 20

# Update malware signatures
update-signatures:
    sudo malware-scanner update

# View real-time monitor logs
scanner-logs:
    journalctl -fu malware-monitor

# Restart real-time monitor
scanner-restart:
    sudo systemctl restart malware-monitor

# ============================================================================
# Storage Management (Phase 8)
# ============================================================================

# Restic Backup Management
# ----------------------------------------------------------------------------

# Add a Restic backup repository
restic-add-repo NAME TYPE PATH:
    restic-manage add-repo {{NAME}} {{TYPE}} {{PATH}}

# Remove a Restic repository
restic-remove-repo NAME:
    restic-manage remove-repo {{NAME}}

# List all Restic repositories
restic-list-repos:
    restic-manage list-repos --verbose

# Add a backup job
restic-add-backup NAME PATHS REPO:
    restic-manage add-backup {{NAME}} --paths {{PATHS}} --repository {{REPO}}

# Remove a backup job
restic-remove-backup NAME:
    restic-manage remove-backup {{NAME}}

# List all backup jobs
restic-list-backups:
    restic-manage list-backups --verbose

# Initialize a repository
restic-init NAME:
    restic-manage init-repo {{NAME}}

# Test repository connection
restic-test NAME:
    restic-manage test-repo {{NAME}}

# Generate systemd services for backups
restic-generate:
    restic-manage generate-services

# Run a backup immediately
backup-now NAME:
    restic-backup-now {{NAME}}

# Show backup status
backup-status:
    restic-status

# List snapshots in a repository
restic-snapshots REPO:
    restic-repo {{REPO}} snapshots

# Restore from backup
restic-restore REPO SNAPSHOT TARGET:
    restic-repo {{REPO}} restore {{SNAPSHOT}} --target {{TARGET}}

# Check repository integrity
restic-check REPO:
    restic-repo {{REPO}} check

# Prune old snapshots
restic-prune REPO:
    restic-repo {{REPO}} forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

# ZFS Management
# ----------------------------------------------------------------------------

# Create a ZFS pool
zfs-pool NAME TYPE DEVICES:
    zfs-manage create-pool {{NAME}} {{TYPE}} {{DEVICES}}

# Create a ZFS dataset
zfs-dataset PATH:
    zfs-manage create-dataset {{PATH}}

# Setup automatic snapshots
zfs-snapshots DATASET FREQ:
    zfs-manage setup-snapshots {{DATASET}} --frequency {{FREQ}}

# List snapshot schedules
zfs-list-schedules:
    zfs-manage list-schedules

# Show ZFS status
zfs-status:
    zfs-status

# Check ZFS health
zfs-health:
    zfs-manage health

# List all datasets
zfs-list:
    zfs-manage list

# Take manual snapshot
zfs-snap DATASET:
    zfs-manage snapshot {{DATASET}}

# Show ARC statistics
zfs-arc:
    zfs-manage arc-stats

# RAID Management
# ----------------------------------------------------------------------------

# Create a RAID array
raid-create LEVEL DEVICE DEVICES:
    raid-manage create {{LEVEL}} {{DEVICE}} {{DEVICES}}

# Show RAID status
raid-status:
    raid-status

# Check RAID health
raid-health:
    raid-manage health

# Show /proc/mdstat
raid-mdstat:
    raid-manage mdstat

# Add disk to array
raid-add ARRAY DEVICE:
    raid-manage add {{ARRAY}} {{DEVICE}}

# Mark disk as failed
raid-fail ARRAY DEVICE:
    raid-manage fail {{ARRAY}} {{DEVICE}}

# Remove disk from array
raid-remove ARRAY DEVICE:
    raid-manage remove {{ARRAY}} {{DEVICE}}

# Show rebuild progress
raid-progress:
    raid-manage progress

# Update mdadm.conf
raid-update-config:
    raid-manage update-config

# Enable RAID monitoring
raid-monitor-enable:
    raid-manage monitor --enable

# Disable RAID monitoring
raid-monitor-disable:
    raid-manage monitor --disable

# ============================================================================
# Installation (Phase 1)
# ============================================================================

# Install NixOS on a new device
install-nixos DEVICE:
    @echo "Installing NixOS with configuration: {{DEVICE}}"
    @echo "Make sure you've partitioned and mounted filesystems first!"
    sudo nixos-install --flake .#{{DEVICE}}

# Generate hardware configuration for current device
gen-hardware:
    sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
    @echo "Hardware configuration saved to hardware-configuration.nix"
    @echo "Review and move to hosts/<hostname>/hardware-configuration.nix"
