# Rust Tooling for NixOS Configuration

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
This workspace contains Rust-based CLI tools for managing the NixOS configuration, with a focus on secrets management and security.

## Tools

### Phase 2: Secrets Management

#### secrets-verify

Verifies that agenix secrets are deployed correctly on the system.

**Features:**
- ✅ Checks secret files exist
- ✅ Verifies file permissions (0600 for SSH keys)
- ✅ Validates SSH key format
- ✅ Tests GitHub SSH connections
- ✅ Fast compiled binary

```bash
secrets-verify                  # Basic verification
secrets-verify --test-github    # Test GitHub connections
secrets-verify --verbose        # Show all secrets
```

See `secrets-verify/README.md` for full documentation.

#### agenix-helper

CLI helper for managing agenix secrets with per-device key generation.

**Features:**
- 🔐 Edit encrypted secrets
- 🔄 Rekey all secrets after adding hosts
- 📋 List secrets and authorized keys
- 🔑 Generate per-device SSH keys for servers
- 🚀 Initialize secrets for new devices
- ✅ Verify host keys

```bash
# Edit a secret
agenix-helper edit github-ssh-personal-laptop-intel

# List all secrets
agenix-helper list

# Generate per-device server keys
agenix-helper add-server client-acme

# Rekey all secrets
agenix-helper rekey
```

See `agenix-helper/README.md` for full documentation.

### Phase 10: Security Wrapper (Future)

The `security-wrapper/` crate is reserved for Phase 10, which will implement:
- Hashicorp Vault / OpenBao integration
- Automatic secret rotation
- Secure secret injection
- Hardware key support (Yubikey)

This is currently disabled in the workspace but the structure is ready for future implementation.

## Building

### Automatic Build (Recommended)

Enter the nix dev shell, which auto-builds all Rust tools:

```bash
cd /path/to/nix-config
nix develop
# Rust tools are automatically built and added to PATH
```

### Manual Build

```bash
cd rust
cargo build --release

# Binaries will be in:
# - target/release/secrets-verify
# - target/release/agenix-helper
```

### Development Build

```bash
cd rust
cargo build

# Faster compilation, binaries in target/debug/
```

## Development

### Adding a New Tool

1. Create a new crate:
   ```bash
   cd rust
   cargo new --bin my-new-tool
   ```

2. Add to workspace `Cargo.toml`:
   ```toml
   [workspace]
   members = [
       "secrets-verify",
       "agenix-helper",
       "my-new-tool",  # Add here
   ]
   ```

3. Use workspace dependencies:
   ```toml
   # In my-new-tool/Cargo.toml
   [dependencies]
   clap = { workspace = true }
   anyhow = { workspace = true }
   colored = { workspace = true }
   ```

4. Build and test:
   ```bash
   cargo build --release
   cargo test
   ```

### Shared Dependencies

Common dependencies are defined in the workspace `Cargo.toml`:

- **CLI**: `clap`, `colored`
- **Error handling**: `anyhow`, `thiserror`
- **File system**: `walkdir`, `dirs`
- **Process execution**: `which`
- **Serialization**: `serde`, `serde_json`, `toml`

Add new shared dependencies to `[workspace.dependencies]` to keep versions consistent.

## Testing

```bash
# Run all tests
cargo test

# Run tests for a specific crate
cargo test -p secrets-verify

# Run with verbose output
cargo test -- --nocapture
```

## Linting

```bash
# Check code with Clippy
cargo clippy

# Fix auto-fixable issues
cargo clippy --fix

# Format code
cargo fmt

# Check formatting without changing
cargo fmt --check
```

## Integration with NixOS

The Rust tools are automatically built and added to PATH when entering the nix dev shell via `flake.nix`:

```nix
devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
  buildInputs = [
    cargo
    rustc
    rust-analyzer
    # ...
  ];

  shellHook = ''
    if [ -d rust ]; then
      cd rust && cargo build --release && cd ..
      export PATH="$PWD/rust/target/release:$PATH"
    fi
  '';
};
```

## Architecture Decisions

### Why Rust?

1. **Performance**: Compiled to native code, instant startup
2. **Type Safety**: Catch errors at compile time, not runtime
3. **Memory Safety**: No segfaults or buffer overflows
4. **Cross-platform**: Works on all NixOS devices
5. **Excellent tooling**: Cargo, rustfmt, clippy, rust-analyzer
6. **Future-proof**: Easy to extend with more complex security features

### Why Workspace?

- **Shared dependencies**: Single version of dependencies
- **Fast compilation**: Shared incremental compilation cache
- **Easy maintenance**: Update all tools together
- **Smaller binaries**: Shared dependencies reduce size
- **Clear organization**: All Rust code in one place

### Design Patterns

- **Subcommands**: Use `clap` with subcommands for multiple operations
- **Colored output**: Use `colored` for clear success/failure indicators
- **Error handling**: Use `anyhow` for application errors, `thiserror` for libraries
- **File operations**: Use `std::fs` for basic operations, `walkdir` for traversal
- **Process execution**: Use `std::process::Command` for external tools

## Performance

All tools are optimized for:

- **Fast startup**: No interpreter overhead
- **Low memory**: Efficient Rust memory management
- **Quick execution**: Native code performance
- **Parallel operations**: Use Rust's async/threading when beneficial

## Security Considerations

- **Input validation**: All user input is validated
- **Path traversal**: Paths are canonicalized and checked
- **Command injection**: No shell execution, only direct process spawning
- **Secret handling**: Secrets never logged or printed to terminal
- **File permissions**: Enforced strict permissions (0600 for keys)

## Future Enhancements

### Phase 3-9
- Backup verification tools
- Network configuration helpers
- System health checks

### Phase 10+
- Vault/OpenBao integration
- Automatic secret rotation
- Hardware key support
- Remote attestation
- Audit logging

## Contributing

When adding new Rust tools:

1. Follow existing patterns (subcommands, colored output, error handling)
2. Add comprehensive `--help` text
3. Include a README.md in the crate
4. Add examples to the crate README
5. Write tests for core functionality
6. Run `cargo fmt` and `cargo clippy` before committing

## Resources

- [Rust Book](https://doc.rust-lang.org/book/)
- [Clap Documentation](https://docs.rs/clap/)
- [Anyhow Documentation](https://docs.rs/anyhow/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Agenix Documentation](https://github.com/ryantm/agenix)
