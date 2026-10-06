# Shared MCP servers

The reference is Ubuntu's user-scoped Claude Code inventory, inspected on
2026-10-05. All development stages register these servers in Claude Code,
Codex, Antigravity CLI (`agy`) and OpenCode; Claude Design in Claude Code only:

| Server | Transport | Credentials |
| --- | --- | --- |
| Mermaid | Shared Node/Playwright launcher | None |
| Context7 | Shared stdio launcher | `CONTEXT7_API_KEY`, if available |
| Perplexity Computer | HTTP | Each client's OAuth login |
| ElevenLabs | Shared stdio launcher, official package 0.12.2 | `ELEVENLABS_API_KEY` |
| Claude Design (Claude Code only) | HTTP | Claude Code's authentication and account access |

Codex and Antigravity also get two browser DevTools servers wherever the
managed browsers are installed (`services.browserPolicies`, dev stage and up).
Claude Code does not: it drives Brave through Claude-in-Chrome instead.

| Server | Transport | Browser |
| --- | --- | --- |
| `brave-devtools` | Shared launcher, npm `chrome-devtools-mcp` 1.10.1 | `/run/current-system/sw/bin/brave` |
| `firefox-developer` | Shared launcher, nixpkgs `firefox-devtools-mcp` | `/run/current-system/sw/bin/firefox-devedition` |

An inventory entry with `clients` is registered only in those clients
(`home/modules/mcp-activation.nix`). The launcher finds the desktop session
(`XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, the XWayland `DISPLAY`, the session bus)
itself, because Codex passes only a few environment variables to servers.

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
credential file. The encrypted host secrets for laptop-intel and devtower-intel
carry `CLAUDE_MONITOR_TOKEN`, `CONTEXT7_API_KEY`, `ELEVENLABS_API_KEY` and
`ELEVENLABS_MCP_BASE_PATH`; devtower-intel declares its copy in
`hosts/devtower-intel/secrets.nix`. Keys are never copied into this repo
or evaluated into the Nix store.

Once that agenix secret is readable, activation stops writing the plaintext
credential file (delete any earlier one). The launcher passes each server only
the keys it needs, removes the rest (including the monitor token), and gives
Context7 its key in the environment rather than as an `--api-key` argument, so
no key shows in the process list. For the servers it manages, registration
removes inline `CONTEXT7_API_KEY`/`ELEVENLABS_API_KEY` values (and Codex
`env_vars` names) and keeps every client file at mode 0600 or narrower.

Ubuntu used `ELEVENLABS_MCP_BASE_PATH=/`; this is preserved, so all clients have
the same file path behaviour. Relative files must still point to directories
the current user can write. A newly provisioned device needs its own secret
or private credential file; the inventory alone cannot provision an API key.

Registration removes managed servers a client does not get (Claude Design
outside Claude Code, the browser servers in Claude Code), including entries an
earlier generation registered. Switching a managed server between stdio and HTTP
drops the other transport's fields, such as stale headers or bearer settings.
Registration updates the managed server transports and preserves other
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

Antigravity reads HTTP servers from `url` (agy 1.3.0 documents `serverUrl` only
as a legacy key, which registration removes so it cannot shadow the managed
URL), and drops a pasted `Authorization` header from managed servers. agy 1.3.0
supports MCP OAuth: sign in to Perplexity Computer from agy's `/mcp` panel
rather than pasting a bearer token, which expires and is never managed here.
Claude Design is limited to Claude Code because, on Ubuntu, Codex skipped it
and agy could not complete its OAuth discovery. Per-device sign-ins on a new machine:
`claude` (and `/mcp`), `codex login` and `codex mcp login perplexity-computer`,
`agy` (Google sign-in, kept in the gnome-keyring Secret Service), and
`pplx auth login` for the Perplexity search CLI.

Codex registration follows [official OpenAI MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
for stdio commands/arguments and HTTP URLs in `config.toml`.
