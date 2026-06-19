{ config, pkgs, lib, ... }:

# Declarative Claude Code setup, reproduced from the manual config on the
# reference machine. Applies to every device that imports it.
#
# Secrets are NOT stored in the repo. The agenix secret `claude-secrets`
# (declared per host in modules/core/secrets-*.nix, editable with
# `agenix -e secrets/claude-secrets-<host>.age`) provides, as an env file at
# /run/agenix/claude-secrets:
#     CLAUDE_MONITOR_TOKEN=...   # claude-code-monitor hook auth
#     CONTEXT7_API_KEY=...       # Context7 MCP auth
# settings.json itself is non-secret (the monitor token is read at hook runtime
# from that file), so it is managed declaratively here. On a new device, edit the
# agenix secret on first use; everything else is reproduced automatically.

let
  homeDir = config.home.homeDirectory;
  claudeBin = lib.getExe pkgs.claude-code;
  nodeBin = "${pkgs.nodejs}/bin/node";
  npmBin = "${pkgs.nodejs}/bin/npm";
  npxBin = "${pkgs.nodejs}/bin/npx";

  monitorRepo = "https://github.com/bruceyxli/claude-code-monitor.git";
  monitorDir = "${homeDir}/Repos/claude-code-monitor";
  secretsFile = "/run/agenix/claude-secrets";

  # Claude (anthropic) browser extension id — must match the Brave forcelist in
  # modules/security/browser-policies and the native-host allowed_origins.
  claudeExtensionId = "fcoeoabgfenejglbffodgkkbkcdhcgfn";

  # One monitor hook entry for a given lifecycle event.
  monitorHook = event: timeout: [{
    matcher = "";
    hooks = [{
      type = "command";
      command = "${homeDir}/.claude/hooks/claude-monitor-hook ${event}";
      inherit timeout;
    }];
  }];

  settings = {
    env."ENABLE_LSP_TOOL" = "1";
    permissions.allow = [ "mcp__claude-in-chrome__*" ];
    model = "opus";

    hooks = {
      SessionStart = monitorHook "SessionStart" 5000;
      SessionEnd = monitorHook "SessionEnd" 5000;
      UserPromptSubmit = monitorHook "UserPromptSubmit" 5000;
      PreToolUse = (monitorHook "PreToolUse" 300000) ++ [{
        matcher = "Write";
        hooks = [{
          type = "command";
          command = "bash ${homeDir}/.claude/hooks/block-auto-memory-write.sh";
        }];
      }];
      PostToolUse = monitorHook "PostToolUse" 5000;
      Notification = monitorHook "Notification" 5000;
      Stop = monitorHook "Stop" 5000;
      SubagentStart = monitorHook "SubagentStart" 5000;
      SubagentStop = monitorHook "SubagentStop" 5000;
    };

    statusLine = {
      type = "command";
      command = "bash ${homeDir}/.claude/statusline-command.sh";
    };

    enabledPlugins = {
      "syntek-dev-suite@syntek-marketplace" = true;
      "syntek-infra@syntek-marketplace" = true;
      "syntek-rust-security@syntek-marketplace" = true;
      "dnd-dm-planner@dnd-dm-planner" = true;
      "plugin-dev@claude-code-plugins" = true;
      "syntek-doc-writer@syntek-marketplace" = true;
    };

    extraKnownMarketplaces = {
      dnd-dm-planner.source = {
        source = "git";
        url = "git@github-personal:SamBailey6194/dnd-dm-planner.git";
      };
      claude-code-plugins.source = {
        source = "github";
        repo = "anthropics/claude-code";
      };
    };

    # Ultracode + xhigh effort + dynamic workflows, default model opus.
    effortLevel = "xhigh";
    ultracode = true;
    enableWorkflows = true;
    skipWorkflowUsageWarning = true;
    skipAutoPermissionPrompt = true;
  };
in
{
  home.packages = [
    pkgs.claude-code
    pkgs.jq # used by the statusline + block-auto-memory hooks
  ];

  home.file = {
    # Declarative settings.json (no secrets — the monitor token is sourced at
    # hook runtime from the agenix env file by claude-monitor-hook).
    ".claude/settings.json".text = builtins.toJSON settings;

    ".claude/statusline-command.sh" = {
      source = ../../config/claude/statusline-command.sh;
      executable = true;
    };

    ".claude/hooks/block-auto-memory-write.sh" = {
      source = ../../config/claude/block-auto-memory-write.sh;
      executable = true;
    };

    # Monitor hook wrapper: sources the agenix secret for CLAUDE_MONITOR_TOKEN
    # and runs the handler. No-ops silently if the monitor repo or secret is
    # absent (e.g. a host without the secret), so hooks never error.
    ".claude/hooks/claude-monitor-hook" = {
      executable = true;
      text = ''
        #!/bin/sh
        HANDLER="${monitorDir}/hook-handler.js"
        [ -f "$HANDLER" ] || exit 0
        if [ -r ${secretsFile} ]; then set -a; . ${secretsFile}; set +a; fi
        exec ${nodeBin} "$HANDLER" "$1"
      '';
    };

    # Claude-in-Chrome native messaging host wrapper -> the Nix claude binary
    # (replaces the version-pinned path the CLI generates).
    ".claude/chrome/chrome-native-host" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec ${claudeBin} --chrome-native-host
      '';
    };

    # Register the native host with Brave so Claude-in-Chrome links to Brave.
    ".config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json".text =
      builtins.toJSON {
        name = "com.anthropic.claude_code_browser_extension";
        description = "Claude Code Browser Extension Native Host";
        path = "${homeDir}/.claude/chrome/chrome-native-host";
        type = "stdio";
        allowed_origins = [ "chrome-extension://${claudeExtensionId}/" ];
      };
  };

  # Clone the Claude Code Monitor repo (best-effort; the hook wrapper no-ops if
  # this hasn't run yet or fails — e.g. offline).
  home.activation.claudeCodeMonitor = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "${monitorDir}/.git" ]; then
      ${pkgs.git}/bin/git clone --depth 1 ${monitorRepo} "${monitorDir}" || true
    fi
    if [ -f "${monitorDir}/package.json" ] && [ ! -d "${monitorDir}/node_modules" ]; then
      ( cd "${monitorDir}" && ${npmBin} ci --omit=dev ) || true
    fi
  '';

  # Register the MCP servers at user scope, idempotently. ~/.claude.json is owned
  # and rewritten by Claude Code itself, so this uses `claude mcp add` rather than
  # managing that file. Context7's key comes from the agenix secret.
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE='${claudeBin}'
    if [ -r ${secretsFile} ]; then . ${secretsFile}; fi

    $CLAUDE mcp get figma >/dev/null 2>&1 || \
      $CLAUDE mcp add --scope user --transport http figma https://mcp.figma.com/mcp || true

    $CLAUDE mcp get mcp-mermaid >/dev/null 2>&1 || \
      $CLAUDE mcp add --scope user mcp-mermaid -- ${npxBin} -y mcp-mermaid || true

    if [ -n "''${CONTEXT7_API_KEY:-}" ]; then
      $CLAUDE mcp get context7 >/dev/null 2>&1 || \
        $CLAUDE mcp add --scope user --transport http context7 https://mcp.context7.com/mcp \
          --header "CONTEXT7_API_KEY: ''${CONTEXT7_API_KEY}" || true
    fi
  '';
}
