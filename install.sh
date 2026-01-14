#!/bin/bash
set -e

ZEDCONFIG="$HOME/Repos/personal/zedconfig"

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
backup_if_exists ~/.config/zed/debug.json

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
echo "  cd ~/Repos/personal/any-repo && git config user.email"
echo "  cd ~/Repos/syntek/any-repo && git config user.email"
echo "  cd ~/Repos/missional-gen/any-repo && git config user.email"
echo ""
echo "Install dependencies if not done:"
echo "  See README.md for full list"
