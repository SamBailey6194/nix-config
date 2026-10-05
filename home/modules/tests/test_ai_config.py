"""Run with the Nix Python tomli-w environment; all fixtures are temporary."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch

MODULES = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("mcp_sync", MODULES / "mcp-sync.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

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
            with patch.object(Path, "read_text", read):
                sync.capture_credentials(home)
                sync.sync("claude", path, INVENTORY)
                sync.capture_credentials(home)
            credentials = home / ".config/ai-mcp/credentials.json"
            self.assertEqual(json.loads(credentials.read_text())["ELEVENLABS_API_KEY"], "fixture-eleven")
            self.assertEqual(json.loads(credentials.read_text())["CONTEXT7_API_KEY"], "fixture-context")
            self.assertEqual(credentials.stat().st_mode & 0o777, 0o600)


class OpenCodeTests(unittest.TestCase):
    def merge(self, config):
        defaults = {"schema": "https://opencode.ai/config.json",
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

    def test_fresh_config_allows_edits_and_has_all_shared_servers(self):
        result = self.merge({})
        self.assertEqual(set(result["mcp"]["servers"]), set(INVENTORY))
        self.assertEqual(result["permissions"][0]["action"], "edit")
        self.assertEqual(result["permissions"][0]["effect"], "allow")


if __name__ == "__main__":
    unittest.main()
