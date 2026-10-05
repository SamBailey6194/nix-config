"""Launch shared stdio servers without embedding credentials in Nix."""
import json
import os
from pathlib import Path
import sys


def main():
    home = Path.home()
    try:
        credentials = json.loads((home / ".config/ai-mcp/credentials.json").read_text())
    except (OSError, ValueError):
        credentials = {}
    for key, value in credentials.items():
        if key in {"CONTEXT7_API_KEY", "ELEVENLABS_API_KEY", "ELEVENLABS_MCP_BASE_PATH"}:
            os.environ.setdefault(key, value)
    kind, executable, *args = sys.argv[1:]
    if kind == "mermaid":
        os.environ["PLAYWRIGHT_BROWSERS_PATH"] = args[0]
        os.environ["PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS"] = "1"
        command = [executable, str(home / ".claude/mcp-mermaid/node_modules/mcp-mermaid/build/index.js")]
    elif kind == "context7":
        command = [executable, "--yes", "@upstash/context7-mcp"]
        key = os.environ.get("CONTEXT7_API_KEY")
        if key:
            command += ["--api-key", key]
    elif kind == "elevenlabs":
        if not os.environ.get("ELEVENLABS_API_KEY"):
            sys.exit("ElevenLabs requires ELEVENLABS_API_KEY in /run/agenix/claude-secrets or ~/.config/ai-mcp/credentials.json")
        os.environ.setdefault("ELEVENLABS_MCP_BASE_PATH", "/")
        command = [executable, "--python", args[0], "elevenlabs-mcp==0.12.2"]
    else:
        sys.exit("Unknown shared MCP server")
    os.execvpe(command[0], command, os.environ)


if __name__ == "__main__":
    main()
