#!/usr/bin/env python3
"""Scan, name and route downloads using deterministic rules and local SQLite history."""

import argparse
import errno
import fcntl
import fnmatch
import hashlib
import html
import itertools
import json
import os
from pathlib import Path
import re
import resource
import shlex
import shutil
import signal
import sqlite3
import stat
import struct
import subprocess
import sys
import tempfile
import time
import unicodedata


PARTIAL_SUFFIXES = (".part", ".partial", ".crdownload", ".download", ".tmp")
GIB = 1024 * 1024 * 1024
MIB = 1024 * 1024
# ClamAV 1.5 cannot scan any single file over 2 GiB - 1 byte (it warns and
# clamps larger --max-filesize values). 2047 MiB leaves a 1 MiB safety margin.
CLAMAV_FILE_LIMIT = 2 ** 31 - 1
# Total bytes ClamAV may inspect within one file, including decompressed
# archive members. It is well above the largest permitted input so a maximal
# file is never cut short by this limit; containers that expand further raise
# Heuristics.Limits.Exceeded (blocked by --alert-exceeds-max) rather than being
# silently truncated. 0 (unlimited) would remove the bomb guard entirely.
CLAMAV_SCAN_SIZE = "4095M"
DEFAULTS = {
    "minimumAge": 120, "minimumChoices": 5, "scanTimeout": 300, "maxSignatureAge": 3,
    "maxFileSize": 2047 * MIB, "autoScanCap": 50 * GIB, "chunkSize": GIB,
    # Longer than any ClamAV body (byte-pattern) signature, so a pattern that
    # straddles a chunk boundary is wholly inside the next chunk.
    "chunkOverlap": 16 * MIB, "maxExtractionDepth": 4, "maxExtractedMembers": 100000,
    "extractionRatio": 4, "freeSpaceMargin": 10 * GIB, "scanTimeoutPerGiB": 300,
}
HELD_STATUSES = ("scan_partial", "scan_blocked", "scan_error")
# Hold reasons a user may approve. "threat" additionally requires --force;
# a NULL hold is a transient failure (signatures, timeouts) that needs a retry.
APPROVABLE_HOLDS = ("partial", "oversize", "unscannable")
UNSCANNABLE_SIGNATURES = ("Heuristics.Limits.Exceeded", "Heuristics.Encrypted")
# clamonacc (modules/security/download-antivirus.nix) makes the kernel refuse
# to open a file in ~/Downloads with EPERM when clamd finds a threat in it.
ON_ACCESS_DETAIL = ("ClamAV on-access scanning (clamonacc) refused to open this file because clamd "
                    "found a threat in it. Details: journalctl -u clamav-clamonacc -u clamav-daemon")
# Restored false positives go to a subfolder: clamonacc watches only the top
# of ~/Downloads, so the restored copy can be opened and released by digest.
RESTORED_FOLDER = "Restored"
ARCHIVE_MAGIC = ((0, b"PK\x03\x04"), (0, b"7z\xbc\xaf\x27\x1c"), (0, b"Rar!\x1a\x07"),
                 (0, b"\x1f\x8b"), (0, b"\xfd7zXZ\x00"), (0, b"BZh"), (0, b"\x28\xb5\x2f\xfd"),
                 (0, b"MSCF"), (0, b"xar!"), (0, b"hsqs"), (0, b"070701"), (0, b"070707"),
                 (0, b"!<arch>\n"), (0, b"\xed\xab\xee\xdb"), (0, b"LZIP"), (0, b"\x04\x22\x4d\x18"),
                 (257, b"ustar"), (32769, b"CD001"))


