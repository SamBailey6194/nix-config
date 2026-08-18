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

  # mcp-mermaid renders diagrams with Playwright-driven Chromium, which is a
  # poor fit for NixOS in two ways:
  #   1. Its npm postinstall runs `playwright install --with-deps chromium`, which
  #      apt/sudo-installs system libs (no tty, no apt on NixOS) → exits 1, aborts
  #      the install, corrupts the npx cache → JSON-RPC -32000 at connect time.
  #   2. Playwright pins an exact Chromium *revision* per version; the prebuilt
  #      binary won't run on NixOS anyway, so we use nixpkgs' browsers bundle.
  # Fix: install mcp-mermaid into a fixed dir with --ignore-scripts (skips the
  # failing browser download) and pin Playwright to playwright-driver's version
  # so its expected Chromium revision matches the nixpkgs bundle. Sourcing the pin
  # from playwright-driver means `nix flake update` moves the override and the
  # browser bundle together — no manual revision chasing.
  playwrightBrowsers = "${pkgs.playwright-driver.browsers}";
  playwrightVersion = pkgs.playwright-driver.version;
  mcpMermaidVersion = "0.4.1";
  mcpMermaidDir = "${homeDir}/.claude/mcp-mermaid";
  mcpMermaidEntry = "${mcpMermaidDir}/node_modules/mcp-mermaid/build/index.js";
  mcpMermaidPkgJson = builtins.toJSON {
    name = "mcp-mermaid-pinned";
    version = "1.0.0";
    private = true;
    dependencies."mcp-mermaid" = mcpMermaidVersion;
    # Force every transitive Playwright onto the version whose Chromium revision
    # the nixpkgs browsers bundle actually ships.
    overrides = {
      playwright = playwrightVersion;
      playwright-core = playwrightVersion;
    };
  };

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

    # ── Auto mode environment context ───────────────────────────────────
    #
    # `/auto-mode-setup` customises auto mode by writing an `autoMode` key
    # here, of the shape:
    #
    #   autoMode = {
    #     environment = "<prose describing this machine and its repos>";
    #     rules = [ /* optional rule tweaks */ ];
    #   };
    #
    # It CANNOT write it itself on this machine. The command states that
    # "--apply-target doesn't change where the config is written — entries
    # always land in the user settings file", and ~/.claude/settings.json is
    # a read-only symlink into /nix/store, generated from this very file.
    #
    # So use the wizard for its draft, then transcribe it here:
    #
    #   claude
    #   /auto-mode-setup --wizard posture=mixed scope=all depth=both --propose
    #
    # posture=mixed reflects this home directory holding personal
    # (SamBailey6194), syntek work, and missional-gen repos side by side.
    # The propose step writes a proposal JSON to a temp file and shows it;
    # copy its `autoMode` object into the attribute below and rebuild. Do
    # NOT run the second (`--expect-sha256 ... --apply-file ...`) phase — it
    # will fail on the read-only settings.json, and would be overwritten by
    # the next rebuild even if it succeeded.
    #
    # The scan reads CLAUDE.md files, repo facts and visibility, shell
    # history (command words only), other git repos under $HOME, and
    # transcript names. It is also the place to prune any classifier-
    # bypassing entries it flags in permissions.allow above.
    #
    # Verified against claude-code 2.1.234: the key is `autoMode`, with an
    # `environment` string and a `rules` list. The exact element shape of
    # `rules` was not confirmed — take it verbatim from the proposal.
    #
    # autoMode = {
    #   environment = "...";
    # };
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

  # Install mcp-mermaid into a fixed dir with Playwright pinned to the nixpkgs
  # browsers bundle (best-effort; needs network on first run / version bump).
  # See the playwright notes in the let block above for why this is necessary.
  home.activation.mcpMermaid = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${mcpMermaidDir}"
    printf '%s' ${lib.escapeShellArg mcpMermaidPkgJson} > "${mcpMermaidDir}/package.json"
    want='${mcpMermaidVersion}-${playwrightVersion}'
    if [ ! -f "${mcpMermaidEntry}" ] || [ "$(cat "${mcpMermaidDir}/.pinned" 2>/dev/null)" != "$want" ]; then
      ( cd "${mcpMermaidDir}" \
        && rm -rf node_modules package-lock.json \
        && ${npmBin} install --ignore-scripts --no-audit --no-fund \
        && printf '%s' "$want" > "${mcpMermaidDir}/.pinned" ) || true
    fi
  '';

  # Register the MCP servers at user scope, idempotently. ~/.claude.json is owned
  # and rewritten by Claude Code itself, so this uses `claude mcp add` rather than
  # managing that file. Context7's key comes from the agenix secret.
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" "mcpMermaid" ] ''
    CLAUDE='${claudeBin}'
    if [ -r ${secretsFile} ]; then . ${secretsFile}; fi

    $CLAUDE mcp get figma >/dev/null 2>&1 || \
      $CLAUDE mcp add --scope user --transport http figma https://mcp.figma.com/mcp || true

    # Re-register each activation so the Playwright env (browser path) and the
    # pinned-install entrypoint stay in sync with this config; a stale entry can't
    # render diagrams. Runs the locally-installed build, not `npx`, so the pinned
    # Playwright (see mcpMermaid activation) is used.
    $CLAUDE mcp remove --scope user mcp-mermaid >/dev/null 2>&1 || true
    $CLAUDE mcp add --scope user mcp-mermaid \
      --env PLAYWRIGHT_BROWSERS_PATH=${playwrightBrowsers} \
      --env PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 \
      -- ${nodeBin} ${mcpMermaidEntry} || true

    if [ -n "''${CONTEXT7_API_KEY:-}" ]; then
      $CLAUDE mcp get context7 >/dev/null 2>&1 || \
        $CLAUDE mcp add --scope user --transport http context7 https://mcp.context7.com/mcp \
          --header "CONTEXT7_API_KEY: ''${CONTEXT7_API_KEY}" || true
    fi
  '';
}
