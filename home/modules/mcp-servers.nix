# Remote MCP servers registered with every AI coding agent this config installs
# (Claude Code, Codex, Antigravity, OpenCode). Defined once here so they stay in
# step.
#
# Plain data, not a Home Manager module: `import ./mcp-servers.nix` from
# claude.nix, codex.nix, antigravity.nix and opencode.nix — do not list it in
# `imports`. opencode.nix registers every entry here (as a remote server); the
# others name theirs one by one.
#
# These authenticate with OAuth on first use, so nothing secret lives here and
# each tool keeps its own token. Servers that need an API key (Context7) stay in
# the tool's own module, where the agenix secret is sourced.
{
  # Perplexity Computer. First use: /mcp in Claude Code, `codex mcp login
  # perplexity-computer`, /mcp in Antigravity, or `opencode mcp auth
  # perplexity-computer` (/mcps in its TUI).
  perplexity-computer.url = "https://www.perplexity.ai/rest/computer/mcp";
}
