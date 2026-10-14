#!/usr/bin/env bash
# Install the Claude Code plugins enabled in settings.json that are missing at
# user scope. Best-effort: every problem is a warning, and it always exits 0.
#
# Usage: claude-plugins.sh CLAUDE PLUGIN@MARKETPLACE...
#
# `claude plugin install` also records the plugin in the user settings file.
# Here that file is a read-only link into /nix/store (claude.nix), so the
# install exits 1 ("Failed to update settings") and leaves the link alone
# (checked with claude-code 2.1.291). The plugin is enabled in that
# file anyway, and Claude Code installs enabled plugins from declared
# marketplaces when a session starts, so a failure here only delays it.
set -u

claude=$1
shift
[ "$#" -gt 0 ] || exit 0

if ! listed=$(timeout 60 "$claude" plugin list --json </dev/null 2>/dev/null) \
  || ! installed=$(printf '%s' "$listed" | jq -r '.[] | select(.scope == "user") | .id' 2>/dev/null); then
  echo "warning: claude plugins: could not list installed plugins; not installing $*" >&2
  exit 0
fi

for id in "$@"; do
  if printf '%s\n' "$installed" | grep -qxF -- "$id"; then
    continue
  fi
  if out=$(timeout 300 "$claude" plugin install "$id" --scope user </dev/null 2>&1); then
    echo "claude plugins: installed $id"
  else
    status=$?
    reason=$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n 1)
    echo "warning: claude plugins: could not install $id (exit $status): ${reason:-no output}" >&2
    echo "  It stays enabled in settings.json; Claude Code installs it when the next session starts." >&2
  fi
done
exit 0
