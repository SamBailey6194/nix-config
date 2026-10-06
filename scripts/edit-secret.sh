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

if [[ -z "${EDITOR:-}" ]]; then
  if [[ -n "${VISUAL:-}" ]]; then
    export EDITOR="$VISUAL"
  else
    for editor in nano vim vi; do
      if command -v "$editor" >/dev/null 2>&1; then
        export EDITOR="$editor"
        break
      fi
    done
  fi
fi
if [[ -z "${EDITOR:-}" ]]; then
  echo "Set EDITOR to an installed editor before editing a secret." >&2
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
