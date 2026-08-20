# Terminal Management System - Implementation Plan

**Feature:** Sophisticated terminal session management with Kitty, Python kittens, and Rust CLI tools
**Version:** 1.0.0
**Last Updated:** 12/02/2026
**Language:** British English (en_GB)
**Timezone:** Europe/London

---

## Overview

Build a layered terminal management system that leverages Hyprland's tiling capabilities with Kitty as the terminal emulator. Python scripts (kittens) handle session orchestration and SSH connection management, whilst Rust CLI tools provide high-performance command execution once terminals are active.

**Architecture Philosophy:**
- **Hyprland**: Automatic tiling layout management (no need for Terminator's built-in tiling)
- **Kitty**: Modern, GPU-accelerated terminal with Python scripting support (kittens)
- **Python (kittens)**: Session orchestration, SSH setup, Kitty window management
- **Rust CLIs**: Performance-critical commands, server management operations

**Key Insight:** Hyprland hotkeys → Python kittens → Kitty sessions → Rust CLIs
(Rust CLIs are **NOT** bound to hotkeys directly; Python glue layer handles this)

---

## Requirements

### Functional Requirements

1. **Session Management**
   - Launch pre-configured terminal layouts with single hotkey
   - Support multiple layout profiles (development, monitoring, deployment)
   - Auto-SSH to specified remote servers per terminal pane
   - Restore previous session state on demand

2. **Layout Profiles**
   - **Development Layout**: 4 terminals (local dev, logs, git, test runner)
   - **Server Monitoring**: 4 terminals SSH'd to production servers
   - **Deployment Layout**: 3 terminals (staging, production, logs) + 1 local control
   - **Custom Layouts**: User-definable YAML/TOML configuration files

3. **Rust CLI Integration**
   - Fast server status checks (`server-status --all`)
   - Deployment commands (`deploy --env staging`)
   - Log aggregation (`logs --service api --follow`)
   - Database operations (`db-query --replica`)

4. **SSH Session Management**
   - Automatic SSH connection with per-device key selection (agenix integration)
   - Session persistence (reconnect on disconnect)
   - Multi-hop SSH (bastion → target server)
   - SSH key forwarding for deployment workflows

### Non-Functional Requirements

1. **Performance**
   - Terminal launch: < 500ms for 4-pane layout
   - SSH connection: < 2s to remote servers
   - Rust CLI commands: < 100ms response time for status checks

2. **Security**
   - All SSH keys managed through agenix (per-device secrets)
   - No hardcoded credentials in Python scripts or Rust tools
   - SSH sessions use existing per-device security model

3. **Usability**
   - Single hotkey per layout profile (Super+Shift+1, Super+Shift+2, etc.)
   - Visual feedback during session launch
   - Error handling with user notifications (dunst)

---

## Technical Design

### Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Hyprland (Window Manager)                          │
│ - Hotkey bindings (Super+Shift+1-9)                         │
│ - Automatic tiling layout                                   │
│ - Window rules for Kitty session management                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Python Kittens (Session Orchestration)             │
│ - kitten-session-launcher.py                                │
│ - Layout parser (YAML/TOML configs)                         │
│ - SSH connection setup                                      │
│ - Kitty window/tab management via kitten API                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Kitty (Terminal Emulator)                          │
│ - GPU-accelerated rendering                                 │
│ - 4-terminal layouts (Hyprland manages tiling)              │
│ - SSH sessions (spawned by Python kittens)                  │
│ - Shell environment with Rust CLIs in PATH                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Rust CLI Tools (Performance-Critical Operations)   │
│ - terminal-session (session management CLI)                 │
│ - server-manager (server status, deployment)                │
│ - log-aggregator (multi-server log collection)              │
│ - db-tools (database query/admin operations)                │
└─────────────────────────────────────────────────────────────┘
```

### File Organization

```
nix-config/
├── modules/
│   └── desktop/
│       ├── hyprland/
│       │   └── default.nix            # Add terminal session hotkeys
│       └── kitty/
│           ├── default.nix            # Kitty configuration module
│           ├── kitty.conf.nix         # Declarative Kitty config
│           └── kittens/               # Python kitten scripts
│               ├── session-launcher.py
│               ├── ssh-manager.py
│               └── layout-parser.py
│
├── config/
│   ├── hypr/
│   │   └── keybinds.conf             # Add: Super+Shift+1-9 for sessions
│   └── kitty/
│       ├── kitty.conf                # Kitty configuration
│       ├── ayu-dark.conf             # Colour scheme
│       └── sessions/                 # Session layout definitions
│           ├── development.toml
│           ├── monitoring.toml
│           ├── deployment.toml
│           └── README.md
│
├── rust/
│   ├── terminal-session/             # NEW: Session management CLI
│   │   ├── src/
│   │   │   ├── main.rs
│   │   │   ├── session.rs            # Session state management
│   │   │   └── config.rs             # Layout config parsing
│   │   └── Cargo.toml
│   │
│   ├── server-manager/               # NEW: Server operations CLI
│   │   ├── src/
│   │   │   ├── main.rs
│   │   │   ├── status.rs             # Server health checks
│   │   │   └── deploy.rs             # Deployment operations
│   │   └── Cargo.toml
│   │
│   ├── log-aggregator/               # NEW: Log collection CLI
│   │   ├── src/
│   │   │   ├── main.rs
│   │   │   ├── collector.rs          # Multi-server log fetch
│   │   │   └── filter.rs             # Log filtering/search
│   │   └── Cargo.toml
│   │
│   └── db-tools/                     # NEW: Database CLI
│       ├── src/
│       │   ├── main.rs
│       │   ├── query.rs              # Query execution
│       │   └── admin.rs              # Admin operations
│       └── Cargo.toml
│
├── home/
│   └── common.nix                    # Add Kitty + kittens configuration
│
└── docs/
    ├── PLANS/
    │   └── PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD  # This file
    └── TERMINAL-SESSION-GUIDE.MD       # User guide (Phase 4)
```

---

## Implementation Phases

### Phase 1: Kitty Configuration & Basic Integration

**Goal:** Configure Kitty as the primary terminal with Hyprland integration.

#### Tasks

- [ ] Create `modules/desktop/kitty/default.nix` NixOS module
  - Install Kitty package
  - Configure Kitty as default terminal
  - Set up Ayu Dark colour scheme
  - Enable GPU acceleration
  - Configure font (JetBrains Mono Nerd Font)

- [ ] Create `config/kitty/kitty.conf` configuration file
  - Font configuration (size, family, ligatures)
  - Colour scheme (Ayu Dark)
  - Window padding and opacity
  - Tab bar styling
  - Scrollback buffer size (10000 lines)
  - Shell integration settings

- [ ] Create `config/kitty/ayu-dark.conf` colour scheme
  - Match existing Hyprland Ayu Dark theme
  - Define all 16 ANSI colours + cursor colours
  - Set background/foreground colours

- [ ] Update `config/hypr/keybinds.conf`
  - Change terminal binding: `bind = $mod, RETURN, exec, kitty`
  - Remove terminator references

- [ ] Update `modules/desktop/hyprland/default.nix`
  - Remove terminator from systemPackages
  - Add kitty to systemPackages (if not already in home-manager)

- [ ] Update `home/common.nix`
  - Enable Kitty via home-manager's `programs.kitty.enable`
  - Source Kitty config from `config/kitty/`

**Deliverable:** Hyprland launches Kitty with Ayu Dark theme. `Super+Return` opens single Kitty terminal.

**Testing:**
```bash
# After rebuild
just rebuild

# Test hotkey
Super+Return  # Should launch Kitty with Ayu Dark theme

# Verify configuration
kitty --debug-config | grep -A5 "background\|foreground"
```

---

### Phase 2: Python Kitten Infrastructure

**Goal:** Set up Python environment and kitten framework for session orchestration.

#### Tasks

- [ ] Create `modules/desktop/kitty/kittens/` directory structure
  - Add `__init__.py` for Python package
  - Create placeholder scripts

- [ ] Create `config/kitty/kittens/session-launcher.py` (v1: basic)
  - Parse command-line arguments (layout name)
  - Read layout config from `~/.config/kitty/sessions/<layout>.toml`
  - Launch Kitty windows using `kitty @ launch` remote control API
  - Handle errors gracefully with exit codes

- [ ] Create `config/kitty/kittens/layout-parser.py`
  - Parse TOML layout files
  - Validate layout structure (required fields)
  - Return structured layout object (window count, SSH targets, commands)

- [ ] Create `config/kitty/sessions/development.toml` (example layout)
  ```toml
  [layout]
  name = "development"
  description = "Local development workflow"

  [[windows]]
  title = "dev"
  directory = "~/Projects/current"
  command = ""  # Default shell

  [[windows]]
  title = "logs"
  directory = "~/Projects/current"
  command = "tail -f logs/development.log"

  [[windows]]
  title = "git"
  directory = "~/Projects/current"
  command = "git status"

  [[windows]]
  title = "test"
  directory = "~/Projects/current"
  command = "just watch-tests"
  ```

- [ ] Update `modules/desktop/kitty/default.nix`
  - Add Python dependencies: `python3.pkgs.toml`, `python3.pkgs.pyyaml`
  - Install kittens to `~/.config/kitty/kittens/`
  - Enable Kitty remote control: `allow_remote_control yes`
  - Configure listen address: `listen_on unix:/tmp/kitty-${USER}`

- [ ] Create `config/kitty/sessions/README.md`
  - Document TOML layout format
  - Provide examples for common layouts
  - Explain field meanings (title, directory, command, ssh_target)

**Deliverable:** Run `python3 ~/.config/kitty/kittens/session-launcher.py development` to launch 4 Kitty windows in a development layout.

**Testing:**
```bash
# After rebuild
just rebuild

# Manual kitten execution
python3 ~/.config/kitty/kittens/session-launcher.py development

# Verify 4 Kitty windows opened (Hyprland tiles them automatically)
hyprctl clients | grep -c "class: kitty"  # Should output: 4
```

---

### Phase 3: SSH Session Management

**Goal:** Extend kittens to establish SSH connections using per-device agenix keys.

#### Tasks

- [ ] Create `config/kitty/kittens/ssh-manager.py`
  - Accept SSH target (user@host or hostname from ~/.ssh/config)
  - Resolve correct per-device SSH key from `~/.ssh/config` (auto-generated by `modules/core/ssh-config.nix`)
  - Build SSH command with correct identity file
  - Return SSH command string for Kitty to execute

- [ ] Update `config/kitty/kittens/session-launcher.py` (v2: SSH support)
  - Check for `ssh_target` field in TOML layout
  - If present, call `ssh-manager.py` to build SSH command
  - Launch Kitty window with SSH command: `kitty @ launch --title <title> --cwd <dir> ssh <target>`
  - Handle SSH connection errors (notify via dunst)

- [ ] Create `config/kitty/sessions/monitoring.toml` (SSH example)
  ```toml
  [layout]
  name = "monitoring"
  description = "Production server monitoring"

  [[windows]]
  title = "web-prod"
  ssh_target = "web-production"  # References ~/.ssh/config
  command = "htop"

  [[windows]]
  title = "api-prod"
  ssh_target = "api-production"
  command = "journalctl -u api.service -f"

  [[windows]]
  title = "db-prod"
  ssh_target = "db-production"
  command = "psql -U app production_db"

  [[windows]]
  title = "local-control"
  directory = "~/ops"
  command = ""  # Local terminal for orchestration
  ```

- [ ] Update `modules/core/ssh-config.nix` (if needed)
  - Ensure auto-generated SSH config includes production server definitions
  - Add placeholder entries for web-production, api-production, db-production
  - Configure per-device key selection

- [ ] Add SSH error handling to kittens
  - Detect failed SSH connections (exit code, timeout)
  - Send desktop notification: `notify-send "SSH Failed" "Could not connect to <target>"`
  - Log errors to `~/.local/share/kitty/session-errors.log`

**Deliverable:** Run `python3 ~/.config/kitty/kittens/session-launcher.py monitoring` to launch 4 Kitty windows, 3 SSH'd to remote servers, 1 local.

**Testing:**
```bash
# After rebuild (with SSH server configs added)
just rebuild

# Launch monitoring layout
python3 ~/.config/kitty/kittens/session-launcher.py monitoring

# Verify SSH connections
# In each SSH'd window, run:
hostname  # Should show remote server hostname

# Check error logging
tail ~/.local/share/kitty/session-errors.log
```

---

### Phase 4: Hyprland Hotkey Integration

**Goal:** Bind Python kittens to Hyprland hotkeys for one-key session launching.

#### Tasks

- [ ] Create wrapper script `~/.local/bin/kitty-session` (installed by NixOS)
  ```bash
  #!/usr/bin/env bash
  # Wrapper for launching Kitty sessions via kittens

  LAYOUT="$1"
  KITTEN_PATH="$HOME/.config/kitty/kittens/session-launcher.py"

  if [[ -z "$LAYOUT" ]]; then
    notify-send "Kitty Session" "Usage: kitty-session <layout-name>"
    exit 1
  fi

  if [[ ! -f "$HOME/.config/kitty/sessions/${LAYOUT}.toml" ]]; then
    notify-send "Kitty Session" "Layout not found: ${LAYOUT}.toml"
    exit 1
  fi

  python3 "$KITTEN_PATH" "$LAYOUT"
  ```

- [ ] Update `modules/desktop/kitty/default.nix`
  - Install wrapper script to `~/.local/bin/kitty-session`
  - Make executable
  - Add to PATH

- [ ] Update `config/hypr/keybinds.conf`
  ```conf
  # Terminal session management (Super+Shift+1-9)
  bind = $mod SHIFT, 1, exec, kitty-session development
  bind = $mod SHIFT, 2, exec, kitty-session monitoring
  bind = $mod SHIFT, 3, exec, kitty-session deployment
  bind = $mod SHIFT, 4, exec, kitty-session custom-1
  # ... up to 9 for user-defined layouts
  ```

- [ ] Update `config/hypr/README.md`
  - Document new hotkeys: `Super+Shift+1-9` for terminal sessions
  - Link to session configuration docs

- [ ] Create `docs/TERMINAL-SESSION-GUIDE.MD`
  - User guide for creating custom layouts
  - TOML configuration reference
  - Troubleshooting SSH issues
  - Examples for common workflows

**Deliverable:** Press `Super+Shift+1` to instantly launch 4-terminal development layout. Press `Super+Shift+2` to launch monitoring layout with SSH sessions.

**Testing:**
```bash
# After rebuild
just rebuild

# Test hotkeys in Hyprland
Super+Shift+1  # Launch development layout
Super+Shift+2  # Launch monitoring layout

# Verify window count
hyprctl clients | grep -c "class: kitty"  # Should match window count

# Test error notification
Super+Shift+9  # Should show "Layout not found" notification
```

---

### Phase 5: Rust CLI Tools - Session Management

**Goal:** Build Rust CLI for advanced session operations (save, restore, list).

#### Tasks

- [ ] Create `rust/terminal-session/` Rust project
  ```bash
  cd rust/
  cargo new terminal-session
  ```

- [ ] Update `rust/Cargo.toml` workspace
  - Add `terminal-session` to workspace members

- [ ] Implement `rust/terminal-session/src/main.rs`
  - CLI using `clap` crate
  - Subcommands: `list`, `save`, `restore`, `kill`
  - Read session state from Kitty socket (`kitty @ ls`)

- [ ] Implement `rust/terminal-session/src/session.rs`
  - Struct `Session { windows: Vec<Window>, layout: String }`
  - Serialize to JSON (`serde_json`)
  - Save to `~/.local/share/kitty/saved-sessions/<name>.json`
  - Restore by reading JSON + launching via `kitty @ launch`

- [ ] Implement `rust/terminal-session/src/config.rs`
  - Parse TOML layout files (using `toml` crate)
  - Validate layout structure
  - Return structured config for Rust operations

- [ ] Update `flake.nix`
  - Add `terminal-session` to Rust packages built by flake
  - Install to system PATH

- [ ] Update `justfile`
  - Add `just terminal-session-list` → `terminal-session list`
  - Add `just terminal-session-save <name>` → `terminal-session save <name>`
  - Add `just terminal-session-restore <name>` → `terminal-session restore <name>`

**Deliverable:** Run `terminal-session list` to see active Kitty sessions. Run `terminal-session save my-work` to snapshot current state. Run `terminal-session restore my-work` to restore.

**Testing:**
```bash
# After rebuild
just rebuild

# Launch a session
Super+Shift+1  # development layout

# Save current state
terminal-session save my-dev-work

# Kill all Kitty windows
pkill kitty

# Restore session
terminal-session restore my-dev-work

# Verify windows restored
hyprctl clients | grep -c "class: kitty"
```

---

### Phase 6: Rust CLI Tools - Server Management

**Goal:** Build Rust CLI for server status checks and deployment operations.

#### Tasks

- [ ] Create `rust/server-manager/` Rust project
  ```bash
  cd rust/
  cargo new server-manager
  ```

- [ ] Update `rust/Cargo.toml` workspace
  - Add `server-manager` to workspace members

- [ ] Implement `rust/server-manager/src/main.rs`
  - CLI using `clap` crate
  - Subcommands: `status`, `deploy`, `rollback`, `health`
  - Use `tokio` for async SSH operations

- [ ] Implement `rust/server-manager/src/status.rs`
  - SSH to servers (read from `~/.ssh/config`)
  - Run health check commands (`systemctl status <service>`, `df -h`, `free -m`)
  - Aggregate results (parallel using `tokio::join!`)
  - Display formatted table (using `tabled` crate)

- [ ] Implement `rust/server-manager/src/deploy.rs`
  - Read deployment config from `~/.config/server-manager/deploy.toml`
  - Execute deployment steps via SSH (git pull, build, restart service)
  - Stream output to terminal (real-time logs)
  - Rollback on failure (previous commit SHA stored in state file)

- [ ] Create `config/server-manager/deploy.toml` (example)
  ```toml
  [staging]
  host = "staging-server"
  user = "deploy"
  app_path = "/var/www/app"
  service = "app.service"
  pre_deploy = ["just test"]
  deploy = ["git pull", "just build", "systemctl restart app.service"]
  post_deploy = ["just smoke-test"]

  [production]
  host = "production-server"
  user = "deploy"
  app_path = "/var/www/app"
  service = "app.service"
  pre_deploy = ["just test", "just security-scan"]
  deploy = ["git pull", "just build-release", "systemctl restart app.service"]
  post_deploy = ["just smoke-test", "just notify-team"]
  ```

- [ ] Update `flake.nix`
  - Add `server-manager` to Rust packages

- [ ] Update `justfile`
  - Add `just server-status` → `server-manager status --all`
  - Add `just deploy <env>` → `server-manager deploy --env <env>`

**Deliverable:** Run `server-manager status --all` to see health of all servers in parallel (< 2s). Run `server-manager deploy --env staging` to deploy to staging server.

**Testing:**
```bash
# After rebuild (with deployment config)
just rebuild

# Check server status
server-manager status --all
# Should show table: Server | Status | CPU | Memory | Disk

# Deploy to staging
server-manager deploy --env staging
# Should show real-time deployment logs

# Test rollback
server-manager rollback --env staging
# Should revert to previous commit
```

---

### Phase 7: Rust CLI Tools - Log Aggregation

**Goal:** Build Rust CLI for multi-server log collection and filtering.

#### Tasks

- [ ] Create `rust/log-aggregator/` Rust project
  ```bash
  cd rust/
  cargo new log-aggregator
  ```

- [ ] Update `rust/Cargo.toml` workspace
  - Add `log-aggregator` to workspace members

- [ ] Implement `rust/log-aggregator/src/main.rs`
  - CLI using `clap` crate
  - Subcommands: `fetch`, `follow`, `search`, `export`
  - Use `tokio` for async SSH + log streaming

- [ ] Implement `rust/log-aggregator/src/collector.rs`
  - SSH to multiple servers in parallel (`tokio::spawn`)
  - Run `journalctl -u <service> --since "<time>"` on each server
  - Merge logs by timestamp (chronological order)
  - Stream to stdout (colorized using `colored` crate)

- [ ] Implement `rust/log-aggregator/src/filter.rs`
  - Regex filtering (using `regex` crate)
  - Log level filtering (ERROR, WARN, INFO, DEBUG)
  - Time range filtering (last 1h, 24h, custom range)
  - Service filtering (API, worker, database)

- [ ] Create `config/log-aggregator/sources.toml`
  ```toml
  [[sources]]
  name = "api-production"
  host = "api-production"
  service = "api.service"

  [[sources]]
  name = "worker-production"
  host = "worker-production"
  service = "worker.service"

  [[sources]]
  name = "db-production"
  host = "db-production"
  service = "postgresql.service"
  ```

- [ ] Update `flake.nix`
  - Add `log-aggregator` to Rust packages

- [ ] Update `justfile`
  - Add `just logs <service>` → `log-aggregator fetch --service <service>`
  - Add `just logs-follow` → `log-aggregator follow --all`
  - Add `just logs-errors` → `log-aggregator fetch --level ERROR --since 1h`

**Deliverable:** Run `log-aggregator fetch --service api --since 1h` to fetch last hour of API logs from all API servers. Run `log-aggregator follow --all` to tail all production logs in real-time.

**Testing:**
```bash
# After rebuild
just rebuild

# Fetch logs from single service
log-aggregator fetch --service api --since 1h
# Should show last hour of API logs from all API servers

# Follow all logs in real-time
log-aggregator follow --all
# Should stream logs from all services with timestamps

# Filter errors
log-aggregator fetch --level ERROR --since 24h
# Should show only ERROR level logs from last 24 hours

# Export logs
log-aggregator export --service api --since 1h --output api-logs.json
# Should export to JSON file
```

---

### Phase 8: Rust CLI Tools - Database Operations

**Goal:** Build Rust CLI for database query execution and admin operations.

#### Tasks

- [ ] Create `rust/db-tools/` Rust project
  ```bash
  cd rust/
  cargo new db-tools
  ```

- [ ] Update `rust/Cargo.toml` workspace
  - Add `db-tools` to workspace members

- [ ] Implement `rust/db-tools/src/main.rs`
  - CLI using `clap` crate
  - Subcommands: `query`, `backup`, `restore`, `replicas`, `migrations`
  - Use `tokio-postgres` for async PostgreSQL operations

- [ ] Implement `rust/db-tools/src/query.rs`
  - Connect to database (read connection string from agenix secret)
  - Execute SELECT queries (read-only by default)
  - Format results as table (using `tabled` crate)
  - Support JSON export (`--format json`)
  - Require `--write` flag for INSERT/UPDATE/DELETE

- [ ] Implement `rust/db-tools/src/admin.rs`
  - List replicas + replication lag (`SELECT * FROM pg_stat_replication`)
  - Run VACUUM/ANALYZE (`--vacuum`, `--analyze`)
  - Show table sizes (`SELECT pg_size_pretty(pg_total_relation_size('table'))`)
  - Show slow queries (from `pg_stat_statements`)

- [ ] Create `secrets/db-connection-strings/` (agenix-encrypted)
  - `production-primary.age` → `postgresql://user:pass@host:5432/db`
  - `production-replica.age` → `postgresql://user:pass@replica:5432/db`
  - `staging.age` → `postgresql://user:pass@staging-db:5432/db`

- [ ] Update `modules/core/secrets-*.nix`
  - Add database connection string secrets
  - Decrypt to `/run/agenix/db-<env>-connection`

- [ ] Update `flake.nix`
  - Add `db-tools` to Rust packages

- [ ] Update `justfile`
  - Add `just db-query <sql>` → `db-tools query --sql <sql>`
  - Add `just db-replicas` → `db-tools replicas`
  - Add `just db-vacuum` → `db-tools admin --vacuum`

**Deliverable:** Run `db-tools query --sql "SELECT COUNT(*) FROM users"` to query production database. Run `db-tools replicas` to check replication lag.

**Testing:**
```bash
# After rebuild (with DB connection secrets)
just rebuild

# Query production database
db-tools query --sql "SELECT COUNT(*) FROM users" --env production
# Should show user count

# Check replicas
db-tools replicas --env production
# Should show table: Replica | Status | Lag (bytes) | Lag (seconds)

# Show slow queries
db-tools admin --slow-queries --env production
# Should show table of slowest queries

# VACUUM database
db-tools admin --vacuum --env staging
# Should run VACUUM ANALYZE on staging database
```

---

### Phase 9: Session State Persistence

**Goal:** Auto-save and restore terminal sessions across reboots.

#### Tasks

- [ ] Update `rust/terminal-session/src/session.rs`
  - Add `auto_save` function (runs every 5 minutes)
  - Save current session state to `~/.local/share/kitty/autosave.json`
  - Include: window count, SSH targets, working directories, running commands

- [ ] Create systemd user service `kitty-session-autosave.service`
  ```ini
  [Unit]
  Description=Kitty session auto-save daemon

  [Service]
  Type=simple
  ExecStart=%h/.nix-profile/bin/terminal-session autosave
  Restart=always
  RestartSec=300  # Run every 5 minutes

  [Install]
  WantedBy=default.target
  ```

- [ ] Update `modules/desktop/kitty/default.nix`
  - Install systemd service
  - Enable by default

- [ ] Create `config/kitty/kittens/restore-prompt.py`
  - On Hyprland login, check for `~/.local/share/kitty/autosave.json`
  - If exists + age < 24 hours, show notification: "Restore previous session?"
  - If user clicks "Yes" → run `terminal-session restore autosave`
  - If user clicks "No" → delete autosave file

- [ ] Update Hyprland autostart
  - Add to `config/hypr/autostart.conf`: `exec-once = python3 ~/.config/kitty/kittens/restore-prompt.py`

**Deliverable:** After reboot, notification asks "Restore previous session?". Clicking "Yes" restores all terminal windows with SSH connections intact.

**Testing:**
```bash
# After rebuild
just rebuild

# Launch a session
Super+Shift+1  # development layout

# Wait 5 minutes for autosave
sleep 300

# Verify autosave file
cat ~/.local/share/kitty/autosave.json
# Should show current session state

# Reboot
sudo reboot

# After login to Hyprland
# Should see notification: "Restore previous session?"
# Click "Yes" → session restored
```

---

### Phase 10: Advanced Layout Features

**Goal:** Add advanced features to session layouts (dynamic commands, environment variables, workspace assignment).

#### Tasks

- [ ] Update TOML layout schema (v2)

  Note on the workspace numbers below: workspace 2 is **reserved** for the
  nix-config dev layout and workspace 1 is the laptop dashboard, so a generic
  layout must target the 3-6 dev pool instead (see `config/hypr/README.md`).

  ```toml
  [layout]
  name = "advanced-dev"
  description = "Advanced development workflow"
  workspace = 3  # NEW: Auto-assign to workspace 3 (in the 3-6 dev pool)

  [[windows]]
  title = "dev"
  directory = "~/Projects/current"
  command = ""
  workspace = 3  # NEW: Override layout workspace (3-6 pool only)
  env = { NODE_ENV = "development", DEBUG = "app:*" }  # NEW: Environment variables

  [[windows]]
  title = "logs"
  directory = "~/Projects/current"
  command = "just logs-follow"
  dynamic_command = true  # NEW: Re-run command on window focus

  [[windows]]
  title = "test-runner"
  directory = "~/Projects/current"
  command = "${RUST_TEST_COMMAND}"  # NEW: Variable interpolation from ~/.config/kitty/sessions/vars.env
  ```

- [ ] Create `config/kitty/sessions/vars.env` (user-defined variables)
  ```env
  RUST_TEST_COMMAND=cargo watch -x test
  NODE_DEV_COMMAND=npm run dev
  PYTHON_DEV_COMMAND=python manage.py runserver
  ```

- [ ] Update `config/kitty/kittens/layout-parser.py` (v2)
  - Parse `workspace`, `env`, `dynamic_command`, variable interpolation
  - Read variables from `vars.env`
  - Validate schema v2 fields

- [ ] Update `config/kitty/kittens/session-launcher.py` (v3)
  - Apply environment variables to window: `env VAR=value kitty @ launch`
  - Set Hyprland workspace: `hyprctl dispatch movetoworkspacesilent <workspace>,address:<window-address>`
  - Handle dynamic commands (re-run on focus using Hyprland window events)

- [ ] Create Hyprland window rule for workspace assignment
  - Update `config/hypr/windowrules.conf`:
    ```conf
    # Kitty session workspace assignment (set by kittens)
    windowrulev2 = workspace <workspace>,title:^kitty-session-
    ```

**Deliverable:** Session layouts can specify workspace, environment variables, and dynamic command re-execution.

**Testing:**
```bash
# After rebuild
just rebuild

# Create advanced layout
cat > ~/.config/kitty/sessions/advanced-dev.toml <<EOF
[layout]
name = "advanced-dev"
workspace = 3

[[windows]]
title = "dev"
env = { NODE_ENV = "development" }

[[windows]]
title = "logs"
command = "just logs-follow"
dynamic_command = true
EOF

# Launch layout
Super+Shift+4  # Mapped to advanced-dev

# Verify workspace assignment
hyprctl clients | grep "workspace: 3"  # Should show Kitty windows

# Verify environment variable
# In "dev" window, run:
echo $NODE_ENV  # Should output: development

# Verify dynamic command
# Focus away from "logs" window, then focus back
# "just logs-follow" should re-run
```

---

## Database Changes

**No database changes required.** This feature is entirely system-configuration and tooling-focused.

---

## API Contracts

**No external API contracts.** All interactions are:
- Kitty remote control API (local socket communication)
- SSH connections (standard SSH protocol)
- Hyprland IPC (via `hyprctl` CLI)

### Internal API: Kitty Remote Control

**Endpoint:** Unix socket `/tmp/kitty-${USER}`
**Protocol:** Kitty remote control protocol (JSON-based)

| Command | Method | Input | Output |
|---------|--------|-------|--------|
| `kitty @ ls` | GET | None | JSON list of windows/tabs |
| `kitty @ launch` | POST | `{"title": "...", "cwd": "...", "cmd": "..."}` | Window ID |
| `kitty @ close-window` | DELETE | `{"match": "id:..."}` | Success/failure |

### Internal API: Hyprland IPC

**Endpoint:** Unix socket `/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock`
**Protocol:** Hyprland IPC protocol (text-based)

| Command | Input | Output |
|---------|-------|--------|
| `hyprctl clients` | None | List of windows (JSON with `-j` flag) |
| `hyprctl dispatch movetoworkspacesilent <ws>,address:<addr>` | Workspace + window address | Success/failure |

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **SSH key mismatch** (kitten uses wrong key for server) | Medium | High | Use `ssh-manager.py` to resolve correct key from auto-generated `~/.ssh/config`. Test in Phase 3. |
| **Kitty remote control disabled** (user disables `allow_remote_control`) | Low | High | Document requirement in `docs/TERMINAL-SESSION-GUIDE.MD`. NixOS config enforces this setting. |
| **Session restore failure** (autosave corrupted or SSH targets unreachable) | Medium | Medium | Add error handling in `terminal-session restore`. Notify user via dunst if restore fails. Keep last 3 autosave backups. |
| **Performance degradation** (Rust CLI SSH operations slow on high-latency networks) | Medium | Medium | Add timeout flags (`--timeout 5s`). Use connection pooling for repeated SSH operations. Cache server status for 30s. |
| **TOML layout parsing errors** (user creates invalid layout) | High | Low | Validate layout schema in `layout-parser.py`. Show helpful error messages. Provide `just validate-layout <name>` command. |
| **Hyprland workspace assignment conflicts** (user manually moves windows) | Low | Low | Document that workspace assignment is a one-time operation on launch. User can override manually. |
| **Python/Rust dependency conflicts** (NixOS Python/Rust packages incompatible) | Low | Medium | Pin package versions in `flake.nix`. Test in `nix develop` shell before system rebuild. |
| **Kitty version incompatibility** (remote control API changes) | Low | High | Pin Kitty version in `flake.nix`. Test on Kitty updates before applying. Document tested version in `TERMINAL-SESSION-GUIDE.MD`. |

---

## Open Questions

### Question 1: SSH Connection Persistence Strategy

**Question:** How should SSH sessions handle disconnections? Auto-reconnect or manual retry?

**Options:**
- **A)** Auto-reconnect with exponential backoff (mosh-style)
- **B)** Show notification on disconnect, require manual reconnection
- **C)** Use `autossh` wrapper for persistent connections

