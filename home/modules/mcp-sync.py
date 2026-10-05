"""Merge shared MCP inventory, preserving other settings and disabled flags."""
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import tomllib
import tomli_w


def write(path, data, mode=None):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".mcp-")
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(data)
        os.chmod(tmp, mode if mode is not None else 0o600)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def capture_credentials(home):
    destination = home / ".config/ai-mcp/credentials.json"
    if destination.is_symlink():
        raise ValueError("credential file is a symlink")
    keys = json.loads(destination.read_text()) if destination.exists() else {}
    # Read the preserved Ubuntu home before replacing its Claude commands.
    for source in [home / ".claude.json", Path("/mnt/ubuntu-home/sam-dev/.claude.json")]:
        try:
            servers = json.loads(source.read_text()).get("mcpServers", {})
        except (OSError, ValueError):
            continue
        context = servers.get("context7", {})
        args = context.get("args", [])
        if "--api-key" in args and args.index("--api-key") + 1 < len(args):
            keys.setdefault("CONTEXT7_API_KEY", args[args.index("--api-key") + 1])
        key = context.get("headers", {}).get("CONTEXT7_API_KEY")
        if key:
            keys.setdefault("CONTEXT7_API_KEY", key)
        for key in ["ELEVENLABS_API_KEY", "ELEVENLABS_MCP_BASE_PATH"]:
            value = servers.get("elevenlabs", {}).get("env", {}).get(key)
            if value:
                keys.setdefault(key, value)
    if keys:
        write(destination, json.dumps(keys, indent=2) + "\n", 0o600)


def sync(client, path, inventory):
    if path.is_symlink():
        raise ValueError("configuration is a symlink")
    old = path.read_text() if path.exists() else ""
    config = (tomllib.loads(old) if client == "codex" else json.loads(old)) if old.strip() else {}
    if not isinstance(config, dict):
        raise ValueError("configuration is not an object")
    before = json.dumps(config, sort_keys=True)
    servers = config.setdefault("mcp_servers" if client == "codex" else "mcpServers", {})
    for name, server in inventory.items():
        entry = servers.setdefault(name, {})
        if not isinstance(entry, dict):
            raise ValueError("server entry is not an object")
        if "command" in server:
            entry.pop("url", None)
            entry.pop("type", None)
            entry["command"], entry["args"] = server["command"][0], server["command"][1:]
            if client == "codex":
                entry.setdefault("startup_timeout_sec", 120)
            if client == "claude":
                entry["type"] = "stdio"
        else:
            entry.pop("command", None)
            entry.pop("args", None)
            entry["url"] = server["url"]
            if client == "claude":
                entry["type"] = "http"
    if json.dumps(config, sort_keys=True) != before:
        mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
        data = tomli_w.dumps(config) if client == "codex" else json.dumps(config, indent=2) + "\n"
        write(path, data, mode)


def main():
    client, inventory_file = sys.argv[1:]
    home = Path.home()
    paths = {
        "claude": Path(os.environ.get("CLAUDE_CONFIG_DIR", str(home))) / ".claude.json",
        "codex": Path(os.environ.get("CODEX_HOME", str(home / ".codex"))) / "config.toml",
        "antigravity": home / ".gemini/config/mcp_config.json",
    }
    try:
        capture_credentials(home)
        sync(client, paths[client], json.loads(Path(inventory_file).read_text()))
    except (OSError, ValueError, TypeError) as error:
        # Parser errors may contain secrets; report only the exception type.
        print(f"shared MCP: {client} configuration left unchanged ({type(error).__name__}); inspect its configuration locally", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
