# Shared MCP servers

The reference is Ubuntu's user-scoped Claude Code inventory, inspected on
2026-10-05. All development stages register the same five servers in Claude
Code, Codex, Antigravity CLI (`agy`) and OpenCode:

| Server | Transport | Credentials |
| --- | --- | --- |
| Mermaid | Shared Node/Playwright launcher | None |
| Context7 | Shared stdio launcher | `CONTEXT7_API_KEY`, if available |
| Perplexity Computer | HTTP | Each client's OAuth login |
| ElevenLabs | Shared stdio launcher, official package 0.12.2 | `ELEVENLABS_API_KEY` |
| Claude Design | HTTP | Each client's authentication and account access |

`home/modules/mcp-servers.nix` is the single inventory. Shared commands use
absolute Nix executables; Mermaid uses the existing pinned Playwright setup,
and ElevenLabs uses the manylinux-aware uv wrapper plus PortAudio/libsndfile.
Context7 and ElevenLabs need network access on first launch to install runtime
packages. ElevenLabs is pinned; Context7 follows the existing Ubuntu npx setup.
Claude, Codex and OpenCode allow up to two minutes for local server startup;
an explicit existing Codex timeout is retained.
The [official ElevenLabs MCP](https://github.com/elevenlabs/elevenlabs-mcp)
provides the server used here.

On activation, registration captures the existing Ubuntu Claude API keys into
`~/.config/ai-mcp/credentials.json` with mode 0600 before updating server commands.
It can also read `/mnt/ubuntu-home/sam-dev/.claude.json` on the migrated machine.
This private file is not a Home Manager store file. The launcher first sources
`/run/agenix/claude-secrets`; its environment takes precedence over that local
credential file. Add `ELEVENLABS_API_KEY=...` to the encrypted host secret for
managed provisioning to other devices. Keys are never copied into this repo
or evaluated into the Nix store.

Ubuntu used `ELEVENLABS_MCP_BASE_PATH=/`; this is preserved, so all clients have
the same file path behaviour. Relative files must still point to directories
the current user can write. A newly provisioned device needs its own secret
or private credential file; the inventory alone cannot provision an API key.

Registration updates the five managed server transports and preserves other
servers, settings and enabled/disabled flags. Codex TOML is reserialised only
when a server definition changes, so comments can be lost on that update.
Malformed configurations and symlinks are left untouched with a warning.
OpenCode JSONC is left untouched and needs a manual equivalent edit. An existing
disabled server remains disabled until enabled in that client.

Use each client's MCP listing after activation (`claude mcp list`,
`codex mcp list`, `agy mcp list`, `opencode mcp list`). Authenticate remote
servers from the relevant client. OAuth credentials and approvals belong to
each client and are not interchangeable; a Claude-only account entitlement
can still prevent Claude Design working in another client. No live paid
ElevenLabs audio request is made by activation or the configuration tests.

Codex registration follows [official OpenAI MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
for stdio commands/arguments and HTTP URLs in `config.toml`.