**Recommendation:** Start with **B** (notify + manual retry) in Phase 3. If users request auto-reconnect, add **A** in Phase 9.

---

### Question 2: Layout Storage Location

**Question:** Should layouts be stored in `~/.config/kitty/sessions/` (user-editable) or `/etc/nixos/nix-config/config/kitty/sessions/` (version-controlled)?

**Options:**
- **A)** User's home directory (`~/.config/kitty/sessions/`) - easy to edit, not version-controlled
- **B)** NixOS config repo (`/etc/nixos/nix-config/config/kitty/sessions/`) - version-controlled, requires rebuild to update
- **C)** Hybrid: system defaults in NixOS repo, user overrides in home directory

**Recommendation:** Use **C** (hybrid approach). System ships with example layouts in `/etc/nixos/nix-config/config/kitty/sessions/`, user creates custom layouts in `~/.config/kitty/sessions/`. Kitten checks user directory first, falls back to system layouts.

---

### Question 3: Rust CLI Distribution Strategy

**Question:** Should Rust CLIs be installed system-wide or user-specific?

**Options:**
- **A)** System-wide (`/run/current-system/sw/bin/`) - available to all users
- **B)** User-specific (`~/.nix-profile/bin/`) - isolated per user
- **C)** Both (system binaries + user-specific configs)

