# Terminal Management System - Implementation Checklist

**Version:** 1.0.0
**Last Updated:** 12/02/2026

---

## Quick Reference

**Total Phases:** 10
**Estimated Timeline:** 4-6 weeks (assuming 1-2 phases per week)
**Priority Order:** Phase 1 → 2 → 3 → 4 (core functionality), then 5-10 (enhancements)

---

## Phase 1: Kitty Configuration & Basic Integration ✅/❌

**Goal:** Replace terminator with Kitty as primary terminal.

**Estimated Time:** 2-4 hours

### NixOS Configuration
- [ ] Create `modules/desktop/kitty/default.nix`
- [ ] Create `config/kitty/kitty.conf`
- [ ] Create `config/kitty/ayu-dark.conf`
- [ ] Update `config/hypr/keybinds.conf` (terminator → kitty)
- [ ] Update `modules/desktop/hyprland/default.nix` (remove terminator)
- [ ] Update `home/common.nix` (enable programs.kitty)

### Testing
```bash
just rebuild
Super+Return  # Should launch Kitty with Ayu Dark theme
kitty --debug-config | grep -A5 "background"
```

### Success Criteria
- [ ] Kitty launches with `Super+Return`
- [ ] Ayu Dark colour scheme applied
- [ ] Font is JetBrains Mono Nerd Font
- [ ] No errors in `journalctl --user -u hyprland.service`

---

## Phase 2: Python Kitten Infrastructure ✅/❌

**Goal:** Set up Python kittens for session orchestration.

**Estimated Time:** 4-6 hours

### Python Scripts
- [ ] Create `config/kitty/kittens/session-launcher.py`
- [ ] Create `config/kitty/kittens/layout-parser.py`
- [ ] Create `config/kitty/sessions/development.toml`
- [ ] Create `config/kitty/sessions/README.md`

### NixOS Configuration
- [ ] Update `modules/desktop/kitty/default.nix` (Python dependencies, remote control)
- [ ] Install kittens to `~/.config/kitty/kittens/`

### Testing
```bash
just rebuild
python3 ~/.config/kitty/kittens/session-launcher.py development
hyprctl clients | grep -c "class: kitty"  # Should output: 4
```

### Success Criteria
- [ ] `session-launcher.py` launches 4 Kitty windows
- [ ] Hyprland tiles windows automatically (2x2 grid)
- [ ] Each window has correct title (dev, logs, git, test)
- [ ] Working directories set correctly

---

## Phase 3: SSH Session Management ✅/❌

**Goal:** Extend kittens to establish SSH connections.

**Estimated Time:** 6-8 hours

### Python Scripts
- [ ] Create `config/kitty/kittens/ssh-manager.py`
- [ ] Update `config/kitty/kittens/session-launcher.py` (v2: SSH support)
- [ ] Create `config/kitty/sessions/monitoring.toml`

### NixOS Configuration
- [ ] Update `modules/core/ssh-config.nix` (add server definitions)
- [ ] Add SSH error handling + dunst notifications

### Testing
```bash
just rebuild
python3 ~/.config/kitty/kittens/session-launcher.py monitoring
# In each SSH'd window:
hostname  # Should show remote server name
tail ~/.local/share/kitty/session-errors.log
```

### Success Criteria
- [ ] SSH connections established using correct per-device keys
- [ ] Remote hostname displayed in SSH'd terminals
- [ ] Failed SSH shows desktop notification
- [ ] Error log created at `~/.local/share/kitty/session-errors.log`

---

## Phase 4: Hyprland Hotkey Integration ✅/❌

**Goal:** Bind kittens to Hyprland hotkeys for one-key launching.

**Estimated Time:** 2-3 hours

### Scripts & Configuration
- [ ] Create `~/.local/bin/kitty-session` wrapper script
- [ ] Update `modules/desktop/kitty/default.nix` (install wrapper)
- [ ] Update `config/hypr/keybinds.conf` (add Super+Shift+1-9 bindings)
- [ ] Update `config/hypr/README.md` (document new hotkeys)
- [ ] Create `docs/TERMINAL-SESSION-GUIDE.MD`

### Testing
```bash
just rebuild
Super+Shift+1  # Launch development layout
Super+Shift+2  # Launch monitoring layout
Super+Shift+9  # Should show "Layout not found" notification
```

### Success Criteria
- [ ] `Super+Shift+1` launches development layout instantly
- [ ] `Super+Shift+2` launches monitoring layout with SSH
- [ ] Invalid layout shows error notification
- [ ] Documentation created with examples

