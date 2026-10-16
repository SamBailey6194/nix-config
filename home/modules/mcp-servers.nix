# Shared inventory from the reference Ubuntu Claude Code configuration.
# Credentials are resolved at runtime, never by Nix evaluation.
#
# An entry may carry `clients`, limiting it to those clients: pass `client` to
# get that client's servers, or null for every managed server (used to retire
# names a client no longer gets). `browsers` adds the browser DevTools servers,
# which need the managed browsers (services.browserPolicies) installed, and
# `resolve` (the davinci-resolve-studio package, ./resolve-package.nix) adds
# Resolve's own server. `all` lists every optional entry by name only, without
# dereferencing `resolve`, so retired-name lists stay complete on every host.
#
# `home` is the user's home directory (config.home.homeDirectory). An entry's
# `env` holds non-secret variables that registration writes into each client's
# entry; the launcher receives the same values as arguments, so what a client
# shows is what the server gets. Secrets never go here.
{ pkgs, lib, home, client ? null, browsers ? false, resolve ? null, all ? false }:
let
  uv = pkgs.callPackage ../../pkgs/uv-manylinux.nix { };
  # The same derivations modules/software/development.nix puts on PATH, so the
  # CLI and the MCP server are always one version.
  code-review-graph = pkgs.callPackage ../../pkgs/code-review-graph.nix { };
  graphify = pkgs.callPackage ../../pkgs/graphify { };
  launch = pkgs.writeShellScript "ai-mcp-launch" ''
    if [ -r /run/agenix/claude-secrets ]; then
      set -a
      . /run/agenix/claude-secrets
      set +a
    fi
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.portaudio pkgs.libsndfile ]}:"''${LD_LIBRARY_PATH:-}"
    exec ${pkgs.python3}/bin/python ${./mcp-launch.py} "$@"
  '';

  # Claude Code uses these rather than Claude-in-Chrome (denied in its settings).
  browserClients = [ "claude" "codex" "antigravity" ];

  # Drop entries limited to other clients, then the `clients` marker itself.
  forClient = servers: lib.mapAttrs (_: server: removeAttrs server [ "clients" ])
    (lib.filterAttrs (_: server: client == null || !(server ? clients) || lib.elem client server.clients) servers);
in forClient ({
  mcp-mermaid.command = [ (toString launch) "mermaid" "${pkgs.nodejs}/bin/node" "${pkgs.playwright-driver.browsers}" ];
  context7.command = [ (toString launch) "context7" "${pkgs.nodejs}/bin/npx" ];
  # The file root is the home directory, so a project anywhere under it (such
  # as syntek-media's `media.py check --setup`, which reads it from
  # ~/.claude.json) is inside it.
  elevenlabs = {
    command = [ (toString launch) "elevenlabs" "${uv}/bin/uvx" "${pkgs.python3}/bin/python3" home ];
    env.ELEVENLABS_MCP_BASE_PATH = home;
  };
  # Scrapling's own server (scrapling[ai]); syntek-media and syntek-author use the
  # same name at project scope, so the two entries are one server. Its Playwright
  # pin is the bundle's (pkgs/uv-manylinux.nix), never a second literal.
  scrapling.command = [ (toString launch) "scrapling" "${uv}/bin/uvx" "${pkgs.python3}/bin/python3" pkgs.python3Packages.playwright.version ];
  # Microsoft's Playwright MCP from nixpkgs (no npx), which drives the same
  # browser bundle Scrapling and Mermaid use; its own Chromium, not the
  # managed browsers, so every client gets it.
  playwright.command = [ (toString launch) "playwright" "${pkgs.playwright-mcp}/bin/playwright-mcp" ];
  # Code graphs. Neither is pinned to a repository: each follows the directory
  # the client starts in (code-review-graph its git root, graphify the directory
  # itself), and every tool also takes the project as an argument. Neither
  # builds a graph until asked. syntek-base and others register
  # `code-review-graph` at project scope under the same name, so the two
  # entries are one server.
  code-review-graph.command = [ (toString launch) "code-review-graph" "${code-review-graph}/bin/code-review-graph" ];
  graphify.command = [ (toString launch) "graphify" "${graphify}/bin/graphify-mcp" ];
  perplexity-computer.url = "https://www.perplexity.ai/rest/computer/mcp";
  # Codex skips it and agy cannot complete its OAuth discovery.
  claude-design = {
    url = "https://api.anthropic.com/v1/design/mcp";
    clients = [ "claude" ];
  };
} // lib.optionalAttrs (all || browsers) {
  # Browsers by their system profile path, so this adds no second copy of them.
  brave-devtools = {
    command = [ (toString launch) "brave" "${pkgs.nodejs}/bin/npx" "/run/current-system/sw/bin/brave" ];
    clients = browserClients;
  };
  firefox-developer = {
    command = [ (toString launch) "firefox" "${pkgs.firefox-devtools-mcp}/bin/firefox-devtools-mcp" "/run/current-system/sw/bin/firefox-devedition" ];
    clients = browserClients;
  };
} // lib.optionalAttrs (all || resolve != null) {
  # Built into Resolve Studio 21.1+ and pinned by nixpkgs, so no updater. Run
  # through the FHS wrapper, whose libraries it needs. Claude Code only until
  # Codex and agy per-tool approval is managed (settings-base.json gates it).
  davinci-resolve = {
    command = [ (toString launch) "resolve" "${resolve}/bin/davinci-resolve-studio" "${resolve.davinci}/bin/ResolveMCP" ];
    clients = [ "claude" ];
  };
})
