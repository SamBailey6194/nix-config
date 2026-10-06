# Claude Code settings on NixOS

The global settings are managed by `home/modules/claude.nix`, with a small,
non-secret baseline in `config/claude/settings-base.json`. They are generated as
`~/.claude/settings.json` on rebuild. Edit the repository and rebuild to change
them; the generated file is a read-only Nix store link.

The baseline was compared with Ubuntu's `/home/sam-dev/.claude/settings.json`
and `/mnt/archive/OldRepos/syntek/syntek-base/.claude/settings.json` on
5 October 2026. It retains the Ubuntu fullscreen UI, normal editor mode,
disabled prompt suggestions and automatic memory, xhigh effort and workflow
preferences. It defaults to Opus and Concise output, matching Syntek. A concise
style is supplied for pinned Claude versions predating the built-in style.
See the [official output style documentation](https://code.claude.com/docs/en/output-styles).

It also adopts Syntek's disabled bundled skills, artifacts, Claude.ai connectors,
remote control and automatic compaction. Project skills, permissions and project
hooks remain in `syntek-base/.claude`, so they apply when working in that repository.
No copies of its project hook commands or repo-specific auto-mode trust settings
are installed globally. Preserved experimental settings are version-dependent;
check `/config` and `/doctor` after the staged upgrade.

The six old Syntek, D&D and plugin-dev plugins are explicitly disabled globally.
The prepared default keeps only `codex@openai-codex` enabled, using the Ubuntu
Codex marketplace definition. Change `enabledPlugins` in the baseline to adjust
this selection. No plugin caches or project skills have been deleted.

Ubuntu's Claude-in-Chrome allowance and explicit prompts for ElevenLabs audio,
music and voice generation are retained. These are independent of registering
the shared MCP servers described in [SHARED-MCP.md](SHARED-MCP.md).

The status line, monitor lifecycle hooks and memory-write guard remain. Monitor
hooks use the new home directory and read credentials at runtime from
`/run/agenix/claude-secrets`; the Ubuntu inline token is not embedded in the Nix
configuration. devtower-intel starts the monitor with fresh server state, which
creates a new API token on first start; copy it into the age secret's
`CLAUDE_MONITOR_TOKEN` line (docs/INSTALL-INTEL-MANUALLY.md, section 8 step 5)
before expecting monitoring to work. The hook is optional when the monitor
repository is absent.

Ubuntu's global Context7 instruction (`~/.claude/rules/context7.md`) and the
`context7-mcp` skill are reproduced from `config/claude/rules` and
`config/claude/skills`.

After the development-stage rebuild, start Claude inside `syntek-base` and verify
`/config`, `/plugin`, `/mcp` and `/skills`. Confirm the project's skills appear,
the old duplicate skill plugins stay disabled, and the status line and monitor
hooks work. Keep Ubuntu's settings backup until these checks pass.
