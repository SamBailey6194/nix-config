# Zedconfig

Portable Zed IDE and development environment configuration for multi-device
deployment. One-command installation sets up SSH keys, installs all development
tools, and symlinks configs to their expected locations.

**Supports:** Native Linux, WSL (Windows Subsystem for Linux), macOS

## Quick Start

### New Device (Complete Setup)

```bash
# 1. Download and run SSH setup
curl -fsSL https://raw.githubusercontent.com/SamBailey6194/zedconfig/main/ssh-setup.sh -o ssh-setup.sh
chmod +x ssh-setup.sh
./ssh-setup.sh

# 2. Add the displayed public keys to your GitHub accounts
#    → Log in to each GitHub account
#    → Go to Settings > SSH and GPG keys > New SSH key
#    → Paste the corresponding public key

# 3. Test SSH connections
ssh -T git@github-personal
ssh -T git@github-syntek
ssh -T git@github-missionalgen

# 4. Clone and run the setup wizard
git clone git@github-personal:SamBailey6194/zedconfig.git ~/Repos/personal/zedconfig
cd ~/Repos/personal/zedconfig
chmod +x *.sh
./setup.sh
```

### Existing Device (Already Have SSH Keys)

```bash
git clone git@github-personal:SamBailey6194/zedconfig.git ~/Repos/personal/zedconfig
cd ~/Repos/personal/zedconfig
chmod +x *.sh
./setup.sh  # Guided wizard, or run individual scripts below:

# Individual scripts:
# ./install.sh --deps  # Install tools
# ./install.sh         # Symlink configs
# ./verify-setup.sh    # Check everything
```

## Project Structure

```
zedconfig/
├── setup.sh                # Guided setup wizard (runs everything)
├── ssh-setup.sh            # SSH key generation for multi-account GitHub
├── install.sh              # Tool installation (--deps) and config symlinks
├── verify-setup.sh         # Verification script
├── config/
│   ├── git/
│   │   ├── config                  # Main gitconfig with conditional includes
│   │   ├── config-personal         # Personal GitHub account
│   │   ├── config-syntek           # Syntek GitHub account
│   │   ├── config-missional-gen    # Missional Gen GitHub account
│   │   ├── gitmessage              # Commit message template
│   │   └── hooks/
│   │       └── pre-commit          # Global pre-commit hook
│   └── zed/
│       ├── settings.json   # Editor settings
│       ├── keymap.json     # Key bindings
│       └── debug.json      # Debug configurations
├── linters/
│   ├── .editorconfig       # Universal editor config
│   ├── .eslintrc.json      # ESLint (legacy config)
│   ├── eslint.config.js    # ESLint (flat config)
│   ├── .markdownlint.json  # Markdown linting
│   ├── .prettierrc         # Prettier formatting
│   ├── pyrightconfig.json  # Python type checking
│   └── ruff.toml           # Python linting/formatting
└── justfile                # Task runner commands
```

## Scripts

| Script                | Purpose                                                     |
| --------------------- | ----------------------------------------------------------- |
| `./setup.sh`          | **Guided wizard** - walks through entire setup with prompts |
| `./ssh-setup.sh`      | Generate SSH keys and config for multi-account GitHub       |
| `./install.sh --deps` | Install all development tools and dependencies              |
| `./install.sh`        | Symlink configuration files to system locations             |
| `./verify-setup.sh`   | Check all tools and configs are properly set up             |

## What Gets Installed

### `./install.sh --deps`

| Category    | Tools                                                             |
| ----------- | ----------------------------------------------------------------- |
| **System**  | git, curl, zsh, jq, ripgrep, fd-find, bat, entr                   |
| **Shell**   | Oh My Zsh                                                         |
| **Node.js** | nvm, Node.js LTS, prettier, eslint, typescript, markdownlint-cli2 |
| **Python**  | pipx, ruff, basedpyright, pip-audit                               |
| **Rust**    | rustup, cargo, clippy, rustfmt, rust-analyzer, just, cargo-audit  |
| **GitHub**  | GitHub CLI (gh)                                                   |
| **PHP**     | php-cs-fixer (if composer is installed)                           |

