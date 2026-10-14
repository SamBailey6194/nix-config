#!/usr/bin/env bash
# Merge declared settings into the Antigravity CLI's settings.json, which agy
# itself rewrites (its /settings screen, and "always allow" answers to
# permission prompts). Best-effort: every problem is a warning on stderr, the
# file is left as it was, and it always exits 0.
#
# Usage: antigravity-settings.sh SETTINGS DEFAULTS_JSON FILTER_FILE
# Needs jq, mktemp, chmod and mv on PATH.
set -u

settings=$1
defaults=$2
filter=$3
dir=$(dirname -- "$settings")
input=/dev/null
if [ -e "$settings" ]; then input=$settings; fi
merged=

if [ -L "$settings" ]; then
  echo "warning: antigravity: $settings is a symlink; settings not merged" >&2
elif [ -e "$settings" ] && [ ! -f "$settings" ]; then
  echo "warning: antigravity: $settings is not a regular file; settings not merged" >&2
elif ! mkdir -p -- "$dir" 2>/dev/null; then
  echo "warning: antigravity: could not create $dir; settings not merged" >&2

# Read whole (-s; /dev/null when missing): see antigravity-merge.jq. jq's
# message is not shown, as it can quote the file.
elif ! merged=$(jq -s --argjson d "$defaults" -f "$filter" "$input" 2>/dev/null) || [ -z "$merged" ]; then
  echo "warning: antigravity: $settings is not a single JSON object with a permissions object and allow list; settings not merged" >&2

# Already as declared: leave the file (and agy's formatting) alone.
elif [ -s "$settings" ] && jq -e --argjson m "$merged" '. == $m' "$settings" >/dev/null 2>&1; then
  :

# Write a temp file beside it, then rename over it, so agy never reads a
# half-written file. Owner-only, like the file agy creates.
elif tmp=$(mktemp "$dir/.settings.json.XXXXXX" 2>/dev/null); then
  if printf '%s\n' "$merged" > "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$settings"; then
    :
  else
    rm -f "$tmp"
    echo "warning: antigravity: could not write $settings" >&2
  fi
else
  echo "warning: antigravity: could not create a temp file in $dir; settings not merged" >&2
fi
exit 0
