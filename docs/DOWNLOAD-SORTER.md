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
   Snapshots too large for ClamAV are scanned in layers (see below).
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
quarantine files. Resolving a notification does not grant scan approval; only
`download-sorter --approve` does (see "Held downloads and approval").
Failed/blocked scans are retried after five minutes; `downloads-retry` requests
an immediate fresh scan of settled downloads. Held results for files larger
than `maxFileSize` are kept until the contents or scan policy change, or a
retry is requested, because each layered scan can take a long time; transient
errors on such files are retried after an hour, doubling with each consecutive
failure up to 64 hours. A held ClamAV detection stays a `threat` hold even if
the file later exceeds a lowered `autoScanCap`.

## Large downloads: layered scanning

ClamAV 1.5 cannot scan any single file over 2 GiB − 1 byte, whether it is the
download itself or a member inside an archive. Downloads are therefore handled
by size:

| Size | Handling |
|------|----------|
| Up to `maxFileSize` (2047 MiB) | Direct `clamscan` of the snapshot, as above. |
| Up to `autoScanCap` (50 GiB) | Unpacked in staging; every member scanned. Clean only for a ZIP whose every byte is accounted for; otherwise `scan_partial` (see below). |
| Above `autoScanCap` | Not scanned; held (`scan_blocked`) until approved. |

`maxFileSize` defaults to 2047 MiB, 1 MiB under ClamAV's hard limit; larger
values are rejected. `--max-scansize` is fixed at 4095 MiB: above any permitted
file, so a maximal file is never cut short by the aggregate limit, while a
container that expands further raises `Heuristics.Limits.Exceeded` (a block)
rather than a silently truncated scan. Disabling it (0) would remove that guard.

Unpacking happens in a fresh `0700` directory inside staging, removed in all
cases, including errors and interruptions. SIGTERM (logout, service stop) and
SIGHUP (closed terminal) are turned into a normal exit so the staged snapshot
and unpacked tree are removed, and extractors are started with a parent-death
signal so they never outlive the sorter. Anything still in staging at the start
of a run (snapshots, unpack trees) is a leftover of a killed run and is removed.
Extractors only read archives; nothing extracted is executed:

