"""Merge shared MCP inventory, preserving other settings and disabled flags."""
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import tomllib
import tomli_w

AGENIX_SECRETS = Path("/run/agenix/claude-secrets")
# Supplied by the launcher; inline copies in a managed server entry are removed.
CREDENTIALS = {"CONTEXT7_API_KEY", "ELEVENLABS_API_KEY"}
# Keys belonging to one transport, dropped when a managed entry uses the other.
HTTP_KEYS = ("url", "serverUrl", "httpUrl", "headers", "http_headers", "env_http_headers",
             "bearer_token_env_var", "bearer_token")
STDIO_KEYS = ("command", "args", "env", "env_vars", "cwd")


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
    # With the agenix secret in place there is no need for a plaintext copy.
    if os.access(AGENIX_SECRETS, os.R_OK):
        return
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


def strip_credentials(entry):
    """Remove inline keys (env values, Codex env_vars names) the launcher supplies."""
    env = entry.get("env")
    if isinstance(env, dict):
        for key in CREDENTIALS:
            env.pop(key, None)
        if not env:
            entry.pop("env")
    names = entry.get("env_vars")
    if isinstance(names, list):
        # Codex accepts plain names or { name, source } tables.
        names[:] = [var for var in names
                    if (var.get("name") if isinstance(var, dict) else var) not in CREDENTIALS]
        if not names:
            entry.pop("env_vars")


def sync(client, path, inventory, retired=()):
    """Register `inventory`, and remove `retired`: managed names this client no longer gets."""
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
            for key in HTTP_KEYS + ("type",):
                entry.pop(key, None)
            entry["command"], entry["args"] = server["command"][0], server["command"][1:]
            strip_credentials(entry)
            if client == "codex":
                entry.setdefault("startup_timeout_sec", 120)
            if client == "claude":
                entry["type"] = "stdio"
        else:
            for key in STDIO_KEYS:
                entry.pop(key, None)
            entry["url"] = server["url"]
            if client == "antigravity":
                # Older Antigravity/Gemini keys would shadow the managed URL.
                entry.pop("serverUrl", None)
                entry.pop("httpUrl", None)
                # agy signs in to these servers with its own MCP OAuth; a pasted
                # bearer token (Ubuntu's was another client's) only goes stale.
                headers = entry.get("headers")
                if isinstance(headers, dict):
                    headers.pop("Authorization", None)
                    if not headers:
                        entry.pop("headers")
            if client == "claude":
                entry["type"] = "http"
    for name in retired:
        servers.pop(name, None)
    # These files can hold credentials: never wider than owner read/write,
    # whether or not this run changes them.
    if path.exists() and stat.S_IMODE(path.stat().st_mode) & 0o177:
        os.chmod(path, stat.S_IMODE(path.stat().st_mode) & 0o600)
    if json.dumps(config, sort_keys=True) != before:
        mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
        data = tomli_w.dumps(config) if client == "codex" else json.dumps(config, indent=2) + "\n"
        write(path, data, mode)


def main():
    client, inventory_file, *retired_file = sys.argv[1:]
    home = Path.home()
    paths = {
        "claude": Path(os.environ.get("CLAUDE_CONFIG_DIR", str(home))) / ".claude.json",
        "codex": Path(os.environ.get("CODEX_HOME", str(home / ".codex"))) / "config.toml",
        "antigravity": home / ".gemini/config/mcp_config.json",
    }
    try:
        capture_credentials(home)
        retired = json.loads(Path(retired_file[0]).read_text()) if retired_file else []
        sync(client, paths[client], json.loads(Path(inventory_file).read_text()), retired)
    except (OSError, ValueError, TypeError) as error:
        # Parser errors may contain secrets; report only the exception type.
        print(f"shared MCP: {client} configuration left unchanged ({type(error).__name__}); inspect its configuration locally", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
