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
# So, like codex.nix and antigravity.nix, every key below is added once, only if
# it is missing, and never touched again: edits stick, and so does disabling a
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
# The model entry mirrors the server's command line (modules/software/
# local-llm.nix): -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS -c 32768 --jinja
# (tool calls need --jinja). Keep `limit.context` equal to -c.

let
  jqBin = "${pkgs.jq}/bin/jq";
  mcp = import ./mcp-servers.nix;

  llm = if osConfig != null then osConfig.services.localLlm or null else null;

  # An IPv6 address (a WireGuard one, say) needs brackets in a URL
  llmHost = if lib.hasInfix ":" llm.host then "[${llm.host}]" else llm.host;

  localProvider = lib.optionalAttrs (llm != null && llm.enable) {
    id = "llama-cpp";
    model = "llama-cpp/qwen3.6-35b-a3b";
    value = {
      name = "llama.cpp (local llama-server)";
      package = "@opencode/ai/providers/openai-compatible";
      settings.baseURL = "http://${llmHost}:${toString llm.port}/v1";
      models."qwen3.6-35b-a3b" = {
        modelID = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS";
        name = "Qwen3.6 35B-A3B (UD-IQ4_XS, local)";
        capabilities = {
          tools = true;
          input = [ "text" ];
          output = [ "text" ];
        };
        limit = {
          context = 32768;
          output = 8192;
        };
      };
    };
  };

  defaults = {
    schema = "https://opencode.ai/config.json";
    # Every shared server is remote (OAuth on first use: `opencode mcp auth <name>`
    # or /mcps in the TUI)
    servers = lib.mapAttrs (_: server: {
      type = "remote";
      inherit (server) url;
    }) mcp;
    provider = if localProvider == { } then null else localProvider;
  };

  # Input (jq -s): every JSON document in the file, so none for a missing or
  # blank file, which starts from {}. Anything but a single object (several
  # documents, an array, null, …) is an error. $d: `defaults` above. Output: the
  # merged config.
  mergeFilter = ''
    (if length == 0 then {}
     elif length == 1 and (.[0] | type) == "object" then .[0]
     else error("not a single JSON object") end)
    | (if has("$schema") then . else {"$schema": $d.schema} + . end)
    | reduce ($d.servers | to_entries[]) as $s (.;
        if (.mcp.servers[$s.key]? // .mcp[$s.key]?) != null then .
        else .mcp.servers[$s.key] = $s.value end)
    | if $d.provider == null then .
      elif (.providers[$d.provider.id]? // .provider[$d.provider.id]?) != null then .
      else .providers[$d.provider.id] = $d.provider.value
        | if has("model") then . else .model = $d.provider.model end
      end
  '';
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
