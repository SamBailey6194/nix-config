# Terminal Management System - Architecture Summary

**Version:** 1.0.0
**Created:** 12/02/2026
**Language:** British English (en_GB)

---

## Overview

I've created a comprehensive implementation plan for your sophisticated terminal management system that leverages Hyprland's tiling capabilities with Kitty, Python kittens, and Rust CLI tools.

---

## Key Architectural Decisions

### 1. Layered Architecture (4 Layers)

**You were correct about the Rust CLI hotkey limitation.** The solution is a layered approach:

```
Layer 1: Hyprland (Window Manager)
         ↓ (Hotkeys: Super+Shift+1-9)
Layer 2: Python Kittens (Session Orchestration)
         ↓ (Launch Kitty sessions, SSH setup)
Layer 3: Kitty (Terminal Emulator)
         ↓ (Provides shell environment)
Layer 4: Rust CLIs (Performance-Critical Commands)
```

**Why this works:**
- Hyprland hotkeys → Python scripts (easy to bind)
- Python scripts → Open Kitty windows with SSH
- Kitty windows → Run Rust CLIs for fast operations
- Rust CLIs are **not** bound to hotkeys directly (Python glue layer handles orchestration)

### 2. Hyprland vs Terminator Tiling

**You're correct to use Kitty instead of Terminator.**