---

## Phase 5: Rust CLI - Session Management ✅/❌

**Goal:** Build Rust CLI for session save/restore.

**Estimated Time:** 8-12 hours

### Rust Project
- [ ] Create `rust/terminal-session/` project
- [ ] Implement `src/main.rs` (CLI with clap)
- [ ] Implement `src/session.rs` (session state management)
- [ ] Implement `src/config.rs` (TOML parsing)
- [ ] Update `rust/Cargo.toml` (workspace member)
- [ ] Update `flake.nix` (build + install package)
- [ ] Update `justfile` (add commands)

### Testing
```bash
just rebuild
Super+Shift+1  # Launch development layout
terminal-session save my-dev-work
pkill kitty
terminal-session restore my-dev-work
hyprctl clients | grep -c "class: kitty"  # Should match saved state
```

### Success Criteria
- [ ] `terminal-session list` shows active sessions
- [ ] `terminal-session save <name>` saves to JSON
- [ ] `terminal-session restore <name>` restores windows + SSH
- [ ] Saved state includes working directories

---

## Phase 6: Rust CLI - Server Management ✅/❌

**Goal:** Build Rust CLI for server operations.

**Estimated Time:** 12-16 hours

### Rust Project
- [ ] Create `rust/server-manager/` project
- [ ] Implement `src/main.rs` (CLI)
- [ ] Implement `src/status.rs` (health checks)
- [ ] Implement `src/deploy.rs` (deployment operations)
- [ ] Create `config/server-manager/deploy.toml`
- [ ] Update `flake.nix` (build + install)
- [ ] Update `justfile` (add commands)

### Testing
```bash
just rebuild
server-manager status --all
# Should show table: Server | Status | CPU | Memory | Disk
server-manager deploy --env staging
# Should show deployment logs in real-time
```

### Success Criteria
- [ ] `server-manager status --all` completes in < 2s (5+ servers)
- [ ] Status displayed in formatted table
- [ ] Deployment streams logs in real-time
- [ ] Rollback on deployment failure

---

## Phase 7: Rust CLI - Log Aggregation ✅/❌

**Goal:** Build Rust CLI for multi-server log collection.

**Estimated Time:** 10-14 hours

### Rust Project
- [ ] Create `rust/log-aggregator/` project
- [ ] Implement `src/main.rs` (CLI)
- [ ] Implement `src/collector.rs` (parallel log fetch)
- [ ] Implement `src/filter.rs` (regex + time filtering)
- [ ] Create `config/log-aggregator/sources.toml`
- [ ] Update `flake.nix` (build + install)
- [ ] Update `justfile` (add commands)

### Testing
```bash
just rebuild
log-aggregator fetch --service api --since 1h
# Should show chronological logs from all API servers
log-aggregator follow --all
# Should stream logs in real-time
log-aggregator fetch --level ERROR --since 24h
# Should show only ERROR logs
```

### Success Criteria
- [ ] Logs fetched from multiple servers in parallel
- [ ] Merged logs sorted by timestamp
- [ ] Regex filtering works
- [ ] Follow mode streams real-time logs
- [ ] Export to JSON works

---

## Phase 8: Rust CLI - Database Operations ✅/❌

**Goal:** Build Rust CLI for database queries and admin tasks.

**Estimated Time:** 12-16 hours

### Rust Project
- [ ] Create `rust/db-tools/` project
- [ ] Implement `src/main.rs` (CLI)
- [ ] Implement `src/query.rs` (query execution)
- [ ] Implement `src/admin.rs` (admin operations)
- [ ] Create agenix secrets for DB connection strings
- [ ] Update `modules/core/secrets-*.nix` (add DB secrets)
- [ ] Update `home/common.nix` (export DB env vars)
- [ ] Update `flake.nix` (build + install)
- [ ] Update `justfile` (add commands)

### Testing
```bash
just rebuild
db-tools query --sql "SELECT COUNT(*) FROM users" --env production
# Should show user count
db-tools replicas --env production
# Should show replication lag
db-tools admin --slow-queries --env production
# Should show table of slow queries
```

### Success Criteria
- [ ] Queries execute without password prompt (uses agenix secret)
- [ ] Read-only by default (`--write` required for mutations)
- [ ] Replica status shows lag in seconds
- [ ] Results formatted as table
- [ ] JSON export works

---

## Phase 9: Session State Persistence ✅/❌

**Goal:** Auto-save and restore sessions across reboots.

