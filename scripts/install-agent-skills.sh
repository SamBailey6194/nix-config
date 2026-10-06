#!/usr/bin/env bash
# User-level installation for every supported agent, also in cloud setup.
set -euo pipefail
exec npx --yes skills add typesafe-ai/skills --skill typesafe-ai -g --agent '*' -y "$@"
