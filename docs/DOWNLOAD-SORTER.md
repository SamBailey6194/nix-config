# Download automation

This is a deterministic Python script using ClamAV, SQLite and desktop
notifications. It does not use AI, models, network classification services or
filename guesses. Home Manager generates each machine's settings from the
shared module; systemd runs it, and `just` provides manual commands.

## Automatic behaviour

Desktop stages and above enable the download processor and hourly ClamAV
signature updates. After rebuilding, the user timer checks the configured
Downloads directory and its subdirectories every minute during a graphical
session. A file must be at least 120 seconds old and unchanged across two checks
before processing begins. Existing downloads are processed too.

1. Copy the file into a private staging directory outside Downloads.
2. Scan the snapshot with `clamscan`, using `/var/lib/clamav` signatures. Require
   exit zero, an explicit OK result, loaded signatures and one scanned file.
3. If the scan succeeds, convert the filename to kebab case quietly.
4. If automatic routing is enabled, use an explicit rule or eligible recorded
   choices to move the scanned contents and show the full destination.

A scan success or filename change produces no desktop notification or sound.
Renaming happens even if no routing rule is known. By default, routing is
disabled, so clean files stay in Downloads with normalised names.

Threat detections, encrypted archives/documents, scan limits, missing/stale
signatures, scan errors, timeouts, filesystem failures and routing uncertainty
raise persistent critical desktop notifications. Critical alerts also attempt
to play the desktop warning sound and are written to the journal and SQLite.
The existing Dunst configuration displays critical notifications in red until
dismissed. Unresolved issues repeat hourly. Failed notification delivery stays
queued for the next timer run, and causes a nonzero service exit.

Blocked scans leave the original file untouched. The script does not delete or
quarantine files. Resolving a notification does not grant scan approval.
Failed/blocked scans are retried after five minutes; `downloads-retry` requests
an immediate fresh scan of settled downloads.

## Configuration

Add rules to the appropriate `home/<machine>-<stage>.nix`, or put common rules
in an imported Home Manager module. Keep routing disabled until destinations
are ready and previews look correct.

```nix
services.downloadSorter = {
  enable = true;
  automatic = false; # Routing to other folders stays opt-in.
  automaticRenaming = true;
  normalizeNames = true;
  learnedRouting = false;
  minimumChoices = 5;
  rules = [
    {
      patterns = [ "invoice-*.pdf" ];
      destination = "${config.xdg.userDirs.documents}/Invoices";
    }
    {
      patterns = [ "*.jpg" "*.jpeg" "*.png" ];
      destination = config.xdg.userDirs.pictures;
    }
  ];
};
```

The source defaults to `config.xdg.userDirs.download`. Paths support `$HOME` and
`~`; expanded paths must be absolute. Rules match case-insensitive filename
globs against the original and normalised name. The first explicit rule wins.
Destinations must be outside Downloads and already exist. If a destination is
unavailable, a clean file is renamed in place and a critical issue is raised.
Directory existence does not verify that an external disk or cloud filesystem
is mounted; configure those destinations only when the mount is available.

Set `automatic = true;` and rebuild to enable timer-driven routing. Set
`learnedRouting = true;` too if you want recorded choices to supply destinations
when no explicit rule matches. Missing or conflicting routing evidence always
leaves the file in Downloads and raises a critical issue.

With `automatic = false;` and `automaticRenaming = false;`, the timer still
scans downloads but makes no naming or routing changes. `normalizeNames = false;`
retains original names on manual and routed processing too. `enable = false;`
disables the entire module and its timer.

The optional Rust malware monitor is independent. This workflow invokes ClamAV
directly and does not require the Rust monitor or the `clamd` daemon. The Home
Manager module asserts that the NixOS ClamAV updater is enabled.

## Naming

`Annual Report_2026 (Final).PDF` becomes `annual-report-2026-final.pdf`.
Spaces, underscores, stem dots and punctuation become hyphens; repeated hyphens
collapse. Camel case is split into words. Accented letters and a leading dot on
hidden files are retained. Extensions are lowercased, including `.tar.gz`.
Stems with no letters or digits use `download`.

