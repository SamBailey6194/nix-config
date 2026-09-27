# Session model (spec excerpt)

Every row of the session browser is one `Session`, whichever tool wrote it.

| Field     | Type          | Meaning                                       |
| --------- | ------------- | --------------------------------------------- |
| `source`  | `Source`      | `claude`, `codex` or `kitty`                  |
| `id`      | `str`         | the tool's own id                             |
| `title`   | `str`         | what the list shows                           |
| `cwd`     | `Path`/`None` | where the session ran, if the file says       |
| `updated` | `datetime`    | last activity, always timezone-aware          |
| `path`    | `Path`        | the file the session was read from            |
| `detail`  | `str`         | one extra line for the preview, default `""`  |

- `key` is `"<source>:<id>"`, unique across all three tools.
- `project` is the last part of `cwd`, or `""` when there is none.
- A naive `updated` (no timezone) is refused with a `ValueError`.

A `Message` is one thing you or the assistant said: a `role` (`"user"` or
`"assistant"`) and its `text`.
