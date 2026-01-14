# Zed Configuration

Personal Zed editor configuration with global linting, formatting, git hooks, and multi-account git setup.

<!-- toc -->

<!-- tocstop -->

## Project Structure

zedconfig/
├── README.md
├── install.sh
├── verify-setup.sh
├── config/
│   ├── git/
│   │   ├── config
│   │   ├── config-personal
│   │   ├── config-syntek
│   │   ├── config-missional-gen
│   │   ├── gitmessage
│   │   └── hooks/
│   │       └── pre-commit
│   └── zed/
│       ├── settings.json
│       └── keymap.json
├── linters/
│   ├── .editorconfig
│   ├── .eslintrc.json
│   ├── .markdownlint.json
│   ├── .prettierrc
│   ├── pyrightconfig.json
│   └── ruff.toml
└── justfile

## Prerequisites

Before running `install.sh`, ensure these are set up:

### SSH Keys

```text
~/.ssh/id_ed25519_personal
~/.ssh/id_ed25519_syntek
~/.ssh/id_ed25519_mg
~/.ssh/config
```

### Directories

```bash
mkdir -p ~/Repos/{personal,syntek,missional-gen}
```

### Required Tools

- git, curl, zsh
- Node.js and npm
- Python 3
- Rust toolchain (rustc, cargo)

Run `./verify-setup.sh` to check all prerequisites.

## Stack Support

- Python (Ruff, Pyright)
- TypeScript/JavaScript (Prettier, ESLint, tsc)
- Rust (rustfmt, Clippy)
- Markdown (Prettier, markdownlint)
- PHP (php-cs-fixer, Intelephense)
- GraphQL
- Tailwind CSS

## Installation
```bash
git clone git@github-personal:SamBailey6194/zedconfig.git ~/Repos/personal/zedconfig
cd ~/Repos/personal/zedconfig
chmod +x install.sh
./install.sh
```

## Dependencies

### System
```bash
sudo apt install entr ripgrep fd-find bat jq
```

### npm
```bash
npm install -g prettier eslint typescript typescript-language-server markdownlint-cli2 markdown-toc onchange @tailwindcss/language-server graphql-language-service-cli intelephense vscode-langservers-extracted @eslint/create-config
```

### pip
```bash
pip install --break-system-packages ruff pyright pip-audit python-lsp-server django-stubs djangorestframework-stubs
```

### cargo
```bash
cargo install just cargo-husky cargo-audit cargo-deny cargo-tarpaulin
rustup component add rust-analyzer
```

### PHP
```bash
composer global require friendsofphp/php-cs-fixer
```

### Zed
```bash
curl -f https://zed.dev/install.sh | sh
```

## Git Accounts

This config supports multiple GitHub accounts:

| Folder | Account | Email |
|--------|---------|-------|
| `~/Repos/personal/` | SamBailey6194 | samabailey6194@gmail.com |
| `~/Repos/syntek/` | syntek-studio | sam.bailey@syntekstudio.com |
| `~/Repos/missional-gen/` | sam-missionalgen | sam@missionalgen.co.uk |

## Layout
```
┌──────────┬─────────────────────────┬──────────────┐
│ Files    │                         │              │
│ (280px)  │      Main Editor        │  Claude CLI  │
├──────────┤    (multiple tabs)      │   (480px)    │
│ Git      │                         │              │
│ Changes  │                         │              │
├──────────┴─────────────────────────┴──────────────┤
│  Terminal 1                │  Terminal 2          │
│  (50000 lines)             │  (50000 lines)       │
└────────────────────────────┴──────────────────────┘
```

## Key Bindings

| Key | Action |
|-----|--------|
| `Ctrl+P` | File finder |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+E` | Toggle file explorer |
| `Ctrl+Shift+G` | Toggle git panel |
| `Ctrl+`` | Toggle terminal |
| `Ctrl+Shift+`` | New terminal |
| `Ctrl+Shift+M` | Diagnostics |
| `Ctrl+\` | Split pane right |
| `Ctrl+Shift+\` | Split pane down |
| `Alt+1-5` | Switch to tab 1-5 |
| `F12` | Go to definition |
| `Shift+F12` | Find references |
| `F2` | Rename |
| `Ctrl+D` | Multi-cursor |

## Usage

### Daily Workflow
```bash
cd ~/Repos/syntek/project
zed .
just watch-md &  # if working with docs
```

### Commands

| Command | Description |
|---------|-------------|
| `just lint` | Run all linters |
| `just format` | Run all formatters |
| `just audit` | Full security audit |
| `just watch-md` | Watch markdown files |
| `just watch-py` | Watch Python files |
| `just watch-ts` | Watch TypeScript files |

## Verify Git Config
```bash
cd ~/Repos/personal/any-repo && git config user.email
# samabailey6194@gmail.com

cd ~/Repos/syntek/any-repo && git config user.email
# sam.bailey@syntekstudio.com

cd ~/Repos/missional-gen/any-repo && git config user.email
# sam@missionalgen.co.uk
```