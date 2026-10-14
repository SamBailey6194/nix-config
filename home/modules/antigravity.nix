{ config, pkgs, lib, osConfig ? { }, ... }:

# Antigravity CLI (agy): shared MCP servers in ~/.gemini/config/mcp_config.json
# (mcp-activation.nix), and declared settings merged into
# ~/.gemini/antigravity-cli/settings.json.
#
# agy rewrites settings.json itself (its settings screen, and "always allow"
# answers to permission prompts), so it is merged into on activation, like
# opencode.nix, rather than linked read-only into /nix/store. Each activation
# sets colorScheme, removes the retired entries below from permissions.allow
# (exact matches only) and adds the declared ones that are missing. Every other
# key (trustedWorkspaces, deny and ask lists, the user's own allow entries)
# stays. A symlink, or a file that is not one JSON object with a permissions
# object and allow list, is left alone with a warning.
#
# PERMISSIONS (https://antigravity.google/docs/permissions?tab=cli)
#
# `command(prefix)` matches by whole words from the start of the command, and
# precedence is deny > ask > allow. A `command(gh)` in ask would therefore
# override every gh allow entry, so none is added: agy already asks for gh
# writes. The CLI's sandbox is off by default and its default toolPermission
# is "request-review", so any command no allow rule covers asks first. (With
# the sandbox on, unlisted commands run inside it without network access and
# ask before running outside it.) This merge does not pin toolPermission:
# setting it to "always-proceed" would let gh writes run without asking.
#
# Only read-only gh subcommands are allowed. Not `gh api` (it can POST), and
# not `gh auth status`, whose --show-token prints the token into the session.

let
  allow = [ "command(git status)" "command(grep)" ] ++ map (c: "command(gh ${c})") [
    "pr view" "pr list" "pr status" "pr diff" "pr checks"
    "issue view" "issue list" "issue status"
    "repo view" "repo list"
    "run view" "run list"
    "release view" "release list"
    "search"
  ];

  defaults = {
    colorScheme = "solarized dark";
    inherit allow;
    # The broad allow entry earlier set by hand: every gh command, writes too.
    remove = [ "command(gh)" ];
  };
in
{
  home.activation.antigravityMcpServers = import ./mcp-activation.nix {
    inherit pkgs lib;
    home = config.home.homeDirectory;
    client = "antigravity";
    browsers = osConfig.services.browserPolicies.enable or false;
  };

  home.activation.antigravitySettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.jq ]}:$PATH \
      ${pkgs.bash}/bin/bash ${./antigravity-settings.sh} \
      "$HOME/.gemini/antigravity-cli/settings.json" \
      ${lib.escapeShellArg (builtins.toJSON defaults)} ${./antigravity-merge.jq} \
      || echo "warning: antigravity: settings merge exited $?" >&2
  '';
}
