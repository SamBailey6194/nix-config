import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "update_craft_apps", Path(__file__).parents[1] / "update-craft-apps.py"
)
craft = importlib.util.module_from_spec(spec)
spec.loader.exec_module(craft)

# PhotoCraft 0.7.0's real AppImage digest, as served by the releases API.
PHOTO_HEX = "87ebce36bcdf6b31d16a9ca22ce29f9ad8db68185e4d98118800d1c2de78ac42"
PHOTO_SRI = "sha256-h+vONrzfazHRapyiLOKfmtjbaBheTZgRiADRwt54rEI="
OTHER_HEX = "0" * 64


def release(app, version, digest=None, extra_assets=()):
    name = f"{app}-{version}-linux-x86_64.AppImage"
    base = f"https://github.com/storytold/{app}/releases/download/v{version}"
    assets = [
        {"name": f"{app}-{version}-linux-aarch64.AppImage", "digest": f"sha256:{OTHER_HEX}",
         "browser_download_url": f"{base}/{app}-{version}-linux-aarch64.AppImage"},
        {"name": f"{name}.zsync", "digest": f"sha256:{OTHER_HEX}",
         "browser_download_url": f"{base}/{name}.zsync"},
        {"name": name, "digest": digest if digest is not None else f"sha256:{PHOTO_HEX}",
         "browser_download_url": f"{base}/{name}"},
        {"name": "SHA256SUMS.txt", "digest": f"sha256:{OTHER_HEX}",
         "browser_download_url": f"{base}/SHA256SUMS.txt"},
        *extra_assets,
    ]
    return {"tag_name": f"v{version}", "assets": assets}


def sums(app, version, hex_digest=PHOTO_HEX):
    return (
        f"{OTHER_HEX}  {app}-{version}-linux-aarch64.AppImage\n"
        f"{hex_digest} *{app}-{version}-linux-x86_64.AppImage\n"
        "not a checksum line\n"
    )


def entry(app, version):
    return {
        "version": version,
        "url": f"https://github.com/storytold/{app}/releases/download/v{version}/"
               f"{app}-{version}-linux-x86_64.AppImage",
        "hash": PHOTO_SRI,
    }


class ConversionTests(unittest.TestCase):
    def test_hex_to_sri(self):
        self.assertEqual(craft.hex_to_sri(PHOTO_HEX), PHOTO_SRI)
        self.assertEqual(craft.hex_to_sri(PHOTO_HEX.upper()), PHOTO_SRI)

    def test_hex_to_sri_rejects_non_sha256(self):
        for bad in ["", "abc", "g" * 64, PHOTO_HEX + "00"]:
            with self.subTest(bad=bad), self.assertRaises(craft.UpdateError):
                craft.hex_to_sri(bad)

    def test_parse_sha256sums_handles_binary_marker_and_junk(self):
        parsed = craft.parse_sha256sums(sums("photocraft", "0.7.0"))
        self.assertEqual(parsed["photocraft-0.7.0-linux-x86_64.AppImage"], PHOTO_HEX)
        self.assertEqual(len(parsed), 2)


class PickEntryTests(unittest.TestCase):
    def test_picks_x86_64_appimage_and_cross_checks_sums(self):
        got = craft.pick_entry("photocraft", release("photocraft", "0.7.0"),
                               sums("photocraft", "0.7.0"))
        self.assertEqual(got, entry("photocraft", "0.7.0"))

    def test_without_sums_file_uses_api_digest(self):
        got = craft.pick_entry("photocraft", release("photocraft", "0.7.0"), None)
        self.assertEqual(got["hash"], PHOTO_SRI)

    def test_mismatch_between_api_and_sums_is_an_error(self):
        with self.assertRaisesRegex(craft.UpdateError, "mismatch"):
            craft.pick_entry("photocraft", release("photocraft", "0.7.0"),
                             sums("photocraft", "0.7.0", OTHER_HEX))

    def test_sums_file_missing_the_asset_is_an_error(self):
        with self.assertRaisesRegex(craft.UpdateError, "does not list"):
            craft.pick_entry("photocraft", release("photocraft", "0.7.0"), "")

    def test_missing_digest_or_asset_or_bad_tag_is_an_error(self):
        cases = {
            "no sha256 digest": release("photocraft", "0.7.0", digest=""),
            "has no": {"tag_name": "v0.7.0", "assets": []},
            "unexpected tag": {"tag_name": "0.7.0", "assets": []},
        }
        for message, rel in cases.items():
            with self.subTest(message=message), self.assertRaisesRegex(craft.UpdateError, message):
                craft.pick_entry("photocraft", rel, None)

    def test_sums_url(self):
        self.assertTrue(craft.sums_url(release("photocraft", "0.7.0")).endswith("/SHA256SUMS.txt"))
        self.assertIsNone(craft.sums_url({"assets": []}))


