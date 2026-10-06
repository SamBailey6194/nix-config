{ pkgs, lib, osConfig ? { }, ... }:
{
  home.activation.codexMcpServers = import ./mcp-activation.nix {
    inherit pkgs lib;
    client = "codex";
    browsers = osConfig.services.browserPolicies.enable or false;
  };
}
