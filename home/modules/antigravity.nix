{ pkgs, lib, osConfig ? { }, ... }:
{
  home.activation.antigravityMcpServers = import ./mcp-activation.nix {
    inherit pkgs lib;
    client = "antigravity";
    browsers = osConfig.services.browserPolicies.enable or false;
  };
}
