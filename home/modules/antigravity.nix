{ config, pkgs, lib, osConfig ? { }, ... }:
{
  home.activation.antigravityMcpServers = import ./mcp-activation.nix {
    inherit pkgs lib;
    home = config.home.homeDirectory;
    client = "antigravity";
    browsers = osConfig.services.browserPolicies.enable or false;
  };
}
