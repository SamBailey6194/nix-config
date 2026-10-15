"""Run with the Nix Python tomli-w environment; all fixtures are temporary."""
import contextlib
import importlib.util
import io
import json
import os
import re
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

BASE = "/home/fixture"
INVENTORY = {
    "elevenlabs": {"command": ["/nix/server", "elevenlabs", "/nix/uvx", "/nix/python3", BASE],
                   "env": {"ELEVENLABS_MCP_BASE_PATH": BASE}},
    "context7": {"command": ["/nix/server", "context7", "/nix/npx"]},
    "mcp-mermaid": {"command": ["/nix/server", "mermaid", "/nix/node"]},
    "scrapling": {"command": ["/nix/server", "scrapling", "/nix/uvx", "/nix/python3", "1.63.0"]},
    "playwright": {"command": ["/nix/server", "playwright", "/nix/playwright-mcp"]},
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
                # Each client's own env shape: a JSON object, or a Codex TOML table.
                self.assertEqual(servers["elevenlabs"]["env"], {"ELEVENLABS_MCP_BASE_PATH": BASE})
                self.assertEqual(servers["elevenlabs"]["args"][-1], BASE)
                self.assertNotIn("env", servers["context7"])
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
            # The base path is declared in the inventory, never captured.
            self.assertNotIn("ELEVENLABS_MCP_BASE_PATH", json.loads(credentials.read_text()))
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
            self.assertEqual(servers["elevenlabs"]["env"], {"ELEVENLABS_MCP_BASE_PATH": BASE})
            self.assertEqual(servers["custom"]["env"], {"CONTEXT7_API_KEY": "fixture"})

    def test_manual_elevenlabs_entry_restored_in_every_client(self):
        # As `claude mcp add --env ELEVENLABS_API_KEY="$UNSET" --env
        # ELEVENLABS_MCP_BASE_PATH=... elevenlabs -- uvx elevenlabs-mcp` leaves it.
        manual = {"type": "stdio", "command": "uvx", "args": ["elevenlabs-mcp"],
                  "env": {"ELEVENLABS_API_KEY": "", "ELEVENLABS_MCP_BASE_PATH": "/elsewhere", "KEEP": "1"},
                  "env_vars": ["ELEVENLABS_MCP_BASE_PATH", "ELEVENLABS_API_KEY", "OTHER"]}
        with tempfile.TemporaryDirectory() as directory:
            for client in ["claude", "codex", "antigravity"]:
                path = Path(directory) / client
                servers = {"elevenlabs": dict(manual, env=dict(manual["env"]), env_vars=list(manual["env_vars"])),
                           "custom": {"command": "custom", "env": {"ELEVENLABS_MCP_BASE_PATH": "/custom"}}}
                if client == "codex":
                    import tomli_w
                    path.write_text(tomli_w.dumps({"mcp_servers": servers}))
                else:
                    path.write_text(json.dumps({"mcpServers": servers}))
                sync.sync(client, path, INVENTORY)
                result = tomllib.loads(path.read_text()) if client == "codex" else json.loads(path.read_text())
                servers = result["mcp_servers" if client == "codex" else "mcpServers"]
                entry = servers["elevenlabs"]
                self.assertEqual([entry["command"], *entry["args"]], INVENTORY["elevenlabs"]["command"])
                self.assertEqual(entry["env"], {"ELEVENLABS_MCP_BASE_PATH": BASE, "KEEP": "1"})
                self.assertEqual(entry["env_vars"], ["OTHER"])
                self.assertEqual(servers["custom"], {"command": "custom", "env": {"ELEVENLABS_MCP_BASE_PATH": "/custom"}})
                if client == "claude":
                    self.assertEqual(entry["type"], "stdio")

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

    def test_empty_config_dir_variable_means_home_not_working_directory(self):
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as cwd:
            inventory = Path(home) / "inventory.json"
            inventory.write_text(json.dumps(INVENTORY))
            env = {"CLAUDE_CONFIG_DIR": "", "CODEX_HOME": ""}
            previous = os.getcwd()
            os.chdir(cwd)
            try:
                with patch.dict(os.environ, env), patch.object(sync.Path, "home", return_value=Path(home)), \
                        patch.object(sync, "capture_credentials"), \
                        patch("sys.argv", ["mcp-sync", "claude", str(inventory)]):
                    sync.main()
            finally:
                os.chdir(previous)
            self.assertTrue((Path(home) / ".claude.json").exists())
            self.assertEqual(list(Path(cwd).iterdir()), [])

    def test_failure_warning_names_client_and_reason_without_contents(self):
        with tempfile.TemporaryDirectory() as home:
            inventory = Path(home) / "inventory.json"
            inventory.write_text(json.dumps(INVENTORY))
            config = Path(home) / ".gemini/config/mcp_config.json"
            config.parent.mkdir(parents=True)
            config.write_text('{"mcpServers": {"x": {"env": {"KEY": "fixture-secret"}}')
            stderr = io.StringIO()
            with patch.object(sync.Path, "home", return_value=Path(home)), \
                    patch.object(sync, "capture_credentials"), \
                    patch("sys.argv", ["mcp-sync", "antigravity", str(inventory)]), \
                    contextlib.redirect_stderr(stderr):
                self.assertEqual(sync.main(), 1)
            message = stderr.getvalue()
            self.assertIn("warning: shared MCP servers not registered for antigravity", message)
            self.assertIn("JSONDecodeError", message)
            self.assertIn("line 1", message)
            self.assertNotIn("fixture-secret", message)
            self.assertNotIn("fixture-secret", sync.describe(sync.tomllib.TOMLDecodeError("x", "a = fixture-secret", 4)))
            self.assertIn("Permission denied", sync.describe(PermissionError(13, "Permission denied", "/fixture")))


class LaunchTests(unittest.TestCase):
    SECRETS = {"CLAUDE_MONITOR_TOKEN": "m", "CONTEXT7_API_KEY": "c", "ELEVENLABS_API_KEY": "e"}

    def run_launcher(self, *argv, credentials=None, agenix=None, environ=None):
        calls = []
        with tempfile.TemporaryDirectory() as directory, \
                patch.dict(os.environ, {"PATH": "/usr/bin", **self.SECRETS, **(environ or {})}, clear=True), \
                patch.object(Path, "home", return_value=Path(directory)), \
                patch.object(launch, "AGENIX_SECRETS", Path(directory) / "claude-secrets"), \
                patch.object(launch.sys, "argv", ["mcp-launch", *argv]), \
                patch.object(launch.os, "execvpe", lambda file, args, env: calls.append((args, dict(env)))):
            if credentials:
                path = Path(directory) / ".config/ai-mcp/credentials.json"
                path.parent.mkdir(parents=True)
                path.write_text(json.dumps(credentials))
            if agenix is not None:
                (Path(directory) / "claude-secrets").write_text(agenix)
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
        command, env = self.run_launcher("elevenlabs", "/nix/uvx", "/nix/python3", BASE)
        self.assertEqual(env["ELEVENLABS_API_KEY"], "e")
        self.assertNotIn("CONTEXT7_API_KEY", env)
        self.assertNotIn("CLAUDE_MONITOR_TOKEN", env)

    def test_elevenlabs_base_path_is_the_declared_argument(self):
        # The agenix secret (sourced into the environment), the credential file
        # and a client's inline env all lose to the inventory's argument.
        with patch.dict(self.SECRETS, {"ELEVENLABS_MCP_BASE_PATH": "/"}):
            command, env = self.run_launcher("elevenlabs", "/nix/uvx", "/nix/python3", "/home/fixture",
                                             credentials={"ELEVENLABS_MCP_BASE_PATH": "/credential"})
        self.assertEqual(env["ELEVENLABS_MCP_BASE_PATH"], "/home/fixture")
        self.assertEqual(command, ["/nix/uvx", "--python", "/nix/python3", "elevenlabs-mcp==0.12.2"])
        self.assertNotIn("ELEVENLABS_MCP_BASE_PATH", self.run_launcher("context7", "/nix/npx")[1])
        with self.assertRaises(SystemExit):
            self.run_launcher("elevenlabs", "/nix/uvx", "/nix/python3")

    def test_blank_inline_key_falls_back_to_credential_file(self):
        with patch.dict(self.SECRETS, {"ELEVENLABS_API_KEY": ""}):
            _, env = self.run_launcher("elevenlabs", "/nix/uvx", "/nix/python3", "/home/fixture",
                                       credentials={"ELEVENLABS_API_KEY": "file"})
        self.assertEqual(env["ELEVENLABS_API_KEY"], "file")

    def test_scrapling_runs_pinned_package_with_bundle_playwright_and_no_secrets(self):
        command, env = self.run_launcher("scrapling", "/nix/uvx", "/nix/python3", "1.63.0")
        self.assertEqual(command, ["/nix/uvx", "--python", "/nix/python3", "--from", "scrapling[ai]==0.4.15",
                                   "--with", "playwright==1.63.0", "scrapling", "mcp"])
        self.assertFalse(set(self.SECRETS) & set(env))
        self.assertNotIn("install", command)
        with self.assertRaises(SystemExit):
            self.run_launcher("scrapling", "/nix/uvx", "/nix/python3")

    def test_scrapling_inventory_entry_uses_wrapped_uvx_and_bundle_version(self):
        # One server name with syntek-media's and syntek-author's project
        # entries; the Playwright pin is read from nixpkgs, never a literal.
        nix = (MODULES / "mcp-servers.nix").read_text()
        entry = next(line for line in nix.splitlines() if line.strip().startswith("scrapling.command"))
        self.assertIn('"scrapling" "${uv}/bin/uvx" "${pkgs.python3}/bin/python3" pkgs.python3Packages.playwright.version', entry)
        self.assertNotIn("clients", entry)
        wrapper = (MODULES.parents[1] / "pkgs/uv-manylinux.nix").read_text()
        pin = re.search(r'patchrightVersion = "(\d+)\.(\d+)\.(\d+)";', wrapper).groups()
        # scrapling 0.4.15[fetchers] requires patchright>=1.62.1.
        self.assertGreaterEqual(tuple(map(int, pin)), (1, 62, 1))

    def test_every_agenix_file_key_removed_unless_the_server_needs_it(self):
        # The wrapper sources the whole file; keys the launcher does not list
        # (TYPESAFE_API_KEY, or one added later) must not reach any server.
        agenix = "CONTEXT7_API_KEY=c\nexport FUTURE_KEY='x=y'\n# NOT_A_KEY=1\nTYPESAFE_API_KEY=t\n"
        extra = {"TYPESAFE_API_KEY": "t", "FUTURE_KEY": "x=y"}
        for argv in (("scrapling", "/nix/uvx", "/nix/python3", "1.63.0"), ("playwright", "/nix/playwright-mcp"),
                     ("context7", "/nix/npx"), ("elevenlabs", "/nix/uvx", "/nix/python3", BASE)):
            _, env = self.run_launcher(*argv, agenix=agenix, environ=extra)
            self.assertFalse(set(extra) & set(env), argv[0])
        _, env = self.run_launcher("context7", "/nix/npx", agenix=agenix, environ=extra)
        self.assertEqual(env["CONTEXT7_API_KEY"], "c")
        # Without the file, the listed TypeSafe key is still removed.
        _, env = self.run_launcher("scrapling", "/nix/uvx", "/nix/python3", "1.63.0", environ=extra)
        self.assertNotIn("TYPESAFE_API_KEY", env)
        self.assertEqual(env["FUTURE_KEY"], "x=y")

    def test_playwright_runs_nixpkgs_server_headed_only_with_a_session(self):
        command, env = self.run_launcher("playwright", "/nix/playwright-mcp", environ={"WAYLAND_DISPLAY": "wayland-1"})
        self.assertEqual(command, ["/nix/playwright-mcp"])
        self.assertFalse(set(self.SECRETS) & set(env))
        with patch.object(launch.Path, "glob", side_effect=lambda *_: iter(())):
            command, _ = self.run_launcher("playwright", "/nix/playwright-mcp")
        self.assertEqual(command, ["/nix/playwright-mcp", "--headless"])
        nix = (MODULES / "mcp-servers.nix").read_text()
        entry = next(line for line in nix.splitlines() if line.strip().startswith("playwright.command"))
        self.assertIn('"playwright" "${pkgs.playwright-mcp}/bin/playwright-mcp"', entry)

    def test_browser_servers_get_no_secrets_and_a_session(self):
        command, env = self.run_launcher("brave", "/nix/npx", "/run/current-system/sw/bin/brave")
        self.assertEqual(command[-2:], ["--executable-path", "/run/current-system/sw/bin/brave"])
        self.assertIn("XDG_RUNTIME_DIR", env)
        self.assertFalse(set(self.SECRETS) & set(env))
        command, env = self.run_launcher("firefox", "/nix/firefox-devtools-mcp", "/run/current-system/sw/bin/firefox-devedition")
        self.assertEqual(command, ["/nix/firefox-devtools-mcp", "--firefoxPath", "/run/current-system/sw/bin/firefox-devedition"])
        self.assertFalse(set(self.SECRETS) & set(env))


def opencode_server(server):
    """As opencode.nix renders an inventory entry: `env` becomes `environment`."""
    if "url" in server:
        return {"type": "remote", **server}
    rendered = {"type": "local", "command": server["command"], "timeout": 120000}
    if "env" in server:
        rendered["environment"] = server["env"]
    return rendered


class OpenCodeTests(unittest.TestCase):
    def merge(self, config, remove=()):
        defaults = {"schema": "https://opencode.ai/config.json", "remove": list(remove),
                    "servers": {name: opencode_server(server) for name, server in INVENTORY.items()},
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

    def test_declared_environment_set_and_inline_keys_dropped(self):
        source = {"mcp": {"elevenlabs": {"type": "local", "command": ["uvx", "elevenlabs-mcp"], "environment": {
                              "ELEVENLABS_API_KEY": "", "ELEVENLABS_MCP_BASE_PATH": "/", "KEEP": "1"}},
                          "servers": {"context7": {"type": "local", "environment": {"CONTEXT7_API_KEY": "fixture"}},
                                      "custom": {"type": "local", "environment": {"ELEVENLABS_API_KEY": "fixture"}}}}}
        result = self.merge(source)
        self.assertEqual(result["mcp"]["elevenlabs"]["environment"], {"ELEVENLABS_MCP_BASE_PATH": BASE, "KEEP": "1"})
        self.assertEqual(result["mcp"]["elevenlabs"]["command"], INVENTORY["elevenlabs"]["command"])
        self.assertNotIn("environment", result["mcp"]["servers"]["context7"])
        self.assertEqual(result["mcp"]["servers"]["custom"]["environment"], {"ELEVENLABS_API_KEY": "fixture"})
        self.assertEqual(self.merge({})["mcp"]["servers"]["elevenlabs"]["environment"], {"ELEVENLABS_MCP_BASE_PATH": BASE})
        self.assertEqual(self.merge(result), result)

    def test_fresh_config_allows_edits_and_has_all_shared_servers(self):
        result = self.merge({})
        self.assertEqual(set(result["mcp"]["servers"]), set(INVENTORY))
        self.assertEqual(result["permissions"][0]["action"], "edit")
        self.assertEqual(result["permissions"][0]["effect"], "allow")


AGY_DEFAULTS = {
    "colorScheme": "solarized dark",
    "allow": ["command(git status)", "command(grep)", "command(gh pr view)", "command(gh pr list)",
              "command(gh issue view)", "command(gh search)"],
    "remove": ["command(gh)"],
}


class AntigravitySettingsTests(unittest.TestCase):
    def run_merge(self, path):
        result = subprocess.run(["bash", str(MODULES / "antigravity-settings.sh"), str(path),
                                 json.dumps(AGY_DEFAULTS), str(MODULES / "antigravity-merge.jq")],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0)
        return result.stderr

    def test_broad_gh_replaced_and_everything_else_kept(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            path.write_text(json.dumps({
                "colorScheme": "light", "trustedWorkspaces": ["/fixture/repo"], "other": {"k": 1},
                "permissions": {"allow": ["command(git status)", "command(gh)", "command(gh pr create)", "command(make)"],
                                "deny": ["command(sudo)"], "ask": ["command(rm)"]}}))
            path.chmod(0o644)
            self.assertEqual(self.run_merge(path), "")
            result = json.loads(path.read_text())
            self.assertEqual(result["colorScheme"], "solarized dark")
            self.assertEqual(result["trustedWorkspaces"], ["/fixture/repo"])
            self.assertEqual(result["other"], {"k": 1})
            self.assertEqual(result["permissions"]["deny"], ["command(sudo)"])
            self.assertEqual(result["permissions"]["ask"], ["command(rm)"])
            # Only the exact broad entry goes; user entries keep their order.
            self.assertEqual(result["permissions"]["allow"],
                             ["command(git status)", "command(gh pr create)", "command(make)", "command(grep)",
                              "command(gh pr view)", "command(gh pr list)", "command(gh issue view)", "command(gh search)"])
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            before, inode = path.read_bytes(), path.stat().st_ino
            self.assertEqual(self.run_merge(path), "")
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(path.stat().st_ino, inode)
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_missing_file_and_directory_created_owner_only(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "antigravity-cli/settings.json"
            self.assertEqual(self.run_merge(path), "")
            result = json.loads(path.read_text())
            self.assertEqual(result, {"colorScheme": "solarized dark",
                                      "permissions": {"allow": AGY_DEFAULTS["allow"]}})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_symlink_and_malformed_files_left_alone_with_warning(self):
        with tempfile.TemporaryDirectory() as directory:
            cases = {"invalid": "{not json", "array": "[]", "two": "{}\n{}",
                     "allow-object": json.dumps({"permissions": {"allow": {"x": 1}}}),
                     "permissions-list": json.dumps({"permissions": ["command(gh)"]})}
            for name, text in cases.items():
                path = Path(directory) / name
                path.write_text(text)
                warning = self.run_merge(path)
                self.assertIn("warning: antigravity:", warning, name)
                self.assertEqual(path.read_text(), text, name)
            target = Path(directory) / "target.json"
            target.write_text(json.dumps({"permissions": {"allow": ["command(gh)"]}}))
            link = Path(directory) / "link.json"
            link.symlink_to(target)
            self.assertIn("is a symlink", self.run_merge(link))
            self.assertTrue(link.is_symlink())
            self.assertIn("command(gh)", target.read_text())

    def test_declared_allow_list_is_read_only_gh(self):
        text = (MODULES / "antigravity.nix").read_text()
        block = text[text.index("allow = ["):text.index("];", text.index("allow = ["))]
        for write in ['"api"', '"auth status"', '"pr create"', '"pr merge"', "edit", "close", "delete"]:
            self.assertNotIn(write, block)
        self.assertIn('remove = [ "command(gh)" ]', text)
        self.assertNotIn("ask", text[text.index("defaults = {"):text.index("in\n{")])


FAKE_CLAUDE = """#!/usr/bin/env bash
echo "$*" >> "$CALLS"
case "$1 $2" in
  "plugin list") [ -n "${LIST_FAILS:-}" ] && exit 1; echo '[{"id":"have@m","scope":"user"},{"id":"project@m","scope":"project"}]' ;;
  "plugin install") echo "Installing..."; [ -n "${INSTALL_FAILS:-}" ] && { echo "Failed to update settings: EACCES"; exit 1; }; echo ok ;;
esac
"""


class ClaudePluginTests(unittest.TestCase):
    def run_installer(self, *plugins, **env):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "claude"
            fake.write_text(FAKE_CLAUDE)
            fake.chmod(0o755)
            calls = Path(directory) / "calls"
            calls.touch()
            result = subprocess.run(["bash", str(MODULES / "claude-plugins.sh"), str(fake), *plugins],
                                    env={**os.environ, "CALLS": str(calls), **env}, text=True, capture_output=True)
            return result, calls.read_text().splitlines()

    def test_only_missing_user_plugins_installed(self):
        result, calls = self.run_installer("have@m", "project@m", "new@m")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, ["plugin list --json", "plugin install project@m --scope user",
                                 "plugin install new@m --scope user"])
        self.assertEqual(result.stderr, "")

    def test_install_failure_warns_with_reason_and_does_not_fail(self):
        result, _ = self.run_installer("new@m", "have@m", INSTALL_FAILS="1")
        self.assertEqual(result.returncode, 0)
        self.assertIn("warning: claude plugins: could not install new@m (exit 1): Failed to update settings: EACCES",
                      result.stderr)
        self.assertNotIn("have@m", result.stderr)

    def test_list_failure_warns_and_installs_nothing(self):
        result, calls = self.run_installer("new@m", LIST_FAILS="1")
        self.assertEqual(result.returncode, 0)
        self.assertIn("could not list installed plugins", result.stderr)
        self.assertEqual(calls, ["plugin list --json"])


class ClaudeSettingsTests(unittest.TestCase):
    BASE = json.loads((MODULES.parents[1] / "config/claude/settings-base.json").read_text())

    def test_plugins_and_marketplaces(self):
        self.assertEqual(self.BASE["enabledPlugins"], {"codex@openai-codex": True,
                                                       "lua-lsp@claude-plugins-official": True,
                                                       "pyright-lsp@claude-plugins-official": True})
        self.assertEqual(self.BASE["extraKnownMarketplaces"]["claude-plugins-official"]["source"],
                         {"source": "github", "repo": "anthropics/claude-plugins-official"})
        text = json.dumps(self.BASE)
        for stale in ["syntek-marketplace", "claude-code-plugins", "dnd-dm-planner", "plugin-dev"]:
            self.assertNotIn(stale, text)

    def test_plain_settings_only_in_the_json(self):
        nix = (MODULES / "claude.nix").read_text()
        for key in ["effortLevel", "ultracode", "enableWorkflows", "skipWorkflowUsageWarning",
                    "skipAutoPermissionPrompt", "model =", "ENABLE_LSP_TOOL", "MCP_TIMEOUT"]:
            self.assertNotIn(key, nix)
        self.assertEqual((self.BASE["effortLevel"], self.BASE["ultracode"], self.BASE["enableWorkflows"],
                          self.BASE["skipWorkflowUsageWarning"], self.BASE["skipAutoPermissionPrompt"],
                          self.BASE["model"], self.BASE["env"]),
                         ("xhigh", True, True, True, True, "opus", {"ENABLE_LSP_TOOL": "1", "MCP_TIMEOUT": "120000"}))

    def test_best_effort_activation_steps_warn_instead_of_hiding_failures(self):
        for name in ["claude.nix", "mcp-activation.nix", "antigravity.nix"]:
            text = (MODULES / name).read_text()
            self.assertNotIn("|| true", text, name)
            self.assertIn("warning:", text, name)


class GlobalInstructionsTests(unittest.TestCase):
    """Codex, OpenCode and agy get Claude's two global rules as one file each."""
    NIX = (MODULES / "agent-skills.nix").read_text()
    ROOT = MODULES.parents[1]

    def test_every_client_gets_one_file_from_both_sources(self):
        for source in ["config/claude/rules/context7.md", "config/agents/nix-source-policy.md"]:
            self.assertIn(f"../../{source}", self.NIX)
            self.assertIn(source, self.NIX.split("instructions = ''", 1)[1].split("'';", 1)[0])
        for target in ['"${codexDir}/AGENTS.md".text = instructions;',
                       '"${opencodeDir}/AGENTS.md".text = instructions;',
                       '".gemini/config/AGENTS.md".text = instructions;']:
            self.assertIn(target, self.NIX)
        self.assertIn('envDir "CODEX_HOME" "${homeDir}/.codex"', self.NIX)
        self.assertIn('envDir "OPENCODE_CONFIG_DIR" "${config.xdg.configHome}/opencode"', self.NIX)

    def test_agy_gets_only_one_global_rules_file(self):
        # agy reads AGENTS.md and GEMINI.md in ~/.gemini and ~/.gemini/config;
        # declaring two would load the same rules twice.
        nix = "\n".join(path.read_text() for path in MODULES.glob("*.nix"))
        declared = re.findall(r'"([^"\s]*(?:AGENTS|GEMINI)\.md)"\.(?:text|source)', nix)
        self.assertEqual([d for d in declared if "gemini" in d], [".gemini/config/AGENTS.md"])

    def test_claude_keeps_its_two_rule_files(self):
        self.assertIn('".claude/rules/nix-source.md".source = policy;', self.NIX)
        self.assertIn('".claude/rules/context7.md".source = ../../config/claude/rules/context7.md;',
                      (MODULES / "claude.nix").read_text())

    def test_combined_file_fits_agy_rule_limit(self):
        # agy truncates a rule file over 24,000 bytes (bundled rules guide).
        size = sum((self.ROOT / name).stat().st_size for name in
                   ["config/claude/rules/context7.md", "config/agents/nix-source-policy.md"])
        self.assertLess(size + 400, 24000)


if __name__ == "__main__":
    unittest.main()
