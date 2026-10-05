# Called by each client module, keeping registration and credentials identical.
{ pkgs, lib, client }:
let
  inventory = import ./mcp-servers.nix { inherit pkgs lib; };
  file = pkgs.writeText "shared-mcp-servers.json" (builtins.toJSON inventory);
  python = pkgs.python3.withPackages (p: [ p.tomli-w ]);
in lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${python}/bin/python ${./mcp-sync.py} ${lib.escapeShellArg client} ${file} || true
''
