# Firebase schema confirmation handoff

Updated on 20 October 2026. Continue schema confirmation for Firebase project
`journa-journeys`. The user wants a sampled
JSON description of the schema, with no document values or document IDs in
the export or logs. Live documents must be read in memory to infer their types.

## Latest sample findings

The user reported results from the first 20 documents in each collection:

- `lastCompletedChapterId` was an integer or null.
- All 20 sampled `chapterIds` values were integer arrays. Other records may
  still differ; the earlier proposed nullable shape is not disproved.
- Sampled `ownerId` values were numeric strings. This does not establish a
  relationship with ADvance IDs.
- All sampled timeline dates and all 18 present progress `updatedAt` values
  failed the original timezone-bearing ISO hypothesis; two progress documents
  had no `updatedAt`. Another valid format or an absent timezone may explain
  the mismatch. Do not classify the dates as corrupt on this evidence.
- Anonymous timeline variants could not be mapped to the four requested type
  names: `devotion`, `journal`, `bible`, `story`. These are now the explicit
  case-sensitive filter values; verify stored spelling/case if a group is empty.
- Length semantics and encryption remain unresolved. The next report must
  inspect nested fields and date patterns per type, using synthetic dates only.

These findings are the user's summary, not a full-database audit. The current
quota availability must be rechecked if the next run fails.

## Earlier setup and quota blocker

The Firebase CLI ran successfully from `nix-shell -p firebase-tools`, reporting
version 15.32.1. No permanent CLI installation is needed.

The user initially had viewer access and requested Owner access; the grant was
not confirmed. An earlier `firebase init` attempted to initialise the home
directory and failed with a missing `serviceusage.services.use` permission.
Initialisation is unnecessary for this read-only schema checker. Inspect any
partially created home-directory Firebase files before deciding on cleanup;
do not delete them automatically.

The Python checker later reached Firestore but received `ResourceExhausted`
with a quota-exceeded message, both during collection discovery and when
querying `story_config` directly. In the signed-in Playwright session, the
Cloud Firestore quota page displayed 49,807 / 50,000 daily free read operations
(99.61%). Other displayed quotas were much lower. The daily read quota was the
leading explanation; the sanitised API error did not identify the exact metric.

Owner permissions do not increase project quota. Recheck the quota before
retrying. Daily free quota resets around midnight Pacific time; on 20 October
2026 that was 08:00 BST. Calculate the relevant UK time afresh when resuming.
Enabling billing is a separate project/billing decision for the user or owner.

Links:

