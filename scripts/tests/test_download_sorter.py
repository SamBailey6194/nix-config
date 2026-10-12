import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import time
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "download_sorter", Path(__file__).resolve().parents[1] / "download-sorter.py"
)
sorter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sorter)


class DownloadSorterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.downloads = self.root / "Downloads"
        self.downloads.mkdir()
        self.destination = self.root / "Documents"
        self.settings = {
            "source": str(self.downloads),
            "minimumAge": 120,
            "rules": [{"patterns": ["*.pdf"], "destination": str(self.destination)}],
            "staging": str(self.root / "state/staging"),
        }
        self.destination.mkdir()
        self.history = sorter.History(self.root / "history.sqlite3")
        self.addCleanup(self.history.connection.close)
        self.scanner = patch.object(sorter, "scan_file", return_value=("clean", "ClamAV: no threat detected"))
        self.scan = self.scanner.start()
        self.addCleanup(self.scanner.stop)

    def run_sorter(self, **kwargs):
        sorter.sort_downloads(self.settings, self.history, **kwargs)

    def settled_run(self, **kwargs):
        self.run_sorter(**kwargs)
        self.run_sorter(**kwargs)

    def alerts(self):
        return self.history.connection.execute("SELECT * FROM alerts WHERE active=1").fetchall()

    def events(self, kind):
        return self.history.connection.execute("SELECT * FROM events WHERE kind=?", (kind,)).fetchall()

    def file(self, name):
        path = self.downloads / name
        path.write_bytes(b"download contents")
        old = time.time() - 300
        os.utime(path, (old, old))
        return path

    def test_only_settled_matches_move_and_first_rule_wins(self):
        invoices = self.root / "Invoices"
        invoices.mkdir()
        self.settings["rules"].insert(0, {
            "patterns": ["invoice-*.pdf"], "destination": str(invoices)
        })
        matched = self.file("invoice-01.PDF")
        other = self.file("readme.txt")
        self.run_sorter()
        self.assertTrue(matched.exists())
        self.run_sorter()
        self.assertFalse(matched.exists())
        self.assertEqual((invoices / "invoice-01.pdf").read_bytes(), b"download contents")
        self.assertTrue(other.exists())

    def test_dry_run_does_not_create_folders_or_move(self):
        path = self.file("report.pdf")
        self.destination.rmdir()
        self.run_sorter(dry_run=True)
        self.assertTrue(path.exists())
        self.assertFalse(self.destination.exists())

    def test_existing_file_and_dangling_symlink_are_never_overwritten(self):
        for name in ("existing.pdf", "symlink.pdf"):
            self.file(name)
        (self.destination / "existing.pdf").write_bytes(b"original")
        (self.destination / "symlink.pdf").symlink_to(self.root / "missing")
        self.settled_run()
        self.assertEqual((self.destination / "existing.pdf").read_bytes(), b"original")
        self.assertTrue((self.destination / "symlink.pdf").is_symlink())
        self.assertEqual(len(list(self.downloads.iterdir())), 2)

    def test_partial_companions_symlinks_and_directories_are_skipped(self):
        self.file("unfinished.pdf")
        self.file("unfinished.pdf.part")
        (self.downloads / "directory.pdf").mkdir()
        (self.downloads / "linked.pdf").symlink_to(self.file("target.txt"))
        partial_directory = self.downloads / "unfinished.download"
        partial_directory.mkdir()
        (partial_directory / "report.pdf").write_bytes(b"still downloading")
        self.settled_run()
        self.assertEqual(list(self.destination.iterdir()), [])
        # The unmatched ordinary text file is still scanned.
        self.assertEqual(self.scan.call_count, 1)

    def test_changed_and_recent_downloads_wait(self):
        changed = self.file("changed.pdf")
        recent = self.file("recent.pdf")
        self.run_sorter()
        changed.write_bytes(b"changed")
        old = time.time() - 300
        os.utime(changed, (old, old))
        os.utime(recent, None)
        self.run_sorter()
        self.assertTrue(changed.exists())
        self.assertTrue(recent.exists())
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_destination_inside_downloads_is_rejected(self):
        self.settings["rules"][0]["destination"] = str(self.downloads / "Sorted")
        with self.assertRaises(ValueError):
            self.run_sorter()

    def test_failed_copy_retains_source_and_removes_temporary_file(self):
        source = self.file("report.pdf")
        with patch.object(sorter.shutil, "copyfileobj", side_effect=OSError("disk full")):
            self.settled_run()
        self.assertTrue(source.exists())
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assertTrue(any("disk full" in alert["body"] for alert in self.alerts()))

    def test_corrupted_published_copy_is_rejected_before_source_removal(self):
        source = self.file("report.pdf")
        with patch.object(sorter.shutil, "copyfileobj", side_effect=lambda _, target: target.write(b"corrupted")):
            self.settled_run()
        self.assertTrue(source.exists())
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assertTrue(any("do not match" in alert["body"] for alert in self.alerts()))

    def test_kebab_names_preserve_extensions_and_are_idempotent(self):
        examples = {
            "Annual Report_2026 (Final).PDF": "annual-report-2026-final.pdf",
            "myHTTPReport.zip": "my-http-report.zip",
            "Project Backup.TAR.GZ": "project-backup.tar.gz",
            "Quarterly.Report.v2.docx": "quarterly-report-v2.docx",
            "Résumé Notes.txt": "résumé-notes.txt",
            "README": "readme",
            "---.pdf": "download.pdf",
            "already-kebab.pdf": "already-kebab.pdf",
            ".Env Config": ".env-config",
        }
        for original, expected in examples.items():
            with self.subTest(original=original):
                self.assertEqual(sorter.kebab_filename(original), expected)
                self.assertEqual(sorter.kebab_filename(expected), expected)

    def test_rename_only_normalises_unmatched_files_without_routing(self):
        pdf = self.file("Annual Report.PDF")
        text = self.file("My Notes.txt")
        self.settled_run(rename_only=True)
        self.assertFalse(pdf.exists())
        self.assertFalse(text.exists())
        self.assertEqual((self.downloads / "annual-report.pdf").read_bytes(), b"download contents")
        self.assertTrue((self.downloads / "my-notes.txt").exists())
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assertEqual(self.alerts(), [])

    def test_rules_match_normalised_names_and_routing_renames_in_one_step(self):
        self.settings["rules"][0]["patterns"] = ["invoice-*.pdf"]
        self.file("Invoice January.PDF")
        self.settled_run()
        self.assertTrue((self.destination / "invoice-january.pdf").exists())
        self.assertEqual(list(self.downloads.iterdir()), [])

    def test_rename_collision_uses_numbered_name_and_preserves_existing_file(self):
        self.file("Project Backup.TAR.GZ")
        occupied = self.file("project-backup.tar.gz")
        occupied.write_bytes(b"original")
        self.file("project-backup-2.tar.gz")
        self.settled_run(rename_only=True)
        self.assertEqual(occupied.read_bytes(), b"original")
        self.assertEqual((self.downloads / "project-backup-3.tar.gz").read_bytes(), b"download contents")

    def test_name_normalisation_can_be_disabled(self):
        self.settings["normalizeNames"] = False
        original = self.file("Annual Report.PDF")
        self.settled_run()
        self.assertFalse(original.exists())
        self.assertTrue((self.destination / original.name).exists())

    def test_rename_preview_leaves_original_and_no_state_changes(self):
        original = self.file("My Notes.txt")
        self.run_sorter(dry_run=True, rename_only=True)
        self.assertTrue(original.exists())
        self.assertFalse((self.downloads / "my-notes.txt").exists())
        self.scan.assert_not_called()
        self.assertEqual(self.events("clean"), [])

    def test_clean_scans_and_renames_are_quiet_and_cached(self):
        self.file("Some File.txt")
        self.settled_run(rename_only=True)
        self.run_sorter(rename_only=True)
        self.assertEqual(self.scan.call_count, 1)
        self.assertEqual(len(self.events("clean")), 1)
        self.assertEqual(len(self.events("rename")), 1)
        self.assertEqual(self.alerts(), [])

    def test_already_kebab_hidden_and_nested_files_are_scanned(self):
        self.file("already-kebab.txt")
        self.file(".env")
        nested = self.downloads / "nested"
        nested.mkdir()
        file = nested / "Nested File.txt"
        file.write_bytes(b"nested")
        old = time.time() - 300
        os.utime(file, (old, old))
        self.settled_run(rename_only=True)
        self.assertEqual(self.scan.call_count, 3)
        self.assertTrue((nested / "nested-file.txt").exists())

    def test_threat_error_and_timeout_stop_rename_and_routing(self):
        original = self.file("Unsafe File.PDF")
        for status in ("scan_blocked", "scan_error"):
            with self.subTest(status=status):
                self.scan.return_value = (status, "ClamAV rejected this scan")
                self.settled_run(retry=True)
                self.assertTrue(original.exists())
                self.assertEqual(list(self.destination.iterdir()), [])
                self.assertTrue(any(a["urgency"] == "critical" for a in self.alerts()))

    def test_file_changed_during_scan_is_not_published(self):
        original = self.file("Changing File.PDF")

        def change_during_scan(*_):
            original.write_bytes(b"changed after snapshot")
            return "clean", "No threat detected"

        self.scan.side_effect = change_during_scan
        self.settled_run()
        self.assertTrue(original.exists())
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assertTrue(any("changed during scanning" in a["body"] for a in self.alerts()))

    def test_scan_snapshot_contains_the_download_bytes(self):
        original = self.file("Report.PDF")
        expected = original.read_bytes()

        def inspect_snapshot(path, settings):
            self.assertNotEqual(path, original)
            self.assertEqual(path.read_bytes(), expected)
            self.assertNotIn(self.downloads, path.parents)
            return "clean", "No threat detected"

        self.scan.side_effect = inspect_snapshot
        self.settled_run()
        self.assertEqual((self.destination / "report.pdf").read_bytes(), expected)

    def test_successful_move_records_destination_and_normal_notification(self):
        self.file("report.pdf")
        self.settled_run()
        events = self.events("move")
        self.assertEqual(events[0]["destination"], str(self.destination / "report.pdf"))
        self.assertEqual(self.alerts()[0]["urgency"], "normal")

    def test_unknown_route_renames_but_raises_critical_alert(self):
        self.file("My Notes.txt")
        self.settled_run()
        self.assertTrue((self.downloads / "my-notes.txt").exists())
        self.assertTrue(any(a["urgency"] == "critical" for a in self.alerts()))

    def test_unavailable_destination_raises_issue_after_successful_scan(self):
        self.destination.rmdir()
        original = self.file("report.pdf")
        self.settled_run()
        self.assertTrue(original.exists())
        self.assertFalse(self.destination.exists())
        self.assertEqual(self.scan.call_count, 1)
        self.assertTrue(any("unavailable" in a["body"] for a in self.alerts()))

    def test_unavailable_route_still_renames_a_clean_download_in_place(self):
        self.destination.rmdir()
        original = self.file("Annual Report.PDF")
        self.settled_run()
        self.assertFalse(original.exists())
        self.assertTrue((self.downloads / "annual-report.pdf").exists())
        self.assertTrue(any("unavailable" in a["body"] for a in self.alerts()))

    def test_notification_failure_is_queued_and_retried(self):
        self.file("report.pdf")
        self.settled_run()
        with patch.object(sorter, "send_notification", side_effect=[False, True]) as notify:
            self.assertFalse(sorter.deliver_alerts(self.history, self.settings))
            self.assertTrue(sorter.deliver_alerts(self.history, self.settings))
            self.assertTrue(sorter.deliver_alerts(self.history, self.settings))
            self.assertEqual(notify.call_count, 2)

    def test_critical_alerts_repeat_hourly_and_clear_after_recovery(self):
        original = self.file("Report.PDF")
        self.scan.return_value = ("scan_error", "Missing signatures")
        self.settled_run(rename_only=True)
        with patch.object(sorter, "send_notification", return_value=True) as notify:
            sorter.deliver_alerts(self.history, self.settings)
            sorter.deliver_alerts(self.history, self.settings)
            self.assertEqual(notify.call_count, 1)
            self.history.connection.execute("UPDATE alerts SET delivered=?", (time.time() - 3601,))
            sorter.deliver_alerts(self.history, self.settings)
            self.assertEqual(notify.call_count, 2)
        self.scan.return_value = ("clean", "No threat detected")
        self.run_sorter(rename_only=True, retry=True)
        self.assertFalse(original.exists())
        self.assertEqual(self.alerts(), [])

    def test_learned_routes_require_distinct_human_choices_and_no_conflicts(self):
        self.settings["rules"] = []
        self.settings["learnedRouting"] = True
        self.settings["minimumChoices"] = 2
        for number in range(2):
            file = self.file(f"sample-{number}.txt")
            file.write_bytes(f"sample {number}".encode())
            old = time.time() - 300
            os.utime(file, (old, old))
            self.settled_run(rename_only=True)
            target = self.destination / file.name
            file.rename(target)
            sorter.record_choice(self.history, target, "sample-*.txt", self.settings)
            sorter.record_choice(self.history, target, "sample-*.txt", self.settings)
            folder, _, uncertainty = sorter.route(Path("sample-next.txt"), "sample-next.txt", [], self.history, self.settings)
            if number == 0:
                self.assertIsNone(folder)
            else:
                self.assertEqual(folder, self.destination)
                self.assertIsNone(uncertainty)
        self.assertEqual(self.history.connection.execute("SELECT COUNT(*) FROM choices").fetchone()[0], 2)
        third = self.root / "Other"
        third.mkdir()
        (self.destination / "sample-0.txt").rename(third / "sample-0.txt")
        sorter.record_choice(self.history, third / "sample-0.txt", "sample-*.txt", self.settings)
        folder, _, uncertainty = sorter.route(Path("sample-next.txt"), "sample-next.txt", [], self.history, self.settings)
        self.assertIsNone(folder)
        self.assertIn("conflicting", uncertainty)

    def test_automatic_moves_do_not_train_and_unscanned_choices_are_rejected(self):
        self.file("report.pdf")
        self.settled_run()
        self.assertEqual(self.history.connection.execute("SELECT COUNT(*) FROM choices").fetchone()[0], 0)
        file = self.destination / "unscanned.txt"
        file.write_bytes(b"new unscanned bytes")
        with self.assertRaises(ValueError):
            sorter.record_choice(self.history, file, "*.txt", self.settings)

    def test_policy_change_requires_a_new_scan(self):
        self.file("already-kebab.txt")
        self.settled_run(rename_only=True)
        self.settings["maxSignatureAge"] = 1
        self.run_sorter(rename_only=True)
        self.assertEqual(self.scan.call_count, 2)

    def test_learned_route_moves_and_conflicting_patterns_stop_the_move(self):
        self.settings["rules"] = []
        self.settings["learnedRouting"] = True
        self.settings["minimumChoices"] = 2
        for number in range(2):
            self.history.connection.execute("INSERT INTO choices VALUES (?, ?, ?, ?)",
                                            ("*.txt", f"digest-{number}", str(self.destination), time.time()))
        file = self.file("New File.txt")
        self.settled_run()
        self.assertFalse(file.exists())
        self.assertTrue((self.destination / "new-file.txt").exists())
        other = self.root / "Other"
        other.mkdir()
        for number in range(2):
            self.history.connection.execute("INSERT INTO choices VALUES (?, ?, ?, ?)",
                                            ("other-*.txt", f"other-{number}", str(other), time.time()))
        self.file("Other File.txt")
        self.settled_run()
        self.assertTrue((self.downloads / "other-file.txt").exists())
        self.assertEqual(list(other.iterdir()), [])
        self.assertTrue(any("conflicting" in a["body"] for a in self.alerts()))

    def test_existing_sqlite_is_read_only_during_cli_preview(self):
        import sys

        self.file("My Notes.txt")
        self.settled_run(rename_only=True)
        config = self.root / "config.json"
        import json
        config.write_text(json.dumps(self.settings))
        database = self.root / "history.sqlite3"
        before = database.read_bytes()
        args = ["download-sorter", "--config", str(config), "--state", str(database), "--dry-run"]
        with patch.object(sys, "argv", args):
            self.assertEqual(sorter.main(), 0)
        self.assertEqual(database.read_bytes(), before)

    def test_scan_only_mode_scans_without_renaming_or_routing(self):
        import json
        import sys

        original = self.file("Original Name.PDF")
        config = self.root / "config.json"
        config.write_text(json.dumps(self.settings))
        args = ["download-sorter", "--config", str(config), "--state", str(self.root / "history.sqlite3"), "--scan-only"]
        with patch.object(sys, "argv", args):
            self.assertEqual(sorter.main(), 0)
            self.assertEqual(sorter.main(), 0)
        self.assertTrue(original.exists())
        self.assertEqual(list(self.destination.iterdir()), [])
        self.assertEqual(self.scan.call_count, 1)


