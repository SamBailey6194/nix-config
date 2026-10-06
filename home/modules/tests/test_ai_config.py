"""Run with the Nix Python tomli-w environment; all fixtures are temporary."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch

MODULES = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, MODULES / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sync = load("mcp_sync", "mcp-sync.py")
launch = load("mcp_launch", "mcp-launch.py")

INVENTORY = {
    "elevenlabs": {"command": ["/nix/server", "elevenlabs", "/nix/uvx"]},
    "context7": {"command": ["/nix/server", "context7", "/nix/npx"]},
    "mcp-mermaid": {"command": ["/nix/server", "mermaid", "/nix/node"]},
    "perplexity-computer": {"url": "https://example.test/perplexity"},
    "claude-design": {"url": "https://example.test/design"},
}


class SharedMcpTests(unittest.TestCase):
    def test_all_clients_match_inventory_and_preserve_disabled_and_custom(self):
        with tempfile.TemporaryDirectory() as directory:
            for client in ["claude", "codex", "antigravity"]:
                path = Path(directory) / client
                source = {"model": "custom", "mcpServers": {
                    "elevenlabs": {"command": "uvx", "args": ["old"], "disabled": True, "enabled": False},
                    "custom": {"command": "custom-command"},
                }}
                if client == "codex":
                    source["mcp_servers"] = source.pop("mcpServers")
                    import tomli_w
                    path.write_text(tomli_w.dumps(source))
                else:
                    path.write_text(json.dumps(source))
                path.chmod(0o600)
                sync.sync(client, path, INVENTORY)
                result = tomllib.loads(path.read_text()) if client == "codex" else json.loads(path.read_text())
                servers = result["mcp_servers" if client == "codex" else "mcpServers"]
                self.assertEqual(set(servers), set(INVENTORY) | {"custom"})
                self.assertEqual(servers["elevenlabs"]["command"], "/nix/server")
                self.assertTrue(servers["elevenlabs"]["disabled"])
                self.assertFalse(servers["elevenlabs"]["enabled"])
                self.assertEqual(result["model"], "custom")
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                first = path.read_bytes()
                sync.sync(client, path, INVENTORY)
                self.assertEqual(path.read_bytes(), first)

    def test_invalid_or_symlink_config_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config"
            path.write_text("invalid configuration")
            with self.assertRaises(ValueError):
                sync.sync("codex", path, INVENTORY)
            self.assertEqual(path.read_text(), "invalid configuration")
            link = Path(directory) / "link"
            link.symlink_to(path)
            with self.assertRaises(ValueError):
                sync.sync("claude", link, INVENTORY)
            self.assertTrue(link.is_symlink())

    def test_credentials_captured_before_transport_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = home / ".claude.json"
            path.write_text(json.dumps({"mcpServers": {
                "context7": {"args": ["-y", "package", "--api-key", "fixture-context"]},
                "elevenlabs": {"env": {"ELEVENLABS_API_KEY": "fixture-eleven", "ELEVENLABS_MCP_BASE_PATH": "/"}},
            }}))
            # Avoid reading this computer's preserved Ubuntu home in a fixture.
            original = Path.read_text
            def read(path, *args, **kwargs):
                if str(path).startswith("/mnt/ubuntu-home/"):
                    raise FileNotFoundError
                return original(path, *args, **kwargs)
            with patch.object(Path, "read_text", read), \
                    patch.object(sync, "AGENIX_SECRETS", home / "absent"):
                sync.capture_credentials(home)
                sync.sync("claude", path, INVENTORY)
                sync.capture_credentials(home)
            credentials = home / ".config/ai-mcp/credentials.json"
            self.assertEqual(json.loads(credentials.read_text())["ELEVENLABS_API_KEY"], "fixture-eleven")
            self.assertEqual(json.loads(credentials.read_text())["CONTEXT7_API_KEY"], "fixture-context")
            self.assertEqual(credentials.stat().st_mode & 0o777, 0o600)

    def test_capture_skipped_when_agenix_secret_is_readable(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / ".claude.json").write_text(json.dumps({"mcpServers": {
                "elevenlabs": {"env": {"ELEVENLABS_API_KEY": "fixture-eleven"}}}}))
            secret = home / "claude-secrets"
            secret.write_text("CONTEXT7_API_KEY=fixture\n")
            with patch.object(sync, "AGENIX_SECRETS", secret):
                sync.capture_credentials(home)
            self.assertFalse((home / ".config/ai-mcp/credentials.json").exists())

    def test_inline_credentials_removed_only_from_managed_servers(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.toml"
            import tomli_w
            path.write_text(tomli_w.dumps({"mcp_servers": {
                "context7": {"command": "sh", "env_vars": ["CONTEXT7_API_KEY"],
                             "env": {"CONTEXT7_API_KEY": "fixture", "KEEP": "1"}},
                "elevenlabs": {"command": "uvx", "env": {"ELEVENLABS_API_KEY": "fixture"}},
                "custom": {"command": "custom", "env": {"CONTEXT7_API_KEY": "fixture"}},
            }}))
            sync.sync("codex", path, INVENTORY)
            servers = tomllib.loads(path.read_text())["mcp_servers"]
            self.assertEqual(servers["context7"]["env"], {"KEEP": "1"})
            self.assertNotIn("env_vars", servers["context7"])
            self.assertNotIn("env", servers["elevenlabs"])
            self.assertEqual(servers["custom"]["env"], {"CONTEXT7_API_KEY": "fixture"})

    def test_antigravity_http_server_drops_legacy_url_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "mcp_config.json"
            path.write_text(json.dumps({"mcpServers": {
                "claude-design": {"serverUrl": "https://old.test", "httpUrl": "https://old.test", "disabled": False},
                "perplexity-computer": {"serverUrl": "https://old.test", "headers": {"Authorization": "Bearer fixture"}},
                "custom": {"serverUrl": "https://custom.test", "headers": {"Authorization": "Bearer fixture", "X-Other": "1"}},
            }}))
            path.chmod(0o644)
            sync.sync("antigravity", path, INVENTORY)
            servers = json.loads(path.read_text())["mcpServers"]
            self.assertEqual(servers["claude-design"], {"url": "https://example.test/design", "disabled": False})
            self.assertEqual(servers["perplexity-computer"], {"url": "https://example.test/perplexity"})
            self.assertEqual(servers["custom"]["headers"]["Authorization"], "Bearer fixture")
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)


    def test_retired_servers_removed_and_custom_kept(self):
        with tempfile.TemporaryDirectory() as directory:
            for client in ["claude", "codex", "antigravity"]:
                path = Path(directory) / client
                servers = {"claude-design": {"url": "https://old.test"}, "custom": {"command": "custom"}}
                if client == "codex":
                    import tomli_w
                    path.write_text(tomli_w.dumps({"mcp_servers": servers}))
                else:
                    path.write_text(json.dumps({"mcpServers": servers}))
                inventory = {k: v for k, v in INVENTORY.items() if k != "claude-design"}
                sync.sync(client, path, inventory, ["claude-design"])
                result = tomllib.loads(path.read_text()) if client == "codex" else json.loads(path.read_text())
                names = set(result["mcp_servers" if client == "codex" else "mcpServers"])
                self.assertEqual(names, set(inventory) | {"custom"})

    def test_codex_env_var_tables_and_other_transport_keys_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.toml"
            import tomli_w
            path.write_text(tomli_w.dumps({"mcp_servers": {
                "context7": {"url": "https://old.test", "bearer_token_env_var": "CONTEXT7_API_KEY",
                             "http_headers": {"CONTEXT7_API_KEY": "fixture"},
                             "env_vars": [{"name": "CONTEXT7_API_KEY", "source": "local"}, "KEEP"]},
                "perplexity-computer": {"command": "old", "args": ["x"], "env": {"TOKEN": "fixture"}},
            }}))
            sync.sync("codex", path, INVENTORY)
            servers = tomllib.loads(path.read_text())["mcp_servers"]
            self.assertEqual(servers["context7"]["env_vars"], ["KEEP"])
            for key in ["url", "bearer_token_env_var", "http_headers"]:
                self.assertNotIn(key, servers["context7"])
            self.assertEqual(servers["perplexity-computer"], {"url": "https://example.test/perplexity"})

    def test_mode_narrowed_even_when_already_in_sync(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "claude.json"
            sync.sync("claude", path, INVENTORY)
            path.chmod(0o644)
            before = path.read_bytes()
            sync.sync("claude", path, INVENTORY)
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)


class LaunchTests(unittest.TestCase):
    SECRETS = {"CLAUDE_MONITOR_TOKEN": "m", "CONTEXT7_API_KEY": "c", "ELEVENLABS_API_KEY": "e"}

    def run_launcher(self, *argv):
        calls = []
        with tempfile.TemporaryDirectory() as directory, \
                patch.dict(os.environ, {"PATH": "/usr/bin", **self.SECRETS}, clear=True), \
                patch.object(Path, "home", return_value=Path(directory)), \
                patch.object(launch.sys, "argv", ["mcp-launch", *argv]), \
                patch.object(launch.os, "execvpe", lambda file, args, env: calls.append((args, dict(env)))):
            launch.main()
        return calls[0]

    def test_context7_key_only_in_environment(self):
        command, env = self.run_launcher("context7", "/nix/npx")
        self.assertNotIn("--api-key", command)
        self.assertNotIn("c", command)
        self.assertEqual(env["CONTEXT7_API_KEY"], "c")
        self.assertNotIn("CLAUDE_MONITOR_TOKEN", env)
        self.assertNotIn("ELEVENLABS_API_KEY", env)

    def test_elevenlabs_gets_only_its_own_key(self):
        command, env = self.run_launcher("elevenlabs", "/nix/uvx", "/nix/python3")
        self.assertEqual(env["ELEVENLABS_API_KEY"], "e")
        self.assertEqual(env["ELEVENLABS_MCP_BASE_PATH"], "/")
        self.assertNotIn("CONTEXT7_API_KEY", env)
        self.assertNotIn("CLAUDE_MONITOR_TOKEN", env)

    def test_browser_servers_get_no_secrets_and_a_session(self):
        command, env = self.run_launcher("brave", "/nix/npx", "/run/current-system/sw/bin/brave")
        self.assertEqual(command[-2:], ["--executable-path", "/run/current-system/sw/bin/brave"])
        self.assertIn("XDG_RUNTIME_DIR", env)
        self.assertFalse(set(self.SECRETS) & set(env))
        command, env = self.run_launcher("firefox", "/nix/firefox-devtools-mcp", "/run/current-system/sw/bin/firefox-devedition")
        self.assertEqual(command, ["/nix/firefox-devtools-mcp", "--firefoxPath", "/run/current-system/sw/bin/firefox-devedition"])
        self.assertFalse(set(self.SECRETS) & set(env))


class OpenCodeTests(unittest.TestCase):
    def merge(self, config, remove=()):
        defaults = {"schema": "https://opencode.ai/config.json", "remove": list(remove),
                    "servers": {name: ({"type": "local", **server} if "command" in server else {"type": "remote", **server}) for name, server in INVENTORY.items()},
                    "permissions": [{"action": "edit", "resource": "*", "effect": "allow"}],
                    "provider": {"id": "llama-cpp", "model": "llama-cpp/qwen3.6-35b-a3b", "value": {"models": {
                        "qwen3.6-35b-a3b": {"modelID": "qwen3.6-35b-a3b", "limit": {"context": 262144}},
                        "gpt-oss-20b": {"modelID": "gpt-oss-20b", "limit": {"context": 131072}},
                    }}}}
        result = subprocess.run(["jq", "-s", "--argjson", "d", json.dumps(defaults), "-f", str(MODULES / "opencode-merge.jq")],
                                input=json.dumps(config), text=True, capture_output=True, check=True)
        return json.loads(result.stdout)

    def test_legacy_provider_upgraded_without_duplicate_or_permission_override(self):
        source = {"model": "custom/model", "permission": {"edit": "ask"},
                  "mcp": {"elevenlabs": {"type": "local", "command": ["uvx"], "enabled": False}},
                  "provider": {"llama-cpp": {"settings": {"baseURL": "http://custom"}, "models": {
                      "qwen3.6-35b-a3b": {"modelID": "unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS", "limit": {"context": 32768, "output": 2048}},
                  }}}}
        result = self.merge(source)
        self.assertNotIn("providers", result)
        self.assertNotIn("permissions", result)
        self.assertEqual(result["model"], "custom/model")
        self.assertFalse(result["mcp"]["elevenlabs"]["enabled"])
        self.assertNotIn("elevenlabs", result["mcp"]["servers"])
        models = result["provider"]["llama-cpp"]["models"]
        self.assertEqual(models["qwen3.6-35b-a3b"]["limit"], {"context": 262144, "output": 2048})
        self.assertIn("gpt-oss-20b", models)
        self.assertEqual(self.merge(result), result)

    def test_retired_servers_removed_in_both_shapes(self):
        source = {"mcp": {"claude-design": {"type": "remote", "url": "https://old.test"},
                          "servers": {"claude-design": {"type": "remote"}, "custom": {"type": "local"}}}}
        result = self.merge(source, remove=["claude-design"])
        self.assertNotIn("claude-design", result["mcp"])
        self.assertNotIn("claude-design", result["mcp"]["servers"])
        self.assertIn("custom", result["mcp"]["servers"])
        self.assertEqual(self.merge({}, remove=["absent"]), self.merge({}))

    def test_fresh_config_allows_edits_and_has_all_shared_servers(self):
        result = self.merge({})
        self.assertEqual(set(result["mcp"]["servers"]), set(INVENTORY))
        self.assertEqual(result["permissions"][0]["action"], "edit")
        self.assertEqual(result["permissions"][0]["effect"], "allow")


if __name__ == "__main__":
    unittest.main()
