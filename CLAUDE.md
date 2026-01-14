# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Portable Zed IDE and development environment configuration for multi-device deployment. One-command installation symlinks all configs to their expected locations.

## Architecture

```
zedconfig/
├── install.sh              # Symlinks configs to system locations
├── config/
│   ├── git/                # Multi-account git setup
│   │   ├── config          # Main gitconfig with conditional includes
│   │   ├── config-personal, config-syntek, config-missional-gen
│   │   ├── gitmessage      # Commit message template
│   │   └── hooks/pre-commit
│   └── zed/
│       ├── settings.json   # Editor settings
│       └── keymap.json     # Keybindings
├── linters/                # Shared linter configs
│   └── .editorconfig, .eslintrc.json, .markdownlint.json,
│       .prettierrc, pyrightconfig.json, ruff.toml
└── justfile                # Task runner
```

## Commands

```bash
just lint       # Run all linters
just format     # Run all formatters
just audit      # Full security audit
just watch-md   # Watch markdown files
just watch-py   # Watch Python files
just watch-ts   # Watch TypeScript files
```

## Multi-Account Git

Directory-based conditional includes auto-switch GitHub accounts:

| Directory | Account | SSH Host |
|-----------|---------|----------|
| `~/Repos/personal/` | SamBailey6194 | github-personal |
| `~/Repos/syntek/` | syntek-studio | github-syntek |
| `~/Repos/missional-gen/` | sam-missionalgen | github-missionalgen |

Verify with: `git config user.email` in each directory.

## Stack Support

- **Python**: Ruff, Pyright, python-lsp-server, Django stubs
- **TypeScript/JavaScript**: Prettier, ESLint, tsc
- **Rust**: rustfmt, Clippy, rust-analyzer (configs stay per-project)
- **Markdown**: Prettier, markdownlint-cli2, markdown-toc
- **PHP**: php-cs-fixer, Intelephense
- **GraphQL, Tailwind CSS**: Language servers included

## Installation

```bash
git clone git@github-personal:SamBailey6194/zedconfig.git ~/Repos/personal/zedconfig
cd ~/Repos/personal/zedconfig
chmod +x install.sh && ./install.sh
```

**Prerequisites**: SSH keys must be configured for each GitHub account before cloning.

## Symlink Targets

- `~/.gitconfig` → config/git/config
- `~/.config/zed/settings.json` → config/zed/settings.json
- `~/.config/zed/keymap.json` → config/zed/keymap.json