Normalisation collisions receive `-2`, `-3`, etc. before the extension. An
already normalised file whose routing destination is occupied raises an issue
and stays in place. Existing destination files and dangling symlinks are never
overwritten. Renames and moves publish a complete, hash-verified copy of the
scanned snapshot, retaining timestamps and ordinary read/write permissions.

## SQLite and recorded choices

SQLite stores file observations, scan outcomes, SHA-256 hashes, renames, moves,
matched rules, issues, notification delivery and explicitly recorded choices.
The default database is
`$XDG_STATE_HOME/download-sorter/history.sqlite3`, normally
`~/.local/state/download-sorter/history.sqlite3`. The database and staging area
must be outside Downloads. `--state /absolute/path/history.sqlite3` selects
another database. Earlier JSON observation files are unused; files are observed
and scanned again after upgrading to SQLite.

After a clean download has been renamed, manually file it in the intended
destination and record your choice:

```sh
just downloads-record-choice 'invoice-*.pdf' "$HOME/Documents/Invoices/invoice-january.pdf"
```

The pattern must match the filename, and the contents must have a successful
ClamAV scan in this database. Recording a choice does not move or scan the file.
Recording the same pattern and file contents again updates the choice rather
than counting another sample. Use it again after moving that file to correct
its recorded destination.

A learned pattern requires at least five distinct scanned file contents, all
recorded to the same destination. Different destinations for one pattern,
insufficient samples, or matching learned patterns pointing to different
destinations cause uncertainty. Explicit ordered rules take priority. Automatic
moves and renames never become learning samples, so the script cannot reinforce
its own routing decisions. Evidence stays local to each machine.

## Commands

```sh
just downloads-preview        # Preview scan/name/routing decisions.
just downloads-preview-names  # Preview names without routing.
just downloads-check          # Scan and rename settled files without routing.
just downloads-retry          # Fresh scan after resolving a problem.
just downloads-history        # Last 50 recorded events.
just downloads-issues         # Active critical issues.
journalctl --user -u download-sorter.service
```

Previews do not scan, rename, move, notify or create persistent state. They read
existing evidence in read-only mode. Manual `download-sorter` runs apply routing
rules; use `--rename-only` or `--scan-only` to limit a run. All actual processing
requires ClamAV approval, including manual runs.

For use before rebuilding, write a JSON configuration and invoke the script:

```json
{
  "source": "$HOME/Downloads",
  "minimumAge": 120,
  "normalizeNames": true,
  "rules": []
}
```

```sh
python3 scripts/download-sorter.py --config /absolute/path/rules.json --rename-only --dry-run
```

## Scan coverage and verification

The default per-file size limit is 1 GiB (`maxFileSize`), signature age limit is
three days (`maxSignatureAge`), and scan timeout is 300 seconds (`scanTimeout`).
ClamAV also enforces a 2 GiB aggregate container scan limit. Exceeding a limit
raises an issue rather than approving a skipped scan. Stable successful scan
results are reused until the file metadata or scan policy changes; changed
contents require another scan.

The processor covers regular files in the configured source, including hidden
and nested files. Symlinks, browser partial files, partial directories and files
with partial companions are excluded. Settlement checks cannot distinguish a
finished download from a paused writer using a final filename. Files saved
outside the configured source are not covered. This is post-download scanning;
it does not intercept browser writes or prevent opening a file before the timer
scans it. Interrupted processing may leave staging files or both copies, with
publication recorded before the source is removed.

Run the focused tests with:

```sh
python3 -m unittest discover -s scripts/tests -p test_download_sorter.py
CLAMSCAN_TEST_BINARY=/absolute/path/to/clamscan python3 -m unittest discover -s scripts/tests -p test_download_sorter.py
```

Real ClamAV tests use an isolated one-signature database and the harmless EICAR
test file. Their adapter omits only the official CVD freshness check for the
local signature fixture; production always enforces it. Another real-binary
test rejects an OK result with zero loaded signatures.
