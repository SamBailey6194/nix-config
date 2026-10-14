# Called by each client module, keeping registration and credentials identical.
{ pkgs, lib, home, client, browsers ? false, resolve ? null }:
let
  inventory = import ./mcp-servers.nix { inherit pkgs lib home client browsers resolve; };
  # Managed names this client does not get (e.g. claude-design outside Claude
  # Code): removed, so an entry an earlier generation registered goes away.
  managed = builtins.attrNames (import ./mcp-servers.nix { inherit pkgs lib home; all = true; });
  retired = lib.subtractLists (builtins.attrNames inventory) managed;
  file = pkgs.writeText "shared-mcp-servers.json" (builtins.toJSON inventory);
  retiredFile = pkgs.writeText "retired-mcp-servers.json" (builtins.toJSON retired);
  python = pkgs.python3.withPackages (p: [ p.tomli-w ]);
in
# Best-effort: a failure never stops activation (it runs under set -e), but
# mcp-sync.py says why on stderr and this line names the client, so it shows
# in the rebuild output instead of passing silently.
lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${python}/bin/python ${./mcp-sync.py} ${lib.escapeShellArg client} ${file} ${retiredFile} \
    || echo ${lib.escapeShellArg "warning: ${client}: shared MCP server registration failed"}" (exit $?); fix the cause above and rebuild" >&2
''
