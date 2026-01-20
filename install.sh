#!/bin/bash
set -e

ZEDCONFIG="$HOME/Repos/personal/zedconfig"

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
        echo "Environment: WSL (Windows Subsystem for Linux)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        IS_LINUX=true
        echo "Environment: Native Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        IS_MACOS=true
        echo "Environment: macOS"
    else
        echo "Environment: Unknown ($OSTYPE)"
    fi
}

# ============================================
# TOOL INSTALLATION (optional, run with --deps)
# ============================================
install_dependencies() {
    echo "=== Installing Development Dependencies ==="
    echo ""

    detect_environment
    echo ""

    # Detect package manager
    PKG_MANAGER="none"
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
    elif command -v brew &> /dev/null; then
        PKG_MANAGER="brew"
    fi

    # Install system packages
    if [[ "$PKG_MANAGER" != "none" ]]; then
        echo "→ System packages ($PKG_MANAGER)"
        case $PKG_MANAGER in
            apt)
                sudo apt update
                sudo apt install -y git curl zsh jq ripgrep fd-find bat entr python3-pip python3-venv
                ;;
            dnf)
                sudo dnf install -y git curl zsh jq ripgrep fd-find bat entr python3-pip
                ;;
            pacman)
                sudo pacman -S --noconfirm git curl zsh jq ripgrep fd bat entr python-pip
                ;;
            brew)
                brew install git curl zsh jq ripgrep fd bat entr python
                ;;
        esac
    else
        echo "→ No supported package manager found. Install system packages manually:"
        echo "  git, curl, zsh, jq, ripgrep, fd-find, bat, entr"
    fi

    # Install Oh My Zsh if not present
    echo ""
    echo "→ Oh My Zsh"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "  Already installed"
    else
        echo "  Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Node.js (suggest nvm if not installed)
    echo ""
    echo "→ Node.js tools"
    if ! command -v node &> /dev/null; then
        echo "  Node.js not found. Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
    fi

    if command -v node &> /dev/null; then
        echo "  Node $(node --version) found"
        echo "  Installing npm global packages..."
        npm install -g prettier eslint typescript markdownlint-cli2 markdown-toc
    fi

    # Python tools (via pipx for isolation)
    echo ""
    echo "→ Python tools"
    if ! command -v pipx &> /dev/null; then
        echo "  Installing pipx..."
        python3 -m pip install --user pipx
        python3 -m pipx ensurepath
        # Add to current session
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if command -v pipx &> /dev/null; then
        echo "  Installing Python tools via pipx..."
        pipx install ruff || pipx upgrade ruff
        pipx install basedpyright || pipx upgrade basedpyright
        pipx install pip-audit || pipx upgrade pip-audit
    else
        echo "  pipx not available. Restart terminal and re-run, or install manually."
    fi

    # Rust tools
    echo ""
    echo "→ Rust tools"
    if ! command -v rustup &> /dev/null; then
        echo "  Rust not found. Installing rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    if command -v rustup &> /dev/null; then
        echo "  Rust $(rustc --version 2>/dev/null | cut -d' ' -f2) found"
        rustup component add clippy rustfmt rust-analyzer
        cargo install just || true
        cargo install cargo-audit || true
    fi

    # GitHub CLI
    echo ""
    echo "→ GitHub CLI"
    if command -v gh &> /dev/null; then
        echo "  Already installed: $(gh --version | head -1)"
    else
        echo "  Installing GitHub CLI..."
        case $PKG_MANAGER in
            apt)
                # Add GitHub CLI repository
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt update
                sudo apt install -y gh
                ;;
            dnf)
                sudo dnf install -y gh
                ;;
            pacman)
                sudo pacman -S --noconfirm github-cli
                ;;
            brew)
                brew install gh
                ;;
            *)
                echo "  Could not install automatically. Visit: https://cli.github.com"
                ;;
        esac
    fi

    # PHP tools (optional)
    echo ""
    echo "→ PHP tools (optional)"
    if command -v composer &> /dev/null; then
        composer global require friendsofphp/php-cs-fixer
    else
        echo "  Composer not found. Skipping PHP tools."
        echo "  Install Composer from: https://getcomposer.org"
    fi

    # WSL-specific tips
    if [[ "$IS_WSL" == true ]]; then
        echo ""
        echo "=== WSL Tips ==="
        echo "• Access Windows files at: /mnt/c/Users/YourName/"
        echo "• Windows can access WSL files at: \\\\wsl$\\Ubuntu\\home\\$USER"
        echo "• Zed terminal config for WSL:"
        echo '  "terminal": { "shell": { "program": "wsl.exe", "args": ["-d", "Ubuntu"] } }'
    fi

    echo ""
    echo "=== Dependencies Installation Complete ==="
    echo ""
    echo "You may need to restart your terminal for PATH changes to take effect."
    echo ""
}

