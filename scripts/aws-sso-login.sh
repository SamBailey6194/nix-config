#!/usr/bin/env bash
# Pick an SSO profile from the AWS config and run `aws sso login` for it.
#
#   just aws               choose interactively (fzf, or a numbered menu)
#   just aws <profile>     log in to that profile directly
#
# Only profiles that can do an SSO login are offered: those with
# sso_session or sso_start_url. Static-key profiles (aws-credentials) are
# left out. The config is ~/.aws/config, the agenix-managed file linked by
# home/modules/aws.nix, or $AWS_CONFIG_FILE if set. The `aws` on PATH opens
# the login in Brave (BROWSER is pinned by the same module's wrapper).
set -euo pipefail

config="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

if [[ $# -gt 0 ]]; then
    exec aws sso login --profile "$1"
fi

if [[ ! -r "$config" ]]; then
    echo "No readable AWS config at $config (is /run/agenix/aws-config deployed?)" >&2
    exit 1
fi

# One line per SSO profile: name<TAB>account<TAB>role<TAB>session.
# Section headers are [default] or [profile <name>]; [sso-session ...] and
# [services ...] sections are skipped. Keys may be written `key=value` or
# `key = value`.
profiles=$(awk '
    function flush() {
        if (name != "" && sso) printf "%s\t%s\t%s\t%s\n", name, account, role, session
        name = ""; sso = 0; account = ""; role = ""; session = ""
    }
    /^[[:space:]]*\[/ {
        flush()
        header = $0
        gsub(/^[[:space:]]*\[[[:space:]]*|[[:space:]]*\][[:space:]]*$/, "", header)
        if (header == "default") name = "default"
        else if (header ~ /^profile[[:space:]]+/) { sub(/^profile[[:space:]]+/, "", header); name = header }
        next
    }
    name != "" && /=/ {
        key = $0; sub(/=.*/, "", key); gsub(/[[:space:]]/, "", key)
        val = $0; sub(/^[^=]*=[[:space:]]*/, "", val); sub(/[[:space:]]+$/, "", val)
        if (key == "sso_session" || key == "sso_start_url") sso = 1
        if (key == "sso_session") session = val
        if (key == "sso_account_id") account = val
        if (key == "sso_role_name") role = val
    }
    END { flush() }
' "$config")

if [[ -z "$profiles" ]]; then
    echo "No SSO profiles (sso_session / sso_start_url) in $config" >&2
    exit 1
fi

if command -v fzf >/dev/null 2>&1; then
    choice=$(printf '%s\n' "$profiles" \
        | column -t -s $'\t' \
        | fzf --prompt='aws sso login > ' --height=~40% --reverse \
              --header='profile  account  role  session' \
        || true)
    profile=${choice%% *}
else
    mapfile -t names < <(printf '%s\n' "$profiles" | cut -f1)
    PS3='aws sso login - profile number: '
    select profile in "${names[@]}"; do
        [[ -n "$profile" ]] && break
    done
fi

if [[ -z "${profile:-}" ]]; then
    echo "Cancelled." >&2
    exit 130
fi

echo "aws sso login --profile $profile"
exec aws sso login --profile "$profile"
