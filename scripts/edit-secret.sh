#!/usr/bin/env bash
# Edit a secret without requiring the Rust helper to be built or installed.
set -euo pipefail

secret_name=${1:-}
secret_base=${secret_name%.age}
if [[ ! "$secret_base" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]]; then
  echo "Usage: edit-secret.sh <secret-name> (with or without .age)" >&2
  exit 2
fi
secret_name="$secret_base.age"
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
secrets_dir="$repo_dir/secrets"
if [[ -L "$secrets_dir/$secret_name" ]]; then
  echo "Refusing to edit a symlink in secrets/." >&2
  exit 2
fi

# Edit in this terminal, not the global $EDITOR (Zed opens a GUI tab and agenix
# then waits until it closes). Restricted nano with no rc file writes no backup
# or history files, so the plaintext stays in agenix's temporary directory.
# SECRET_EDITOR overrides this. Piped input skips the editor (agenix copies stdin).
if [[ -n "${SECRET_EDITOR:-}" ]]; then
  export EDITOR="$SECRET_EDITOR"
elif command -v nano >/dev/null 2>&1; then
  export EDITOR="nano --restricted --ignorercfiles"
else
  echo "nano is not installed; set SECRET_EDITOR to a terminal editor." >&2
  exit 2
fi

identity=${AGENIX_IDENTITY:-$HOME/.ssh/id_ed25519_agenix}
agenix_args=(-e "$secret_name")
if [[ -f "$identity" ]]; then
  agenix_args+=(-i "$identity")
fi
cd -- "$secrets_dir"
if command -v agenix >/dev/null 2>&1; then
  exec agenix "${agenix_args[@]}"
fi
# Resolve agenix through the repository's locked input, not an unpinned URL.
exec nix run "$repo_dir#agenix" -- "${agenix_args[@]}"
