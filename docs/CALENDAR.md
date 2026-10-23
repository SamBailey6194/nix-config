# Syntek calendar

The devtower-intel full stage installs khal for the terminal calendar and runs
vdirsyncer every five minutes. Open the interactive calendar with `ikhal` (or
`khal interactive`), or press **SUPER + SHIFT + C** to open it alongside mail on
workspace 4. **SUPER + C** opens Zoom. Use `khal list today 7d` for the coming week. Dates use
DD/MM/YYYY, 24-hour time and Europe/London.

The configuration in `hosts/devtower-intel/calendar.nix` synchronises only
`https://sync.infomaniak.com/calendars/SB25145/f09ff832-71de-46f8-9f02-07a463a06607/`.
It uses a direct collection with `collections = null`; it does not enumerate
other calendars or address books. Changes made in khal are uploaded on the next
successful sync, including event deletions. Conflicts stop synchronisation and
appear in the service journal; neither side automatically wins.

The application password stays root-only at `/run/agenix/calendar-caldav`.
systemd supplies it to the sandboxed root service with `LoadCredential`.
Neither khal nor its configuration contains the password. The Infomaniak
credential itself still grants broader account sync access; selecting one
calendar in vdirsyncer does not narrow the credential's permissions.

Local events are private to `sam-desktop` in
`/var/lib/syntek-calendar/calendar`. Sync history is root-only in
`/var/lib/syntek-calendar/status`. Keep that history when backing up or moving
the local calendar: it distinguishes remote deletions from new local events.

After rebuilding and switching to the full stage, run the first sync:

```sh
sudo systemctl start syntek-calendar-sync
ikhal
```

Check synchronisation or trigger it immediately after editing:

```sh
systemctl status syntek-calendar-sync.timer
journalctl -u syntek-calendar-sync -n 30
sudo systemctl start syntek-calendar-sync
```

An absent password skips the service. Authentication failures and conflicts
fail the service and are recorded in the journal. Do not use debug logging
when sharing output, because it can contain private event data.