### `./install.sh` (Symlinks)

| Source                        | Target                                 |
| ----------------------------- | -------------------------------------- |
| `config/zed/settings.json`    | `~/.config/zed/settings.json`          |
| `config/zed/keymap.json`      | `~/.config/zed/keymap.json`            |
| `config/zed/debug.json`       | `~/.config/zed/debug.json`             |
| `config/git/config`           | `~/.gitconfig`                         |
| `config/git/config-*`         | `~/.gitconfig-*`                       |
| `config/git/gitmessage`       | `~/.gitmessage`                        |
| `config/git/hooks/pre-commit` | `~/.config/git/hooks/pre-commit`       |
| `linters/.editorconfig`       | `~/.editorconfig`                      |
| `linters/.eslintrc.json`      | `~/.eslintrc.json`                     |
| `linters/eslint.config.js`    | `~/eslint.config.js`                   |
| `linters/.markdownlint.json`  | `~/.markdownlint.json`                 |
| `linters/.prettierrc`         | `~/.prettierrc`                        |
| `linters/ruff.toml`           | `~/.config/ruff/ruff.toml`             |
| `linters/pyrightconfig.json`  | `~/.config/pyright/pyrightconfig.json` |
| `justfile`                    | `~/justfile`                           |

## Multi-Account Git Setup

Directory-based conditional includes automatically switch GitHub accounts:

| Directory                | GitHub Account   | SSH Host              |
| ------------------------ | ---------------- | --------------------- |
| `~/Repos/personal/`      | SamBailey6194    | `github-personal`     |
| `~/Repos/syntek/`        | syntek-studio    | `github-syntek`       |
| `~/Repos/missional-gen/` | sam-missionalgen | `github-missionalgen` |

### Clone Examples

```bash
# Personal repos
git clone git@github-personal:SamBailey6194/myrepo.git ~/Repos/personal/myrepo

# Syntek repos
git clone git@github-syntek:syntek-studio/project.git ~/Repos/syntek/project

# Missional Gen repos
git clone git@github-missionalgen:sam-missionalgen/app.git ~/Repos/missional-gen/app
```

### Verify Git Account

```bash
cd ~/Repos/personal/any-repo && git config user.email
# → samabailey6194@gmail.com

cd ~/Repos/syntek/any-repo && git config user.email
# → sam.bailey@syntekstudio.com

cd ~/Repos/missional-gen/any-repo && git config user.email
# → sam@missionalgen.co.uk
```

## WSL (Windows Subsystem for Linux)

This config works identically on native Linux and WSL. When running on Windows:

1. **Install WSL:**

   ```powershell
   wsl --install
   ```

2. **Run setup inside WSL:**

   ```bash
   # All commands run in Ubuntu/WSL terminal
   ./setup.sh
   ```

3. **Configure Zed (on Windows) to use WSL terminal:**
   ```json
   "terminal": {
     "shell": {
       "program": "wsl.exe",
       "args": ["-d", "Ubuntu"]
     }
   }
   ```

### File Access in WSL

