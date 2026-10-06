# Nix source and build artifacts

Use Git-backed flake references (`.` or `git+file:///absolute/repo`) when
evaluating repositories. Never pass a working repository as `path:`: Nix
copies ignored files too, including Rust targets, node_modules and .git.

If Nix needs new, untracked source without changing the Git index, first run
`python3 scripts/prepare-nix-source.py /tmp/nix-config-source-UNIQUE` from this
repository. Only use `path:` with that fresh, filtered copy. Do not modify
the Git index just to make an evaluation work. Other repositories need their
own source-only copy; do not assume .gitignore filters a path flake.

Keep `CARGO_TARGET_DIR` outside repositories, normally
`${XDG_CACHE_HOME:-$HOME/.cache}/cargo-target`. Shells may override it with
another directory outside a repository. Existing target directories are
not moved automatically; remove obsolete artifacts only when authorised.

Use Docker's build-cache GC/prune interfaces. Never automate deletion of
containerd leases or snapshots based only on age or absence from
`docker system df`: running containers and active builds can depend on them.