def setting(settings, key):
    return settings.get(key, DEFAULTS[key])


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
            CREATE TABLE IF NOT EXISTS approvals (
                digest TEXT PRIMARY KEY, path TEXT NOT NULL, time REAL NOT NULL,
                previous_status TEXT NOT NULL, hold TEXT, forced INTEGER NOT NULL DEFAULT 0
            );
        """)
        # Databases created before held scans existed lack the hold reason.
        columns = {row["name"] for row in self.connection.execute("PRAGMA table_info(files)")}
        if "hold" not in columns:
            with self.connection:
                self.connection.execute("ALTER TABLE files ADD COLUMN hold TEXT")

    def get(self, path):
        return self.connection.execute("SELECT * FROM files WHERE path = ?", (str(path),)).fetchone()

    def remember(self, path, signature, status, digest=None, policy="", hold=None):
        with self.connection:
            self.connection.execute(
                "INSERT OR REPLACE INTO files(path, signature, status, digest, attempted, policy, hold)"
                " VALUES (?, ?, ?, ?, ?, ?, ?)",
                (str(path), json.dumps(signature), status, digest, time.time(), policy, hold))

    def approved(self, digest):
        return digest is not None and self.connection.execute(
            "SELECT 1 FROM approvals WHERE digest=?", (digest,)).fetchone() is not None

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

    def issue(self, path, kind, detail, digest=None, title="Download needs attention"):
        self.event(kind, path, digest=digest, detail=detail)
        self.alert(path, kind, title, f"{path}\n{detail}")

    def hold(self, path, status, detail, digest, hold):
        """Raise a held-download issue, naming the approval command where it applies."""
        title = "Download needs attention"
        if hold in APPROVABLE_HOLDS:
            detail += f"\nTo release these exact bytes deliberately: download-sorter --approve {shlex.quote(str(path))}"
            title = "Scanned in part — approve to release" if hold == "partial" else "Download held — approve to release"
        self.issue(path, status, detail, digest, title)

    def forget(self, path):
        with self.connection:
            self.connection.execute("DELETE FROM files WHERE path=?", (str(path),))
        self.clear_alerts(path)


def validate_settings(settings):
    source = expand_path(settings["source"]).resolve()
    for key in DEFAULTS:
        value = setting(settings, key)
        if not isinstance(value, int) or value < (0 if key in ("minimumAge", "chunkOverlap", "freeSpaceMargin") else 1):
            raise ValueError(f"Invalid {key}: {value}")
    if setting(settings, "maxFileSize") > CLAMAV_FILE_LIMIT:
        raise ValueError(f"maxFileSize cannot exceed ClamAV's {CLAMAV_FILE_LIMIT}-byte per-file limit")
    if setting(settings, "autoScanCap") < setting(settings, "maxFileSize"):
        raise ValueError("autoScanCap must not be smaller than maxFileSize")
    if not setting(settings, "chunkOverlap") < setting(settings, "chunkSize") <= setting(settings, "maxFileSize"):
        raise ValueError("chunkOverlap must be smaller than chunkSize, which must not exceed maxFileSize")
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


def scan_timeout(settings, size):
    """Allow a fixed base plus time per GiB, so large inputs are not cut short."""
    return setting(settings, "scanTimeout") + setting(settings, "scanTimeoutPerGiB") * -(-size // GIB)


def clamscan(settings, arguments, expected, size):
    """Run clamscan and require an explicit OK for every expected path."""
    command = [
        settings.get("scanner", "clamscan"), "--stdout",
        "--database=" + settings.get("signatureDirectory", "/var/lib/clamav"),
        "--alert-exceeds-max=yes", "--alert-encrypted=yes", "--scan-archive=yes",
        f"--fail-if-cvd-older-than={setting(settings, 'maxSignatureAge')}",
        f"--max-filesize={setting(settings, 'maxFileSize')}",
        f"--max-scansize={CLAMAV_SCAN_SIZE}", "--max-scantime=0", *arguments,
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, errors="replace",
                                timeout=scan_timeout(settings, size), stdin=subprocess.DEVNULL,
                                env={**os.environ, "LC_ALL": "C"})
    except (OSError, subprocess.TimeoutExpired) as error:
        return "scan_error", f"ClamAV could not complete the scan: {error}"
    detail = (result.stdout + result.stderr).strip()
    # Require an explicit OK result as well as exit 0; skipped scans aren't success.
    # ClamAV reports a 0-byte file as "Empty file" and leaves it out of the count.
    known = re.search(r"^Known viruses:\s*(\d+)\s*$", result.stdout, re.MULTILINE)
    scanned = re.search(r"^Scanned files:\s*(\d+)\s*$", result.stdout, re.MULTILINE)
    lines = result.stdout.splitlines()
    ok = {line[:-4] for line in lines if line.endswith(": OK")}
    empty = {line[:-12] for line in lines if line.endswith(": Empty file")} & set(expected)
    if (result.returncode == 0 and known and int(known[1]) > 0 and scanned
            and int(scanned[1]) == len(expected) - len(empty) and set(expected) <= ok | empty):
        if "WARNING" not in detail and "ERROR" not in detail:
            return "clean", "ClamAV: no threat detected"
    # A --file-list scan prints one line per member. Put real detections first
    # so truncation can never hide one behind limit or encryption alerts, which
    # hold_reason() would otherwise classify as merely unscannable.
    lines = detail.splitlines()
    threats = [line for line in lines if line.endswith(" FOUND") and
               not line[:-6].rsplit(" ", 1)[-1].startswith(UNSCANNABLE_SIGNATURES)]
    shown = set(threats)
    detail = "\n".join(threats + [line for line in lines if line not in shown])[:3000]
    if result.returncode == 1:
        return "scan_blocked", f"ClamAV detected a threat or cannot inspect the entire file:\n{detail}"
    return "scan_error", f"ClamAV did not confirm a completed clean scan (exit {result.returncode}):\n{detail}"


def scan_file(path, settings):
    try:
        size = path.stat().st_size
    except OSError:
        size = 0
    return clamscan(settings, ["--", str(path)], [str(path)], size)


def hold_reason(status, detail):
    """Classify a held result: a real detection, an unscannable input, or transient."""
    if status == "scan_error":
        return None
    if status != "scan_blocked":
        return "partial" if status == "scan_partial" else None
    # clamscan() lists real detections first, so a truncated detail keeps them.
    found = re.findall(r"(\S+) FOUND$", detail, re.MULTILINE)
    if found and all(name.startswith(UNSCANNABLE_SIGNATURES) for name in found):
        return "unscannable"
    return "threat"


class Hold(Exception):
    """Stop a layered scan with (status, detail, hold reason)."""


def appended_squashfs_offset(path):
    """Find an AppImage-style SquashFS payload appended to an ELF file without running it.

    The payload starts where the ELF section header table ends
    (e_shoff + e_shentsize * e_shnum), the same rule appimage-exec -x uses.
    """
    with open(path, "rb") as file:
        header = file.read(64)
        if len(header) < 52 or header[:4] != b"\x7fELF" or header[5] not in (1, 2):
            return None
        order = "<" if header[5] == 1 else ">"
        if header[4] == 2 and len(header) == 64:
            shoff, = struct.unpack_from(order + "Q", header, 0x28)
            shentsize, shnum = struct.unpack_from(order + "HH", header, 0x3A)
        elif header[4] == 1:
            shoff, = struct.unpack_from(order + "I", header, 0x20)
            shentsize, shnum = struct.unpack_from(order + "HH", header, 0x2E)
        else:
            return None
        offset = shoff + shentsize * shnum
        if offset <= 0 or offset + 96 > os.fstat(file.fileno()).st_size:
            return None
        file.seek(offset)
        return offset if file.read(4) == b"hsqs" else None


def squashfs_end(path, offset):
    with open(path, "rb") as file:
        file.seek(offset + 40)
        used, = struct.unpack("<Q", file.read(8))
    return offset + used


def looks_like_archive(path):
    with open(path, "rb") as file:
        for position, magic in ARCHIVE_MAGIC:
            file.seek(position)
            if file.read(len(magic)) == magic:
                return True
    return False


def tree_usage(root):
    entries = size = 0
    for folder, directories, files in os.walk(root, followlinks=False):
        entries += len(directories) + len(files)
        for name in files:
            try:
                size += os.lstat(os.path.join(folder, name)).st_size
            except OSError:
                pass
    return entries, size


def collect_members(root):
    """Make extracted entries private and readable without following any link.

    Returns regular files and the non-regular entries that were skipped. chmod
    only touches entries lstat identified as directories or regular files, which
    also clears setuid/setgid and execute bits.
    """
    regular, skipped = [], []
    os.chmod(root, 0o700)
    pending = [root]
    while pending:
        with os.scandir(pending.pop()) as entries:
            for entry in entries:
                info = entry.stat(follow_symlinks=False)
                path = Path(entry.path)
                if stat.S_ISDIR(info.st_mode):
                    os.chmod(path, 0o700)
                    pending.append(path)
                elif stat.S_ISREG(info.st_mode):
                    os.chmod(path, 0o600)
                    regular.append((path, info.st_size))
                else:
                    skipped.append(path)
    return sorted(regular), sorted(skipped)


def remove_tree(root):
    """Remove an extraction directory even when archived modes denied access."""
    if not os.path.lexists(root):
        return
    for folder, directories, _ in os.walk(root, followlinks=False):
        for name in directories:
            path = os.path.join(folder, name)
            if stat.S_ISDIR(os.lstat(path).st_mode):
                os.chmod(path, 0o700)
    shutil.rmtree(root)


def gib(size):
    return f"{size / GIB:.1f} GiB"


def parent_death_signal():
    """Return a preexec hook that kills a tool when this process dies, however it dies.

    Tools run in their own session (no controlling terminal, so no passphrase
    prompt), which also hides them from the terminal's SIGHUP. Without this an
    extractor orphaned by a closed terminal would keep writing into staging
    with no space or entry limits.
    """
    import ctypes

    libc = ctypes.CDLL(None, use_errno=True)
    parent = os.getpid()

    def hook():
        libc.prctl(1, signal.SIGKILL)  # PR_SET_PDEATHSIG
        if os.getppid() != parent:
            os._exit(1)
    return hook


def zip_coverage(path, unpacked, deadline):
    """Return None when a ZIP's entries and directories account for every byte, else why not.

    libarchive reads ZIPs through the central directory, so bytes outside the
    listed entries (appended data, entries missing from the directory) are never
    unpacked. Here the local entries must tile the file from offset 0 to the
    central directory, which must end at its end record, which must end the
    file. Stored data is exactly its range; a deflate stream must end exactly
    at its compressed size, so nothing hides after the stream's end; directory
    entries must be empty. Each entry's decompressed SHA-256 must equal the
    unpacked file (or link target) of that name in `unpacked`, which also shows
    libarchive read the file as this ZIP, not as another format (ISO, tar)
    that the same bytes also happen to form.
    """
    size = path.stat().st_size
    with open(path, "rb") as file:
        def read(offset, length):
            if offset < 0 or length < 0:
                raise ValueError("negative offset")
            file.seek(offset)
            data = file.read(length)
            if len(data) != length:
                raise ValueError("truncated")
            return data

        try:
            tail_start = max(0, size - 22 - 65535)
            tail = read(tail_start, size - tail_start)
            position, end_record = tail.rfind(b"PK\x05\x06"), None
            while position >= 0:
                if position + 22 <= len(tail) and position + 22 + struct.unpack_from("<H", tail, position + 20)[0] == len(tail):
                    end_record = tail_start + position
                    break
                position = tail.rfind(b"PK\x05\x06", 0, position)
            if end_record is None:
                return "no ZIP end record ends the file"
            disk, directory_disk, here, total, directory_size, directory_offset = struct.unpack_from(
                "<HHHHII", tail, end_record - tail_start + 4)
            directory_end = end_record
            if 0xFFFF in (here, total) or 0xFFFFFFFF in (directory_size, directory_offset):
                locator = read(end_record - 20, 20)
                if locator[:4] != b"PK\x06\x07":
                    return "ZIP64 locator is missing"
                record, = struct.unpack_from("<Q", locator, 8)
                head = read(record, 56)
                length, = struct.unpack_from("<Q", head, 4)
                if head[:4] != b"PK\x06\x06" or record + 12 + length != end_record - 20:
                    return "ZIP64 end record does not adjoin its locator"
                disk, directory_disk, here, total, directory_size, directory_offset = struct.unpack_from(
                    "<IIQQQQ", head, 16)
                directory_end = record
            if disk or directory_disk or here != total:
                return "multi-volume ZIP"
            if directory_offset + directory_size != directory_end or directory_size > 256 * MIB:
                return "unexplained bytes around the central directory"
            directory = read(directory_offset, directory_size)
            entries, position = [], 0
            for _ in range(total):
                if directory[position:position + 4] != b"PK\x01\x02":
                    return "malformed central directory"
                flags, method = struct.unpack_from("<HH", directory, position + 8)
                compressed, uncompressed, name_length, extra_length, comment_length, start_disk = \
                    struct.unpack_from("<IIHHHH", directory, position + 20)
                local, = struct.unpack_from("<I", directory, position + 42)
                name = directory[position + 46:position + 46 + name_length]
                extra = directory[position + 46 + name_length:position + 46 + name_length + extra_length]
                position += 46 + name_length + extra_length + comment_length
                if position > len(directory):
                    return "malformed central directory"
                while len(extra) >= 4:
                    kind, length = struct.unpack_from("<HH", extra)
                    if kind == 1:  # ZIP64: 64-bit values only for the saturated 32-bit fields, in this order.
                        values = iter(struct.unpack_from(f"<{length // 8}Q", extra, 4))
                        uncompressed = next(values) if uncompressed == 0xFFFFFFFF else uncompressed
                        compressed = next(values) if compressed == 0xFFFFFFFF else compressed
                        local = next(values) if local == 0xFFFFFFFF else local
                    extra = extra[4 + length:]
                if start_disk not in (0, 0xFFFF):
                    return "multi-volume ZIP"
                entries.append((local, flags, method, compressed, uncompressed, name))
            if position != len(directory):
                return "unexplained bytes in the central directory"
            seen = set()
            for *_, name in entries:
                text = name.decode("ascii", errors="replace")
                if (not all(0 < byte < 128 for byte in name) or text.startswith("/") or "\\" in text
                        or any(part in ("", ".", "..") for part in text.rstrip("/").split("/"))):
                    return "entry names cannot be matched to unpacked paths"
                if not text.endswith("/"):
                    seen.add(text)
            if len(seen) != sum(1 for *_, name in entries if not name.endswith(b"/")) or seen != set(unpacked):
                return "entries listed in the central directory differ from those unpacked"
            expected, descriptor = 0, False
            for local, flags, method, compressed, uncompressed, name in sorted(entries):
                gap = local - expected
                if gap and not (descriptor and gap in (12, 16, 20, 24)):
                    return f"unexplained bytes at offset {expected}"
                if flags & 1:
                    return "encrypted entries"
                if method not in (0, 8):
                    return f"compression method {method} cannot be verified"
                header = read(local, 30)
                name_length, extra_length = struct.unpack_from("<HH", header, 26)
                if header[:4] != b"PK\x03\x04" or read(local + 30, name_length) != name:
                    return "local entry headers disagree with the central directory"
                start = local + 30 + name_length + extra_length
                digest = entry_digest(file, method, start, compressed, deadline)
                text = name.decode("ascii")
                if digest is None:
                    return f"{text}: compressed data does not end exactly at its recorded size"
                if text.endswith("/"):
                    if digest != hashlib.sha256().hexdigest():
                        return f"{text}: directory entry carries data"
                elif digest != unpacked_digest(unpacked[text]):
                    return f"{text}: unpacked contents differ from the ZIP entry"
                expected, descriptor = start + compressed, bool(flags & 8)
            gap = directory_offset - expected
            if expected > directory_offset or (gap and not (descriptor and gap in (12, 16, 20, 24))):
                return f"unexplained bytes at offset {expected}"
        except (ValueError, struct.error, StopIteration, OSError) as error:
            return f"malformed ZIP structure ({error})"
    return None


def unpacked_digest(path):
    info = os.lstat(path)
    if stat.S_ISLNK(info.st_mode):
        return hashlib.sha256(os.fsencode(os.readlink(path))).hexdigest()
    if not stat.S_ISREG(info.st_mode):
        return None
    with open(path, "rb") as incoming:
        return hashlib.file_digest(incoming, "sha256").hexdigest()


def entry_digest(file, method, start, length, deadline):
    """SHA-256 of a stored or deflated entry, or None unless its data ends on its last byte."""
    import zlib

    inflater = zlib.decompressobj(-15) if method == 8 and length else None
    digest = hashlib.sha256()
    file.seek(start)
    remaining = length
    try:
        while remaining:
            if time.monotonic() > deadline:
                raise Hold("scan_error", "Checking that unpacking read every byte timed out.", None)
            data = file.read(min(MIB, remaining))
            if not data or (inflater and inflater.eof):
                return None
            remaining -= len(data)
            if not inflater:
                digest.update(data)
                continue
            while data and not inflater.eof:
                digest.update(inflater.decompress(data, 16 * MIB))
                data = inflater.unconsumed_tail
            if inflater.eof and (inflater.unused_data or remaining):
                return None
    except zlib.error:
        return None
    return digest.hexdigest() if not inflater or inflater.eof else None


class LayeredScan:
    """Scan a file too large for ClamAV by unpacking it, then chunk-scanning the rest.

    Everything is written under a fresh private directory inside staging. The
    extraction tools only read archives; nothing extracted is ever executed.
    """

    def __init__(self, work, settings):
        self.work, self.settings = work, settings
        self.limit = setting(settings, "maxFileSize")
        self.members = work / "members"
        self.members.mkdir(mode=0o700)
        self.counter = itertools.count()
        self.small, self.chunked, self.skipped, self.unverified = [], [], [], []
        self.layers = self.entries = self.written = 0

    def run(self, snapshot, name):
        size = snapshot.stat().st_size
        free = shutil.disk_usage(self.work).free
        margin = setting(self.settings, "freeSpaceMargin")
        ratio_budget = setting(self.settings, "extractionRatio") * size
        space_budget = free - margin
        if space_budget < min(size, ratio_budget):
            raise Hold("scan_error", f"Not enough free space to unpack {name} ({gib(size)}) while keeping "
                       f"a {gib(margin)} margin; {gib(free)} available in staging.", None)
        self.budget = min(ratio_budget, space_budget)
        self.space_bound = space_budget < ratio_budget
        self.inspect(snapshot, name, 0)
        self.scan_members()
        notes = []
        if self.skipped:
            shown = ", ".join(self.skipped[:10]) + (" ..." if len(self.skipped) > 10 else "")
            notes.append(f"Skipped {len(self.skipped)} links or special entries with no content: {shown}")
        empty = sum(1 for *_, size in self.small if size == 0)
        summary = (f"ClamAV: no threat detected in {len(self.small)} members"
                   + (f" ({empty} empty)" if empty else "") + f" unpacked from {self.layers} archive layer(s).")
        if self.chunked:
            shown = "\n".join(f"  {label}" for label in self.chunked[:20])
            more = "\n  ..." if len(self.chunked) > 20 else ""
            if self.unverified:
                notes.append("Unpacking could not be shown to read every byte of: " + "; ".join(
                    f"{label} ({reason})" for label, reason in self.unverified[:10])
                    + ". Their raw bytes were chunk-scanned as well.")
            return "scan_partial", "\n".join([
                ("Scanned in part: these exceed ClamAV's per-file limit and could not be unpacked completely, "
                 "so they were scanned in overlapping chunks. File-type aware and whole-file signatures "
                 "cannot match chunked data. Held until you approve it."),
                f"Chunk-scanned:\n{shown}{more}", summary, *notes]), "partial"
        return "clean", "\n".join([summary, *notes]), None

    def path(self, prefix):
        return self.work / f"{prefix}-{next(self.counter)}"

    def inspect(self, file, label, depth):
        """Handle one file larger than the ClamAV limit."""
        offset = appended_squashfs_offset(file)
        with open(file, "rb") as incoming:
            if incoming.read(4) == b"hsqs":
                offset = 0
        archive = offset is not None or looks_like_archive(file)
        if depth >= setting(self.settings, "maxExtractionDepth"):
            if archive:
                raise Hold("scan_blocked", f"{label}: archives are nested more than "
                           f"{setting(self.settings, 'maxExtractionDepth')} levels deep; possible archive bomb. "
                           "Not unpacked further.", "unscannable")
            return self.chunk_scan(file, label)
        out = self.path("layer")
        listed = None
        if offset is not None:
            self.add_slice(file, 0, offset, f"{label} [ELF runtime]")
            self.extract([self.settings.get("unsquashfs", "unsquashfs"), "-no-xattrs", "-quiet",
                          "-no-progress", "-offset", str(offset), "-dest", str(out), str(file)],
                         out, label, file, squashfs=True)
            # SquashFS can hold bytes no file references (bytes_used is not
            # checked against the inodes), and data may follow the image.
            unverified = "SquashFS images can hold bytes that no file references"
        elif archive:
            # Only formats identified by magic bytes reach libarchive: its mtree
            # reader would otherwise copy host files named inside the "archive".
            # A fixed wrong passphrase makes encrypted entries fail rather than
            # loop on a prompt with no terminal.
            listed = self.list_entries(file, label)
            if listed is None:
                return self.chunk_scan(file, label)
            out.mkdir(mode=0o700)
            if not self.extract([self.settings.get("bsdtar", "bsdtar"), "-x", "-f", str(file), "-C", str(out),
                                 "--no-same-owner", "--no-same-permissions", "--no-xattrs", "--no-acls",
                                 "--no-fflags", "--passphrase", "download-sorter-has-no-passphrase"],
                                out, label, file):
                remove_tree(out)
                return self.chunk_scan(file, label)
            unverified = "this format can hold bytes that unpacking never reads"
        else:
            return self.chunk_scan(file, label)
        self.layers += 1
        regular, skipped = collect_members(out)
        if listed == -1:
            raise Hold("scan_error", f"{label}: libarchive could not list this archive, although it unpacked; "
                       "its members cannot be accounted for.", "unscannable")
        if listed is not None and listed != len(regular) + len(skipped):
            # A later entry with the same path (file, link or directory)
            # replaces an earlier one on disk, so the earlier bytes would never
            # be scanned although another extractor would produce them.
            raise Hold("scan_blocked", f"{label}: the archive lists {listed} file or link entries but "
                       f"{len(regular) + len(skipped)} were unpacked; duplicate or overlapping member paths "
                       "would hide members from the scan.", "unscannable")
        if listed is not None and self.is_zip(file):
            unpacked = {str(path.relative_to(out)): path for path in [p for p, _ in regular] + skipped}
            unverified = zip_coverage(file, unpacked,
                                      time.monotonic() + scan_timeout(self.settings, file.stat().st_size))
        if unverified:
            # Scan the container's raw bytes too: this finds signatures in data
            # the extractor skipped, but chunked scanning makes the result partial.
            self.unverified.append((label, unverified))
            self.add_slice(file, offset or 0, file.stat().st_size, f"{label} [raw container bytes]")
        self.skipped += [f"{label}/{path.relative_to(out)}" for path in skipped]
        for path, size in regular:
            member = f"{label}/{path.relative_to(out)}"
            if size <= self.limit:
                target = self.members / str(next(self.counter))
                path.rename(target)
                self.small.append((target, member, size))
            else:
                self.inspect(path, member, depth + 1)
                path.unlink()

    @staticmethod
    def is_zip(file):
        with open(file, "rb") as incoming:
            return incoming.read(4) == b"PK\x03\x04"

    def supervise(self, command, file, output, check):
        """Run a read-only tool until it exits, check() names a reason to stop, or time runs out."""
        deadline = time.monotonic() + scan_timeout(self.settings, file.stat().st_size)
        remaining = max(self.budget - self.written, 1)
        death = parent_death_signal()

        def prepare():
            death()
            # A single member larger than the remaining budget is stopped by
            # the kernel (SIGXFSZ) before it can fill the disk.
            resource.setrlimit(resource.RLIMIT_FSIZE, (remaining, remaining))

        # A new session has no controlling terminal, so a passphrase prompt cannot block.
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
                                   env={**os.environ, "LC_ALL": "C"}, start_new_session=True,
                                   preexec_fn=prepare)
        reason = None
        try:
            while True:
                try:
                    process.wait(timeout=1)
                    break
                except subprocess.TimeoutExpired:
                    pass
                reason = check() or ("timeout" if time.monotonic() > deadline else None)
                if reason:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                    break
        except BaseException:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise
        return process.returncode, reason

    def list_entries(self, file, label):
        """Count the file and link entries libarchive sees, or None if it is not an archive.

        One line per entry (bsdtar escapes control characters in names); the
        first character is the entry type, 'd' for directories.
        """
        members = setting(self.settings, "maxExtractedMembers")
        listing = self.path("listing")
        with open(listing, "w+b") as output:
            code, reason = self.supervise(
                [self.settings.get("bsdtar", "bsdtar"), "-t", "-v", "-f", str(file),
                 "--passphrase", "download-sorter-has-no-passphrase"], file, output,
                lambda: "limit" if os.fstat(output.fileno()).st_size > members * 4096 else None)
            if reason == "timeout":
                raise Hold("scan_error", f"{label}: listing the archive timed out.", None)
            if reason == "limit":
                self.exceeded(label)
            output.seek(0)
            lines = output.read().decode(errors="replace").splitlines()
        listing.unlink()
        if code != 0:
            if any("Unrecognized archive format" in line for line in lines):
                return None
            # Extraction reports the precise failure (encryption, damage).
            return -1
        # Mode strings such as "-rw-r--r--" or "drwxr-xr-x"; diagnostics ("bsdtar: ...") do not match.
        entries = [line for line in lines if re.match(r"[-dlhbcps][-rwxsStT]{9}[+@.]?\s", line)]
        if len(entries) > members:
            self.exceeded(label)
        return sum(1 for line in entries if not line.startswith("d"))

    def extract(self, command, out, label, file, squashfs=False):
        """Run a read-only extractor within byte, member, space and time limits."""
        remaining = self.budget - self.written
        members = setting(self.settings, "maxExtractedMembers") - self.entries
        if remaining < 1 or members < 1:
            self.exceeded(label)
        margin = setting(self.settings, "freeSpaceMargin")

        def check():
            entries, size = tree_usage(out)
            if size > remaining or entries > members:
                return "limit"
            if shutil.disk_usage(self.work).free < margin:
                return "space"
            return None

        with open(self.path("log"), "w+b") as output:
            code, reason = self.supervise(command, file, output, check)
            output.seek(0)
            log = output.read()[-4000:].decode(errors="replace").strip()
        if reason == "space":
            raise Hold("scan_error", f"{label}: staging free space fell below the {gib(margin)} margin while "
                       "unpacking; stopped.", None)
        if reason == "timeout":
            raise Hold("scan_error", f"{label}: unpacking timed out.", None)
        if reason == "limit" or code == -signal.SIGXFSZ or "File too large" in log:
            self.exceeded(label)
        if code != 0:
            if re.search(r"encrypt|passphrase|password", log, re.IGNORECASE):
                raise Hold("scan_blocked", f"{label}: encrypted or password-protected archive; its contents "
                           f"cannot be scanned.\n{log[:1000]}", "unscannable")
            if not squashfs and "Unrecognized archive format" in log and not any(out.iterdir()):
                return False
            if re.search(r"Path contains '\.\.'|absolute|through symlink|Hard-link|Link target", log, re.IGNORECASE):
                raise Hold("scan_blocked", f"{label}: archive contains unsafe member paths (path traversal, "
                           f"absolute paths or links escaping the extraction directory); these members were "
                           f"refused.\n{log[:1000]}", "unscannable")
            if not (squashfs and code == 2 and self.harmless_squashfs_errors(log)):
                raise Hold("scan_error", f"{label}: could not unpack this format completely "
                           f"(exit {code}).\n{log[:1000]}", "unscannable")
        entries, size = tree_usage(out)
        self.entries += entries
        self.written += size
        if self.written > self.budget or self.entries > setting(self.settings, "maxExtractedMembers"):
            self.exceeded(label)
        return True

    @staticmethod
    def harmless_squashfs_errors(log):
        # Unprivileged unsquashfs cannot create device nodes or set ownership;
        # those entries carry no file content to scan.
        lines = [line for line in log.splitlines() if line.strip()]
        return all(re.search(r"device|fifo|socket|mknod|chown|ownership|xattr|Non-fatal|errors? (occurred|reported)",
                             line, re.IGNORECASE) for line in lines)

    def exceeded(self, label):
        if self.space_bound:
            raise Hold("scan_error", f"{label}: unpacking needs more than the free space in staging "
                       f"({gib(self.budget)} after the safety margin).", None)
        raise Hold("scan_blocked", f"{label}: unpacked contents exceed the extraction limits "
                   f"({setting(self.settings, 'extractionRatio')}x the download size, "
                   f"{setting(self.settings, 'maxExtractedMembers')} entries); possible archive bomb.",
                   "unscannable")

    def add_slice(self, file, start, end, label):
        """Scan bytes of a container that are not inside its unpacked payload."""
        if end - start > self.limit:
            return self.chunk_scan(file, label, start, end)
        if end <= start:
            return
        target = self.members / str(next(self.counter))
        self.copy_range(file, target, start, end)
        self.written += end - start
        self.small.append((target, label, end - start))

    @staticmethod
    def copy_range(file, target, start, end):
        descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with open(file, "rb") as incoming, os.fdopen(descriptor, "wb") as outgoing:
            incoming.seek(start)
            remaining = end - start
            while remaining and (data := incoming.read(min(MIB, remaining))):
                outgoing.write(data)
                remaining -= len(data)

    def chunk_scan(self, file, label, start=0, end=None):
        """Scan overlapping chunks, keeping only one chunk on disk at a time."""
        end = file.stat().st_size if end is None else end
        size, overlap = setting(self.settings, "chunkSize"), setting(self.settings, "chunkOverlap")
        position = start
        while True:
            chunk = self.path("chunk")
            stop = min(position + size, end)
            try:
                self.copy_range(file, chunk, position, stop)
                status, detail = scan_file(chunk, self.settings)
            finally:
                chunk.unlink(missing_ok=True)
            if status != "clean":
                hold = hold_reason(status, detail)
                detail = detail.replace(str(chunk), f"{label} [bytes {position}-{stop}]")
                raise Hold(status, f"{label}: chunk scan of bytes {position}-{stop}:\n{detail}", hold)
            if stop >= end:
                break
            position = stop - overlap
        self.chunked.append(label)

    def scan_members(self):
        # Empty members hold no bytes to scan; clamscan would only call them "Empty file".
        names = {str(path): label for path, label, size in self.small if size}
        if not names:
            return
        listing = self.path("list")
        listing.write_text("".join(f"{name}\n" for name in names))
        status, detail = clamscan(self.settings, [f"--file-list={listing}"], list(names),
                                  sum(size for _, _, size in self.small))
        if status != "clean":
            # Classify before member names, which the archive controls, enter the text.
            hold = hold_reason(status, detail)
            for name in sorted(names, key=len, reverse=True):
                detail = detail.replace(name, names[name])
            raise Hold(status, f"Unpacked member scan:\n{detail}", hold)


def inspect_file(path, settings, name=None):
    """Scan directly when ClamAV can; otherwise unpack and scan in layers."""
    name = name or path.name
    size = path.stat().st_size
    if size <= setting(settings, "maxFileSize"):
        status, detail = scan_file(path, settings)
        return status, detail, hold_reason(status, detail)
    if size > setting(settings, "autoScanCap"):
        return "scan_blocked", oversize_detail(settings), "oversize"
    work = Path(tempfile.mkdtemp(prefix="unpack-", dir=path.parent))
    try:
        return LayeredScan(work, settings).run(path, name)
    except Hold as held:
        return held.args
    except (OSError, subprocess.SubprocessError, struct.error) as error:
        return "scan_error", f"Unpacking for a layered scan failed: {error}", None
    finally:
        remove_tree(work)


def oversize_detail(settings):
    return (f"File exceeds the {gib(setting(settings, 'autoScanCap'))} automatic scan cap; it was not scanned "
            "and is held.")


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
    with tempfile.NamedTemporaryFile(prefix="snapshot-", dir=staging, suffix=filename_extension(path.name)) as snapshot:
        try:
            digest = copy_snapshot(path, snapshot, signature)
        except PermissionError as error:
            if error.errno != errno.EPERM:
                raise
            quarantine(path, signature, ON_ACCESS_DETAIL, history, settings, policy)
            return
        hold = None
        if cached and cached["digest"] == digest:
            status, detail = "clean", "Previously scanned, unchanged content"
        elif history.approved(digest):
            # Approval covers these exact bytes only; any change needs a new scan.
            status, detail = "clean", f"Released by user approval (sha256 {digest})"
            history.event("released", path, digest=digest, detail=detail)
        else:
            status, detail, hold = inspect_file(Path(snapshot.name), settings, path.name)
            if status == "clean":
                history.event(status, path, digest=digest, detail=detail)
        if fingerprint(path) != signature:
            raise OSError("Download changed during scanning; rename and routing were stopped")
        if hold == "threat":
            quarantine(path, signature, detail, history, settings, policy, snapshot, digest)
            return
        history.remember(path, signature, status, digest, policy, hold)
        if status != "clean":
            history.hold(path, status, detail, digest, hold)
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


def quarantine_folder(settings):
    return Path(settings.get("quarantine") or Path(settings["staging"]).parent / "quarantine")


def quarantine(path, signature, detail, history, settings, policy, snapshot=None, digest=None):
    """Move a detected threat out of Downloads into a private folder, with no permissions.

    A scanned snapshot is linked in (staging shares the state folder), so the
    quarantined bytes are exactly those ClamAV saw. A file clamonacc refused
    to open cannot be read, so it is renamed instead.
    """
    folder = quarantine_folder(settings)
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    target = available_name(folder / path.name)
    if fingerprint(path) != signature:
        raise OSError("Download changed before quarantine; it was left in place to be scanned again")
    contained = True
    linked = False
    try:
        if snapshot is not None:
            os.link(snapshot.name, target)
            linked = True
            # Keep the download's own modification time on the snapshot's bytes.
            os.utime(target, ns=(signature[3], signature[3]))
            if fingerprint(path) != signature:
                raise OSError("Download changed before quarantine; it was left in place to be scanned again")
            path.unlink()
        else:
            os.rename(path, target)
            # rename() changes only ctime; anything else means another file
            # replaced the refused one between the check and the rename.
            if (fingerprint(target) or [])[:4] != signature[:4]:
                if not os.path.lexists(path):
                    os.rename(target, path)
                raise OSError("Download changed before quarantine; it was left in place to be scanned again")
    except OSError as error:
        if linked:
            target.unlink(missing_ok=True)
        if error.errno not in (errno.EXDEV, errno.EPERM, errno.EACCES):
            raise
        # Another filesystem, or the move was refused: keep it in place, unusable.
        contained = False
        target = path
    if digest is None and contained:
        # Outside Downloads, clamonacc no longer refuses to open it.
        with open(target, "rb") as moved:
            digest = hashlib.file_digest(moved, "sha256").hexdigest()
    os.chmod(target, 0)
    history.event("scan_blocked", path, digest=digest, detail=detail)
    if contained:
        history.forget(path)
        history.event("quarantined", path, target, digest, detail)
        title = "Threat quarantined"
        where = f"Moved to {target} with all permissions removed."
        release = f"Only for a confirmed false positive: download-sorter --approve {shlex.quote(str(target))} --force"
    else:
        title = "Threat found — could not quarantine"
        where = "Could not move it out of Downloads; all its permissions were removed in place."
        release = "It cannot be released from here; delete it and download it again if it was a false positive."
    history.remember(target, fingerprint(target), "scan_blocked", digest, policy, "threat")
    history.alert(target, "quarantined", title,
                  f"{path}\n{where}\n{detail}\nDelete it: rm -f {shlex.quote(str(target))}\n{release}")


def restore_quarantined(history, file, settings, force):
    """Return a confirmed false positive to Downloads/Restored, approved by SHA-256."""
    source, _ = validate_settings(settings)
    row = history.get(file)
    if not row or row["hold"] != "threat":
        raise ValueError(f"Not a quarantined download: {file}")
    if not force:
        raise ValueError("ClamAV detected a threat in this download; it was not restored. Use --force only "
                         "after confirming the detection is a false positive.")
    # ctime is left out: removing the staged snapshot (a second link) changes it.
    # The SHA-256 below is what binds the restore to the scanned bytes.
    if json.loads(row["signature"])[:4] != (fingerprint(file) or [])[:4]:
        raise ValueError("The quarantined file changed; nothing was restored")
    folder = source / RESTORED_FOLDER
    folder.mkdir(exist_ok=True)
    if not stat.S_ISDIR(folder.lstat().st_mode):
        raise ValueError(f"{folder} must be a folder, not a file or symlink; nothing was restored")
    original = history.connection.execute(
        "SELECT source FROM events WHERE kind='quarantined' AND destination=? ORDER BY id DESC LIMIT 1",
        (str(file),)).fetchone()
    target = available_name(folder / (Path(original["source"]).name if original else file.name))
    os.chmod(file, 0o600)
    try:
        with file.open("rb") as incoming:
            digest = hashlib.file_digest(incoming, "sha256").hexdigest()
        if row["digest"] and row["digest"] != digest:
            raise ValueError("Quarantined contents differ from the scanned snapshot; nothing was restored")
        shutil.move(file, target)
    except BaseException:
        if os.path.lexists(file):
            os.chmod(file, 0)
        raise
    with history.connection:
        history.connection.execute("INSERT OR REPLACE INTO approvals VALUES (?, ?, ?, ?, ?, ?)",
                                   (digest, str(target), time.time(), row["status"], "threat", 1))
    history.forget(file)
    history.event("restored", file, target, digest, "forced past a ClamAV detection")
    print(f"Restored: {file} -> {target}\nSHA-256: {digest}\nForced past a ClamAV detection"
          "\nIt is released on the next run only while its contents still match this digest.")


def scan_policy(settings):
    values = {key: settings.get(key) for key in
              ("scanner", "signatureDirectory", "bsdtar", "unsquashfs", *DEFAULTS)
              if key not in ("minimumAge", "minimumChoices")}
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()


def clear_staging(staging):
    """Remove leftovers of an interrupted run: snapshots (up to autoScanCap) and unpack trees.

    Callers hold the lock, so nothing else is using staging. A failure is
    reported but does not stop the run.
    """
    if not staging.is_dir():
        return
    for stale in staging.iterdir():
        try:
            if stale.is_dir() and not stale.is_symlink():
                remove_tree(stale)
            else:
                stale.unlink()
        except OSError as error:
            print(f"Could not remove stale staging entry {stale}: {error}", file=sys.stderr)


def retry_delay(history, path, large):
    """Seconds before a transient failure is retried; doubles per failure for large files.

    A layered scan copies and unpacks gigabytes, so repeated failures back off
    from one hour to at most 64 hours instead of repeating every hour.
    """
    if not large:
        return 300
    failures = 0
    for row in history.connection.execute(
            "SELECT kind FROM events WHERE source=? ORDER BY id DESC LIMIT 7", (str(path),)):
        if row["kind"] not in HELD_STATUSES:
            break
        failures += 1
    return 3600 * 2 ** max(failures - 1, 0)


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
    if not dry_run and "staging" in settings:
        clear_staging(Path(settings["staging"]))
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
            approved = history.approved(row["digest"])
            if row["hold"] == "threat" and not approved:
                # Unchanged bytes ClamAV already detected. Quarantine those held
                # by older versions without another scan; a threat that could
                # not be moved has no permissions left and stays held.
                if stat.S_IMODE(path.lstat().st_mode) != 0:
                    quarantine(path, signature, "ClamAV detected a threat in this download earlier.",
                               history, settings, policy, digest=row["digest"])
                continue
            large = signature[2] > setting(settings, "maxFileSize")
            if not retry and not approved and row["status"] in HELD_STATUSES:
                # Layered scans of large files are expensive: hold their verdict
                # until the contents, the scan policy or --retry asks again.
                if large and row["hold"] and row["policy"] == policy:
                    continue
                if time.time() - row["attempted"] < retry_delay(history, path, large):
                    continue
            cached = row if same and row["status"] == "clean" and row["policy"] == policy and not retry else None
            if cached and destination == path:
                history.clear_alerts(path)
                if uncertainty:
                    # Avoid growing history every minute for the same uncertainty.
                    history.alert(path, "routing_uncertain", "Download needs attention", f"{path}\n{uncertainty}")
                continue
            if signature[2] > setting(settings, "autoScanCap") and not approved:
                # Checked before copying: the cap also bounds staging space.
                if row["status"] == "scan_blocked" and row["hold"] == "threat":
                    # Unchanged bytes (same signature) in which ClamAV found a
                    # threat stay a threat: an oversize hold needs no --force.
                    continue
                history.remember(path, signature, "scan_blocked", row["digest"], policy, "oversize")
                history.hold(path, "scan_blocked", oversize_detail(settings), None, "oversize")
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


def check_on_access(history, settings):
    """Raise a critical alert while clamonacc, the open-time scanner, is not running."""
    unit = settings.get("onAccessUnit")
    if not unit:
        return
    try:
        active = subprocess.run([settings.get("systemctl", "systemctl"), "is-active", "--quiet", unit],
                                check=False, timeout=10, stdin=subprocess.DEVNULL,
                                capture_output=True).returncode == 0
    except (OSError, subprocess.SubprocessError):
        active = False
    if active:
        history.clear_alerts(unit)
    else:
        history.alert(unit, "on_access_down", "On-access virus scanning is off",
                      f"{unit} is not running, so files in Downloads can be opened before they are "
                      f"scanned. Scheduled scans continue.\nDetails: journalctl -u {unit}")


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


def approve_download(history, file, settings, force=False):
    """Release one held download, bound to the SHA-256 of its current contents."""
    validate_settings(settings)
    file = expand_path(str(file)).absolute()
    signature = fingerprint(file)
    if signature is None:
        raise ValueError("Approve a regular file, not a symlink or directory")
    if quarantine_folder(settings).resolve() in file.resolve().parents:
        restore_quarantined(history, file, settings, force)
        return
    row = history.get(file)
    if not row or row["status"] not in HELD_STATUSES:
        raise ValueError(f"Not currently held by the download sorter: {file}")
    if row["signature"] != json.dumps(signature):
        raise ValueError("The file changed after it was held; wait for it to be scanned again")
    hold = row["hold"]
    if hold == "threat" and not force:
        raise ValueError("ClamAV detected a threat in this download; it was not approved. Use --force only "
                         "after confirming the detection is a false positive.")
    if hold not in (*APPROVABLE_HOLDS, "threat"):
        raise ValueError(f"Held for a transient failure ({row['status']}), not an approvable reason; "
                         "fix the cause and run downloads-retry")
    with file.open("rb") as incoming:
        digest = hashlib.file_digest(incoming, "sha256").hexdigest()
    if fingerprint(file) != signature:
        raise ValueError("File changed while computing its SHA-256; nothing was approved")
    if row["digest"] and row["digest"] != digest:
        raise ValueError("File contents differ from the scanned snapshot; nothing was approved")
    with history.connection:
        history.connection.execute("INSERT OR REPLACE INTO approvals VALUES (?, ?, ?, ?, ?, ?)",
                                   (digest, str(file), time.time(), row["status"], hold, int(force)))
        history.connection.execute("UPDATE files SET digest=? WHERE path=?", (digest, str(file)))
    history.event("approved", file, digest=digest,
                  detail=f"previous status {row['status']} ({hold})" + ("; forced" if force else ""))
    history.clear_alerts(file)
    print(f"Approved: {file}\nSHA-256: {digest}\nPrevious status: {row['status']} ({hold})"
          + ("\nForced past a ClamAV detection" if force else "")
          + "\nIt is released on the next run only while its contents still match this digest.")


def stop_on_signal(number, _frame):
    # Turn SIGTERM (logout, service stop) and SIGHUP (closed terminal) into an
    # exception so finally blocks remove staged snapshots and kill extractors.
    raise SystemExit(128 + number)


def main():
    os.umask(0o077)
    for number in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(number, stop_on_signal)
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
    parser.add_argument("--approve", type=Path, help="Release a held download whose SHA-256 still matches, "
                        "or restore a quarantined one (with --force) to Downloads/Restored")
    parser.add_argument("--force", action="store_true",
                        help="With --approve, also release a file in which ClamAV detected a threat")
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
        settings["quarantine"] = str(args.state.parent / "quarantine")
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
            if args.force and not args.approve:
                raise ValueError("--force is only valid with --approve")
            if args.approve:
                approve_download(history, args.approve, settings, args.force)
                return 0
            sort_downloads(settings, history, rename_only=args.rename_only, retry=args.retry)
            check_on_access(history, settings)
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
