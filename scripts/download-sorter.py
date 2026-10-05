#!/usr/bin/env python3
"""Scan, name and route downloads using deterministic rules and local SQLite history."""

import argparse
import fcntl
import fnmatch
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import stat
import subprocess
import sys
import tempfile
import time
import unicodedata


PARTIAL_SUFFIXES = (".part", ".partial", ".crdownload", ".download", ".tmp")


def filename_extension(name):
    extension = Path(name).suffix
    if extension.lower() in (".gz", ".bz2", ".xz", ".zst", ".lz", ".lzma"):
        preceding = Path(name[:-len(extension)]).suffix
        if preceding.lower() == ".tar":
            extension = preceding + extension
    return extension


def kebab_filename(name):
    """Normalise the stem while retaining ordinary and tar archive extensions."""
    hidden = name.startswith(".")
    name = name.lstrip(".") if hidden else name
    extension = filename_extension(name)
    stem = name[:-len(extension)] if extension else name
    stem = unicodedata.normalize("NFC", stem)
    stem = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1-\2", stem)
    stem = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", stem)
    stem = "".join(char if char.isalnum() else "-" for char in stem.lower())
    stem = re.sub("-+", "-", stem).strip("-") or "download"
    return ("." if hidden else "") + stem + extension.lower()


def available_name(destination):
    """Use a numbered kebab-case name when normalisation creates a collision."""
    name = destination.name
    extension = filename_extension(name)
    stem = name[:-len(extension)] if extension else name
    number = 2
    while os.path.lexists(destination):
        destination = destination.with_name(f"{stem}-{number}{extension}")
        number += 1
    return destination


def expand_path(value):
    path = Path(os.path.expandvars(os.path.expanduser(value)))
    if not path.is_absolute():
        raise ValueError(f"Path must be absolute: {value}")
    return path