**Recommendation:** Use **A** (system-wide). Single-user machines benefit from system-wide installation. Multi-user servers can still use system binaries with user-specific configs (read from `~/.config/server-manager/`, etc.).

---

### Question 4: Agenix Integration for Database Credentials

**Question:** How should database connection strings be stored and accessed?

**Current State:** Agenix secrets are decrypted to `/run/agenix/<secret-name>` (root-readable).

**Options:**
- **A)** Decrypt to user-readable location (`/run/agenix-user/<secret-name>` owned by user)
- **B)** Read from `/run/agenix/` using sudo wrapper
- **C)** Use environment variables (export from agenix-decrypted files on shell init)

**Recommendation:** Use **C** (environment variables). Update `home/common.nix` to source database connection strings from agenix secrets into environment variables on shell initialisation. Rust CLIs read from `DB_PRODUCTION_URL` environment variable.

**Implementation:**
```nix
# home/common.nix
programs.zsh.initExtra = ''
  export DB_PRODUCTION_URL="$(cat /run/agenix/db-production-connection 2>/dev/null || echo '')"
  export DB_STAGING_URL="$(cat /run/agenix/db-staging-connection 2>/dev/null || echo '')"
'';
```

---

### Question 5: Session Layout Versioning

**Question:** How should we handle breaking changes to the TOML layout format?