- **ELF with an appended SquashFS** (AppImage type 2, DaVinci Resolve's `.run`):
  the payload offset is read from the ELF header (`e_shoff + e_shentsize ×
  e_shnum`, as `appimage-exec -x` does) and checked for the `hsqs` magic, then
  `unsquashfs -no-xattrs -offset <n>` unpacks it. The ELF runtime bytes before
  the payload are scanned as a separate member.
- **SquashFS images**: `unsquashfs`.
- **Archives identified by magic bytes** (zip, tar and its compressors, 7z, rar,
  cab, xar, iso, cpio, ar/deb, rpm): `bsdtar` (libarchive) with
  `--no-same-owner --no-same-permissions --no-xattrs --no-acls --no-fflags`.
  bsdtar refuses `..` paths and extraction through symlinks and strips leading
  `/` by default (`-P` is never used). Files without known magic are not given
  to libarchive, whose mtree reader would copy host files named inside them.

Tools run from argument lists with `LC_ALL=C`, no terminal (a fixed wrong
passphrase makes encrypted entries fail rather than prompt), a per-file write
limit (`RLIMIT_FSIZE`) equal to the remaining extraction budget, and a timeout
of `scanTimeout + scanTimeoutPerGiB` × input GiB. Unpacking stops and the
download is held when:

- unpacked bytes exceed `extractionRatio` (4) × the download size, or
  `maxExtractedMembers` (100,000) entries are created — possible archive bomb;
- archives nest deeper than `maxExtractionDepth` (4) layers;
- members are encrypted or password-protected, or use unsafe paths;
- the format cannot be unpacked completely (held as `scan_error`, approvable).

Free space is checked before starting and while unpacking. The budget never
exceeds free space minus `freeSpaceMargin` (10 GiB); running short is a
transient `scan_error`, retried later, rather than a block.

After unpacking, entries are inspected with `lstat` and never followed.
Directories and regular files are made private (clearing setuid/setgid and
execute bits); symlinks, device nodes and other special entries carry no content
and are listed as skipped. Before extracting, `bsdtar -tv` lists the archive;
the number of file and link entries must equal what was unpacked, so a later
entry with the same path (a duplicate file, link or directory) cannot replace
an earlier member unscanned — such archives are held as `unscannable`.
Non-empty regular members up to `maxFileSize` are scanned in one
`clamscan --file-list` run that must report OK for every member (ClamAV reports
empty files as `Empty file`; they hold nothing to scan). Any detection names the
member, such as `download.zip/bin/tool: Signature FOUND`; real detections are
listed before limit/encryption alerts so a long report can never hide one.
Members still larger are unpacked recursively when they are archives, otherwise
chunk-scanned.

### Bytes the extractor never reads

Extractors read what a format's index points at, not every byte: data after a
tar end marker, a ZIP appended to another archive, ZIP entries missing from the
central directory, ISO content outside ISO 9660, or space inside a SquashFS
image that no file references would never be unpacked. A layered scan is
therefore `clean` only for a ZIP whose local entries tile the file from offset 0
to the central directory, which ends at its end record, which ends the file;
stored data must be exactly its range, each deflate stream must end on its last
recorded byte, directory entries must be empty, and every entry's decompressed
SHA-256 must equal the unpacked file of that name (which also proves libarchive
read it as this ZIP and not as another format the same bytes form). For every
other container (tar, 7z, ISO, SquashFS, ZIPs failing the check), the raw
container bytes are also chunk-scanned, so signatures in skipped data are still
found, and the result is `scan_partial`, naming the reason.

### Chunk scans and `scan_partial`

A file that is too large and cannot be unpacked further is copied into
`chunkSize` (1 GiB) chunks, one at a time, each scanned and deleted
immediately. Consecutive chunks share `chunkOverlap` (16 MiB), which is longer
than any ClamAV byte-pattern signature, so a match straddling a boundary lies
wholly inside the next chunk. Any detection blocks the download. If every chunk
is clean, the result is `scan_partial`: whole-file hash signatures and
file-type aware parsing cannot match chunked data, so the download is held,
not routed or renamed, with the notification "Scanned in part — approve to
release" listing the chunk-scanned members.

## Held downloads and approval

Held statuses are `scan_partial`, `scan_blocked` and `scan_error`; each records
a hold reason:

| Reason | Cause | Approval |
|--------|-------|----------|
| `partial` | Some members, or raw container bytes, were chunk-scanned | `--approve` |
| `oversize` | Larger than `autoScanCap`; not scanned | `--approve` |
| `unscannable` | Encrypted, unsafe or duplicate paths, archive bomb limits, unsupported format, ClamAV `Heuristics.Limits.Exceeded`/`Heuristics.Encrypted` only | `--approve` |
| `threat` | Any other ClamAV detection | `--approve --force` |
| none | Transient failure (stale/missing signatures, timeout, space) | Not approvable; fix and retry |

```sh
just approve-download "$HOME/Downloads/DaVinci_Resolve_Studio_21.1.1_Linux.zip"
download-sorter --approve /absolute/path --force  # Only for a confirmed false positive.
```

Approval refuses files that are not currently held, changed since they were
held, or differ from the scanned snapshot. It computes the file's SHA-256
(streaming), records the digest, path, time, previous status, hold reason and
whether `--force` was used in the `approvals` table, logs an `approved` event,
clears the alert and prints what was approved. On the next run the snapshot's
digest is compared again: only identical bytes are released (a `released`
event) and then renamed or routed as a clean download. Any change to the file
means a new scan. `--force` overrides a real ClamAV detection; use it only after
confirming a false positive.

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
just approve-download FILE    # Release a held download by its SHA-256.
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

The default per-file size limit is 2047 MiB (`maxFileSize`), the automatic
layered scan cap is 50 GiB (`autoScanCap`), the signature age limit is three
days (`maxSignatureAge`), and each scan or unpacking step may take 300 seconds
plus 300 seconds per GiB (`scanTimeout`, `scanTimeoutPerGiB`). Exceeding a limit
raises an issue rather than approving a skipped scan. Stable successful scan
results are reused until the file metadata or scan policy (including all of the
limits above and the extractor paths) changes; changed contents require another
scan.

The processor covers regular files in the configured source, including hidden
and nested files. Symlinks, browser partial files, partial directories and files
with partial companions are excluded. Settlement checks cannot distinguish a
finished download from a paused writer using a final filename. Files saved
outside the configured source are not covered. This is post-download scanning;
it does not intercept browser writes or prevent opening a file before the timer
scans it. A SIGKILL may leave staging files (removed by the next run) or both
copies, with publication recorded before the source is removed. A layered scan needs the
snapshot plus up to `extractionRatio` × its size in staging, so a 50 GiB
download can need over 200 GiB free; the free-space budget holds it otherwise.
A ZIP that passes the coverage check is not scanned raw, so its own metadata
(names, extra fields, comments, at most 64 KiB each) is not given to ClamAV;
no extractor produces it as file content.

Run the focused tests with:

```sh
python3 -I -m unittest discover -s scripts/tests -p test_download_sorter.py
CLAMSCAN_TEST_BINARY=/absolute/path/to/clamscan python3 -I -m unittest discover -s scripts/tests -p test_download_sorter.py
```

Layered-scan tests use a fake `clamscan` with 4 KiB/2 KiB limits and need
`bsdtar` on `PATH` (or `BSDTAR_TEST_BINARY`); the ELF + SquashFS test also needs
`mksquashfs` and `unsquashfs`. They are skipped otherwise, for example:

```sh
nix shell --inputs-from . nixpkgs#libarchive nixpkgs#squashfsTools -c \
  python3 -I -m unittest discover -s scripts/tests -p test_download_sorter.py
```

Real ClamAV tests use an isolated one-signature database and the harmless EICAR
test file. Their adapter omits only the official CVD freshness check for the
local signature fixture; production always enforces it. Another real-binary
test rejects an OK result with zero loaded signatures.
