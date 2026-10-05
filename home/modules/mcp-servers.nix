# Shared inventory from the reference Ubuntu Claude Code configuration.
# Credentials are resolved at runtime, never by Nix evaluation.
{ pkgs, lib }:
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
in {
  mcp-mermaid.command = [ (toString launch) "mermaid" "${pkgs.nodejs}/bin/node" "${pkgs.playwright-driver.browsers}" ];
  context7.command = [ (toString launch) "context7" "${pkgs.nodejs}/bin/npx" ];
  elevenlabs.command = [ (toString launch) "elevenlabs" "${uv}/bin/uvx" "${pkgs.python3}/bin/python3" ];
  perplexity-computer.url = "https://www.perplexity.ai/rest/computer/mcp";
  claude-design.url = "https://api.anthropic.com/v1/design/mcp";
}