**Options:**
- **A)** Version field in TOML (`schema_version = 2`)
- **B)** Separate directories per version (`sessions/v1/`, `sessions/v2/`)
- **C)** Automatic migration tool (`layout-migrate v1 v2`)

**Recommendation:** Use **A** (version field). Add `schema_version = 2` to Phase 10 layouts. Kitten parser checks version and uses appropriate parser. If version missing, assume v1 (backward compatibility).

---

## Success Criteria

### Phase 1-4 Success Criteria (Basic Functionality)

- [ ] `Super+Return` launches Kitty with Ayu Dark theme
- [ ] `Super+Shift+1` launches 4-terminal development layout (tiled by Hyprland)
- [ ] `Super+Shift+2` launches 4-terminal monitoring layout with SSH connections
- [ ] All SSH connections use correct per-device keys (verified by `ssh -v`)
- [ ] Failed SSH connections show desktop notification
- [ ] Custom layouts can be created by editing TOML files

### Phase 5-8 Success Criteria (Rust CLI Tools)

- [ ] `terminal-session list` shows active sessions in < 100ms
- [ ] `terminal-session save my-work` + `terminal-session restore my-work` works across reboots
- [ ] `server-manager status --all` checks 5+ servers in < 2s
- [ ] `server-manager deploy --env staging` deploys app with real-time logs
- [ ] `log-aggregator follow --all` streams logs from 3+ servers with timestamps
- [ ] `db-tools query` executes read-only queries without requiring password (uses agenix secret)

