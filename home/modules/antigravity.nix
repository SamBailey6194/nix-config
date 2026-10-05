{ pkgs, lib, ... }:
{
  home.activation.antigravityMcpServers = import ./mcp-activation.nix {
    inherit pkgs lib;
    client = "antigravity";
  };
}
