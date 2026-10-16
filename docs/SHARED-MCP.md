# Shared MCP servers

The reference is Ubuntu's user-scoped Claude Code inventory, inspected on
2026-10-05. All development stages register these servers in Claude Code,
Codex, Antigravity CLI (`agy`) and OpenCode; Claude Design in Claude Code only:

| Server | Transport | Credentials |
| --- | --- | --- |
| Mermaid | Shared Node/Playwright launcher | None |
| Context7 | Shared stdio launcher | `CONTEXT7_API_KEY`, if available |
| Perplexity Computer | HTTP | Each client's OAuth login |
| ElevenLabs | Shared stdio launcher, official package 0.12.2 | `ELEVENLABS_API_KEY`; base path declared (home directory) |
| Scrapling (`scrapling`) | Shared stdio launcher, `scrapling[ai]` 0.4.15 with the bundle's `playwright` | None |
| Playwright (`playwright`) | Shared stdio launcher, nixpkgs `playwright-mcp` | None |
| code-review-graph (`code-review-graph`) | Shared stdio launcher, `pkgs/code-review-graph.nix` (2.3.9 via uvx) | None |
| graphify (`graphify`) | Shared stdio launcher, `graphify-mcp` from `pkgs/graphify` (0.9.91) | None |
| Claude Design (Claude Code only) | HTTP | Claude Code's authentication and account access |

Claude Code, Codex and Antigravity also get two browser DevTools servers
wherever the managed browsers are installed (`services.browserPolicies`, dev
stage and up). Each server launches its own browser instance, separate from
your everyday profile. Claude Code uses these for browser testing instead of
Claude-in-Chrome, which is blocked (see [CLAUDE-SETTINGS.md](CLAUDE-SETTINGS.md)).

| Server | Transport | Browser |
| --- | --- | --- |
| `brave-devtools` | Shared launcher, npm `chrome-devtools-mcp` 1.10.1 | `/run/current-system/sw/bin/brave` |
| `firefox-developer` | Shared launcher, nixpkgs `firefox-devtools-mcp` | `/run/current-system/sw/bin/firefox-devedition` |

Claude Code alone also gets `davinci-resolve` on hosts whose NixOS
configuration installs `davinci-resolve-studio` (devtower-intel full and
creative stages; devtower and framework creative and full). This is
Blackmagic's own stdio server, `bin/ResolveMCP`, built into Resolve Studio
21.1 and later; nixpkgs pins it with Resolve, so it has no updater. The
launcher runs it through Resolve's FHS wrapper
(`davinci-resolve-studio <unwrapped>/bin/ResolveMCP`), so its bundled Python
and `fusionscript.so` find their libraries, with `QT_QPA_PLATFORM=xcb` and no
API keys. Codex and agy do not get it until their per-tool approval is managed.

Before using it, start Resolve yourself with the `resolve` alias, and once set
Preferences > System > General > External scripting using: Local in Resolve.
`launch_resolve` is denied (it would start Resolve without the XWayland
setting) and so is `run_script_unsafe` (full OS access). `run_script` (the whole
Resolve scripting API), `update_dctl`, `generate_lut`, `delete_dctl` and
`delete_lut` ask first; the read-only tools (status, scripting API and docs,
DCTL and LUT listings) run without a prompt. Do not use Resolve's File > Setup
AI Assistants on NixOS: it writes client entries pointing at `/opt/resolve`
paths, which do not exist here.