### Phase 9-10 Success Criteria (Advanced Features)

- [ ] After reboot, notification prompts to restore previous session
- [ ] Restored session includes all SSH connections and working directories
- [ ] Advanced layouts with `workspace`, `env`, `dynamic_command` work as expected
- [ ] Variable interpolation in layout commands (from `vars.env`) works
- [ ] All features documented in `docs/TERMINAL-SESSION-GUIDE.MD`

---

## Performance Targets

| Operation | Target | Measurement Method |
|-----------|--------|-------------------|
| Kitty launch (single window) | < 300ms | `time kitty --single-instance --detach` |
| Session launch (4 windows, no SSH) | < 500ms | `time kitty-session development` |
| Session launch (4 windows, 3 SSH) | < 3s | `time kitty-session monitoring` |
| `terminal-session list` | < 100ms | `time terminal-session list` |
| `server-manager status --all` (5 servers) | < 2s | `time server-manager status --all` |
| `log-aggregator fetch` (1 hour, 3 servers) | < 5s | `time log-aggregator fetch --since 1h` |
| `db-tools query` (simple SELECT) | < 500ms | `time db-tools query --sql "SELECT COUNT(*) FROM users"` |

---

## Dependencies

### External Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Kitty | ≥ 0.32.0 | Terminal emulator with remote control API |
| Python | 3.11+ | Kitten scripting (session orchestration) |
| Hyprland | ≥ 0.35.0 | Window manager (tiling + IPC) |
| OpenSSH | 9.0+ | SSH client for remote connections |
| Agenix | Latest | Per-device secrets management |

