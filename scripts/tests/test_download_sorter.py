import importlib.util
import os
from pathlib import Path
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

    def test_notifications_use_persistent_critical_urgency_and_escape_markup(self):
        row = {"key": "test", "title": "Problem", "body": "bad <file>.pdf", "urgency": "critical"}
        with patch.object(sorter.subprocess, "run") as command:
            self.assertTrue(sorter.send_notification(row, {}))
            flags = command.call_args.args[0]
            self.assertIn("--urgency=critical", flags)
            self.assertIn("--expire-time=0", flags)
            self.assertEqual(flags[-1], "bad &lt;file&gt;.pdf")


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

    def test_real_zero_signature_scan_is_rejected(self):
        # ClamAV 1.4.3 can report OK with zero signatures when an HDB-only
        # database is supplied alongside --fail-if-cvd-older-than. Reject it.
        self.settings["scanner"] = os.environ["CLAMSCAN_TEST_BINARY"]
        original = self.process(self.eicar)
        self.assertTrue(original.exists())
        self.assertEqual(self.history.get(original)["status"], "scan_error")


if __name__ == "__main__":
    unittest.main()
