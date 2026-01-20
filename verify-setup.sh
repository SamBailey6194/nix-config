#!/bin/bash

# ============================================
# ENVIRONMENT DETECTION
# ============================================
detect_environment() {
    IS_WSL=false
    IS_LINUX=false
    IS_MACOS=false

    if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
        IS_WSL=true
        IS_LINUX=true
        ENV_NAME="WSL (Windows Subsystem for Linux)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        IS_LINUX=true
        ENV_NAME="Native Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        IS_MACOS=true
        ENV_NAME="macOS"
    else
        ENV_NAME="Unknown ($OSTYPE)"
    fi
}

# ============================================
# HELPER FUNCTIONS
# ============================================
check_command() {
    local cmd="$1"
    local name="${2:-$1}"
    local version_cmd="$3"

    if command -v "$cmd" &>/dev/null; then
        if [[ -n "$version_cmd" ]]; then
            local version
            version=$(eval "$version_cmd" 2>/dev/null)
            echo "✓ $name $version"
        else
            echo "✓ $name"
        fi
        return 0
    else
        echo "✗ $name"
        return 1
    fi
}

check_file() {
    local path="$1"
    local name="$2"

    if [ -f "$path" ]; then
        echo "✓ $name"
        return 0
    else
        echo "✗ $name"
        return 1
    fi
}

check_symlink() {
    local path="$1"
    local name="$2"

    if [ -L "$path" ]; then
        echo "✓ $name"
        return 0
    else
        echo "✗ $name"
        return 1
    fi
}

check_dir() {
    local path="$1"
    local name="${2:-$1}"

    if [ -d "$path" ]; then
        echo "✓ $name"
        return 0
    else
        echo "✗ $name"
        return 1
    fi
}

# ============================================
# MAIN VERIFICATION
# ============================================
detect_environment

echo "=== Zedconfig Setup Verification ==="
echo ""
echo "Environment: $ENV_NAME"
echo ""

# Track failures
FAILED=0

echo "=== System Tools ==="
check_command git git "git --version | cut -d' ' -f3" || ((FAILED++))
check_command curl || ((FAILED++))
check_command zsh zsh "zsh --version | cut -d' ' -f2" || ((FAILED++))
check_command jq || ((FAILED++))
check_command rg ripgrep "rg --version | head -1 | cut -d' ' -f2" || ((FAILED++))
# fd is named differently on some systems
(check_command fdfind fd-find || check_command fd fd) || ((FAILED++))
# bat is named differently on some systems
(check_command batcat bat || check_command bat bat) || ((FAILED++))
check_command entr || ((FAILED++))
echo ""

echo "=== Shell ==="
check_dir "$HOME/.oh-my-zsh" "Oh My Zsh" || ((FAILED++))
if [[ "$IS_WSL" == true ]]; then
    echo "  (WSL: Zed should use wsl.exe as terminal shell)"
fi
echo ""

echo "=== Editors ==="
if [[ "$IS_WSL" == true ]]; then
    # In WSL, Zed runs on Windows side
    if command -v zed.exe &>/dev/null || [ -f "/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')/AppData/Local/Programs/Zed/Zed.exe" ] 2>/dev/null; then
        echo "✓ zed (Windows)"
    else
        echo "✗ zed (check Windows installation)"
    fi
else
    check_command zed || ((FAILED++))
fi
echo ""

echo "=== Node.js ==="
check_command node node "node --version" || ((FAILED++))
check_command npm npm "npm --version" || ((FAILED++))
check_dir "$HOME/.nvm" "nvm"
echo ""

echo "=== npm Global Packages ==="
check_command prettier || ((FAILED++))
check_command eslint || ((FAILED++))
check_command tsc typescript || ((FAILED++))
check_command markdownlint-cli2 || ((FAILED++))
check_command markdown-toc
echo ""