### NixOS Packages (new)

- `python3.pkgs.toml` - TOML parsing in kittens
- `python3.pkgs.pyyaml` - YAML parsing (if needed)
- `autossh` - Persistent SSH connections (optional, Phase 9)

### Rust Crates (new projects)

**terminal-session:**
- `clap` - CLI argument parsing
- `serde` / `serde_json` - Session state serialization
- `toml` - Layout config parsing
- `tokio` - Async runtime (for future SSH operations)

**server-manager:**
- `clap` - CLI argument parsing
- `tokio` - Async runtime for parallel SSH
- `ssh2` - SSH client library (or `openssh` crate for wrapping CLI)
- `tabled` - Table formatting for status output
- `colored` - Colourized terminal output

**log-aggregator:**
- `clap` - CLI argument parsing
- `tokio` - Async runtime for parallel log streaming
- `regex` - Log filtering
- `chrono` - Timestamp parsing/formatting
- `colored` - Colourized log output

**db-tools:**
- `clap` - CLI argument parsing
- `tokio-postgres` - Async PostgreSQL client
- `tabled` - Table formatting for query results
- `serde_json` - JSON export format

---

## Security Considerations

### SSH Key Management

- **Per-device keys:** Each device has unique SSH keys (generated via `agenix-helper add-server`)
- **Agenix encryption:** All private keys encrypted with per-device public keys
- **No hardcoded credentials:** Python kittens and Rust CLIs read from agenix-decrypted files
- **SSH agent forwarding:** Disabled by default (security risk). Only enable for specific workflows if needed.

