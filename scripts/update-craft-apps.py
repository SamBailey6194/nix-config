#!/usr/bin/env python3
"""Pin the ArtCraft "Craft" apps (storytold/*) to their latest GitHub releases.

Rewrites pkgs/craft-apps/sources.json with, per app, the release version, the
linux-x86_64 AppImage URL and its SRI sha256 hash. The hash comes from the
GitHub releases API `digest` field and is cross-checked against the release's
SHA256SUMS.txt asset when one is published. Nothing is downloaded apart from
the API JSON and SHA256SUMS.txt; the AppImages themselves are fetched by Nix.

Usage:
  scripts/update-craft-apps.py            # rewrite sources.json, print changes
  scripts/update-craft-apps.py --check    # exit 1 if any app is out of date
  GITHUB_TOKEN=... scripts/update-craft-apps.py   # avoid the 60/h API limit

Standard library only.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

OWNER = "storytold"
APPS = (
    "photocraft",
    "vectorcraft",
    "lightcraft",
    "pdfcraft",
    "designcraft",
    "effectcraft",
    "filmcraft",
    "soundcraft",
    "wordcraft",
    "deckcraft",
    "cadcraft",
    "figcraft",
    "gridcraft",
)
SOURCES = Path(__file__).resolve().parents[1] / "pkgs" / "craft-apps" / "sources.json"
API = "https://api.github.com/repos/{owner}/{app}/releases/latest"
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")


class UpdateError(Exception):
    """A release that cannot be pinned safely."""


def hex_to_sri(hex_digest: str) -> str:
    """Convert a hex sha256 digest to Nix's SRI form (sha256-<base64>)."""
    hex_digest = hex_digest.strip().lower()
    if not HEX_SHA256.match(hex_digest):
        raise UpdateError(f"not a sha256 hex digest: {hex_digest!r}")
    return "sha256-" + base64.b64encode(bytes.fromhex(hex_digest)).decode("ascii")


def parse_sha256sums(text: str) -> dict[str, str]:
    """Parse `sha256sum` output ("<hex>  <name>" or "<hex> *<name>")."""
    sums: dict[str, str] = {}
    for line in text.splitlines():
        parts = line.strip().split(maxsplit=1)
        if len(parts) != 2 or not HEX_SHA256.match(parts[0].lower()):
            continue
        name = parts[1].lstrip("*").strip()
        sums[Path(name).name] = parts[0].lower()
    return sums


def asset_name(app: str, version: str) -> str:
    return f"{app}-{version}-linux-x86_64.AppImage"


def pick_entry(app: str, release: dict, sums_text: str | None) -> dict[str, str]:
    """Build the sources.json entry for one app from its release JSON."""
    tag = release.get("tag_name") or ""
    if not tag.startswith("v") or len(tag) < 2:
        raise UpdateError(f"{app}: unexpected tag {tag!r} (want v<version>)")
    version = tag[1:]
    wanted = asset_name(app, version)
    assets = {a.get("name"): a for a in release.get("assets", [])}
    asset = assets.get(wanted)
    if asset is None:
        raise UpdateError(f"{app}: release {tag} has no {wanted}")
    digest = asset.get("digest") or ""
    algo, _, hex_digest = digest.partition(":")
    if algo != "sha256" or not hex_digest:
        raise UpdateError(f"{app}: {wanted} has no sha256 digest in the API ({digest!r})")
    hex_digest = hex_digest.lower()
    if sums_text is not None:
        listed = parse_sha256sums(sums_text).get(wanted)
        if listed is None:
            raise UpdateError(f"{app}: SHA256SUMS.txt does not list {wanted}")
        if listed != hex_digest:
            raise UpdateError(
                f"{app}: digest mismatch for {wanted}: API {hex_digest}, SHA256SUMS.txt {listed}"
            )
    url = asset.get("browser_download_url") or (
        f"https://github.com/{OWNER}/{app}/releases/download/{tag}/{wanted}"
    )
    return {"version": version, "url": url, "hash": hex_to_sri(hex_digest)}


