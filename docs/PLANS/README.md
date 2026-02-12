# Implementation Plans

**Last Updated:** 12/02/2026
**Language:** British English (en_GB)

---

## Purpose

This directory contains detailed implementation plans for major features in the nix-config repository. Each plan breaks down a complex feature into phased, testable implementation steps.

---

## Plan Structure

Each plan follows this format:

1. **Overview**: What we're building and why
2. **Requirements**: Functional and non-functional requirements
3. **Technical Design**: Architecture, component breakdown, file organisation
4. **Implementation Phases**: Step-by-step tasks with deliverables
5. **Risks & Mitigations**: What could go wrong and how to handle it
6. **Open Questions**: Decisions needed before/during implementation
7. **Success Criteria**: How to know the feature is complete

---

## Current Plans

| Plan | Status | Priority | Estimated Time |
|------|--------|----------|----------------|
| [Terminal Management System](PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD) | Draft | High | 4-6 weeks |

---

## Plan Naming Convention

**Format:** `PLAN-<FEATURE-NAME>.MD`

**Examples:**
- `PLAN-TERMINAL-MANAGEMENT-SYSTEM.MD`
- `PLAN-BACKUP-AUTOMATION.MD`
- `PLAN-MULTI-DEVICE-SYNC.MD`

**Rules:**
- Use FULL CAPITALISATION for filenames
- Use hyphens to separate words (not underscores or spaces)
- Use `.MD` extension (not `.md`)

---

## How to Use Plans

### For Architects
1. Read CLAUDE.md to understand the project context
2. Create a new plan in `docs/PLANS/`
3. Break the feature into 5-10 phases (each phase = 1-2 days work)
4. Define clear deliverables and success criteria per phase
5. Identify risks and open questions early

### For Implementers
1. Read the plan thoroughly before starting
2. Follow phases in order (don't skip ahead)
3. Complete the checklist for each phase (see `docs/TERMINAL-MANAGEMENT-CHECKLIST.MD`)
4. Update the plan if you discover new requirements or blockers
5. Mark phases complete as you finish them

### For Reviewers
1. Check that each phase has testable deliverables
2. Verify success criteria are measurable
3. Ensure risks have mitigations
4. Confirm phases can be completed in isolation (no hidden dependencies)

---

## Plan Lifecycle

### Draft
- Plan created but not yet reviewed
- May have open questions or missing details
- Not yet approved for implementation

### Approved
- Plan reviewed and approved by team
- Ready for implementation
- All open questions resolved (or deferred to later phases)

### In Progress
- Implementation has started
- Track progress using checklist (e.g., `TERMINAL-MANAGEMENT-CHECKLIST.MD`)
- Update plan if requirements change

### Complete
- All phases implemented and tested
- Success criteria met
- Documentation complete
- Plan archived (moved to `docs/PLANS/ARCHIVE/`)

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `CLAUDE.md` | Project overview, stack, conventions |
| `ARCHITECTURE.md` | System architecture, modular design |
| `docs/PLANS/<PLAN>.MD` | Feature implementation plans (this directory) |
| `docs/<FEATURE>-CHECKLIST.MD` | Phase-by-phase testing checklist |
| `docs/<FEATURE>-GUIDE.MD` | End-user documentation for completed features |

---

## Tips for Writing Good Plans

### Do:
- Break work into small, testable phases (1-2 days each)
- Define clear deliverables ("can run X command and see Y output")
- Identify risks early and propose mitigations
- Use diagrams for complex architectures
- Write success criteria that can be measured
- Consider performance, security, and usability from the start

### Don't:
- Create phases that depend on future unknown work
- Skip risk analysis for non-trivial features
- Make technology choices that contradict CLAUDE.md stack
- Write implementation code in the plan (save that for actual implementation)
- Create overly detailed plans that lock in decisions prematurely

### Example Phase Structure

```markdown
### Phase 3: SSH Session Management

**Goal:** Extend kittens to establish SSH connections using per-device agenix keys.

#### Tasks

- [ ] Create `config/kitty/kittens/ssh-manager.py`
  - Accept SSH target (user@host or hostname)
  - Resolve correct per-device SSH key from ~/.ssh/config
  - Build SSH command with correct identity file

- [ ] Update `config/kitty/kittens/session-launcher.py`
  - Check for `ssh_target` field in TOML layout
  - Call ssh-manager.py to build SSH command
  - Handle SSH connection errors (notify via dunst)

**Deliverable:** Run `python3 ~/.config/kitty/kittens/session-launcher.py monitoring` to launch 4 Kitty windows, 3 SSH'd to remote servers.

**Testing:**
```bash
# Launch monitoring layout
python3 ~/.config/kitty/kittens/session-launcher.py monitoring

# Verify SSH connections
hostname  # Should show remote server hostname
```

**Success Criteria:**
- [ ] SSH connections established using correct per-device keys
- [ ] Remote hostname displayed in terminals
- [ ] Failed SSH shows desktop notification
```

---

## Questions?

If you have questions about a plan or need clarification:

1. Check the plan's "Open Questions" section
2. Review related documentation (CLAUDE.md, ARCHITECTURE.md)
3. Ask the architect who created the plan
4. Update the plan with your findings

---

**End of README**
