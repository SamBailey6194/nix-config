# NixOS Configuration Management
# Run with: just <command>
# List all commands: just --list

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