class RenderTests(unittest.TestCase):
    def test_render_orders_apps_and_keys_with_trailing_newline(self):
        sources = {
            app: {"hash": PHOTO_SRI, "url": "u", "version": "1"} for app in reversed(craft.APPS)
        }
        text = craft.render(sources)
        self.assertTrue(text.endswith("}\n"))
        data = json.loads(text)
        self.assertEqual(list(data), list(craft.APPS))
        self.assertEqual(list(data["photocraft"]), ["version", "url", "hash"])

    def test_summarise(self):
        old = {"photocraft": entry("photocraft", "0.6.0"), "gone": entry("gone", "1")}
        new = {"photocraft": entry("photocraft", "0.7.0"), "filmcraft": entry("filmcraft", "0.6.0")}
        self.assertEqual(craft.summarise(old, new), [
            "photocraft: 0.6.0 -> 0.7.0", "filmcraft: new at 0.6.0", "gone: removed",
        ])


class MainTests(unittest.TestCase):
    def setUp(self):
        self.versions = {app: "1.0.0" for app in craft.APPS}

    def fake_fetch(self, app, token):
        return entry(app, self.versions[app])

    def run_main(self, path, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = craft.main(["--file", str(path), *args], fetch=self.fake_fetch)
        return code, out.getvalue()

    def test_writes_then_check_passes_then_detects_new_release(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sources.json"
            code, out = self.run_main(path)
            self.assertEqual(code, 0)
            self.assertIn("photocraft: new at 1.0.0", out)
            written = path.read_text()
            self.assertEqual(list(json.loads(written)), list(craft.APPS))

            self.assertEqual(self.run_main(path, "--check")[0], 0)

            self.versions["filmcraft"] = "1.1.0"
            code, out = self.run_main(path, "--check")
            self.assertEqual(code, 1)
            self.assertIn("filmcraft: 1.0.0 -> 1.1.0", out)
            self.assertEqual(path.read_text(), written, "--check must not write")

            code, out = self.run_main(path)
            self.assertEqual((code, out.strip()), (0, "filmcraft: 1.0.0 -> 1.1.0"))
            self.assertEqual(json.loads(path.read_text())["filmcraft"]["version"], "1.1.0")

    def test_fetch_error_leaves_file_untouched(self):
        def failing(app, token):
            raise craft.UpdateError(f"{app}: boom")

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sources.json"
            path.write_text("{}\n")
            with contextlib.redirect_stderr(io.StringIO()):
                code = craft.main(["--file", str(path)], fetch=failing)
            self.assertEqual(code, 2)
            self.assertEqual(path.read_text(), "{}\n")

    def test_network_and_bad_json_failures_become_update_errors(self):
        original = craft._request
        try:
            def timeout(url, token, accept):
                raise craft.UpdateError(f"GET {url}: timed out")

            craft._request = timeout
            with self.assertRaises(craft.UpdateError):
                craft.fetch_entry("photocraft", None)

            craft._request = lambda url, token, accept: b"<html>rate limited</html>"
            with self.assertRaisesRegex(craft.UpdateError, "not JSON"):
                craft.fetch_entry("photocraft", None)

            craft._request = lambda url, token, accept: b'{"message": "Not Found"}'
            with self.assertRaisesRegex(craft.UpdateError, "unexpected release JSON"):
                craft.fetch_entry("photocraft", None)
        finally:
            craft._request = original

    def test_request_wraps_socket_timeouts(self):
        import urllib.request

        original = urllib.request.urlopen

        def raising(*args, **kwargs):
            raise TimeoutError("read timed out")

        urllib.request.urlopen = raising
        try:
            with self.assertRaisesRegex(craft.UpdateError, "timed out"):
                craft._request("https://example.invalid/", None, "application/json")
        finally:
            urllib.request.urlopen = original

    def test_corrupt_sources_file_is_treated_as_empty(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sources.json"
            path.write_text("{not json")
            self.assertEqual(craft.load(path), {})
            path.write_text("[]")
            self.assertEqual(craft.load(path), {})

    def test_repository_sources_cover_every_app_in_sri_form(self):
        data = json.loads(craft.SOURCES.read_text())
        self.assertEqual(list(data), list(craft.APPS))
        for app, item in data.items():
            with self.subTest(app=app):
                self.assertTrue(item["hash"].startswith("sha256-"))
                self.assertTrue(item["url"].endswith(craft.asset_name(app, item["version"])))
                self.assertIn(f"/download/v{item['version']}/", item["url"])


if __name__ == "__main__":
    unittest.main()