- [Project Firestore API quotas](https://console.cloud.google.com/apis/api/firestore.googleapis.com/quotas?project=journa-journeys)
- [Project Firestore usage](https://console.firebase.google.com/project/journa-journeys/firestore/usage)
- [Firestore quota documentation](https://firebase.google.com/docs/firestore/quotas)

## Schema supplied by the user

These are proposed fields, not independently verified database observations.
Field requiredness and UUID formatting are unconfirmed. Keep `ownerId` as a
string even when it contains only digits; the user believes it comes from ADvance.

| Collection | Field | Proposed type or format |
| --- | --- | --- |
| story_config | addedAt | String containing an ISO datetime with timezone |
| story_config | id | String, appears to be a UUID |
| story_config | lastCompletedChapterId | int64 or null, observed in sample |
| story_config | ownerId | String, possibly digits only |
| story_config | storyId | int64 |
| story_config | updatedAt | String containing an ISO datetime with timezone |
| story_progress | chapterIds | int64 arrays observed in 20 samples; null was proposed but not observed there |
| story_progress | id | String, appears to be a UUID |
| story_progress | isCompleted | Boolean |
| story_progress | ownerId | String, possibly digits only |
| story_progress | storyId | int64 |
| story_progress | updatedAt | String containing an ISO datetime with timezone |
| timeline | createdAt | String containing an ISO datetime with timezone |
| timeline | id | String, appears to be a UUID |
| timeline | ownerId | String, possibly digits only |
| timeline | title | String |
| timeline | type | String; determines additional fields |

The requested timeline type names are now known, but type-specific field lists
are not. Do not invent fields, assume all documents share a shape, or turn string datetimes into
Firestore timestamp fields without observing that difference.

## Preserved checker

The original script from `/tmp/firestore-schema-export.py` was preserved as
[`scripts/firestore-schema-export.py`](../scripts/firestore-schema-export.py).
It has since been updated to produce `firestore-schema-check-v2`. It uses the Python Firestore client and Application Default Credentials,
separately from Firebase CLI login.

- Queries `story_config` and `story_progress` once each, and queries `timeline`
  separately for each of the four approved type names. With `--sample 20`,
  this samples up to 120 documents across six bounded queries. Sampling uses
  default query order and is not random. Other/missing/null type values are
  outside the query scope; this is still not the complete database schema.
- Performs no root collection discovery, parent enumeration or subcollection
  traversal. Earlier versions scanned all parents and could issue many more
  requests; do not restore that behaviour for this task.
- Reports expected and observed types, present/missing counts, additional
  fields, and tentative UUID, int64, digits-only and datetime format checks.
- Allows integer or null `lastCompletedChapterId` values. Checks integer array
  or null hypotheses for `chapterIds`; scalar values and unexpected array item
  types are reported as differences.
- Reports separate nested schemas under `variants.devotion`, `variants.journal`,
  `variants.bible`, `variants.story`. The four user-approved type names are the
  only discriminator values allowed in the output; empty groups stay visible.
- Reports native timestamps and inferred string-date patterns for date/time/At
  field names, including nested fields and array items. It distinguishes naive
  ISO, ISO with timezone offsets, date-only and slash-format candidates. All
  example dates are synthetic. Unrecognised patterns remain unresolved.
- Reports missing nested fields relative to observed parent maps. Lists
  length/count and encryption-related field paths based on their names only;
  it does not infer units, encryption algorithms or key management.
- Exports no other field values or document IDs. Field/collection names and dynamic
  map keys remain present, so review those before sharing the result.
- Uses a 15-second request timeout and no retries. Errors show exception
  classes and fixed diagnostic labels, not raw server messages or tracebacks.
- Writes JSON only after all samples succeed, uses mode 0600, and refuses to
  overwrite an existing output file. A partial failure produces no report.
- Missing fields are observations, not proof they are optional. Empty results
  cannot distinguish absent collections/types from those with no matching
  documents. Timezone offsets do not identify a region or DST rules, and naive
  strings must not be assumed UTC. Original format checks remain separate from
  the expanded date-pattern analysis; neither is strict RFC 3339 validation.

Earlier client-lifecycle bug: Firestore Client is not a context manager.
The preserved script uses `contextlib.closing` instead. The original script
passed local lifecycle/privacy checks and subsequently produced the sample
summarised by the user above. The expanded v2 behaviour has six automated tests
covering targeted type queries, nested fields, nullable IDs, date patterns,
synthetic examples and output privacy. Run them with:

```sh
python3 -m unittest discover -s scripts/tests -p test_firestore_schema_export.py -v
```

No live v2 report has yet been inspected. Confirm migration semantics from
application code as well as the report; do not request user records or an
encryption key.

## Resume commands

The user runs all sudo commands themselves; none is needed for these steps.
From any existing shell, add the temporary tools:

```sh
nix-shell -p google-cloud-sdk \
  'python3.withPackages (ps: [ ps.google-cloud-firestore ])'
```

If the existing Application Default Credentials are still valid, reuse them.
Otherwise authenticate with the intended account:

```sh
gcloud auth application-default login --disable-quota-project
```

That flag avoids assigning a quota project to user credentials. It does not
grant permissions or increase Firestore quota. A warning about absent quota
project was printed previously, but the observed read failure was quota
exhaustion. Do not print credentials, tokens or command environments.

Once the quota is available, run the checker directly rather than the old
`--probe`, which tests collection discovery that this targeted check does not need:

```sh
python3 /home/sam-desktop/Repos/personal/nix-config/scripts/firestore-schema-export.py \
  --project journa-journeys \
  --sample 20 \
  --output ~/journa-schema-by-type.json
```

Use a new output filename if that file already exists. The default database is
`(default)`; confirm it if the project uses another database. If quota errors
persist, inspect the quota metric instead of repeatedly issuing reads. If
permission errors occur, verify the account and its Firestore document read
permissions rather than assuming Owner is required.

Review the report with the user, especially `chapterIds` shape, timestamp
strings versus native timestamp types, additional fields and timeline variants.
Sampling can confirm consistency within observed documents; it cannot prove
the complete schema. Keep the live report outside the repository unless the
user requests otherwise.

## Browser access

Use the Playwright instance. The user reported Brave and Firefox Developer
were unreliable. Playwright was signed into Google Cloud during this session;
recheck authentication on resume. A Google Cloud Terms of Service dialog was
present: the user must handle agreement themselves before blocked interactions.