- Hyprland provides automatic tiling (no need for Terminator's built-in tiling)
- Kitty is more powerful (GPU acceleration, Python scripting via kittens)
- 4 terminal layout = 4 separate Kitty windows (Hyprland tiles them into 2x2 grid automatically)

### 3. Python Kittens for Orchestration

**Kittens handle:**
- Session layout parsing (TOML config files)
- SSH connection setup (using per-device agenix keys)
- Kitty window management (via Kitty remote control API)
- Error handling (dunst notifications)

**Example workflow:**
```bash
# User presses: Super+Shift+2
# Hyprland executes: kitty-session monitoring
# Python kitten:
#   1. Reads monitoring.toml
#   2. Launches 4 Kitty windows
#   3. SSH's 3 windows to production servers
#   4. Keeps 1 window local for control
# Result: 4 terminals auto-tiled, 3 SSH'd, all in < 3 seconds
```

### 4. Rust CLIs for Performance

**Rust tools are available in the shell once Kitty opens:**

```bash
# Inside any Kitty terminal (local or SSH'd):
server-manager status --all         # Check all servers in < 2s
log-aggregator fetch --since 1h     # Fetch logs from multiple servers
db-tools query --sql "SELECT ..."   # Query production database
terminal-session save my-work       # Save current session state
```

**Why Rust:**
- Speed: < 100ms response for status checks
- Parallel operations: Multiple SSH connections simultaneously
- Security: Integrates with agenix secrets (no hardcoded credentials)

---

## 10-Phase Implementation Plan

### Phases 1-4: Core Functionality (2-3 weeks)

**Phase 1:** Kitty configuration + Ayu Dark theme
**Phase 2:** Python kittens infrastructure + layout parsing
**Phase 3:** SSH session management (using agenix per-device keys)
**Phase 4:** Hyprland hotkey bindings (Super+Shift+1-9)

**Deliverable after Phase 4:**
```bash
Super+Shift+1  # Instant 4-terminal development layout
Super+Shift+2  # Instant 4-terminal monitoring (with SSH)
```

### Phases 5-8: Rust CLI Tools (2-3 weeks)

**Phase 5:** `terminal-session` CLI (save/restore sessions)
**Phase 6:** `server-manager` CLI (deployment + health checks)
**Phase 7:** `log-aggregator` CLI (multi-server log collection)
**Phase 8:** `db-tools` CLI (database queries + admin)

**Deliverable after Phase 8:**
All performance-critical operations available as Rust CLIs.

### Phases 9-10: Advanced Features (1 week)

**Phase 9:** Auto-save/restore sessions across reboots
**Phase 10:** Advanced layouts (workspace assignment, env vars, dynamic commands)

**Deliverable after Phase 10:**
Production-ready terminal management system with auto-restore.

---

## File Organization

```
nix-config/
├── modules/desktop/kitty/
│   ├── default.nix                  # NixOS module
│   └── kittens/                     # Python scripts
│       ├── session-launcher.py
│       ├── ssh-manager.py
│       └── layout-parser.py
│
├── config/kitty/
│   ├── kitty.conf                   # Kitty configuration
│   ├── ayu-dark.conf                # Colour scheme
│   └── sessions/                    # Layout definitions
│       ├── development.toml
│       ├── monitoring.toml
│       └── deployment.toml
│
├── rust/
│   ├── terminal-session/            # Session management CLI
│   ├── server-manager/              # Server operations CLI
│   ├── log-aggregator/              # Log collection CLI
│   └── db-tools/                    # Database CLI
│
└── docs/
    ├── PLANS/
    │   └── PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD  # Full implementation plan
    ├── TERMINAL-MANAGEMENT-CHECKLIST.MD        # Phase-by-phase checklist
    └── TERMINAL-MANAGEMENT-SUMMARY.MD          # This file
```

---

## Example Layout Configuration

### Development Layout (4 terminals, no SSH)

**File:** `~/.config/kitty/sessions/development.toml`

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

**Usage:**
```bash
Super+Shift+1  # Instant launch
# OR
kitty-session development  # Manual launch
```

### Monitoring Layout (4 terminals, 3 SSH'd)

**File:** `~/.config/kitty/sessions/monitoring.toml`

```toml
[layout]
name = "monitoring"
description = "Production server monitoring"

[[windows]]
title = "web-prod"
ssh_target = "web-production"  # From ~/.ssh/config
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
command = ""  # Local terminal for Rust CLIs
```

**Usage:**
```bash
Super+Shift+2  # Instant launch with SSH
# In local-control window:
server-manager status --all
log-aggregator follow --all
```

---

## Security Integration

### Per-Device SSH Keys (Existing agenix Setup)

**Already implemented in Phase 2:**
- Each device has unique SSH keys (generated via `agenix-helper add-server`)
- Keys encrypted with per-device public keys (agenix)
- Auto-generated SSH config (`modules/core/ssh-config.nix`)

**Terminal management integration:**
- Python `ssh-manager.py` reads `~/.ssh/config`
- Automatically selects correct per-device key for each SSH target
- No manual key selection needed

### Database Credentials (New - Phase 8)

**Stored in agenix:**
- `secrets/db-production-connection.age`
- `secrets/db-staging-connection.age`

**Accessed via environment variables:**
```bash
# Decrypted to /run/agenix/db-production-connection
# Exported by shell init (home/common.nix)
export DB_PRODUCTION_URL="postgresql://user:pass@host:5432/db"
```

**Rust CLI usage:**
```bash
# No password needed (reads from $DB_PRODUCTION_URL)
db-tools query --sql "SELECT COUNT(*) FROM users" --env production
```

---

## Performance Targets

| Operation | Target | Achieved By |
|-----------|--------|-------------|
| Kitty launch (single) | < 300ms | GPU acceleration, lightweight config |
| 4-window layout (no SSH) | < 500ms | Parallel window spawning |
| 4-window layout (with SSH) | < 3s | Parallel SSH connections |
| `terminal-session list` | < 100ms | Rust binary + Kitty socket IPC |
| `server-manager status --all` | < 2s | Parallel SSH (tokio async) |
| `log-aggregator fetch` (1h) | < 5s | Parallel fetch + merge |
| `db-tools query` | < 500ms | Direct PostgreSQL connection (no overhead) |

---

## Hotkey Reference

| Hotkey | Action | Description |
|--------|--------|-------------|
| `Super+Return` | Launch Kitty | Single terminal (standard) |
| `Super+Shift+1` | Development layout | 4 local terminals for dev work |
| `Super+Shift+2` | Monitoring layout | 3 SSH'd + 1 local (production monitoring) |
| `Super+Shift+3` | Deployment layout | Staging + production + logs |
| `Super+Shift+4-9` | Custom layouts | User-defined TOML layouts |

---

## Rust CLI Reference

### terminal-session

**Session state management:**
```bash
terminal-session list                 # Show active sessions
terminal-session save my-work         # Save current state
terminal-session restore my-work      # Restore saved state
terminal-session kill --all           # Close all Kitty windows
```

### server-manager

**Server operations:**
```bash
server-manager status --all           # Health check all servers
server-manager status --server web    # Check specific server
server-manager deploy --env staging   # Deploy to staging
server-manager rollback --env staging # Rollback deployment
```

### log-aggregator

**Log collection:**
```bash
log-aggregator fetch --service api --since 1h
log-aggregator follow --all
log-aggregator fetch --level ERROR --since 24h
log-aggregator export --format json --output logs.json
```

### db-tools

**Database operations:**
```bash
db-tools query --sql "SELECT COUNT(*) FROM users" --env production
db-tools replicas --env production
db-tools admin --vacuum --env staging
db-tools admin --slow-queries --env production
```

---

## Next Steps

### Immediate (Start Implementation)

1. **Read the full plan:**
   - `docs/PLANS/PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD`

2. **Start Phase 1:**
   - Follow `docs/TERMINAL-MANAGEMENT-CHECKLIST.MD`
   - Create Kitty configuration
   - Replace terminator with Kitty

3. **Test after each phase:**
   - Each phase has clear deliverables
   - Success criteria are measurable
   - Don't skip ahead (dependencies between phases)

### Questions to Answer Before Starting

From the plan's "Open Questions" section:

1. **SSH persistence:** Auto-reconnect or manual retry?
   - Recommendation: Start with manual (Phase 3), add auto-reconnect if needed (Phase 9)

2. **Layout storage:** Version-controlled or user-editable?
   - Recommendation: Hybrid (system defaults + user overrides)

3. **Rust CLI distribution:** System-wide or user-specific?
   - Recommendation: System-wide (simpler for single-user machines)

4. **Database credentials:** How to access agenix secrets?
   - Recommendation: Environment variables (exported on shell init)

5. **Layout versioning:** How to handle schema changes?
   - Recommendation: Version field in TOML (`schema_version = 2`)

---

## Documentation Created

| Document | Purpose | Location |
|----------|---------|----------|
| **Implementation Plan** | Full 10-phase plan with architecture, risks, success criteria | `docs/PLANS/PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD` |
| **Checklist** | Phase-by-phase testing checklist | `docs/TERMINAL-MANAGEMENT-CHECKLIST.MD` |
| **Summary** | This file - quick reference | `docs/TERMINAL-MANAGEMENT-SUMMARY.MD` |
| **Plans README** | How to use the planning system | `docs/PLANS/README.MD` |

---

## Estimated Timeline

**Conservative estimate:** 6 weeks (part-time work)
**Aggressive estimate:** 4 weeks (full-time work)

**Breakdown:**
- Phases 1-4: 2-3 weeks (core functionality)
- Phases 5-8: 2-3 weeks (Rust CLI tools)
- Phases 9-10: 1 week (advanced features)

**Each phase:** 1-2 days of focused work

---

## Questions?

If you have questions or want to discuss any architectural decisions:

1. Review the full plan: `docs/PLANS/PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD`
2. Check "Open Questions" section for unresolved decisions
3. Ask for clarification on specific phases

---

**Ready to start implementation?**

Run this to begin Phase 1:
```bash
# Read the full plan
less docs/PLANS/PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD

# Read the checklist
less docs/TERMINAL-MANAGEMENT-CHECKLIST.MD

# Start Phase 1 tasks
# (see checklist for specific steps)
```

---

**End of Summary**
