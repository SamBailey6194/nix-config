# Called by each client module, keeping registration and credentials identical.
{ pkgs, lib, client, browsers ? false }:
let
  inventory = import ./mcp-servers.nix { inherit pkgs lib client browsers; };
  # Managed names this client does not get (e.g. claude-design outside Claude
  # Code): removed, so an entry an earlier generation registered goes away.
  managed = builtins.attrNames (import ./mcp-servers.nix { inherit pkgs lib; browsers = true; });
  retired = lib.subtractLists (builtins.attrNames inventory) managed;
  file = pkgs.writeText "shared-mcp-servers.json" (builtins.toJSON inventory);
  retiredFile = pkgs.writeText "retired-mcp-servers.json" (builtins.toJSON retired);
  python = pkgs.python3.withPackages (p: [ p.tomli-w ]);
in lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${python}/bin/python ${./mcp-sync.py} ${lib.escapeShellArg client} ${file} ${retiredFile} || true
''