def fingerprint(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        return None
    return [info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns]


class History:
    def __init__(self, path, readonly=False):
        self.connection = sqlite3.connect(path, uri=readonly)
        self.connection.row_factory = sqlite3.Row
        if readonly:
            return
        self.connection.executescript("""
            CREATE TABLE IF NOT EXISTS files (
                path TEXT PRIMARY KEY, signature TEXT NOT NULL,
                status TEXT NOT NULL, digest TEXT, attempted REAL NOT NULL,
                policy TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY, time REAL NOT NULL, kind TEXT NOT NULL,
                source TEXT NOT NULL, destination TEXT, digest TEXT, detail TEXT
            );
            CREATE TABLE IF NOT EXISTS choices (
                pattern TEXT NOT NULL, digest TEXT NOT NULL, destination TEXT NOT NULL,
                time REAL NOT NULL, PRIMARY KEY (pattern, digest)
            );
            CREATE TABLE IF NOT EXISTS alerts (
                key TEXT PRIMARY KEY, path TEXT NOT NULL, urgency TEXT NOT NULL,
                title TEXT NOT NULL, body TEXT NOT NULL, delivered REAL NOT NULL DEFAULT 0,
                active INTEGER NOT NULL DEFAULT 1
            );
        """)

    def get(self, path):
        return self.connection.execute("SELECT * FROM files WHERE path = ?", (str(path),)).fetchone()

    def remember(self, path, signature, status, digest=None, policy=""):
        with self.connection:
            self.connection.execute("INSERT OR REPLACE INTO files VALUES (?, ?, ?, ?, ?, ?)",
                                    (str(path), json.dumps(signature), status, digest, time.time(), policy))

    def event(self, kind, source, destination=None, digest=None, detail=""):
        with self.connection:
            self.connection.execute(
                "INSERT INTO events(time, kind, source, destination, digest, detail) VALUES (?, ?, ?, ?, ?, ?)",
                (time.time(), kind, str(source), str(destination) if destination else None, digest, detail))

    def alert(self, path, kind, title, body, urgency="critical"):
        key = f"{path}:{kind}"
        with self.connection:
            self.connection.execute("""
                INSERT INTO alerts(key, path, urgency, title, body) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET title=excluded.title, body=excluded.body, active=1,
                    delivered=CASE WHEN excluded.urgency='normal' OR alerts.body != excluded.body
                                   THEN 0 ELSE alerts.delivered END
            """, (key, str(path), urgency, title, body))
        if urgency == "critical":
            print(f"{title}: {body}", file=sys.stderr)

    def clear_alerts(self, path):
        with self.connection:
            self.connection.execute("UPDATE alerts SET active=0 WHERE path=? AND urgency='critical'", (str(path),))

    def issue(self, path, kind, detail, digest=None):
        self.event(kind, path, digest=digest, detail=detail)
        self.alert(path, kind, "Download needs attention", f"{path}\n{detail}")

    def forget(self, path):
        with self.connection:
            self.connection.execute("DELETE FROM files WHERE path=?", (str(path),))
        self.clear_alerts(path)


def validate_settings(settings):
    source = expand_path(settings["source"]).resolve()
    for key, default in (("minimumAge", 120), ("minimumChoices", 5), ("scanTimeout", 300),
                         ("maxSignatureAge", 3), ("maxFileSize", 1024 * 1024 * 1024)):
        value = settings.get(key, default)
        if not isinstance(value, int) or value < (0 if key == "minimumAge" else 1):
            raise ValueError(f"Invalid {key}: {value}")
    rules = []
    for rule in settings.get("rules", []):
        destination = validate_destination(rule["destination"], source)
        if not rule["patterns"] or not all(isinstance(p, str) and p for p in rule["patterns"]):
            raise ValueError("Each rule needs non-empty filename patterns")
        rules.append((rule["patterns"], destination))
    return source, rules


def validate_destination(value, source):
    destination = expand_path(value).resolve()
    if destination == source or source in destination.parents:
        raise ValueError("Routing destinations must be outside the download directory")
    return destination


def matches(pattern, original, normalised):
    return any(fnmatch.fnmatchcase(name.lower(), pattern.lower()) for name in (original, normalised))


def route(path, name, rules, history, settings):
    # Explicit rules are ordered. Learned rules never override them.
    for patterns, destination in rules:
        if any(matches(pattern, path.name, name) for pattern in patterns):
            return destination, "explicit: " + ", ".join(patterns), None
    if not settings.get("learnedRouting", False):
        return None, "", "No routing rule matches this file."
    candidates = set()
    evidence = []
    unresolved = False
    grouped = {}
    for row in history.connection.execute(
            "SELECT pattern, destination, COUNT(*) AS count FROM choices GROUP BY pattern, destination"):
        if matches(row["pattern"], path.name, name):
            grouped.setdefault(row["pattern"], []).append(row)
    for pattern, rows in grouped.items():
        if len(rows) != 1 or rows[0]["count"] < settings.get("minimumChoices", 5):
            unresolved = True
            continue
        candidates.add(rows[0]["destination"])
        evidence.append(pattern)
    if unresolved or len(candidates) != 1:
        return None, "", "Routing evidence is missing, insufficient, or conflicting. Record a choice or add an explicit rule."
    destination = validate_destination(candidates.pop(), expand_path(settings["source"]).resolve())
    return destination, "recorded choices: " + ", ".join(evidence), None


def scan_file(path, settings):
    command = [
        settings.get("scanner", "clamscan"), "--stdout",
        "--database=" + settings.get("signatureDirectory", "/var/lib/clamav"),
        "--alert-exceeds-max=yes", "--alert-encrypted=yes", "--scan-archive=yes",
        f"--fail-if-cvd-older-than={settings.get('maxSignatureAge', 3)}",
        f"--max-filesize={settings.get('maxFileSize', 1024 * 1024 * 1024)}",
        "--max-scansize=2048M", "--max-scantime=0", "--", str(path),
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, errors="replace",
                                timeout=settings.get("scanTimeout", 300),
                                env={**os.environ, "LC_ALL": "C"})
    except (OSError, subprocess.TimeoutExpired) as error:
        return "scan_error", f"ClamAV could not complete the scan: {error}"
    detail = (result.stdout + result.stderr).strip()
    # Require an explicit OK result as well as exit 0; skipped scans aren't success.
    known = re.search(r"^Known viruses:\s*(\d+)\s*$", result.stdout, re.MULTILINE)
    scanned = re.search(r"^Scanned files:\s*(\d+)\s*$", result.stdout, re.MULTILINE)
    if (result.returncode == 0 and known and int(known[1]) > 0 and scanned and int(scanned[1]) == 1
            and any(line.endswith(": OK") for line in result.stdout.splitlines())):
        if "WARNING" not in detail and "ERROR" not in detail:
            return "clean", "ClamAV: no threat detected"
    if result.returncode == 1:
        return "scan_blocked", f"ClamAV detected a threat or cannot inspect the entire file:\n{detail[:3000]}"
    return "scan_error", f"ClamAV did not confirm a completed clean scan (exit {result.returncode}):\n{detail[:3000]}"


def copy_snapshot(source, target, expected):
    digest = hashlib.sha256()
    descriptor = os.open(source, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as incoming:
        info = os.fstat(incoming.fileno())
        actual = [info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns]
        if actual != expected:
            raise OSError("Download changed before copying; waiting for it to settle")
        while chunk := incoming.read(1024 * 1024):
            target.write(chunk)
            digest.update(chunk)
    target.flush()
    os.fsync(target.fileno())
    if fingerprint(source) != expected:
        raise OSError("Download changed while copying; no file was processed")
    return digest.hexdigest()


def process_file(path, signature, destination, rule, uncertainty, history, settings, cached):
    policy = scan_policy(settings)
    # Stage in a private directory outside Downloads. Scan these exact bytes,
    # then publish the same snapshot (or a hash-verified copy on another disk).
    staging = Path(settings["staging"])
    staging.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(dir=staging, suffix=filename_extension(path.name)) as snapshot:
        digest = copy_snapshot(path, snapshot, signature)
        if cached and cached["digest"] == digest:
            status, detail = "clean", "Previously scanned, unchanged content"
        else:
            status, detail = scan_file(Path(snapshot.name), settings)
            if status == "clean":
                history.event(status, path, digest=digest, detail=detail)
        if fingerprint(path) != signature:
            raise OSError("Download changed during scanning; rename and routing were stopped")
        history.remember(path, signature, status, digest, policy)
        if status != "clean":
            history.issue(path, status, detail, digest)
            return
        history.clear_alerts(path)
        if destination != path:
            # Avoid silently filing into an unmounted or misspelled destination.
            if not destination.parent.is_dir():
                raise OSError(f"Destination folder is unavailable: {destination.parent}")
            if path.name != destination.name:
                destination = available_name(destination)
            if os.path.lexists(destination):
                raise FileExistsError(f"Destination already exists: {destination}")
            with tempfile.NamedTemporaryFile(prefix=".download-sorter-", dir=destination.parent) as published:
                snapshot.seek(0)
                shutil.copyfileobj(snapshot, published)
                published.flush()
                os.fsync(published.fileno())
                with open(published.name, "rb") as copied:
                    if hashlib.file_digest(copied, "sha256").hexdigest() != digest:
                        raise OSError("Copied bytes do not match the scanned file")
                # Preserve timestamps and only ordinary read/write permission bits.
                os.chmod(published.name, path.stat().st_mode & 0o666)
                os.utime(published.name, ns=(path.stat().st_atime_ns, signature[3]))
                if fingerprint(path) != signature:
                    raise OSError("Download changed before publishing; processing stopped")
                os.link(published.name, destination)
                history.event("published", path, destination, digest, rule)
                if fingerprint(path) != signature:
                    raise OSError(f"Source changed after publishing; both copies retained at {path} and {destination}")
                path.unlink()
            moved = destination.parent != path.parent
            history.event("move" if moved else "rename", path, destination, digest, rule)
            history.forget(path)
            if moved:
                print(f"Moved: {path} -> {destination}")
                history.alert(destination, f"move:{digest}", "Download moved", str(destination), "normal")
            else:
                history.remember(destination, fingerprint(destination), "clean", digest, policy)
            path = destination
        if uncertainty:
            history.issue(path, "routing_uncertain", uncertainty, digest)


def scan_policy(settings):
    values = {key: settings.get(key) for key in
              ("scanner", "signatureDirectory", "maxSignatureAge", "maxFileSize", "scanTimeout")}
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()


def download_files(source):
    if not source.exists():
        return
    for folder, directories, files in os.walk(source, followlinks=False):
        directories[:] = sorted(name for name in directories
                                if not (Path(folder) / name).is_symlink()
                                and not name.lower().endswith(PARTIAL_SUFFIXES))
        for name in sorted(files):
            if name.lower().endswith(PARTIAL_SUFFIXES) or name.startswith(".download-sorter-"):
                continue
            path = Path(folder) / name
            if any(os.path.lexists(str(path) + suffix) for suffix in PARTIAL_SUFFIXES):
                continue
            yield path


def sort_downloads(settings, history=None, dry_run=False, rename_only=False, retry=False):
    source, rules = validate_settings(settings)
    policy = scan_policy(settings)
    for path in download_files(source):
        try:
            signature = fingerprint(path)
            if signature is None:
                continue
            name = kebab_filename(path.name) if settings.get("normalizeNames", True) else path.name
            folder, rule, uncertainty = (None, "", None) if rename_only else route(path, name, rules, history, settings)
            if folder and not folder.is_dir():
                uncertainty = f"Destination folder is unavailable: {folder}. File retained in Downloads."
                folder = None
            destination = (folder or path.parent) / name
            if dry_run:
                if time.time() - signature[3] / 1e9 >= settings.get("minimumAge", 120):
                    print(f"Would scan: {path}; then {destination}" + (f"; needs attention: {uncertainty}" if uncertainty else ""))
                continue
            row = history.get(path)
            same = row and row["signature"] == json.dumps(signature)
            if not same:
                history.clear_alerts(path)
                history.remember(path, signature, "waiting")
                continue
            if time.time() - signature[3] / 1e9 < settings.get("minimumAge", 120):
                continue
            if not retry and row["status"] in ("scan_error", "scan_blocked") and time.time() - row["attempted"] < 300:
                continue
            cached = row if same and row["status"] == "clean" and row["policy"] == policy and not retry else None
            if cached and destination == path:
                history.clear_alerts(path)
                if uncertainty:
                    # Avoid growing history every minute for the same uncertainty.
                    history.alert(path, "routing_uncertain", "Download needs attention", f"{path}\n{uncertainty}")
                continue
            if signature[2] > settings.get("maxFileSize", 1024 * 1024 * 1024):
                detail = "File exceeds the configured ClamAV scan size limit; processing stopped."
                history.remember(path, signature, "scan_blocked", policy=policy)
                history.issue(path, "scan_blocked", detail)
                continue
            process_file(path, signature, destination, rule, uncertainty, history, settings, cached)
        except OSError as error:
            if dry_run:
                print(f"Cannot process {path}: {error}", file=sys.stderr)
            else:
                history.issue(path, "processing_error", str(error))


def send_notification(row, settings):
    try:
        subprocess.run([
            settings.get("notifier", "notify-send"), "--app-name=download-sorter",
            f"--urgency={row['urgency']}", "--expire-time=0" if row["urgency"] == "critical" else "--expire-time=10000",
            "--hint=string:x-dunst-stack-tag:" + hashlib.sha256(row["key"].encode()).hexdigest(),
            "--", row["title"], html.escape(row["body"]),
        ], check=True, timeout=10, capture_output=True)
        if row["urgency"] == "critical" and settings.get("alertSound"):
            try:
                subprocess.run([settings.get("soundPlayer", "paplay"), settings["alertSound"]],
                               check=True, timeout=5, capture_output=True)
            except (OSError, subprocess.SubprocessError) as error:
                print(f"Alert sound failed; desktop notification delivered: {error}", file=sys.stderr)
        return True
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Desktop notification failed (will retry): {error}\n{row['body']}", file=sys.stderr)
        return False


def deliver_alerts(history, settings):
    failed = False
    for row in history.connection.execute("""
        SELECT * FROM alerts WHERE active=1 AND
        (delivered=0 OR (urgency='critical' AND delivered < ?))
    """, (time.time() - 3600,)).fetchall():
        if send_notification(row, settings):
            with history.connection:
                history.connection.execute("UPDATE alerts SET delivered=? WHERE key=?", (time.time(), row["key"]))
        else:
            failed = True
    return not failed


def record_choice(history, file, pattern, settings):
    source, _ = validate_settings(settings)
    file = expand_path(str(file)).absolute()
    if fingerprint(file) is None:
        raise ValueError("Record a choice using a regular file, not a symlink")
    destination = validate_destination(str(file.parent), source)
    if not matches(pattern, file.name, kebab_filename(file.name)):
        raise ValueError("The supplied pattern does not match this file")
    signature = fingerprint(file)
    with file.open("rb") as incoming:
        digest = hashlib.file_digest(incoming, "sha256").hexdigest()
    if fingerprint(file) != signature:
        raise ValueError("File changed while recording the choice")
    if not history.connection.execute("SELECT 1 FROM events WHERE kind='clean' AND digest=?", (digest,)).fetchone():
        raise ValueError("Only a previously ClamAV-scanned download can be recorded as a routing choice")
    with history.connection:
        history.connection.execute("INSERT OR REPLACE INTO choices VALUES (?, ?, ?, ?)",
                                   (pattern.lower(), digest, str(destination), time.time()))
    history.event("choice", file, destination, digest, pattern.lower())
    print(f"Recorded choice: {pattern.lower()} -> {destination}")


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true", help="Preview only; does not scan or change files")
    parser.add_argument("--rename-only", action="store_true", help="Scan and rename without routing")
    parser.add_argument("--scan-only", action="store_true", help="Scan without renaming or routing")
    parser.add_argument("--retry", action="store_true", help="Rescan settled files, including blocked downloads")
    parser.add_argument("--history", action="store_true", help="Show the last 50 recorded events")
    parser.add_argument("--issues", action="store_true", help="Show active critical alerts")
    parser.add_argument("--record-choice", type=Path, help="Record where you manually filed a previously scanned download")
    parser.add_argument("--pattern", help="Filename glob for --record-choice")
    parser.add_argument("--state", type=Path, default=Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "download-sorter/history.sqlite3")
    args = parser.parse_args()
    history = None
    settings = {}
    try:
        settings = json.loads(args.config.read_text())
        validate_settings(settings)
        args.state = args.state.resolve()
        source = expand_path(settings["source"]).resolve()
        if args.state == source or source in args.state.parents:
            raise ValueError("SQLite state and staging must be outside the download directory")
        settings["staging"] = str(args.state.parent / "staging")
        if args.scan_only:
            args.rename_only = True
            settings["normalizeNames"] = False
        if args.dry_run:
            # Existing evidence may be read; preview never creates persistent state.
            if args.state.exists():
                history = History(args.state.resolve().as_uri() + "?mode=ro", readonly=True)
            else:
                history = History(":memory:")
            sort_downloads(settings, history, dry_run=True, rename_only=args.rename_only)
            return 0
        args.state.parent.mkdir(parents=True, exist_ok=True)
        with args.state.with_suffix(".lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            history = History(args.state)
            if args.history:
                for row in history.connection.execute("SELECT * FROM events ORDER BY id DESC LIMIT 50"):
                    print(json.dumps(dict(row)))
                return 0
            if args.issues:
                for row in history.connection.execute("SELECT * FROM alerts WHERE active=1 AND urgency='critical'"):
                    print(f"{row['title']}: {row['body']}")
                return 0
            if args.record_choice:
                if not args.pattern:
                    raise ValueError("--record-choice requires --pattern")
                record_choice(history, args.record_choice, args.pattern, settings)
                return 0
            sort_downloads(settings, history, rename_only=args.rename_only, retry=args.retry)
            # Retain the audit trail while retiring observations of removed files.
            for row in history.connection.execute("SELECT path FROM files").fetchall():
                if not os.path.lexists(row["path"]):
                    history.forget(Path(row["path"]))
            return 0 if deliver_alerts(history, settings) else 1
    except (OSError, ValueError, sqlite3.Error, KeyError, TypeError) as error:
        print(f"Download automation failed: {error}", file=sys.stderr)
        send_notification({"key": "automation-failed", "title": "Download automation failed",
                           "body": str(error), "urgency": "critical"}, settings)
        return 1
    finally:
        if history:
            history.connection.close()


if __name__ == "__main__":
    sys.exit(main())
