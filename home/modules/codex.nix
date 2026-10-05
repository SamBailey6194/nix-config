{ pkgs, lib, ... }:
{
  home.activation.codexMcpServers = import ./mcp-activation.nix {
    inherit pkgs lib;
    client = "codex";
  };
}
