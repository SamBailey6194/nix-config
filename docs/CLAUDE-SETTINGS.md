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

The baseline JSON is the single authority for plain settings (effort,
workflows, model, `env`, UI, permissions and plugins); `claude.nix` adds only
what needs Nix: hook and status line paths, and the output style it installs.
`MCP_TIMEOUT` (120 s) allows the first launch of an MCP server to download its
runtime packages.

Enabled plugins: `codex@openai-codex` (Ubuntu's Codex marketplace definition),
and the `lua-lsp` and `pyright-lsp` code intelligence plugins from the official
`claude-plugins-official` marketplace, which is declared in
`extraKnownMarketplaces` so a fresh machine knows it. The old Syntek, D&D and
plugin-dev entries are gone. Change `enabledPlugins` in the baseline to adjust
the selection.

The `claudePlugins` activation step runs `claude plugin install --scope user`
for each enabled plugin that `claude plugin list` does not show. That command
also writes the user settings file, which here is the read-only store link, so
on claude-code 2.1.291 it exits 1 ("Failed to update settings") and leaves the
link alone. The step then prints a warning and activation continues. Claude
Code installs enabled plugins from declared marketplaces when the next session
starts, so a missing plugin arrives then.

Explicit prompts for ElevenLabs audio, music and voice generation are retained.
Ubuntu's Claude-in-Chrome allowance is replaced by allowances for the
`brave-devtools` and `firefox-developer` servers described in
[SHARED-MCP.md](SHARED-MCP.md). Claude-in-Chrome is blocked three ways: its
tools (`mcp__claude-in-chrome__*`) are in `permissions.deny`, activation sets
`claudeInChromeDefaultEnabled` to false in `~/.claude.json`, and no native
messaging host is registered with Brave. The deny rule still applies when a
session is started with `claude --chrome`.
On Resolve hosts, `davinci-resolve` (see [SHARED-MCP.md](SHARED-MCP.md)) has
`run_script_unsafe` and `launch_resolve` denied, and `run_script`,
`update_dctl`, `generate_lut`, `delete_dctl` and `delete_lut` set to ask.

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

Codex, OpenCode and Antigravity get the same two global instructions
(`config/claude/rules/context7.md` and `config/agents/nix-source-policy.md`,
which Claude loads as `~/.claude/rules/nix-source.md`) as one generated file
each, from `home/modules/agent-skills.nix`: `~/.codex/AGENTS.md` (or under
`CODEX_HOME` if one is declared), `~/.config/opencode/AGENTS.md` and
`~/.gemini/config/AGENTS.md`. Edit the two sources, not the generated files.

After the development-stage rebuild, start Claude inside `syntek-base` and verify
`/config`, `/plugin`, `/mcp` and `/skills`. Confirm the project's skills appear,
the old duplicate skill plugins stay disabled, and the status line and monitor
hooks work. Keep Ubuntu's settings backup until these checks pass.