class ClamAVCommandTests(unittest.TestCase):
    def scan(self, result):
        with patch.object(sorter.subprocess, "run", return_value=result) as command:
            outcome = sorter.scan_file(Path("/tmp/snapshot.pdf"), {})
            flags = command.call_args.args[0]
            self.assertIn("--alert-exceeds-max=yes", flags)
            self.assertIn("--alert-encrypted=yes", flags)
            self.assertIn("--fail-if-cvd-older-than=3", flags)
            return outcome

    def test_exit_zero_requires_an_explicit_clean_result_without_warnings(self):
        from subprocess import CompletedProcess

        self.assertEqual(self.scan(CompletedProcess([], 0, "/tmp/snapshot.pdf: OK\nKnown viruses: 1\nScanned files: 1\n", ""))[0], "clean")
        self.assertEqual(self.scan(CompletedProcess([], 0, "/tmp/snapshot.pdf: OK\nKnown viruses: 0\nScanned files: 1\n", ""))[0], "scan_error")
        self.assertEqual(self.scan(CompletedProcess([], 0, "", ""))[0], "scan_error")
        self.assertEqual(self.scan(CompletedProcess([], 0, "file: OK", "WARNING: stale"))[0], "scan_error")

    def test_threat_scan_limits_encryption_errors_and_timeouts_are_blocked(self):
        import subprocess

        for code, message in ((1, "Eicar FOUND"), (1, "Heuristics.Limits.Exceeded FOUND"),
                              (1, "Heuristics.Encrypted FOUND"), (2, "ERROR: no database")):
            self.assertNotEqual(self.scan(subprocess.CompletedProcess([], code, message, ""))[0], "clean")
        for error in (FileNotFoundError("no scanner"), subprocess.TimeoutExpired("clamscan", 1)):
            with patch.object(sorter.subprocess, "run", side_effect=error):
                self.assertEqual(sorter.scan_file(Path("/tmp/file"), {})[0], "scan_error")

    def test_empty_file_is_clean_although_clamscan_does_not_count_it(self):
        from subprocess import CompletedProcess

        output = "/tmp/snapshot.pdf: Empty file\nKnown viruses: 1\nScanned files: 0\n"
        self.assertEqual(self.scan(CompletedProcess([], 0, output, ""))[0], "clean")
        # Only paths that were expected may be excused as empty.
        output = "/tmp/other: Empty file\nKnown viruses: 1\nScanned files: 0\n"
        self.assertEqual(self.scan(CompletedProcess([], 0, output, ""))[0], "scan_error")

    def test_real_detection_survives_truncation_behind_heuristic_alerts(self):
        from subprocess import CompletedProcess

        lines = [f"/tmp/m/{n:04}: Heuristics.Encrypted.Zip FOUND" for n in range(200)]
        lines.append("/tmp/m/9999: Win.Test.EICAR_HDB-1 FOUND")
        status, detail = self.scan(CompletedProcess([], 1, "\n".join(lines) + "\nKnown viruses: 1\n", ""))
        self.assertLessEqual(len(detail), 3100)
        self.assertIn("EICAR", detail)
        self.assertEqual(sorter.hold_reason(status, detail), "threat")
        status, detail = self.scan(CompletedProcess([], 1, "\n".join(lines[:-1]), ""))
        self.assertEqual(sorter.hold_reason(status, detail), "unscannable")

    def test_notifications_use_persistent_critical_urgency_and_escape_markup(self):
        row = {"key": "test", "title": "Problem", "body": "bad <file>.pdf", "urgency": "critical"}
        with patch.object(sorter.subprocess, "run") as command:
            self.assertTrue(sorter.send_notification(row, {}))
            flags = command.call_args.args[0]
            self.assertIn("--urgency=critical", flags)
            self.assertIn("--expire-time=0", flags)
            self.assertEqual(flags[-1], "bad &lt;file&gt;.pdf")