| From          | Access                         |
| ------------- | ------------------------------ |
| WSL → Windows | `/mnt/c/Users/YourName/`       |
| Windows → WSL | `\\wsl$\Ubuntu\home\username\` |

## Language Support

| Language              | LSP                         | Formatter    | Linter       |
| --------------------- | --------------------------- | ------------ | ------------ |
| Python                | basedpyright                | ruff         | ruff         |
| TypeScript/JavaScript | typescript-language-server  | prettier     | eslint       |
| Rust                  | rust-analyzer               | rustfmt      | clippy       |
| PHP                   | intelephense                | php-cs-fixer | -            |
| Markdown              | -                           | prettier     | markdownlint |
| JSON/YAML/HTML/CSS    | -                           | prettier     | -            |
| GraphQL               | graphql-language-service    | prettier     | -            |
| Tailwind CSS          | tailwindcss-language-server | -            | -            |

## Debug Configurations

Pre-configured debug tasks in `debug.json`:

| Language    | Configurations                                              |
| ----------- | ----------------------------------------------------------- |
| **Python**  | Active File, Module, Django Runserver, Django Shell, Pytest |
| **Node.js** | Active File, npm dev/start, Next.js, Vite, Jest             |
| **Rust**    | Debug Binary, Release, Tests, Current Test                  |
| **PHP**     | Active File, Xdebug, Laravel Artisan, PHPUnit               |

## Key Bindings

### Workspace

| Key              | Action               |
| ---------------- | -------------------- |
| `Ctrl+P`         | File finder          |
| `Ctrl+Shift+P`   | Command palette      |
| `Ctrl+,`         | Open settings        |
| `Ctrl+Shift+E`   | Toggle file explorer |
| `Ctrl+Shift+G`   | Toggle git panel     |
| `Ctrl+Shift+O`   | Toggle outline panel |
| `Ctrl+Shift+M`   | Toggle diagnostics   |
| `Ctrl+`` `       | Toggle terminal      |
| `Ctrl+Shift+`` ` | New terminal         |
| `Ctrl+\`         | Split pane right     |
| `Ctrl+Shift+\`   | Split pane down      |
| `Ctrl+W`         | Close tab            |
| `Ctrl+Tab`       | Next tab             |
| `Ctrl+Shift+Tab` | Previous tab         |

### Editor

| Key                  | Action                 |
| -------------------- | ---------------------- |
| `Ctrl+D`             | Select next occurrence |
| `Ctrl+Shift+L`       | Select all occurrences |
| `Ctrl+L`             | Select line            |
| `Ctrl+/`             | Toggle comment         |
| `Ctrl+Shift+K`       | Delete line            |
| `Alt+Up/Down`        | Move line up/down      |
| `Ctrl+Shift+Up/Down` | Add cursor above/below |
| `F12`                | Go to definition       |
| `Shift+F12`          | Find all references    |
| `F2`                 | Rename symbol          |
| `Ctrl+.`             | Code actions           |
| `Ctrl+Space`         | Show completions       |

### Project Panel

| Key       | Action        |
| --------- | ------------- |
| `a`       | New file      |
| `Shift+A` | New directory |
| `r`       | Rename        |
| `d`       | Delete        |
| `x`       | Cut           |
| `c`       | Copy          |
| `p`       | Paste         |

## Just Commands

```bash
just lint       # Run all linters
just format     # Run all formatters
just audit      # Full security audit (npm, pip, cargo)
just watch-md   # Watch and lint markdown files
just watch-py   # Watch and lint Python files
just watch-ts   # Watch and lint TypeScript files
```

## Zed Layout

```
┌──────────┬─────────────────────────┬──────────────┐
│ Files    │                         │              │
│ (280px)  │      Main Editor        │    Agent     │
├──────────┤    (multiple tabs)      │   (480px)    │
│ Git      │                         │              │
│ Panel    │                         │              │
├──────────┤                         │              │
│ Outline  │                         │              │
├──────────┴─────────────────────────┴──────────────┤
│              Terminal (zsh)                       │
│           (100,000 line scrollback)               │
└───────────────────────────────────────────────────┘
```

## Troubleshooting

### SSH Connection Fails

```bash
# Test connection
ssh -T git@github-personal

# Check SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_personal

# Verify config
cat ~/.ssh/config
```

### Wrong Git Account

```bash
# Check which account is active
git config user.email

# Ensure you're in the right directory
# ~/Repos/personal/ → personal account
# ~/Repos/syntek/ → syntek account
```

### Zed Not Finding Tools

```bash
# Verify tools are installed
./verify-setup.sh

# Restart Zed after installing dependencies
# Tools should be in PATH
which ruff prettier eslint
```

### WSL: Zed Can't Access Files

Make sure you're working in the WSL filesystem (`/home/user/`), not the Windows
filesystem (`/mnt/c/`). Performance is much better in the native WSL filesystem.

## Updating

```bash
cd ~/Repos/personal/zedconfig
git pull
./install.sh  # Re-symlink if needed
```

## License

MIT
