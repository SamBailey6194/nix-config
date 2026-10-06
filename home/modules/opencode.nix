{ pkgs, lib, osConfig ? null, ... }:

# OpenCode v2: MCP servers shared with the other agents (./mcp-servers.nix) and,
# on a host that serves a model itself, the local llama-server as a provider.
# The package itself is system-wide, in modules/software/development.nix.
#
# ~/.config/opencode/opencode.json is merged into rather than managed as a
# file. OpenCode v2 writes it itself: `opencode mcp add --global` adds servers
# to it, and its documented v1 -> v2 migration is to ask OpenCode to rewrite it.
# Home Manager's programs.opencode would make it a read-only symlink into
# /nix/store that those writes fail on, and it renders shared MCP servers in the
# v1 shape (`mcp.<name>`, `enabled`) rather than v2's `mcp.servers.<name>`. What
# OpenCode writes most often is elsewhere and untouched here: the terminal
# client's settings screen writes cli.json, and provider credentials
# (`opencode auth login`) go to its SQLite database under
# ~/.local/share/opencode. Switching a session's model does not rewrite the
# config.
#
# Shared MCP transports follow the catalog on activation; other keys are added
# only when missing. Explicit permission rules stick, and so does disabling a
# server (`"disabled": true` in its entry). Removing a server or the provider
# does not — it comes back on the next rebuild, like Context7 in claude.nix. An
# entry counts as present in either shape (v1 `mcp.<name>` / `provider.<id>`, or
# v2), so a hand-written v1 config is never given a duplicate. The first write
# re-indents the file (jq); later activations with nothing to add leave it alone.
# A missing or blank file starts from {}. An opencode.jsonc, a symlink, or a
# file that is anything but one JSON object (unparsable, a top-level array,
# several documents) is left alone with a warning.
#
# LOCAL PROVIDER, PER HOST
#
# The provider belongs to the machine running llama-server, so it is added only
# where modules/software/local-llm.nix is enabled (devtower-intel, dev stage and
# up), with its baseURL built from that host's services.localLlm.host/port
# (127.0.0.1:8080 today; an IPv6 address is bracketed). laptop-intel and
# framework run no model server and get no provider — OpenCode then falls back
# to the newest available model (its own free models, or a logged-in
# provider's). When devtower serves them over WireGuard, give those hosts a
# provider pointing at devtower's tunnel address instead (never 127.0.0.1 on a
# laptop). The default `model` is set together with the provider, the first
# time only, and only if no model is set.
#
# Changing services.localLlm.host/port later does not rewrite an existing
# provider entry: update its settings.baseURL, or delete the entry and rebuild.
#
# Model IDs and context limits come from the same catalog as llama-swap.
# Missing models are added to an existing provider; the old generated 32K
# Qwen entry is upgraded to native context. Other custom entries are preserved.

let
  jqBin = "${pkgs.jq}/bin/jq";
  mcp = import ./mcp-servers.nix { inherit pkgs lib; client = "opencode"; };
  # Managed names OpenCode does not get (e.g. claude-design), removed if present.
  retiredMcp = lib.subtractLists (builtins.attrNames mcp)
    (builtins.attrNames (import ./mcp-servers.nix { inherit pkgs lib; browsers = true; }));

  llm = if osConfig != null then osConfig.services.localLlm or null else null;

  # An IPv6 address (a WireGuard one, say) needs brackets in a URL
  llmHost = if lib.hasInfix ":" llm.host then "[${llm.host}]" else llm.host;

  localProvider = lib.optionalAttrs (llm != null && llm.enable && llm.serverEnable) {
    id = "llama-cpp";
    model = "llama-cpp/${llm.defaultModel}";
    value = {
      name = "llama.cpp (local, one model at a time)";
      package = "@opencode/ai/providers/openai-compatible";
      settings.baseURL = "http://${llmHost}:${toString llm.port}/v1";
      models = lib.mapAttrs (id: model: {
        modelID = id;
        inherit (model) name;
        capabilities = {
          tools = true;
          input = [ "text" ];
          output = [ "text" ];
        };
        limit = {
          context = model.contextSize;
          output = 8192;
        };
      }) llm.models;
    };
  };

  defaults = {
    schema = "https://opencode.ai/config.json";
    servers = lib.mapAttrs (_: server:
      if server ? url then { type = "remote"; inherit (server) url; }
      else { type = "local"; inherit (server) command; timeout = 120000; }
    ) mcp;
    remove = retiredMcp;
    provider = if localProvider == { } then null else localProvider;
    # OpenCode v2 ordered permission rules. Its edit permission covers writing
    # files and patches; the external-directory policy still applies.
    permissions = [ { action = "edit"; resource = "*"; effect = "allow"; } ];
  };

  # Input (jq -s): every JSON document in the file, so none for a missing or
  # blank file, which starts from {}. Anything but a single object (several
  # documents, an array, null, …) is an error. $d: `defaults` above. Output: the
  # merged config.
  mergeFilter = builtins.readFile ./opencode-merge.jq;
in
{
  # Best-effort throughout, like codex.nix: activation runs under
  # `set -eu -o pipefail`, so every step that can fail only warns.
  home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ocDir="''${OPENCODE_CONFIG_DIR:-''${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
    ocConfig="$ocDir/opencode.json"
    ocDefaults=${lib.escapeShellArg (builtins.toJSON defaults)}
    ocFilter=${lib.escapeShellArg mergeFilter}
    ocInput=/dev/null
    if [ -e "$ocConfig" ]; then ocInput=$ocConfig; fi
    ocMerged=

    if [ -e "$ocDir/opencode.jsonc" ]; then
      echo "opencodeConfig: $ocDir/opencode.jsonc exists and jq cannot edit JSONC; skipped (add the shared MCP servers by hand)" >&2
    elif [ -L "$ocConfig" ]; then
      echo "opencodeConfig: $ocConfig is a symlink; skipped" >&2
    elif [ -e "$ocConfig" ] && [ ! -w "$ocConfig" ]; then
      echo "opencodeConfig: $ocConfig is not writable; skipped" >&2
    elif ! mkdir -p "$ocDir" 2>/dev/null; then
      echo "opencodeConfig: could not create $ocDir; skipped" >&2

    # Read whole (-s; /dev/null when missing): see mergeFilter. Anything that
    # is not one JSON object is reported and left as it is, and an empty result
    # is never written.
    elif ! ocMerged=$(${jqBin} -s --argjson d "$ocDefaults" "$ocFilter" "$ocInput" 2>/dev/null) || [ -z "$ocMerged" ]; then
      echo "opencodeConfig: left $ocConfig alone (jq could not merge into it; is it a single JSON object?)" >&2

    # Nothing missing: leave the file (and its formatting) exactly as it is
    elif [ -s "$ocConfig" ] && ${jqBin} -e --argjson m "$ocMerged" '. == $m' "$ocConfig" >/dev/null 2>&1; then
      :

    # Write a temp file beside it, keep the mode, then rename over it, so
    # OpenCode never reads a half-written config
    elif ocTmp=$(mktemp "$ocDir/.opencode.json.XXXXXX" 2>/dev/null); then
      if printf '%s\n' "$ocMerged" > "$ocTmp" \
        && { [ ! -e "$ocConfig" ] || chmod --reference="$ocConfig" "$ocTmp"; } \
        && mv -f "$ocTmp" "$ocConfig"
      then :
      else
        rm -f "$ocTmp"
        echo "opencodeConfig: could not write $ocConfig" >&2
      fi
    else
      echo "opencodeConfig: could not create a temp file in $ocDir; skipped" >&2
    fi
  '';
}