An inventory entry with `clients` is registered only in those clients
(`home/modules/mcp-activation.nix`). The launcher finds the desktop session
(`XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, the XWayland `DISPLAY`, the session bus)
itself, because Codex passes only a few environment variables to servers.

`home/modules/mcp-servers.nix` is the single inventory. Shared commands use
absolute Nix executables; Mermaid uses the existing pinned Playwright setup,
and ElevenLabs uses the manylinux-aware uv wrapper plus PortAudio/libsndfile.
Context7, ElevenLabs and Scrapling need network access on first launch to install
runtime packages. ElevenLabs and Scrapling are pinned; Context7 follows the
existing Ubuntu npx setup.

Scrapling runs `uvx --from "scrapling[ai]==0.4.15" --with "playwright==<bundle>"
scrapling mcp` through the same uv wrapper (`pkgs/uv-manylinux.nix`), which
fixes greenlet's `libstdc++` import, points `PLAYWRIGHT_BROWSERS_PATH` at the
nixpkgs browser bundle and constrains `playwright`/`patchright` to the bundle's
revisions. The `playwright` pin is read from `python3Packages.playwright`
(1.63.0, `just check-playwright`), so it moves with the bundle. Its name,
`scrapling`, is the one syntek-media and syntek-author use at project scope, so
the two entries are one server. Never run `scrapling install`: the store is
read-only and the browsers are already there. It lists 13 tools: `fetch`,
`bulk_fetch` (DynamicFetcher, Playwright), `stealthy_fetch`,
`bulk_stealthy_fetch` (StealthyFetcher, patchright), `make_request`,
`bulk_get` (plain HTTP, curl_cffi), `open_session`, `open_request_session`,
`session_fetch`, `session_make_request`, `list_sessions`, `close_session` and
`screenshot`. Both browser fetchers launch the bundle's Chromium (revision
1243); Scrapling 0.4.15 no longer uses camoufox. Only the `real_chrome` option
does not work here, as it looks for Google Chrome at its FHS path; pass
`executable_path` (or set `SCRAPLING_EXECUTABLE_PATH`) for another Chromium.

The two code-graph servers run the same packages that
`modules/software/development.nix` puts on PATH, so the CLI and the server are
one version. Neither is pinned to a repository: each starts in the client's
working directory (code-review-graph uses its git root, graphify reads
`graphify-out/` in that directory), and every tool also takes the project as an
argument (`repo_root`, `project_path`). Neither builds a graph until asked.
graphify reports a missing graph; code-review-graph's `get_minimal_context_tool`
reports `not_ready`, but most of its other query tools create an empty
`.code-review-graph/graph.db` and answer with zero nodes. Build one per project
with `code-review-graph build` (then `update`, which the project hooks run) or
`/graphify .` in any client. Outside a git repository code-review-graph refuses
tool calls without a `repo_root`: its per-user state lives in
`$XDG_STATE_HOME/code-review-graph` (`CRG_HOME`), not `~/.code-review-graph`,
which made the home directory look like a project. code-review-graph keeps its SQLite graph in
`<repo>/.code-review-graph/`, graphify writes `graphify-out/`; add both to the
project's `.gitignore`. syntek-base and others also register
`code-review-graph` at project scope (`uvx code-review-graph serve`, unpinned);
the names match, so the two entries are one server, and the project's wins
where both apply.

code-review-graph is a pinned `uvx --from "code-review-graph==2.3.9"` wrapper
through the wrapped uv: nixpkgs cannot build it, as it needs
`tree-sitter-language-pack<1` and nixpkgs has 1.4.1. Its first run needs network
access to fill the uv cache. Do not run `code-review-graph install` for these
clients: it would write a server entry pinned to one repository into
`~/.codex/config.toml` and `~/.gemini/antigravity/mcp_config.json`, and global
Codex and OpenCode hooks that build a graph in every repository they touch. Per
repository, `code-review-graph install --platform claude --no-instructions`
remains fine.

graphify is nixpkgs' derivation bumped to 0.9.91 with its `mcp`, `watch`,
`pdf`, `video` and `gemini`/`openai` extras (Whisper fetches its model into
`~/.cache/huggingface` the first time a folder holds audio or video).
`graphify hook install` pins `/run/current-system/sw/bin/graphify-python` in the
git hooks and merge driver, rather than a store path a garbage collection would
delete. Its `/graphify` skill is linked into every client
(`home/modules/agent-skills.nix`), with the variant graphify's own installer
would pick: Claude's for Claude Code and agy, Codex's (`spawn_agent`) in
`~/.agents/skills`, OpenCode's (`@agent`) for OpenCode, local models included.
The skill is patched (`pkgs/graphify/patch-skill.py`) to run its pipeline with
`/run/current-system/sw/bin/graphify-python`; upstream's text would otherwise
fetch graphify from PyPI with `uv tool run` and fall back to
`uv tool install` / `pip install`. Do not run `graphify install`: it would
replace the links with copies and edit `~/.claude/CLAUDE.md`. Leiden clustering
is not packaged (it needs graspologic-native 1.3.1 on Python 3.13+; nixpkgs has
1.2.5), so graphify uses networkx's Louvain, which it falls back to on its own.
Semantic extraction of docs, papers and images runs through the client's own
model; code is parsed locally with no model at all.

Playwright is Microsoft's Playwright MCP as packaged by nixpkgs
(`pkgs.playwright-mcp`), so it needs no npx download and its wrapper already
points `PLAYWRIGHT_BROWSERS_PATH` at the same bundle and uses an isolated
profile. The launcher finds the desktop session as it does for the DevTools
servers and runs it headed there, adding `--headless` when there is none. It
drives the bundle's Chromium, not the managed browsers, so every client gets it.
It writes page snapshots to `.playwright-mcp/` in the client's working directory.
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
carry `CLAUDE_MONITOR_TOKEN`, `CONTEXT7_API_KEY` and `ELEVENLABS_API_KEY`
(an `ELEVENLABS_MCP_BASE_PATH` still in them is ignored; see below);
devtower-intel declares its copy in `hosts/devtower-intel/secrets.nix`. Keys are never copied into this repo
or evaluated into the Nix store.

Once that agenix secret is readable, activation stops writing the plaintext
credential file (delete any earlier one). The launcher passes each server only
the keys it needs, removes the rest (including the monitor token, and every
other name the agenix file sets, such as `TYPESAFE_API_KEY`), and gives
Context7 its key in the environment rather than as an `--api-key` argument, so
no key shows in the process list. For the servers it manages, registration
removes inline `CONTEXT7_API_KEY`/`ELEVENLABS_API_KEY` values (and Codex
`env_vars` names), including empty ones, and keeps every client file at mode
0600 or narrower.

The ElevenLabs file root, `ELEVENLABS_MCP_BASE_PATH`, is not a secret: the
inventory declares it as the user's home directory (`config.home.homeDirectory`,
so `/home/sam-desktop` on devtower-intel and `/home/sam-laptop` on
laptop-intel), and it is reproduced on every rebuild. Registration writes it
into each client's ElevenLabs entry in that client's format: the `env` object
in Claude Code's `~/.claude.json` and Antigravity's `mcp_config.json`, the
`env` table in Codex's `config.toml`, and `environment` in OpenCode's
`opencode.json`. Other variables in that entry are kept; a Codex `env_vars`
name for it is removed, so nothing competes with the written value. Tools that
read the entry, such as syntek-media's `python3 toolkit/media.py check --setup`,
therefore see a base path containing any project under the home directory. On
devtower-intel that includes the WD data drive through `~/Data`, a bind mount
of `/mnt/data` ([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#data-the-drive-in-the-home-folder)):
both the server and `check --setup` resolve symlinks, so open media projects
as `~/Data/...`, never through `/mnt/data` or a link to it. The
launcher receives the same value as an argument and sets it itself, so the
server's effective base path is always the one the clients show; neither the
agenix secret, the credential file nor a client's inline value overrides it.
(Ubuntu used `/`; the home directory keeps every project reachable without
exposing the whole filesystem.) Relative files must still point to directories
the current user can write.

Replacing the entry by hand (`claude mcp add ... elevenlabs -- uvx
elevenlabs-mcp`, as `media.py` suggests) is not needed and is undone on the
next activation: registration restores the managed command and arguments,
removes the inline (possibly empty) `ELEVENLABS_API_KEY` and sets the declared
base path, keeping any other variables you added. A newly provisioned device needs its own secret
or private credential file; the inventory alone cannot provision an API key.

Registration removes managed servers a client does not get (Claude Design
outside Claude Code, the browser servers in OpenCode, `davinci-resolve` on
hosts without Resolve), including entries an
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

Registration is best-effort and never stops a rebuild. When a client's file
cannot be updated (unparsable, a symlink, unwritable), activation prints
`warning: shared MCP servers not registered for <client>: <reason>` and
`warning: <client>: shared MCP server registration failed (exit N)`, and leaves
the file as it was. The reason gives a parser error's position, never the
file's contents, as these files can hold credentials.

Antigravity's own settings (`~/.gemini/antigravity-cli/settings.json`, which
agy rewrites) are merged by `home/modules/antigravity.nix`: colour scheme
`solarized dark`, and an allow list of `git status`, `grep` and read-only `gh`
subcommands in place of a blanket `command(gh)`, so agy asks before any other
`gh` command. Its global skills directory is `~/.gemini/config/skills/`.
