# Meeting notes

`meeting-notes` records a call as two tracks, your microphone ("Me") and the
call audio ("Them"), transcribes both on the GPU, labels the remote speakers,
asks you to confirm their names, then writes a transcript and notes with
action points. It works for Teams-for-Linux, a browser or anything else that
plays through the configured outputs.

Enabled on devtower-intel from the dev stage up
(`hosts/devtower-intel/meeting-notes.nix`); options live in
`modules/software/meeting-notes.nix`, the program in `pkgs/meeting-notes/`.
laptop-intel records in-person D&D sessions from one room microphone instead:
see [D&D sessions](#dd-sessions-in-person).

## Use

The interactive way, from the repository:

```sh
just meeting          # title, remote attendees, audio; records until Ctrl+C
just meeting-stop     # stop it from another terminal instead
just meeting-notes    # pick a recording, confirm details, transcript + notes
```

Answer `n`, `n/a` or `none` to skip a question; Enter takes the default
shown in brackets. `just meeting` can write the notes as soon as the
recording stops, or leave that for `just meeting-notes` later.

The same steps directly:

```sh
meeting-notes run --title "Weekly sync" --attendees "Jane Smith, Tom Lee"
# ... meeting ... Ctrl+C (or `meeting-notes stop` from elsewhere)
```

`run` records, then processes when the recording stops. The steps can also be
separate:

```sh
meeting-notes record --title "Weekly sync" --attendees "Jane Smith, Tom Lee"
meeting-notes stop                      # e.g. from a keybind
meeting-notes process                   # newest recording
meeting-notes process ~/Documents/Meetings/2026-10-21_1400-weekly-sync --speakers "00=Jane Smith, 01=Tom Lee"
meeting-notes sources                   # check the PipeWire nodes exist
```

List only the **remote** attendees; you are added as `selfName` ("Me").
Each meeting gets a folder under `~/Documents/Meetings/`:

| File | Contents |
| --- | --- |
| `me.flac`, `them-chat.flac`, `them-hdmi.flac` | the raw tracks (16 kHz mono FLAC) |
| `meta.json` | title, attendees, start/end |
| `speakers.json` | the confirmed label → name mapping |
| `transcript.md` / `.json` | `[hh:mm:ss] Name: text`, one timeline |
| `notes.md` | summary, decisions, action points table, open questions |
| `work/` | intermediate audio, cached transcription and labelling |

`process` reuses `work/asr.json` and `work/diarisation.json`, so re-running it
with different `--speakers` or `--summariser` is quick. `--redo` recomputes.

## Audio routing

| Track | PipeWire node |
| --- | --- |
| Me | GoXLR Mini "Chat Mic" source: the routing matrix sends only the microphone there |
| Them (headphones) | monitor of the GoXLR "Chat" sink |
| Them (speakers) | monitor of the HDMI 2 sink, the centre AG271QG4 |

`--output auto` (the default) records both remote monitors and mixes them, so
it does not matter which one the call uses, or if you switch mid-call. Use
`--output chat` or `--output hdmi` to record only one. All tracks come from
one `ffmpeg` process, so their timestamps line up.

On the monitor speakers the microphone also hears the call. When the HDMI
track has audio, Me lines of four or more words that repeat, in order, what
the remote track says at the same moment are dropped before merging; the
count is reported. Short replies are always kept. On headphones the filter
does not run. `--bleed-filter on|off` overrides the automatic choice.

Each capture stream is pinned to its node, so if a monitor disappears
mid-call (screen switched off) its track simply ends rather than PipeWire
moving it onto another source.

## Speakers and names

Pyannote (through the CPU-only WhisperX) splits the remote track into
`SPEAKER_00`, `SPEAKER_01`, ... The numbers only exist after processing, so
names cannot be given at recording time. Instead:

1. `--attendees` at recording time caps the number of remote voices.
   With exactly one remote attendee, labelling is skipped and every remote
   line is theirs.
2. The summariser suggests a mapping from the attendee list and evidence in
   the transcript (introductions, "thanks, Jane").
3. You confirm it: each label is shown with its talk time and sample lines.
   Press Enter to accept, or type corrections such as `01=Tom Lee, 02=?`
   (`?` clears a name). `--speakers` skips the suggestion; `--yes` skips the
   prompt.
4. Code, not the model, swaps the names into the transcript.

Labelling needs a Hugging Face read token, and the terms of
[pyannote/speaker-diarization-community-1](https://huggingface.co/pyannote/speaker-diarization-community-1)
accepted once on that account. Provide it as an agenix secret:

1. Uncomment the `huggingface-token-devtower-intel.age` line in
   `secrets/secrets.nix`.
2. `cd secrets && agenix -e huggingface-token-devtower-intel.age`, paste the
   token only (no `HF_TOKEN=` prefix).
3. `git add secrets/huggingface-token-devtower-intel.age`: the flake only sees
   tracked files, and the module silently skips a secret it cannot see.
4. `just rebuild`.

It is decrypted to `/run/agenix/huggingface-token` for your user. `HF_TOKEN`
in the environment also works. Without a token, remote lines stay as "Them".

## Summaries

`summariser = "claude"` (the default for now) runs `claude -p` with no tools
and no MCP servers. **The transcript leaves the machine** and goes to
Anthropic; audio, transcription and labelling stay local. Consider that for
confidential client meetings.

Once the local models are tuned, switch to fully local notes:

```nix
software.meetingNotes.summariser = "local";   # llama-swap, localModel
```

or per run with `--summariser local`. `localUrl` and `localModel` default to
`services.localLlm`'s endpoint and `defaultModel`.

## GPU and resources

Transcription uses faster-whisper `large-v3-turbo` in FP16 on the RTX 2080 Ti,
through a CTranslate2 compiled with CUDA for compute 7.5 only (no Torch on the
GPU path). The model downloads on first use. If CUDA is unavailable or runs
out of memory (for example a llama.cpp model is holding the VRAM), it falls
back to the CPU in INT8, which is much slower; `--cpu` forces that.
Speaker labelling runs on the CPU.

Both heavy steps run through `resource-run`, inside `workload.slice` and its
memory and CPU caps ([Media tools](MEDIA-WORKLOADS.md)). Recording does not.

## Filing and backup

On devtower-intel, from the dev stage, a user timer
(`meeting-notes-filing`, `home/modules/meeting-notes-filing.nix`) runs
syntek-business-docs' `file_meeting_notes.py run --notify` every 15 minutes.
It copies each finished meeting's `notes.md` and `transcript.md` into the
client's `meeting-notes/` folder, by the client name the title starts with
(so title meetings "Urban Saints – aice review"). It notifies once when it
files a meeting or first holds one; a meeting still held after that is only
listed by `status`. It never commits and never files Premier, whose meetings
must not be recorded on this PC at all (its contract forbids storing its data
on personal equipment).
The procedure, client aliases and review steps are in that repo's
`library/workflows/local/01-file-meeting-notes/`. The timer skips until both
that script and `~/Documents/Meetings/` exist; a failed run raises a critical
notification.

```bash
systemctl --user list-timers meeting-notes-filing
journalctl --user -u meeting-notes-filing
python3 -I ~/Repos/syntek/syntek-business-docs/library/workflows/local/01-file-meeting-notes/file_meeting_notes.py status
```

The recordings themselves stay on the SSD. `~/Documents/Meetings/` is in the
business off-site backup design
([SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md#off-site-backup-and-the-kdrive-viewing-copy)),
which is not built yet, so until it runs nothing backs them up.

## D&D sessions (in person)

laptop-intel runs `meeting-notes` in **room mode**: its built-in microphone
hears the whole table as one track, and Pyannote splits that track into
speakers. Enabled in the full config (`hosts/laptop-intel/meeting-notes.nix`).
The same `--kind dnd` works on devtower-intel in call mode, for online games.

```sh
just dnd              # campaign, session title, players; records until Ctrl+C
just meeting-stop     # stop it from another terminal instead
just meeting-notes    # pick the session: transcript, names, DM notes and players' recap
```

List **everyone at the table, you included**, as `Player (Character)` and
`Name (DM)`, e.g. `Sam (DM), Jane (Elira), Tom (Brakka)`. `just dnd`
remembers the last session's list and numbers sessions for you.

Sessions are kept per campaign under `~/Documents/DnD/<campaign>/`:

| File | Contents |
| --- | --- |
| `campaign.md` | optional, **DM only**: setting, party, recurring NPCs, quests, house rules, secrets. Used for the DM notes only, never the recap; text in `<!-- -->` is not sent |
| `glossary.txt` | names Whisper should spell correctly (characters, NPCs, places), one per line or comma-separated |
| `<date>-<session>/room.flac` | the recording (16 kHz mono FLAC) |
| `<date>-<session>/transcript.md` | who said what, timestamped |
| `<date>-<session>/dm-notes.md` | **for the DM only** (below) |
| `<date>-<session>/recap.md` | the players' recap, safe to share (below) |

Two summaries, from two separate LLM calls:

- **`dm-notes.md`** (DM only): a read-aloud *Previously on...*, what
  happened with timestamps, NPCs, places, loot, quests and leads, character
  moments, **what the players think and want** (theories, plans and wishes
  from out-of-character table talk), rulings, a **threads to pick up**
  checklist for prep, where you left off, and **names to check**. It sees
  `campaign.md` and the previous session's DM notes.
- **`recap.md`** (players): only what the characters saw, heard and were
  told: recap, what we did, people met, places, loot, quests, where we left
  off. It never sees `campaign.md` or any DM notes, and is told to leave out
  DM asides, hidden results and out-of-character talk. It is still an LLM
  summary of everything said at the table, so skim it before sharing.

Copy the names to check into `glossary.txt`, and later sessions spell them
correctly. Keep secret names out of `glossary.txt`: it also helps spell the
recap. Put them in `campaign.md`, which the recap never sees.

### Before a session

- Mic input volume 80-100%: `meeting-notes sources` shows it, and recording
  warns below 50%. Set it in pavucontrol (Input Devices) or with
  `wpctl set-volume @DEFAULT_SOURCE@ 0.9`.
- Put the laptop in the middle of the table, lid open: the microphone is in
  the lid. Suspend, idle sleep and lid-close suspend are blocked for as long
  as the recording runs, and released when it stops.
- Plug in for processing. Recording uses almost no CPU.

Online games on devtower-intel (`just dnd`, mode `call`) work the same way.
The wizard asks which listed person you are, which is your mic track.

### Speakers on one microphone

Labelling needs the Hugging Face token (see [Speakers and names](#speakers-and-names));
for this laptop the secret is `huggingface-token-laptop-intel.age`:

```sh
just edit-secret huggingface-token-laptop-intel   # paste the hf_... read token only
git add secrets/huggingface-token-laptop-intel.age
just rebuild
```

Without it everything is labelled "Table": the transcript and log still work,
but not who said what. With it, the summariser suggests names (players are
often addressed by character name) and you confirm them. One microphone
across a table can split a person across two labels: give both the same name,
e.g. `00=Jane (Elira), 03=Jane (Elira)`, and their lines are merged. A USB
conference or boundary microphone in the middle of the table separates voices
noticeably better than the built-in one; set `micSource` to it.

### Time

Everything runs on the i5-10210U CPU: Whisper `large-v3-turbo` in INT8, then
Pyannote. Expect processing to take a large fraction of the session's length
(an estimate; time a first real session), so start `just meeting-notes`
after the game and let it run. `--no-diarise` skips labelling to save time.
Transcription is cached, so adding the token later and re-running only does
the labelling and notes.

## Consent

Tell people you are recording, and why: at a D&D table, everyone present. Keep recordings and transcripts only
as long as you need them.
