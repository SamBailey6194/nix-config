# Fuzzing Infrastructure

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
Comprehensive fuzzing for security-critical Rust tools in nix-config.

## Quick Start

```bash
# Install prerequisites
rustup install nightly
cargo install cargo-fuzz

# Run quick fuzzing (all targets, 1 minute each)
just fuzz-quick

# Fuzz specific target
just fuzz fuzz_secret_name_validation 300

# Check for crashes
just fuzz-check
```

## Fuzz Targets

| Target | Risk | Purpose |
|--------|------|---------|
| `fuzz_secret_name_validation` | CRITICAL | Path traversal in secret names |
| `fuzz_wireguard_validation` | HIGH | Input validation for VPN config |
| `fuzz_mullvad_relay_parsing` | HIGH | JSON API parsing |
| `fuzz_wireguard_config_generation` | MEDIUM | Config generation |
| `fuzz_malware_heuristics` | MEDIUM | Malware detection engine |
| `fuzz_path_validation` | CRITICAL | Directory traversal prevention |

## Documentation

- **Complete Guide**: [FUZZING-GUIDE.md](./FUZZING-GUIDE.md)
- **Summary**: [../FUZZING-INFRASTRUCTURE-SUMMARY.md](../../FUZZING-INFRASTRUCTURE-SUMMARY.md)

## CI/CD

Automated fuzzing runs:
- **Pull Requests**: 1 minute per target
- **Daily (Scheduled)**: 1 hour per target
- **Manual Trigger**: Custom duration

See `.github/workflows/fuzzing.yml`

## Commands

```bash
# List all targets
just fuzz-list

# Fuzz with sanitizers
just fuzz-asan TARGET 300   # AddressSanitizer
just fuzz-msan TARGET 300   # MemorySanitizer
just fuzz-ubsan TARGET 300  # UndefinedBehaviorSanitizer

# Minimize corpus
just fuzz-cmin

# Clean artifacts
just fuzz-clean
```

## Structure

```
fuzz/
├── Cargo.toml              # Fuzz workspace
├── README.md               # This file
├── FUZZING-GUIDE.md        # Complete documentation
├── fuzz_targets/           # 6 fuzz target harnesses
└── corpus/                 # Seed corpus (13 inputs)
```

## Security Impact

Prevents:
- ✅ Path traversal attacks
- ✅ Shell/command injection
- ✅ Denial of service (panics)
- ✅ Memory safety issues
- ✅ Logic errors in validation

---

**See [FUZZING-GUIDE.md](./FUZZING-GUIDE.md) for complete documentation.**