echo "=== Python Tools ==="
check_command python3 python3 "python3 --version | cut -d' ' -f2" || ((FAILED++))
check_command pipx
check_command ruff ruff "ruff --version | cut -d' ' -f2" || ((FAILED++))
# basedpyright or pyright
(check_command basedpyright basedpyright || check_command pyright pyright) || ((FAILED++))
check_command pip-audit
echo ""

echo "=== Rust Tools ==="
check_command rustc rustc "rustc --version | cut -d' ' -f2"
check_command cargo cargo "cargo --version | cut -d' ' -f2"
check_command just just "just --version | cut -d' ' -f2"
check_command rust-analyzer
cargo audit --version &>/dev/null && echo "✓ cargo-audit" || echo "✗ cargo-audit"
echo ""

echo "=== GitHub CLI ==="
check_command gh gh "gh --version | head -1 | cut -d' ' -f3"
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null 2>&1; then
        echo "✓ gh auth (logged in)"
    else
        echo "✗ gh auth (not logged in - run: gh auth login)"
    fi
fi
echo ""

echo "=== PHP Tools (optional) ==="
check_command php php "php --version | head -1 | cut -d' ' -f2"
check_command composer composer "composer --version | cut -d' ' -f3"
check_command php-cs-fixer
echo ""

echo "=== SSH Keys ==="
check_file ~/.ssh/id_ed25519_personal "personal key"
check_file ~/.ssh/id_ed25519_syntek "syntek key"
check_file ~/.ssh/id_ed25519_mg "missional-gen key"
check_file ~/.ssh/config "ssh config"
echo ""

echo "=== Directories ==="
check_dir ~/Repos/personal "~/Repos/personal"
check_dir ~/Repos/syntek "~/Repos/syntek"
check_dir ~/Repos/missional-gen "~/Repos/missional-gen"
echo ""

echo "=== Symlinks (run after install.sh) ==="
check_symlink ~/.config/zed/settings.json "zed/settings.json"
check_symlink ~/.config/zed/keymap.json "zed/keymap.json"
check_symlink ~/.config/zed/debug.json "zed/debug.json"
check_symlink ~/.gitconfig ".gitconfig"
check_symlink ~/.gitconfig-personal ".gitconfig-personal"
check_symlink ~/.gitconfig-syntek ".gitconfig-syntek"
check_symlink ~/.gitconfig-missional-gen ".gitconfig-missional-gen"
check_symlink ~/.gitmessage ".gitmessage"
check_symlink ~/.config/git/hooks/pre-commit "git hooks/pre-commit"
check_symlink ~/.editorconfig ".editorconfig"
check_symlink ~/.eslintrc.json ".eslintrc.json"
check_symlink ~/eslint.config.js "eslint.config.js"
check_symlink ~/.markdownlint.json ".markdownlint.json"
check_symlink ~/.prettierrc ".prettierrc"
check_symlink ~/.config/ruff/ruff.toml "ruff/ruff.toml"
check_symlink ~/.config/pyright/pyrightconfig.json "pyright/pyrightconfig.json"
check_symlink ~/justfile "justfile"
echo ""

# WSL-specific checks
if [[ "$IS_WSL" == true ]]; then
    echo "=== WSL Integration ==="
    check_dir /mnt/c "Windows C: drive access"

    # Check if Windows user folder is accessible
    WIN_USER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
    if [[ -n "$WIN_USER" ]] && [ -d "/mnt/c/Users/$WIN_USER" ]; then
        echo "✓ Windows user folder (/mnt/c/Users/$WIN_USER)"
    else
        echo "✗ Windows user folder"
    fi
    echo ""

    echo "=== WSL Tips ==="
    echo "• Your Linux home: $HOME"
    echo "• Windows files: /mnt/c/Users/$WIN_USER/"
    echo "• Windows accesses WSL: \\\\wsl\$\\Ubuntu$HOME"
    echo ""
fi

echo "=== Verification Complete ==="
if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Some required tools are missing. Run: ./install.sh --deps"
fi