FAKE_CLAMSCAN = r"""
import json, os, sys
arguments = sys.argv[1:]
paths = arguments[arguments.index("--") + 1:] if "--" in arguments else []
for argument in arguments:
    if argument.startswith("--file-list="):
        paths += open(argument.split("=", 1)[1]).read().splitlines()
limit = int(next(a for a in arguments if a.startswith("--max-filesize=")).split("=", 1)[1])
found = 0
with open(os.environ["FAKE_CLAMSCAN_LOG"], "a") as log:
    log.write(json.dumps([[path, os.path.getsize(path), open(path, "rb").read().decode("latin-1")]
                          for path in paths]) + "\n")
empty = 0
for path in paths:
    data = open(path, "rb").read()
    if not data:
        # Like real ClamAV: no OK line, and not counted as scanned.
        print(f"{path}: Empty file"); empty += 1
    elif len(data) > limit:
        print(f"{path}: Heuristics.Limits.Exceeded.MaxFileSize FOUND"); found += 1
    elif b"EVILSIGNATURE" in data:
        print(f"{path}: Fake.Signature FOUND"); found += 1
    elif b"ENCRYPTEDMARK" in data:
        print(f"{path}: Heuristics.Encrypted.Zip FOUND"); found += 1
    else:
        print(f"{path}: OK")
print("----------- SCAN SUMMARY -----------\nKnown viruses: 1\nScanned files: %d" % (len(paths) - empty))
sys.exit(1 if found else 0)
"""


