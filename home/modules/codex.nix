{ pkgs, lib, ... }:

# Codex CLI: MCP servers shared with the other agents (./mcp-servers.nix).
# The package itself is system-wide, in modules/software/development.nix.
#
# ~/.codex/config.toml is left to Codex rather than managed as a file. Codex
# rewrites it at runtime (project trust, model choice, TUI hints, `codex mcp
# add`), and Home Manager's programs.codex would make it a read-only symlink
# into /nix/store that every one of those writes fails on. So the server is
# appended once, only if it is missing, and never touched again: disabling it
# (`enabled = false` in its table) sticks. Removing it does not — like Context7
# in claude.nix, it comes back on the next rebuild.
#
# Not `codex mcp add`: for a server that advertises OAuth (Perplexity does) it
# registers a client, opens the browser and then blocks for up to 5 minutes
# waiting for the callback — inside the home-manager-<user> unit, which imports
# the session's WAYLAND_DISPLAY and itself times out at 5 minutes. It is also an
# upsert that replaces the whole table, so it would drop `enabled = false`. Log
# in on first use instead:  codex mcp login perplexity-computer

let
  codexBin = lib.getExe pkgs.codex;
  mcp = import ./mcp-servers.nix;

  # A JSON string is also a valid TOML basic string.
  codexTable = ''
    [mcp_servers.perplexity-computer]
    url = ${builtins.toJSON mcp.perplexity-computer.url}
  '';
in
{
  # Best-effort throughout: activation runs under `set -eu -o pipefail`, so every
  # step that can fail is guarded and only warns, rather than aborting the rest
  # of the switch.
  home.activation.codexMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CODEX='${codexBin}'
    codexHome="''${CODEX_HOME:-$HOME/.codex}"
    codexConfig="$codexHome/config.toml"
    codexTable=${lib.escapeShellArg codexTable}
    codexScratch=

    # Codex refuses to start at all when CODEX_HOME names a directory that does
    # not exist yet, so create it first (0700: it also holds auth.json).
    if ! ( umask 077; mkdir -p "$codexHome" ) 2>/dev/null; then
      echo "codexMcpServers: could not create $codexHome; skipped" >&2
    elif [ -e "$codexConfig" ] && [ ! -w "$codexConfig" ]; then
      echo "codexMcpServers: $codexConfig is not writable; skipped" >&2

    # `codex mcp get` only reads config (no network). It exits 1 both when the
    # server is missing and when config.toml fails to parse; append only on the
    # former, so a broken file is reported rather than added to. Only the
    # `Error:` summary is echoed, so no config content lands in the journal.
    elif ! out=$($CODEX mcp get perplexity-computer 2>&1); then
      case "$out" in
        *"No MCP server named"*)
          if [ -s "$codexConfig" ]; then codexTable=$'\n'"$codexTable"; fi
          # A file that parses can still refuse the table: TOML cannot extend
          # an inline `mcp_servers = { … }`, and appending blind would leave
          # every codex command failing to start. So append to a scratch copy
          # first and only touch the real file if Codex still reads the copy.
          if codexScratch=$(mktemp -d) \
            && { [ ! -e "$codexConfig" ] || cp "$codexConfig" "$codexScratch/config.toml"; } \
            && printf '%s' "$codexTable" >> "$codexScratch/config.toml" \
            && CODEX_HOME="$codexScratch" $CODEX mcp get perplexity-computer >/dev/null 2>&1
          then
            ( umask 077; printf '%s' "$codexTable" >> "$codexConfig" ) 2>/dev/null \
              || echo "codexMcpServers: could not append to $codexConfig" >&2
          else
            echo "codexMcpServers: left $codexConfig alone (Codex would not parse it with the table appended); see \`codex mcp list\`" >&2
          fi
          if [ -n "$codexScratch" ]; then rm -rf "$codexScratch"; fi
          ;;
        *)
          err=$(printf '%s\n' "$out" | grep -m1 '^Error:' || true)
          echo "codexMcpServers: left $codexConfig alone (''${err:-codex mcp get failed}); see \`codex mcp list\`" >&2
          ;;
      esac
    fi
  '';
}
