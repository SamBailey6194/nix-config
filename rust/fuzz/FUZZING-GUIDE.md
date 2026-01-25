# Fuzzing Guide for nix-config Rust Tools

This guide covers comprehensive fuzzing infrastructure for security-critical Rust tools in the nix-config repository.

## Table of Contents

- [Overview](#overview)
- [Fuzz Targets](#fuzz-targets)
- [Quick Start](#quick-start)
- [Running Fuzzing Campaigns](#running-fuzzing-campaigns)
- [Analyzing Results](#analyzing-results)
- [CI/CD Integration](#cicd-integration)
- [Best Practices](#best-practices)

---

## Overview

Fuzzing is configured using **cargo-fuzz** (libFuzzer) with coverage-guided mutation. All security-critical parsing, validation, and cryptographic functions are fuzzed to discover:

- **Panics and crashes** - Unhandled edge cases
- **Path traversal** - Directory traversal attacks
- **Injection vulnerabilities** - Command/shell injection
- **Memory safety issues** - Buffer overflows, use-after-free
- **Logic errors** - Incorrect validation, off-by-one errors

### Fuzzing Engine

- **libFuzzer**: Coverage-guided fuzzing with LLVM sanitizers
- **Sanitizers**: AddressSanitizer, MemorySanitizer, UndefinedBehaviorSanitizer
- **Corpus**: Seed inputs in `fuzz/corpus/` for each target

---

## Fuzz Targets

### Security-Critical Targets

| Target | Module | Purpose | Risk Level |
|--------|--------|---------|------------|
| `fuzz_secret_name_validation` | agenix-helper | Path traversal in secret names | **CRITICAL** |
| `fuzz_wireguard_validation` | wireguard-helper | Input validation for VPN config | **HIGH** |
| `fuzz_mullvad_relay_parsing` | wireguard-helper | JSON parsing of Mullvad API | **HIGH** |
| `fuzz_wireguard_config_generation` | wireguard-helper | WireGuard config generation | **MEDIUM** |
| `fuzz_malware_heuristics` | malware-scanner | Heuristic malware detection | **MEDIUM** |
| `fuzz_path_validation` | agenix-helper | Path canonicalization attacks | **CRITICAL** |

### Target Details

#### 1. **fuzz_secret_name_validation**

**Purpose**: Prevents path traversal in agenix secret names.

**Tested Functions**:
- `validate_secret_name()` - Rejects `../`, `/`, `\` in secret names
- `validate_name()` - Prevents shell injection in device/server names

**Example Inputs**:
```rust
// Valid
"github-ssh-personal"
"server_key"

// Should be rejected
"../etc/passwd"
"../../secret"
"/etc/shadow"
"key; rm -rf /"
```

#### 2. **fuzz_wireguard_validation**

**Purpose**: Validates WireGuard configuration inputs.

**Tested Functions**:
- `validate_wg_key()` - WireGuard public/private key format (44 chars base64)
- `validate_hostname()` - DNS hostname format
- `validate_ipv4()` - IPv4 address parsing
- `validate_country_code()` - ISO 3166-1 alpha-2 codes
- `validate_simple_filename()` - Filename without path components

**Example Inputs**:
```rust
// Valid WireGuard key (44 chars base64)
"WJvRtX+jiRq/yvJKdYZKcMJl6gk0Gs4RN7WBFnoJnXs="

// Valid hostname
"se-sto-wg-001.mullvad.net"

// Valid IPv4
"185.65.134.66"
```

#### 3. **fuzz_mullvad_relay_parsing**

**Purpose**: Fuzzes JSON deserialization of Mullvad API relay lists.

**Tested Functions**:
- `serde_json::from_str::<RelayList>()` - JSON parsing
- Relay validation pipeline

**Example Input**:
```json
{
  "wireguard": {
    "relays": [{
      "hostname": "se-sto-wg-001",
      "ipv4_addr_in": "185.65.134.66",
      "ipv6_addr_in": "2a03:1b20:5:f011::a01f",
      "public_key": "WJvRtX+jiRq/yvJKdYZKcMJl6gk0Gs4RN7WBFnoJnXs=",
      "multihop_port": 51820,
      "country_code": "se",
      "city_name": "Stockholm",
      "active": true
    }]
  }
}
```

#### 4. **fuzz_wireguard_config_generation**

**Purpose**: Tests WireGuard config generation with malformed relay data.

**Tested Functions**:
- `generate_config()` - WireGuard INI-style config generation

**Input Format**: `privateKey|hostname|ipv4|ipv6|publicKey|port|country|city`

#### 5. **fuzz_malware_heuristics**

**Purpose**: Tests malware detection heuristics for crashes and false positives.

**Tested Functions**:
- `HeuristicEngine::analyze()` - Pattern-based malware detection

**Input Format**: `<256 bytes path>|<file content>`

#### 6. **fuzz_path_validation**

**Purpose**: Prevents directory traversal via symlinks and `..` components.

**Tested Functions**:
- `validate_path_in_directory()` - Path canonicalization

**Input Format**: `<path>|<base_directory>`

---

## Quick Start

### Prerequisites

1. **Install Rust nightly**:
   ```bash
   rustup install nightly
   rustup default nightly
   ```

2. **Install cargo-fuzz**:
   ```bash
   cargo install cargo-fuzz
   ```

### Run Your First Fuzz Test

```bash
cd rust/fuzz

# Quick fuzzing (1 minute)
cargo fuzz run fuzz_secret_name_validation -- -max_total_time=60

# Check for crashes
ls artifacts/fuzz_secret_name_validation/
```

---

## Running Fuzzing Campaigns

### Basic Fuzzing

```bash
# Fuzz for 10 minutes
cargo fuzz run fuzz_wireguard_validation -- -max_total_time=600

# Fuzz with specific number of runs
cargo fuzz run fuzz_mullvad_relay_parsing -- -runs=1000000
```

### Advanced Fuzzing

#### With AddressSanitizer (default)

```bash
cargo fuzz run fuzz_path_validation -- \
  -max_total_time=3600 \
  -print_final_stats=1
```

#### With MemorySanitizer

```bash
cargo fuzz run fuzz_secret_name_validation \
  --sanitizer memory -- \
  -max_total_time=1800
```

#### With UndefinedBehaviorSanitizer

```bash
cargo fuzz run fuzz_wireguard_config_generation \
  --sanitizer undefined -- \
  -max_total_time=1800
```

### Parallel Fuzzing

```bash
# Run 4 parallel jobs
cargo fuzz run fuzz_malware_heuristics -- \
  -jobs=4 \
  -workers=4 \
  -max_total_time=3600
```

---

## Analyzing Results

### Check for Crashes

```bash
# List crash artifacts
ls -la artifacts/fuzz_secret_name_validation/

# View crash input
hexdump -C artifacts/fuzz_secret_name_validation/crash-xyz
```

### Minimize Crashing Input

```bash
# Minimize crash to smallest input that triggers the bug
cargo fuzz tmin fuzz_secret_name_validation artifacts/fuzz_secret_name_validation/crash-xyz
```

### Minimize Corpus

```bash
# Remove redundant inputs from corpus
cargo fuzz cmin fuzz_wireguard_validation
```

### Coverage Reporting

```bash
# Generate coverage report
cargo fuzz coverage fuzz_mullvad_relay_parsing

# View HTML coverage report (requires llvm-cov)
cargo cov -- show target/x86_64-unknown-linux-gnu/coverage/x86_64-unknown-linux-gnu/release/fuzz_mullvad_relay_parsing \
  --format=html > coverage.html
```

---

## CI/CD Integration

Fuzzing runs automatically on:

1. **Pull Requests** - Quick 1-minute fuzzing per target
2. **Scheduled (Daily)** - Extended 1-hour fuzzing campaigns
3. **Manual Trigger** - Custom duration fuzzing

### GitHub Actions Workflow

Location: `.github/workflows/fuzzing.yml`

**Jobs**:
- `fuzz-quick`: PR validation (1 minute per target)
- `fuzz-extended`: Daily extended fuzzing (1 hour per target)
- `fuzz-sanitizer`: Sanitizer-based fuzzing (AddressSanitizer, MemorySanitizer, UndefinedBehaviorSanitizer)

### Manual Trigger

```bash
# Via GitHub Actions UI
# 1. Go to Actions tab
# 2. Select "Continuous Fuzzing" workflow
# 3. Click "Run workflow"
# 4. Set custom fuzz_time (default: 300 seconds)
```

---

## Best Practices

### 1. Seed Corpus Management

- **Add valid inputs**: Help fuzzer understand expected input format
- **Add edge cases**: Boundary conditions, empty strings, max-length inputs
- **Add attack vectors**: Known path traversal, injection payloads

```bash
# Add new seed input
echo "new-valid-secret-name" > corpus/fuzz_secret_name_validation/seed_new
```

### 2. Regular Fuzzing

- **Daily automated fuzzing**: Catch regressions early
- **Pre-release fuzzing**: Run extended campaigns before version bumps
- **Post-refactor fuzzing**: Verify safety of code changes

### 3. Crash Analysis

1. **Reproduce crash locally**:
   ```bash
   cargo fuzz run fuzz_target artifacts/fuzz_target/crash-xyz
   ```

2. **Minimize input**:
   ```bash
   cargo fuzz tmin fuzz_target artifacts/fuzz_target/crash-xyz
   ```

3. **Debug with GDB/LLDB**:
   ```bash
   gdb --args target/x86_64-unknown-linux-gnu/release/fuzz_target artifacts/crash-xyz
   ```

4. **Fix bug and add regression test**:
   ```rust
   #[test]
   fn test_regression_crash_xyz() {
       let input = include_bytes!("../fuzz/artifacts/crash-xyz");
       let result = validate_function(input);
       assert!(result.is_err()); // Should not panic
   }
   ```

### 4. Corpus Minimization

Minimize corpus monthly to reduce fuzzing overhead:

```bash
# Minimize all targets
for target in fuzz/fuzz_targets/*.rs; do
    name=$(basename "$target" .rs)
    cargo fuzz cmin "$name"
done
```

### 5. Integration with Development Workflow

```bash
# 1. Before committing changes
cargo fuzz run fuzz_target -- -max_total_time=300

# 2. Check for new crashes
[ -d artifacts/fuzz_target ] && echo "CRASHES FOUND" && exit 1

# 3. If no crashes, commit changes
git add .
git commit -m "Add new validation logic"

# 4. CI will run extended fuzzing on PR
```

---

## Troubleshooting

### Issue: "error: target `fuzz_target` not found"

**Solution**: Ensure you're in the `rust/fuzz` directory.

### Issue: "could not compile `libfuzzer-sys`"

**Solution**: Use Rust nightly:
```bash
rustup default nightly
```

### Issue: Fuzzing runs slowly

**Solution**: Use parallel jobs:
```bash
cargo fuzz run target -- -jobs=4 -workers=4
```

### Issue: Out of memory

**Solution**: Limit corpus size or reduce max input length:
```bash
cargo fuzz run target -- -rss_limit_mb=2048 -max_len=4096
```

---

## Resources

- [cargo-fuzz Documentation](https://rust-fuzz.github.io/book/cargo-fuzz.html)
- [libFuzzer Options](https://llvm.org/docs/LibFuzzer.html#options)
- [Rust Fuzzing Trophy Case](https://github.com/rust-fuzz/trophy-case)

---

**Last Updated**: 2026-01-24
**Fuzzing Infrastructure Version**: 1.0.0
