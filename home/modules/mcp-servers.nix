# Shared inventory from the reference Ubuntu Claude Code configuration.
# Credentials are resolved at runtime, never by Nix evaluation.
#
# An entry may carry `clients`, limiting it to those clients: pass `client` to
# get that client's servers, or null for every managed server (used to retire
# names a client no longer gets). `browsers` adds the browser DevTools servers,
# which need the managed browsers (services.browserPolicies) installed.
{ pkgs, lib, client ? null, browsers ? false }:
let
  uv = pkgs.callPackage ../../pkgs/uv-manylinux.nix { };
  launch = pkgs.writeShellScript "ai-mcp-launch" ''
    if [ -r /run/agenix/claude-secrets ]; then
      set -a
      . /run/agenix/claude-secrets
      set +a
    fi
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.portaudio pkgs.libsndfile ]}:"''${LD_LIBRARY_PATH:-}"
    exec ${pkgs.python3}/bin/python ${./mcp-launch.py} "$@"
  '';

  # Claude Code drives Brave through Claude-in-Chrome instead.
  browserClients = [ "codex" "antigravity" ];

  # Drop entries limited to other clients, then the `clients` marker itself.
  forClient = servers: lib.mapAttrs (_: server: removeAttrs server [ "clients" ])
    (lib.filterAttrs (_: server: client == null || !(server ? clients) || lib.elem client server.clients) servers);
in forClient ({
  mcp-mermaid.command = [ (toString launch) "mermaid" "${pkgs.nodejs}/bin/node" "${pkgs.playwright-driver.browsers}" ];
  context7.command = [ (toString launch) "context7" "${pkgs.nodejs}/bin/npx" ];
  elevenlabs.command = [ (toString launch) "elevenlabs" "${uv}/bin/uvx" "${pkgs.python3}/bin/python3" ];
  perplexity-computer.url = "https://www.perplexity.ai/rest/computer/mcp";
  # Codex skips it and agy cannot complete its OAuth discovery.
  claude-design = {
    url = "https://api.anthropic.com/v1/design/mcp";
    clients = [ "claude" ];
  };
} // lib.optionalAttrs browsers {
  # Browsers by their system profile path, so this adds no second copy of them.
  brave-devtools = {
    command = [ (toString launch) "brave" "${pkgs.nodejs}/bin/npx" "/run/current-system/sw/bin/brave" ];
    clients = browserClients;
  };
  firefox-developer = {
    command = [ (toString launch) "firefox" "${pkgs.firefox-devtools-mcp}/bin/firefox-devtools-mcp" "/run/current-system/sw/bin/firefox-devedition" ];
    clients = browserClients;
  };
})