# Check for --deps flag
if [[ "$1" == "--deps" ]]; then
    install_dependencies
    exit 0
fi

echo "=== Installing Zed Configuration ==="

# Create directories
mkdir -p ~/.config/zed
mkdir -p ~/.config/git/hooks
mkdir -p ~/.config/ruff
mkdir -p ~/.config/pyright

# Backup existing configs
backup_if_exists() {
    if [ -f "$1" ] && [ ! -L "$1" ]; then
        echo "Backing up $1 to $1.bak"
        mv "$1" "$1.bak"
    fi
}

backup_if_exists ~/.gitconfig
backup_if_exists ~/.gitconfig-personal
backup_if_exists ~/.gitconfig-syntek
backup_if_exists ~/.gitconfig-missional-gen
backup_if_exists ~/.gitmessage
backup_if_exists ~/.editorconfig
backup_if_exists ~/.prettierrc
backup_if_exists ~/.eslintrc.json
backup_if_exists ~/.markdownlint.json
backup_if_exists ~/.config/zed/settings.json
backup_if_exists ~/.config/zed/keymap.json
backup_if_exists ~/.config/zed/debug.json
backup_if_exists ~/eslint.config.js

# Symlink Zed config
echo "→ Zed config"
ln -sf "$ZEDCONFIG/config/zed/settings.json" ~/.config/zed/settings.json
ln -sf "$ZEDCONFIG/config/zed/keymap.json" ~/.config/zed/keymap.json
ln -sf "$ZEDCONFIG/config/zed/debug.json" ~/.config/zed/debug.json

# Symlink Git config
echo "→ Git config"
ln -sf "$ZEDCONFIG/config/git/config" ~/.gitconfig
ln -sf "$ZEDCONFIG/config/git/config-personal" ~/.gitconfig-personal
ln -sf "$ZEDCONFIG/config/git/config-syntek" ~/.gitconfig-syntek
ln -sf "$ZEDCONFIG/config/git/config-missional-gen" ~/.gitconfig-missional-gen
ln -sf "$ZEDCONFIG/config/git/gitmessage" ~/.gitmessage

# Symlink git hooks
echo "→ Git hooks"
ln -sf "$ZEDCONFIG/config/git/hooks/pre-commit" ~/.config/git/hooks/pre-commit
chmod +x ~/.config/git/hooks/pre-commit

# Set global git hooks path
git config --global core.hooksPath ~/.config/git/hooks

# Symlink linter configs
echo "→ Linter configs"
ln -sf "$ZEDCONFIG/linters/.editorconfig" ~/.editorconfig
ln -sf "$ZEDCONFIG/linters/.eslintrc.json" ~/.eslintrc.json
ln -sf "$ZEDCONFIG/linters/eslint.config.js" ~/eslint.config.js
ln -sf "$ZEDCONFIG/linters/.markdownlint.json" ~/.markdownlint.json
ln -sf "$ZEDCONFIG/linters/.prettierrc" ~/.prettierrc
ln -sf "$ZEDCONFIG/linters/ruff.toml" ~/.config/ruff/ruff.toml
ln -sf "$ZEDCONFIG/linters/pyrightconfig.json" ~/.config/pyright/pyrightconfig.json

# Symlink justfile
echo "→ Justfile"
ln -sf "$ZEDCONFIG/justfile" ~/justfile

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Verify setup:"
echo "  ./verify-setup.sh"
echo ""
echo "Verify git accounts:"
echo "  cd ~/Repos/personal/any-repo && git config user.email"
echo "  cd ~/Repos/syntek/any-repo && git config user.email"
echo "  cd ~/Repos/missional-gen/any-repo && git config user.email"
echo ""
echo "Install dev tools (formatters, linters, LSPs):"
echo "  ./install.sh --deps"