### Database Credentials

- **Connection strings in agenix:** Encrypted database URLs (username + password)
- **Environment variable export:** Decrypted on shell init (not committed to version control)
- **Read-only by default:** `db-tools query` requires `--write` flag for mutations
- **Connection pooling:** Reuse connections (avoid re-authentication overhead)

### Terminal Session State

- **Autosave contains sensitive data:** SSH targets, working directories (no passwords/keys)
- **File permissions:** `~/.local/share/kitty/autosave.json` readable only by user (mode 600)
- **Expiry:** Autosave deleted after 24 hours or after successful restore

### Rust CLI Binary Permissions

- **System-wide installation:** Binaries in `/run/current-system/sw/bin/` (world-readable, root-owned)
- **Config files:** User-specific configs in `~/.config/<tool>/` (mode 600)
- **Secrets access:** Rust CLIs read from `/run/agenix/` (root-readable) via environment variables (exported by shell)

---

## Testing Strategy

### Unit Testing

**Python Kittens:**
- Test TOML parsing with valid/invalid layouts
- Test SSH command building with various targets
- Test error handling (missing layout files, invalid SSH targets)

**Rust CLIs:**
- Test session state serialization/deserialization
- Test TOML config parsing
- Test SSH command execution (mocked SSH connections)
- Test database query execution (mocked PostgreSQL client)