def tool(name):
    return os.environ.get(f"{name.upper()}_TEST_BINARY") or shutil.which(name)


def random_bytes(size):
    return os.urandom(size).replace(b"EVIL", b"evil")


@unittest.skipUnless(tool("bsdtar"), "bsdtar (libarchive) is not on PATH; set BSDTAR_TEST_BINARY")
class LayeredScanTests(unittest.TestCase):
    """Layered scans with tiny limits: ClamAV max 4 KiB, 2 KiB chunks, 64-byte overlap."""

    def setUp(self):
        import sys

        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.downloads = self.root / "Downloads"
        self.downloads.mkdir()
        self.destination = self.root / "Sorted"
        self.destination.mkdir()
        self.staging = self.root / "state/staging"
        scanner = self.root / "bin/clamscan"
        scanner.parent.mkdir()
        scanner.write_text(f"#!{sys.executable} -I\n{FAKE_CLAMSCAN}")
        scanner.chmod(0o700)
        self.log = self.root / "scans.jsonl"
        patcher = patch.dict(os.environ, {"FAKE_CLAMSCAN_LOG": str(self.log)})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.settings = {
            "source": str(self.downloads), "staging": str(self.staging), "minimumAge": 0,
            "rules": [{"patterns": ["*"], "destination": str(self.destination)}],
            "scanner": str(scanner), "bsdtar": tool("bsdtar"), "unsquashfs": tool("unsquashfs") or "unsquashfs",
            "maxFileSize": 4096, "chunkSize": 2048, "chunkOverlap": 64, "autoScanCap": 1024 * 1024,
            "freeSpaceMargin": 0, "extractionRatio": 4,
        }
        self.history = sorter.History(self.root / "history.sqlite3")
        self.addCleanup(self.history.connection.close)

    def scans(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def write(self, name, data):
        path = self.downloads / name
        path.write_bytes(data)
        return path

    def zip(self, name, members, compression=None):
        import zipfile

        path = self.downloads / name if "/" not in name else Path(name)
        with zipfile.ZipFile(path, "w", compression or zipfile.ZIP_STORED) as archive:
            for member, data in members.items():
                archive.writestr(member, data)
        return path

    def inspect(self, path):
        self.staging.mkdir(parents=True, exist_ok=True)
        return sorter.inspect_file(path, self.settings)

    def run_sorter(self):
        sorter.sort_downloads(self.settings, self.history)
        sorter.sort_downloads(self.settings, self.history)

    def assert_staging_empty(self):
        self.assertEqual([p for p in self.staging.iterdir()] if self.staging.exists() else [], [])

    def test_small_file_is_scanned_directly(self):
        path = self.write("small.txt", b"harmless")
        self.assertEqual(self.inspect(path)[0], "clean")
        self.assertEqual(len(self.scans()), 1)

    def test_zip_with_clean_members_is_clean_and_each_member_scanned(self):
        path = self.zip("bundle.zip", {"a.bin": random_bytes(3000), "dir/b.bin": random_bytes(3000)})
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("clean", None), detail)
        scanned = [entry for batch in self.scans() for entry in batch]
        self.assertEqual(sorted(size for _, size, _ in scanned), [3000, 3000])
        self.assert_staging_empty()

    def test_threat_inside_archive_is_blocked_with_member_name(self):
        path = self.zip("bundle.zip", {"a.bin": random_bytes(3000), "bad/evil.txt": b"EVILSIGNATURE" + random_bytes(3000)})
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "threat"))
        self.assertIn("bundle.zip/bad/evil.txt: Fake.Signature FOUND", detail)

    def test_nested_archives_respect_the_depth_limit(self):
        inner = self.zip(str(self.root / "inner.zip"), {"payload.bin": random_bytes(5000)})
        path = self.zip("outer.zip", {"inner.zip": inner.read_bytes()})
        self.settings["maxExtractionDepth"] = 1
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "unscannable"))
        self.assertIn("nested more than 1 levels", detail)
        self.settings["maxExtractionDepth"] = 2
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_partial", "partial"))
        self.assertIn("outer.zip/inner.zip/payload.bin", detail)

    def test_path_traversal_and_symlink_members_are_refused(self):
        import io
        import tarfile

        for kind in ("traversal", "symlink"):
            with self.subTest(kind=kind):
                path = self.downloads / f"{kind}.tar"
                with tarfile.open(path, "w") as archive:
                    def add(name, data=b"", **fields):
                        info = tarfile.TarInfo(name)
                        info.size = len(data)
                        for key, value in fields.items():
                            setattr(info, key, value)
                        archive.addfile(info, io.BytesIO(data))
                    add("padding.bin", random_bytes(3000))
                    if kind == "traversal":
                        add("../../escaped.txt", b"escaped")
                    else:
                        add("link", type=tarfile.SYMTYPE, linkname=str(self.root))
                        add("link/escaped.txt", b"escaped")
                status, detail, hold = self.inspect(path)
                self.assertEqual((status, hold), ("scan_blocked", "unscannable"), detail)
                self.assertIn("unsafe member paths", detail)
                self.assertFalse(any(self.root.rglob("escaped.txt")))
                self.assert_staging_empty()

    def test_archive_bomb_exceeding_extracted_bytes_is_blocked(self):
        import zipfile

        path = self.zip("bomb.zip", {"pad.bin": random_bytes(5000), "zeros.bin": bytes(4 * 1024 * 1024)},
                        zipfile.ZIP_DEFLATED)
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "unscannable"))
        self.assertIn("possible archive bomb", detail)
        self.assert_staging_empty()

    def test_encrypted_archive_is_held_with_clear_detail(self):
        path = self.zip("secret.zip", {"a.bin": random_bytes(5000)})
        data = bytearray(path.read_bytes())
        # Set the "encrypted" flag in the local and central directory headers.
        for signature, flag_offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
            position = data.index(signature)
            data[position + flag_offset] |= 1
        path.write_bytes(bytes(data))
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "unscannable"), detail)
        self.assertIn("encrypted", detail)

    def test_elf_with_appended_squashfs_is_unpacked_without_running_it(self):
        import struct
        import subprocess

        mksquashfs = tool("mksquashfs")
        if not mksquashfs or not tool("unsquashfs"):
            self.skipTest("mksquashfs/unsquashfs (squashfsTools) are not on PATH")
        tree = self.root / "tree"
        (tree / "bin").mkdir(parents=True)
        (tree / "bin/tool").write_bytes(random_bytes(3000))
        (tree / "bin/evil").write_bytes(b"EVILSIGNATURE" + random_bytes(100))
        (tree / "link").symlink_to("/etc/passwd")
        image = self.root / "payload.squashfs"
        subprocess.run([mksquashfs, str(tree), str(image), "-noappend", "-quiet", "-no-progress", "-comp", "gzip",
                        "-all-root"], check=True, capture_output=True)
        # A minimal ELF64 header whose section table ends at byte 192.
        header = bytearray(192)
        header[:7] = b"\x7fELF\x02\x01\x01"
        struct.pack_into("<Q", header, 0x28, 64)
        struct.pack_into("<HH", header, 0x3A, 64, 2)
        path = self.write("tool.AppImage", bytes(header) + image.read_bytes())
        path.chmod(0o600)
        self.assertEqual(sorter.appended_squashfs_offset(path), 192)
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "threat"), detail)
        self.assertIn("tool.AppImage/bin/evil", detail)
        scanned = [entry for batch in self.scans() for entry in batch]
        self.assertIn(192, [size for _, size, _ in scanned])  # The ELF runtime itself.
        self.assert_staging_empty()

    def test_oversize_unpackable_file_is_chunk_scanned_held_then_approved(self):
        path = self.write("Video.bin", random_bytes(7000))
        self.run_sorter()
        row = self.history.get(path)
        self.assertEqual((row["status"], row["hold"]), ("scan_partial", "partial"))
        self.assertTrue(path.exists())
        self.assertEqual(list(self.destination.iterdir()), [])
        alert = self.history.connection.execute("SELECT * FROM alerts WHERE active=1").fetchone()
        self.assertEqual(alert["title"], "Scanned in part — approve to release")
        self.assertIn("--approve", alert["body"])
        chunks = [batch[0][1] for batch in self.scans()]
        self.assertEqual(chunks, [2048, 2048, 2048, 1048])  # 64-byte overlaps cover 7000 bytes.
        self.assertTrue(all(size <= 4096 for size in chunks))
        # Held: neither the timer nor the five-minute retry window rescans it.
        self.history.connection.execute("UPDATE files SET attempted=0")
        self.run_sorter()
        self.assertEqual(len(self.scans()), 4)
        with contextlib.redirect_stdout(io.StringIO()) as output:
            sorter.approve_download(self.history, path, self.settings)
        self.assertIn("Approved:", output.getvalue())
        self.assertEqual(self.history.connection.execute(
            "SELECT * FROM alerts WHERE active=1 AND urgency='critical'").fetchall(), [])
        self.run_sorter()
        self.assertFalse(path.exists())
        self.assertTrue((self.destination / "video.bin").exists())
        self.assertEqual(len(self.scans()), 4)  # Released by digest, not rescanned.

    def test_cli_approve_and_force_flag_validation(self):
        import sys

        path = self.write("held.bin", random_bytes(7000))
        self.run_sorter()
        config = self.root / "config.json"
        config.write_text(json.dumps(self.settings))
        base = ["download-sorter", "--config", str(config), "--state", str(self.root / "history.sqlite3")]
        with patch.object(sorter, "send_notification", return_value=True), \
                contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()):
            with patch.object(sys, "argv", base + ["--force"]):
                self.assertEqual(sorter.main(), 1)
            with patch.object(sys, "argv", base + ["--approve", str(path)]):
                self.assertEqual(sorter.main(), 0)
        self.assertIn(f"Approved: {path}", output.getvalue())
        self.assertEqual(len(self.history.connection.execute("SELECT * FROM approvals").fetchall()), 1)

    def test_approval_only_releases_matching_contents(self):
        path = self.write("data.bin", random_bytes(7000))
        self.run_sorter()
        with contextlib.redirect_stdout(io.StringIO()):
            sorter.approve_download(self.history, path, self.settings)
        path.write_bytes(random_bytes(7000))
        self.run_sorter()
        self.assertTrue(path.exists())
        self.assertEqual(self.history.get(path)["status"], "scan_partial")
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_signature_spanning_a_chunk_boundary_is_found_thanks_to_overlap(self):
        data = bytearray(random_bytes(7000))
        data[2040:2053] = b"EVILSIGNATURE"
        path = self.write("span.bin", bytes(data))
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "threat"))
        self.assertIn("span.bin [bytes 1984-4032]", detail)
        self.settings["chunkOverlap"] = 0
        self.assertEqual(self.inspect(path)[0], "scan_partial")

    def test_approval_is_refused_for_detected_threats_without_force(self):
        path = self.write("evil.bin", b"EVILSIGNATURE" + random_bytes(100))
        self.run_sorter()
        self.assertEqual(self.history.get(path)["hold"], "threat")
        with self.assertRaisesRegex(ValueError, "--force"):
            sorter.approve_download(self.history, path, self.settings)
        with contextlib.redirect_stdout(io.StringIO()) as output:
            sorter.approve_download(self.history, path, self.settings, force=True)
        self.assertIn("Forced", output.getvalue())
        self.run_sorter()
        self.assertTrue((self.destination / "evil.bin").exists())

    def test_approval_is_refused_when_not_held_or_transient(self):
        clean = self.write("clean.txt", b"harmless")
        sorter.sort_downloads(self.settings, self.history)
        with self.assertRaisesRegex(ValueError, "Not currently held"):
            sorter.approve_download(self.history, clean, self.settings)
        self.settings["scanner"] = str(self.root / "missing-scanner")
        sorter.sort_downloads(self.settings, self.history)
        self.assertEqual(self.history.get(clean)["status"], "scan_error")
        with self.assertRaisesRegex(ValueError, "transient"):
            sorter.approve_download(self.history, clean, self.settings)

    def test_download_above_the_cap_is_blocked_unscanned_and_approvable(self):
        self.settings["autoScanCap"] = 6000
        path = self.write("huge.iso", random_bytes(7000))
        self.run_sorter()
        row = self.history.get(path)
        self.assertEqual((row["status"], row["hold"]), ("scan_blocked", "oversize"))
        self.assertEqual(self.scans(), [])
        self.assert_staging_empty()
        with contextlib.redirect_stdout(io.StringIO()):
            sorter.approve_download(self.history, path, self.settings)
        self.run_sorter()
        self.assertTrue((self.destination / "huge.iso").exists())
        self.assertEqual(self.scans(), [])

    def test_staging_is_removed_after_success_and_exceptions(self):
        path = self.zip("bundle.zip", {"a.bin": random_bytes(3000), "b.bin": random_bytes(3000)})
        with patch.object(sorter.LayeredScan, "scan_members", side_effect=OSError("disk failure")):
            status, detail, _ = self.inspect(path)
        self.assertEqual(status, "scan_error")
        self.assertIn("disk failure", detail)
        self.assert_staging_empty()
        with patch.object(sorter.LayeredScan, "scan_members", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                self.inspect(path)
        self.assert_staging_empty()
        self.run_sorter()
        self.assertTrue((self.destination / "bundle.zip").exists())
        self.assert_staging_empty()

    def tar(self, name, entries, trailer=b""):
        import tarfile

        path = self.downloads / name
        with tarfile.open(path, "w") as archive:
            for member, data, kind in entries:
                info = tarfile.TarInfo(member)
                info.type = kind
                if kind == tarfile.SYMTYPE:
                    info.linkname = data
                    archive.addfile(info)
                else:
                    info.size = len(data)
                    archive.addfile(info, io.BytesIO(data))
        with open(path, "ab") as appended:
            appended.write(trailer)
        return path

    def test_duplicate_member_paths_cannot_hide_an_earlier_member(self):
        import tarfile
        import warnings

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")  # zipfile warns about the duplicate name.
            path = self.zip("dup.zip", {"pad.bin": random_bytes(3000), "pad2.bin": random_bytes(3000)})
            import zipfile
            with zipfile.ZipFile(path, "a") as archive:
                archive.writestr("setup.com", b"EVILSIGNATURE")
                archive.writestr("setup.com", b"benign")
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "unscannable"), detail)
        self.assertIn("duplicate or overlapping member paths", detail)
        # A later link entry replacing an earlier regular file, in a tar.
        path = self.tar("dup.tar", [("pad.bin", random_bytes(5000), tarfile.REGTYPE),
                                    ("setup.com", b"EVILSIGNATURE", tarfile.REGTYPE),
                                    ("setup.com", "pad.bin", tarfile.SYMTYPE)])
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "unscannable"), detail)
        self.assertIn("lists 3 file or link entries but 2 were unpacked", detail)
        self.assert_staging_empty()

    def test_empty_members_do_not_fail_a_layered_scan(self):
        path = self.zip("pkg.zip", {"pkg/__init__.py": b"", "pkg/.keep": b"", "pkg/data.bin": random_bytes(5000),
                                    "pkg/b.bin": random_bytes(3000)})
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_partial", "partial"), detail)
        self.assertIn("(2 empty)", detail)
        scanned = [entry for batch in self.scans() for entry in batch]
        self.assertNotIn(0, [size for _, size, _ in scanned])

    def test_real_detection_is_not_downgraded_by_earlier_heuristic_members(self):
        members = {"a-enc.bin": b"ENCRYPTEDMARK" + random_bytes(10)}
        members.update({f"text/{n:03}.txt": random_bytes(50) for n in range(80)})
        members["z/eicar.com"] = b"EVILSIGNATURE"
        members["pad.bin"] = random_bytes(5000)
        path = self.zip("mixed.zip", members)
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "threat"), detail)
        self.assertIn("mixed.zip/z/eicar.com: Fake.Signature FOUND", detail)

    def test_well_formed_zip_is_clean_but_unread_bytes_make_it_partial(self):
        import zipfile

        members = {"a.bin": random_bytes(3000), "b.txt": b"text " * 1000}
        path = self.zip("tight.zip", members, zipfile.ZIP_DEFLATED)
        self.assertEqual(self.inspect(path)[:3:2], ("clean", None))
        # A local entry missing from the central directory is never unpacked.
        hidden = b"PK\x03\x04" + bytes(26) + b"EVILSIGNATURE"
        path = self.write("gap.zip", self.with_hidden_entry(members, hidden))
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "threat"), detail)
        self.assertIn("gap.zip [raw container bytes]", detail)
        path = self.write("gap.zip", self.with_hidden_entry(members, b"PK\x03\x04" + bytes(26) + b"harmless"))
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_partial", "partial"), detail)
        self.assertIn("unexplained bytes", detail)
        self.assertIn("gap.zip [raw container bytes]", detail)
        self.assert_staging_empty()

    def with_hidden_entry(self, members, hidden):
        import zipfile

        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            for member, data in members.items():
                archive.writestr(member, data)
            # Bytes written between the entries and the central directory.
            archive.fp.write(hidden)
            archive.start_dir = archive.fp.tell()
        return buffer.getvalue()

    def test_bytes_hidden_after_a_deflate_stream_are_not_called_clean(self):
        import struct
        import zipfile
        import zlib

        payload, pad = b"text " * 1000, random_bytes(5000)
        compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
        stream = compressor.compress(payload) + compressor.flush() + b"hidden after the stream"
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("pad.bin", pad)
            info = zipfile.ZipInfo("a.txt")
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, payload)
        data = buffer.getvalue()
        # Rebuild a.txt's data region with the padded stream and fix its sizes.
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            entry = archive.getinfo("a.txt")
        start = entry.header_offset + 30 + len("a.txt") + len(entry.extra)
        end = start + entry.compress_size
        grown = len(stream) - entry.compress_size
        data = bytearray(data[:start] + stream + data[end:])
        struct.pack_into("<I", data, entry.header_offset + 18, len(stream))
        central = data.index(b"PK\x01\x02", start + len(stream))
        while data[central + 46:central + 51] != b"a.txt":
            central = data.index(b"PK\x01\x02", central + 4)
        struct.pack_into("<I", data, central + 20, len(stream))
        end_record = data.rindex(b"PK\x05\x06")
        offset, = struct.unpack_from("<I", data, end_record + 16)
        struct.pack_into("<I", data, end_record + 16, offset + grown)
        path = self.write("trailing.zip", bytes(data))
        # libarchive itself rejects the size mismatch; the coverage proof does too.
        self.assertNotEqual(self.inspect(path)[0], "clean")
        unpacked = self.root / "unpacked"
        unpacked.mkdir()
        (unpacked / "a.txt").write_bytes(payload)
        (unpacked / "pad.bin").write_bytes(pad)
        reason = sorter.zip_coverage(path, {"a.txt": unpacked / "a.txt", "pad.bin": unpacked / "pad.bin"},
                                     time.monotonic() + 60)
        self.assertIn("does not end exactly", reason)

    def test_data_after_a_tar_end_marker_is_scanned_and_held(self):
        import tarfile
        import zipfile

        appended = io.BytesIO()
        with zipfile.ZipFile(appended, "w") as archive:
            archive.writestr("payload.com", b"EVILSIGNATURE")
        entries = [(f"m{n}.bin", random_bytes(3000), tarfile.REGTYPE) for n in range(2)]
        path = self.tar("padded.tar", entries, appended.getvalue())
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_blocked", "threat"), detail)
        self.assertIn("padded.tar [raw container bytes]", detail)
        path = self.tar("plain.tar", entries)
        status, detail, hold = self.inspect(path)
        self.assertEqual((status, hold), ("scan_partial", "partial"), detail)
        self.assertIn("Unpacking could not be shown to read every byte of: plain.tar", detail)

    def test_stale_snapshots_and_unpack_trees_are_removed_at_the_start_of_a_run(self):
        self.staging.mkdir(parents=True)
        (self.staging / "snapshot-abc.zip").write_bytes(b"old snapshot")
        (self.staging / "tmpold.zip").write_bytes(b"older snapshot name")
        (self.staging / "unpack-x/members").mkdir(parents=True)
        (self.staging / "unpack-x/members/0").write_bytes(b"member")
        (self.staging / "unpack-x/members").chmod(0o500)
        sorter.sort_downloads(self.settings, self.history)
        self.assert_staging_empty()

    def test_termination_during_a_scan_removes_the_staged_snapshot(self):
        self.write("bundle.bin", random_bytes(100))
        sorter.sort_downloads(self.settings, self.history)
        with patch.object(sorter, "inspect_file", side_effect=lambda *_: sorter.stop_on_signal(15, None)):
            with self.assertRaises(SystemExit) as stopped:
                sorter.sort_downloads(self.settings, self.history)
        self.assertEqual(stopped.exception.code, 143)
        self.assert_staging_empty()

    def test_extractor_dies_with_its_parent(self):
        import subprocess
        import sys

        script = self.root / "parent.py"
        script.write_text(
            "import importlib.util, subprocess, sys, os\n"
            "spec = importlib.util.spec_from_file_location('s', sys.argv[1])\n"
            "s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)\n"
            "child = subprocess.Popen(['sleep', '30'], start_new_session=True, preexec_fn=s.parent_death_signal())\n"
            "print(child.pid, flush=True)\nos._exit(0)\n")
        output = subprocess.run([sys.executable, "-I", str(script), sorter.__file__], capture_output=True,
                                text=True, check=True, timeout=20).stdout
        pid = int(output)
        for _ in range(50):
            try:
                with open(f"/proc/{pid}/stat") as status:
                    if status.read().split(") ", 1)[1].startswith("Z"):
                        break
            except OSError:  # Already reaped.
                break
            time.sleep(0.1)
        else:
            os.kill(pid, 9)
            self.fail("orphaned extractor kept running after its parent died")

    def test_held_threat_is_not_downgraded_to_an_approvable_oversize_hold(self):
        path = self.write("evil.bin", b"EVILSIGNATURE" + random_bytes(100))
        self.run_sorter()
        self.assertEqual(self.history.get(path)["hold"], "threat")
        self.settings["autoScanCap"] = 50
        self.settings["maxFileSize"] = 50
        self.settings["chunkSize"] = 40
        self.settings["chunkOverlap"] = 8
        self.history.connection.execute("UPDATE files SET attempted=0")
        self.run_sorter()
        self.assertEqual(self.history.get(path)["hold"], "threat")
        with self.assertRaisesRegex(ValueError, "--force"):
            sorter.approve_download(self.history, path, self.settings)

    def test_large_transient_failures_back_off(self):
        path = self.downloads / "big.zip"
        self.assertEqual(sorter.retry_delay(self.history, path, False), 300)
        self.assertEqual(sorter.retry_delay(self.history, path, True), 3600)
        for count in range(1, 9):
            self.history.issue(path, "scan_error", f"failure {count}")
        self.assertEqual(sorter.retry_delay(self.history, path, True), 3600 * 64)
        self.history.event("approved", path)
        self.history.issue(path, "scan_error", "failure after approval")
        self.assertEqual(sorter.retry_delay(self.history, path, True), 3600)

    def test_existing_database_gains_hold_column_and_approvals_table(self):
        import sqlite3

        database = self.root / "old.sqlite3"
        connection = sqlite3.connect(database)
        connection.execute("CREATE TABLE files (path TEXT PRIMARY KEY, signature TEXT NOT NULL, status TEXT NOT NULL,"
                           " digest TEXT, attempted REAL NOT NULL, policy TEXT NOT NULL)")
        connection.execute("INSERT INTO files VALUES ('/x', '[]', 'clean', NULL, 0, '')")
        connection.commit()
        connection.close()
        history = sorter.History(database)
        self.addCleanup(history.connection.close)
        self.assertIsNone(history.get("/x")["hold"])
        self.assertFalse(history.approved("digest"))


