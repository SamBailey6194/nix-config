{ pkgs, lib, ... }:

# Antigravity CLI (agy): MCP servers shared with the other agents
# (./mcp-servers.nix). The package itself is system-wide, in
# modules/software/development.nix; both call ../../pkgs/antigravity-cli.nix, so
# this runs the exact agy that is on PATH.
#
# ~/.gemini/config/mcp_config.json belongs to agy (`agy mcp add/remove/enable/
# disable` and /mcp all rewrite it), so it is not a Home Manager file. With
# programs.antigravity-cli it would be a store symlink that agy silently
# replaces with a plain file on the first toggle, which the next activation
# then moves aside as *.hm-backup — undoing the change.
#
# `agy mcp add` is "add or update": it rewrites the whole entry, re-enabling a
# server you disabled and dropping any headers, so it runs only when the entry
# is absent. agy has no `mcp get` and `mcp list` only prints a table, hence jq
# on the file itself. `add` makes no network calls; OAuth happens on first use
# via /mcp inside agy.
#
# `add` also rewrites the whole file (temp file, then rename over it), which
# resets its mode to 0644 and would turn a symlinked mcp_config.json (say, into
# a dotfiles repo) into a plain file agy then reads instead. So the mode is put
# back afterwards, and a symlink is left alone with a warning.

let
  antigravity-cli = pkgs.callPackage ../../pkgs/antigravity-cli.nix { };
  agyBin = lib.getExe antigravity-cli;
  jqBin = "${pkgs.jq}/bin/jq";
  mcp = import ./mcp-servers.nix;
in
{
  home.activation.antigravityMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    AGY='${agyBin}'
    # agy derives ~/.gemini from $HOME (no env override), so check the same file.
    agyMcpConfig="$HOME/.gemini/config/mcp_config.json"

    # Any entry counts as present, including a disabled one (and the
    # {"disabled": true} stub `agy mcp disable` leaves for an unknown name). A
    # missing or empty file adds; an unparseable one also reaches `agy mcp add`,
    # which refuses to overwrite it and says why.
    if ! ${jqBin} -e '.mcpServers["perplexity-computer"]' "$agyMcpConfig" >/dev/null 2>&1; then
      if [ -L "$agyMcpConfig" ]; then
        echo "antigravityMcpServers: $agyMcpConfig is a symlink, which \`agy mcp add\` would replace with a plain file; skipped" >&2
      else
        agyMode=$(stat -c %a "$agyMcpConfig" 2>/dev/null || true)
        $AGY mcp add perplexity-computer ${lib.escapeShellArg mcp.perplexity-computer.url} || true
        if [ -n "$agyMode" ]; then chmod "$agyMode" "$agyMcpConfig" 2>/dev/null || true; fi
      fi
    fi
  '';
}
