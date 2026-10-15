"""Launch shared stdio servers without embedding credentials in Nix."""
import json
import os
from pathlib import Path
import sys

# Everything the launcher may receive from /run/agenix/claude-secrets or the
# captured credential file, and which of it each server needs. The rest is
# removed, so no server sees another's key or the monitor token. A secret's
# ELEVENLABS_MCP_BASE_PATH is removed too: the inventory declares that one.
SECRETS = {"CLAUDE_MONITOR_TOKEN", "CONTEXT7_API_KEY", "ELEVENLABS_API_KEY", "ELEVENLABS_MCP_BASE_PATH"}
NEEDS = {
    "context7": {"CONTEXT7_API_KEY"},
    "elevenlabs": {"ELEVENLABS_API_KEY"},
}
CHROME_DEVTOOLS_MCP = "chrome-devtools-mcp@1.10.1"
SCRAPLING = "scrapling[ai]==0.4.15"


def graphical_environment():
    """Find the desktop session; clients such as Codex pass only a few variables."""
    runtime = Path(os.environ.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    if "WAYLAND_DISPLAY" not in os.environ:
        sockets = sorted(p.name for p in runtime.glob("wayland-*") if not p.name.endswith(".lock"))
        if sockets:
            os.environ["WAYLAND_DISPLAY"] = sockets[0]
    if "DISPLAY" not in os.environ:
        displays = sorted(p.name for p in Path("/tmp/.X11-unix").glob("X*"))
        if displays:
            os.environ["DISPLAY"] = ":" + displays[0][1:]
    if "DBUS_SESSION_BUS_ADDRESS" not in os.environ and (runtime / "bus").exists():
        os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={runtime / 'bus'}"


def main():
    home = Path.home()
    try:
        credentials = json.loads((home / ".config/ai-mcp/credentials.json").read_text())
    except (OSError, ValueError):
        credentials = {}
    for key, value in credentials.items():
        # An empty inherited value (a client's blank inline key) counts as unset.
        if key in SECRETS and not os.environ.get(key):
            os.environ[key] = value
    kind, executable, *args = sys.argv[1:]
    for key in SECRETS - NEEDS.get(kind, set()):
        os.environ.pop(key, None)
    if kind == "mermaid":
        os.environ["PLAYWRIGHT_BROWSERS_PATH"] = args[0]
        os.environ["PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS"] = "1"
        command = [executable, str(home / ".claude/mcp-mermaid/node_modules/mcp-mermaid/build/index.js")]
    elif kind == "context7":
        # The server reads CONTEXT7_API_KEY itself; an --api-key argument would
        # show the key in the process list.
        command = [executable, "--yes", "@upstash/context7-mcp"]
    elif kind == "elevenlabs":
        if not os.environ.get("ELEVENLABS_API_KEY"):
            sys.exit("ElevenLabs requires ELEVENLABS_API_KEY in /run/agenix/claude-secrets or ~/.config/ai-mcp/credentials.json")
        # The inventory's declared base path (the home directory), the value
        # registration writes into every client's entry; nothing overrides it.
        if len(args) < 2 or not args[1]:
            sys.exit("ElevenLabs requires the declared base path argument (home/modules/mcp-servers.nix)")
        os.environ["ELEVENLABS_MCP_BASE_PATH"] = args[1]
        command = [executable, "--python", args[0], "elevenlabs-mcp==0.12.2"]
    elif kind == "scrapling":
        # The wrapped uvx supplies the greenlet library path, the nixpkgs browser
        # bundle and its version constraints; the Playwright pin is the bundle's,
        # passed from the inventory. Never `scrapling install`: the store is read-only.
        if len(args) < 2 or not args[1]:
            sys.exit("Scrapling requires the Playwright version argument (home/modules/mcp-servers.nix)")
        command = [executable, "--python", args[0], "--from", SCRAPLING,
                   "--with", f"playwright=={args[1]}", "scrapling", "mcp"]
    elif kind == "brave":
        graphical_environment()
        command = [executable, "--yes", CHROME_DEVTOOLS_MCP, "--executable-path", args[0]]
    elif kind == "firefox":
        graphical_environment()
        command = [executable, "--firefoxPath", args[0]]
    elif kind == "resolve":
        # The FHS wrapper runs ResolveMCP in Resolve's sandbox; it attaches to
        # (or launches) Resolve, which needs XWayland.
        graphical_environment()
        os.environ["QT_QPA_PLATFORM"] = "xcb"
        command = [executable, args[0]]
    else:
        sys.exit("Unknown shared MCP server")
    os.execvpe(command[0], command, os.environ)


if __name__ == "__main__":
    main()