**Estimated Time:** 6-8 hours

### Implementation
- [ ] Update `rust/terminal-session/src/session.rs` (auto_save function)
- [ ] Create `kitty-session-autosave.service` systemd service
- [ ] Update `modules/desktop/kitty/default.nix` (install service)
- [ ] Create `config/kitty/kittens/restore-prompt.py`
- [ ] Update `config/hypr/autostart.conf` (restore prompt)

### Testing
```bash
just rebuild
Super+Shift+1  # Launch development layout
sleep 300  # Wait for autosave
cat ~/.local/share/kitty/autosave.json
sudo reboot
# After login: should see "Restore previous session?" notification
# Click "Yes" → session restored
```

### Success Criteria
- [ ] Autosave runs every 5 minutes
- [ ] Autosave file contains current state
- [ ] Restore prompt appears after reboot
- [ ] Restored session includes SSH connections
- [ ] Autosave deleted after successful restore

---

## Phase 10: Advanced Layout Features ✅/❌

**Goal:** Add workspace assignment, environment variables, dynamic commands.

**Estimated Time:** 8-12 hours

### Implementation
- [ ] Update TOML schema (v2: workspace, env, dynamic_command)
- [ ] Create `config/kitty/sessions/vars.env`
- [ ] Update `config/kitty/kittens/layout-parser.py` (v2)
- [ ] Update `config/kitty/kittens/session-launcher.py` (v3)
- [ ] Update `config/hypr/windowrules.conf` (workspace assignment)

### Testing
```bash
just rebuild
# Create advanced layout with workspace=3, env vars, dynamic commands
Super+Shift+4
hyprctl clients | grep "workspace: 3"  # Should show Kitty windows
# In terminal with env: { NODE_ENV = "development" }
echo $NODE_ENV  # Should output: development
# Focus away from dynamic_command window, then back
# Command should re-run
```

### Success Criteria
- [ ] Workspace assignment works
- [ ] Environment variables applied per window
- [ ] Variable interpolation works (from vars.env)
- [ ] Dynamic commands re-run on focus
- [ ] Schema version validation works

---

## Final Validation Checklist ✅/❌

### Core Functionality
- [ ] All 10 phases completed
- [ ] All hotkeys working (`Super+Shift+1-9`)
- [ ] All Rust CLIs installed and functional
- [ ] All documentation complete

### Performance Targets
- [ ] Kitty launch: < 300ms
- [ ] 4-window session launch (no SSH): < 500ms
- [ ] 4-window session launch (with SSH): < 3s
- [ ] `terminal-session list`: < 100ms
- [ ] `server-manager status --all` (5 servers): < 2s
- [ ] `log-aggregator fetch` (1h, 3 servers): < 5s
- [ ] `db-tools query` (simple SELECT): < 500ms

### Security
- [ ] All SSH keys managed via agenix
- [ ] No hardcoded credentials in code
- [ ] Database credentials in environment variables (from agenix)
- [ ] Autosave file permissions: mode 600

### Documentation
- [ ] `PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD` complete
- [ ] `TERMINAL-SESSION-GUIDE.MD` created (user guide)
- [ ] `config/kitty/sessions/README.md` created (layout reference)
- [ ] `config/hypr/README.md` updated (new hotkeys)
- [ ] Each Rust CLI has README.md

---

## Rollback Plan (If Issues Arise)

### Phase 1-4 Rollback
```bash
# Revert to terminator
git checkout HEAD~1 config/hypr/keybinds.conf
git checkout HEAD~1 modules/desktop/hyprland/default.nix
just rebuild
```

### Phase 5-10 Rollback
```bash
# Remove Rust CLIs from PATH
# Edit flake.nix to remove terminal-session, server-manager, etc.
just rebuild
```

### Full Rollback
```bash
# Revert to commit before terminal management implementation
git log --oneline | grep "feat(terminal)"  # Find commit hash
git revert <commit-hash>
just rebuild
```

---

## Post-Implementation Tasks

### Phase 11+ Planning (Future)
- [ ] Evaluate user feedback on Phases 1-10
- [ ] Decide on Tmux/Zellij integration (Phase 11)
- [ ] Decide on multi-user session sharing (Phase 12)
- [ ] Decide on session recording/replay (Phase 13)

### Maintenance
- [ ] Update dependencies monthly (`just update`)
- [ ] Test new Kitty versions before applying
- [ ] Monitor performance metrics
- [ ] Collect user feedback on layout workflows

---

**End of Checklist**
