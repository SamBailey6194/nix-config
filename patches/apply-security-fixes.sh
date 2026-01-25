#!/usr/bin/env bash
set -euo pipefail

# Security Fixes Application Script
# Applies all security patches from the comprehensive security review

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "========================================"
echo "  Applying Security Fixes"
echo "========================================"
echo

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: Not in a git repository"
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "WARNING: You have uncommitted changes."
    echo "It's recommended to commit or stash them first."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Applying patches in order of severity..."
echo

# HIGH severity patches
echo "==> HIGH SEVERITY FIXES"
for patch in patches/001-high-*.patch patches/002-high-*.patch patches/003-high-*.patch; do
    if [ -f "$patch" ]; then
        echo "  Applying: $(basename "$patch")"
        git apply "$patch" || {
            echo "  ERROR: Failed to apply $patch"
            echo "  You may need to apply it manually or resolve conflicts"
            exit 1
        }
    fi
done
echo

# MEDIUM severity patches
echo "==> MEDIUM SEVERITY FIXES"
for patch in patches/004-medium-*.patch patches/005-medium-*.patch patches/006-medium-*.patch patches/007-medium-*.patch; do
    if [ -f "$patch" ]; then
        echo "  Applying: $(basename "$patch")"
        git apply "$patch" || {
            echo "  ERROR: Failed to apply $patch"
            echo "  You may need to apply it manually or resolve conflicts"
            exit 1
        }
    fi
done
echo

# LOW severity patches
echo "==> LOW SEVERITY FIXES"
for patch in patches/008-low-*.patch; do
    if [ -f "$patch" ]; then
        echo "  Applying: $(basename "$patch")"
        git apply "$patch" || {
            echo "  ERROR: Failed to apply $patch"
            echo "  You may need to apply it manually or resolve conflicts"
            exit 1
        }
    fi
done
echo

echo "✅ All patches applied successfully!"
echo

# Test compilation
echo "==> Testing compilation..."
cd rust
if cargo check --workspace --quiet; then
    echo "✅ Compilation successful!"
else
    echo "❌ Compilation failed. Please review the changes."
    exit 1
fi

cd "$REPO_ROOT"

echo
echo "========================================"
echo "  Security Fixes Applied Successfully"
echo "========================================"
echo
echo "Next steps:"
echo "1. Review the changes: git diff"
echo "2. Run tests: cd rust && cargo test --workspace"
echo "3. Format code: cargo fmt --all"
echo "4. Commit changes: git add -A && git commit -m 'security: Fix 11 vulnerabilities from audit'"
echo "5. Re-enable format-on-save in Zed settings"
echo