@unittest.skipUnless(os.environ.get("CLAMSCAN_TEST_BINARY"), "Set CLAMSCAN_TEST_BINARY for real ClamAV tests")
class RealClamAVTests(unittest.TestCase):
    def setUp(self):
        import hashlib
        import sys

        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "Downloads"
        self.source.mkdir()
        self.eicar = b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
        self.database = self.root / "test.hdb"
        self.database.write_text(f"{hashlib.md5(self.eicar).hexdigest()}:{len(self.eicar)}:Eicar-Test-Signature\n")
        # An isolated one-signature fixture cannot test official CVD freshness.
        # Only this test adapter removes the CVD age flag; production never does.
        wrapper = self.root / "scanner"
        wrapper.write_text(f"#!{sys.executable}\nimport subprocess, sys\nsys.exit(subprocess.call("
                           f"[{os.environ['CLAMSCAN_TEST_BINARY']!r}] + "
                           "[a for a in sys.argv[1:] if not a.startswith('--fail-if-cvd-older-than=')]))\n")
        wrapper.chmod(0o700)
        self.history = sorter.History(self.root / "history.sqlite3")
        self.addCleanup(self.history.connection.close)
        self.settings = {"source": str(self.source), "staging": str(self.root / "staging"),
                         "minimumAge": 0, "scanner": str(wrapper), "signatureDirectory": str(self.database)}

    def process(self, contents):
        file = self.source / "Downloaded File.txt"
        file.write_bytes(contents)
        sorter.sort_downloads(self.settings, self.history, rename_only=True)
        sorter.sort_downloads(self.settings, self.history, rename_only=True)
        return file

    def test_real_clean_scan_renames_quietly(self):
        original = self.process(b"Harmless download fixture\n")
        self.assertFalse(original.exists())
        self.assertTrue((self.source / "downloaded-file.txt").exists())
        self.assertEqual(self.history.connection.execute("SELECT COUNT(*) FROM alerts").fetchone()[0], 0)

    def test_real_eicar_detection_preserves_file_and_raises_critical_issue(self):
        original = self.process(self.eicar)
        self.assertTrue(original.exists())
        alert = self.history.connection.execute("SELECT * FROM alerts WHERE active=1").fetchone()
        self.assertEqual(alert["urgency"], "critical")
        self.assertIn("Eicar", alert["body"])

    @unittest.skipUnless(tool("bsdtar"), "bsdtar (libarchive) is not on PATH")
    def test_real_layered_scan_maps_member_detections_and_clean_members(self):
        import zipfile

        self.settings.update({"bsdtar": tool("bsdtar"), "maxFileSize": 4096, "chunkSize": 2048,
                              "chunkOverlap": 64, "freeSpaceMargin": 0})
        archive = self.root / "bundle.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("clean one.bin", random_bytes(3000))
            bundle.writestr("odd\tname.bin", random_bytes(3000))
        self.assertEqual(sorter.inspect_file(archive, self.settings)[0], "clean")
        with zipfile.ZipFile(archive, "a") as bundle:
            bundle.writestr("nested/eicar.com", self.eicar)
        status, detail, hold = sorter.inspect_file(archive, self.settings)
        self.assertEqual((status, hold), ("scan_blocked", "threat"))
        self.assertIn("bundle.zip/nested/eicar.com: Eicar-Test-Signature", detail)

    @unittest.skipUnless(tool("bsdtar"), "bsdtar (libarchive) is not on PATH")
    def test_real_empty_members_and_downloads_are_clean(self):
        import zipfile

        self.settings.update({"bsdtar": tool("bsdtar"), "maxFileSize": 4096, "chunkSize": 2048,
                              "chunkOverlap": 64, "freeSpaceMargin": 0})
        archive = self.root / "pkg.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("pkg/__init__.py", b"")
            bundle.writestr("pkg/a.bin", random_bytes(3000))
            bundle.writestr("pkg/b.bin", random_bytes(3000))
        status, detail, hold = sorter.inspect_file(archive, self.settings)
        self.assertEqual((status, hold), ("clean", None), detail)
        empty = self.root / "empty.txt"
        empty.write_bytes(b"")
        self.assertEqual(sorter.scan_file(empty, self.settings)[0], "clean")

    @unittest.skipUnless(tool("bsdtar"), "bsdtar (libarchive) is not on PATH")
    def test_real_detection_is_not_hidden_behind_encrypted_member_alerts(self):
        import zipfile

        self.settings.update({"bsdtar": tool("bsdtar"), "maxFileSize": 4096, "chunkSize": 2048,
                              "chunkOverlap": 64, "freeSpaceMargin": 0})
        encrypted = self.root / "enc.zip"
        with zipfile.ZipFile(encrypted, "w") as bundle:
            bundle.writestr("secret.txt", b"secret " * 10)
        data = bytearray(encrypted.read_bytes())
        for signature, flag_offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
            data[data.index(signature) + flag_offset] |= 1
        archive = self.root / "mixed.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("a-enc.zip", bytes(data))
            for number in range(80):
                bundle.writestr(f"text/file-{number:03}.txt", f"harmless text {number}\n" * 20)
            bundle.writestr("z/eicar.com", self.eicar)
        status, detail, hold = sorter.inspect_file(archive, self.settings)
        self.assertEqual((status, hold), ("scan_blocked", "threat"), detail)
        self.assertIn("mixed.zip/z/eicar.com: Eicar-Test-Signature", detail)

    def test_real_zero_signature_scan_is_rejected(self):
        # ClamAV 1.4.3 can report OK with zero signatures when an HDB-only
        # database is supplied alongside --fail-if-cvd-older-than. Reject it.
        self.settings["scanner"] = os.environ["CLAMSCAN_TEST_BINARY"]
        original = self.process(self.eicar)
        self.assertTrue(original.exists())
        self.assertEqual(self.history.get(original)["status"], "scan_error")


if __name__ == "__main__":
    unittest.main()