def sums_url(release: dict) -> str | None:
    for asset in release.get("assets", []):
        if asset.get("name") == "SHA256SUMS.txt":
            return asset.get("browser_download_url")
    return None


def render(sources: dict[str, dict[str, str]]) -> str:
    """Serialise with a stable key order: apps as in APPS, then version/url/hash."""
    ordered = {}
    for app in [a for a in APPS if a in sources] + sorted(set(sources) - set(APPS)):
        entry = sources[app]
        ordered[app] = {k: entry[k] for k in ("version", "url", "hash")}
    return json.dumps(ordered, indent=2) + "\n"


def summarise(old: dict, new: dict) -> list[str]:
    lines = []
    for app in new:
        before, after = old.get(app), new[app]
        if before is None:
            lines.append(f"{app}: new at {after['version']}")
        elif before.get("version") != after["version"]:
            lines.append(f"{app}: {before.get('version')} -> {after['version']}")
        elif before != after:
            lines.append(f"{app}: {after['version']} (url/hash changed, same version)")
    for app in old:
        if app not in new:
            lines.append(f"{app}: removed")
    return lines


def _request(url: str, token: str | None, accept: str) -> bytes:
    request = urllib.request.Request(url, headers={
        "Accept": accept,
        "User-Agent": "nix-config-update-craft-apps",
    })
    if token:
        # Unredirected: the asset download redirects to a CDN host, which must
        # not receive the token.
        request.add_unredirected_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        raise UpdateError(f"GET {url}: HTTP {error.code} {error.reason}") from error
    except urllib.error.URLError as error:
        raise UpdateError(f"GET {url}: {error.reason}") from error
    except (TimeoutError, OSError) as error:
        # A timeout or reset while reading the body is not wrapped in URLError.
        raise UpdateError(f"GET {url}: {error}") from error


def fetch_entry(app: str, token: str | None) -> dict[str, str]:
    url = API.format(owner=OWNER, app=app)
    try:
        release = json.loads(_request(url, token, "application/vnd.github+json"))
    except ValueError as error:
        raise UpdateError(f"GET {url}: response is not JSON ({error})") from error
    if not isinstance(release, dict) or not isinstance(release.get("assets"), list):
        raise UpdateError(f"{app}: unexpected release JSON from {url}")
    url = sums_url(release)
    sums_text = None
    if url:
        sums_text = _request(url, token, "application/octet-stream").decode("utf-8", "replace")
    return pick_entry(app, release, sums_text)


def load(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
    except FileNotFoundError:
        return {}
    except ValueError:
        # Corrupt or hand-mangled file: treat as empty so a run rewrites it.
        return {}
    return data if isinstance(data, dict) else {}


def main(argv: list[str] | None = None, fetch=fetch_entry) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="exit 1 if sources.json is not at the latest releases; write nothing")
    parser.add_argument("--file", type=Path, default=SOURCES, help="sources.json to update")
    args = parser.parse_args(argv)

    token = os.environ.get("GITHUB_TOKEN") or None
    old = load(args.file)
    try:
        new = {app: fetch(app, token) for app in APPS}
    except UpdateError as error:
        print(f"update-craft-apps: {error}", file=sys.stderr)
        return 2

    changes = summarise(old, new)
    text = render(new)
    if args.check:
        if changes or (args.file.exists() and args.file.read_text() != text):
            for line in changes or ["sources.json formatting differs"]:
                print(f"out of date: {line}")
            return 1
        print("Craft apps are at their latest releases.")
        return 0

    if not args.file.exists() or args.file.read_text() != text:
        args.file.parent.mkdir(parents=True, exist_ok=True)
        args.file.write_text(text)
    for line in changes:
        print(line)
    if not changes:
        print("Craft apps are at their latest releases.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
