# Coding agent setup

Read [the Nix source policy](config/agents/nix-source-policy.md) before running
Nix commands. Use Git-backed flakes or `scripts/prepare-nix-source.py`;
never evaluate a repository directly with `path:`.

Keep Cargo build output outside the repository:
`export CARGO_TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cargo-target"`.
The development shell and devtower-intel Home Manager setup do this already.

The shared TypeSafe/Jev skill is checked in at
`config/agent-skills/typesafe-ai/SKILL.md`. Read it when building AI features
that need typed judgments, ranking, routing or extraction. This applies to
all coding agents, regardless of whether their model runs locally or in the cloud.

For user-level skill discovery in any supported client, run
`bash scripts/install-agent-skills.sh` in the cloud environment's setup step
or on the local machine. It runs the requested global Skills CLI install
for all supported agents. NixOS development stages also deploy the vendored
skill to the configured clients without requiring network access.

On NixOS, run SDK commands as `with-typesafe <command> ...` to load only
`TYPESAFE_API_KEY` from `/run/agenix/typesafe-api-key` (or the legacy shared
`/run/agenix/claude-secrets` env file) at execution time. Never
print that file, the key, or the command's environment. In cloud environments,
inject `TYPESAFE_API_KEY` through the provider's secret settings.