### Integration Testing

**Phase 1-4:**
- Launch each layout profile (`development`, `monitoring`, `deployment`)
- Verify window count matches layout definition
- Verify SSH connections established (check `hostname` in remote terminals)
- Verify Hyprland tiling works correctly (4 windows in 2x2 grid)

**Phase 5-8:**
- `terminal-session save` + `restore` roundtrip test
- `server-manager status` with multiple servers (verify parallel execution)
- `log-aggregator fetch` with time range filtering
- `db-tools query` with read-only query (verify connection)

**Phase 9-10:**
- Reboot + autosave restore workflow
- Advanced layout features (workspace assignment, environment variables)

### Performance Testing

- Benchmark each operation against performance targets (see table above)
- Profile Rust CLIs with `cargo flamegraph` to identify bottlenecks
- Test on high-latency networks (SSH to remote servers)

---

## Documentation Deliverables

| Document | Location | Purpose |
|----------|----------|---------|
| **Implementation Plan** | `docs/PLANS/PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD` | This file - architecture and phased implementation |
| **User Guide** | `docs/TERMINAL-SESSION-GUIDE.MD` | End-user documentation (how to create layouts, use Rust CLIs) |
| **Layout Config Reference** | `config/kitty/sessions/README.md` | TOML schema documentation + examples |
| **Rust CLI Reference** | `rust/<tool>/README.md` | CLI usage, flags, examples for each Rust tool |
| **Hyprland Keybinds Update** | `config/hypr/README.md` | Document new `Super+Shift+1-9` hotkeys |
| **Phase Completion Checklist** | `docs/TERMINAL-MANAGEMENT-CHECKLIST.MD` | Phase-by-phase testing checklist |

---

## Future Enhancements (Post-Phase 10)

### Phase 11: Tmux/Zellij Integration (Optional)

**Goal:** Support tmux/zellij as alternative to Kitty-native layouts.

- Create `tmux-session.py` kitten (launches tmux with layout)
- Support tmux layout definitions in TOML
- Allow switching between Kitty-native and tmux layouts

**Why deferred:** Hyprland + Kitty provides sufficient tiling. Tmux adds complexity without clear benefit for single-user workstations.

### Phase 12: Multi-User Session Sharing (Optional)

**Goal:** Allow team members to share layout configurations.

- Central layout repository (Git repo with shared TOML layouts)
- `layout-sync` command to pull/push layouts
- Team-specific layout profiles (`team/backend-dev.toml`)

**Why deferred:** Single-user focus for initial implementation. Multi-user needs to be validated first.

### Phase 13: Session Recording/Replay (Optional)

**Goal:** Record terminal sessions for debugging/training purposes.

- `terminal-session record` → saves all terminal output to file
- `terminal-session replay` → replays session in real-time
- Export to asciinema format

**Why deferred:** Niche use case. Evaluate user demand before implementing.

---

## Handoff Signals

After completing this plan:

1. **Start implementation:**
   - Run `/syntek-dev-suite:stories` to create user stories for each phase
   - Run `/syntek-dev-suite:sprint` to organise phases into balanced sprints

2. **Phase 1-4 implementation:**
   - Run `/syntek-dev-suite:backend` to implement NixOS modules (Kitty, Hyprland keybinds)
   - Run `/syntek-dev-suite:frontend` (N/A - no UI components)
   - Manually implement Python kittens (not Rust, so no backend agent needed)

3. **Phase 5-8 implementation:**
   - Run `/syntek-dev-suite:backend` to implement Rust CLI tools
   - Update `flake.nix` to build new Rust packages

4. **Testing:**
   - Run `/syntek-dev-suite:test-writer` to create integration tests for each phase
   - Manual testing using checklist in `docs/TERMINAL-MANAGEMENT-CHECKLIST.MD`

5. **Documentation:**
   - Run `/syntek-dev-suite:doc-writer` to generate user-facing documentation
   - Update `CLAUDE.md` with new commands (`just terminal-session-list`, `just server-status`, etc.)

6. **Deployment:**
   - Run `/syntek-dev-suite:cicd` to set up NixOS rebuild automation (if needed)
   - Deploy to `laptop-intel` first (testing), then `framework`, `devtower`

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 12/02/2026 | Initial implementation plan created |

---

**End of Implementation Plan**
