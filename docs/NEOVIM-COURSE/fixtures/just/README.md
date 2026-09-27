# just-panel fixtures

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

A small, synthetic justfile for the just-panel capstone and the lessons' tapes, plus the JSON that
`just` dumps for it. Use these instead of the repo's real `justfile` whenever a demo or a recording
would otherwise run real recipes.

## Files

| File | What it is |
|------|------------|
| `justfile` | 15 recipes (14 public, 1 private) in the same shape as the real one: `# ====` banner sections, a `# ----` sub-section style, doc comments, an exported variable, singular parameters, defaults, a variadic `*ARGS`, a shebang recipe, dependencies, one `[group]` and one `[confirm]` attribute. |
| `dump.json` | The unedited output of `just --dump --dump-format json` for that justfile, generated with just 1.46.0. |

## Every recipe is harmless

Each recipe only echoes, prints the time or sleeps. Nothing runs `sudo`, changes the system or needs
the network, so it is safe to press Enter on anything in a demo.

The recipes that just-panel treats with caution are still in there, because the panel's behaviour is
the point of the demo:

| Recipe | Why just-panel asks before running it |
|--------|---------------------------------------|
| `rebuild`, `snapshot` | Their bodies mention `sudo`. |
| `update` | It carries `[confirm("…")]`. |
| `rekey-secrets`, `clean-cache`, `lock` | Their names match the panel's caution rules (`rekey-*`, `clean-*`, `lock`). |

**Why the "sudo" recipes only echo**: just-panel decides that a recipe needs sudo by looking for the
word `sudo` in the recipe body. An `echo "demo: would run: sudo …"` line is enough to set that off, so
the panel shows exactly the same confirmation it would for the real `rebuild`. Nothing ever runs
sudo, so a demo cannot stop at a password prompt, and a recording cannot catch you typing one.
Guarding a real `sudo` call behind a variable would have worked too, but a wrong value would then run
the real command.

## Using it

Run these from the repo root:

```bash
just --justfile docs/NEOVIM-COURSE/fixtures/just/justfile --list
just-panel --justfile docs/NEOVIM-COURSE/fixtures/just/justfile
```

Always pass `--justfile`. On laptop-intel, zsh exports `JUST_JUSTFILE` and `JUST_WORKING_DIRECTORY`
for the real nix-config justfile, so a bare `just` would run the real recipes.

## Regenerating `dump.json`

Regenerate it after any change to `justfile`, from the repo root:

```bash
just --justfile "$PWD/docs/NEOVIM-COURSE/fixtures/just/justfile" --dump --dump-format json \
  > docs/NEOVIM-COURSE/fixtures/just/dump.json
```

- The output is one long line. `jq . docs/NEOVIM-COURSE/fixtures/just/dump.json` pretty-prints it.
- The top-level `source` field records the absolute path of the justfile on the machine that
  generated the file. Nothing reads it, so a different path after regenerating is harmless.
- just 1.58 (on NixOS) adds fields such as `flag`, `min`, `max` and `multiple` to each parameter and
  a top-level `module_path`. just-panel ignores fields it does not know about, so a dump from either
  version works.

## Copies inside the crate

just-panel's unit tests use copies of both files in `rust/just-panel/tests/fixtures/`. The Nix build
only sees `rust/`, so the tests can never read files from `docs/`. After regenerating, copy them
across and rerun the tests:

```bash
cp docs/NEOVIM-COURSE/fixtures/just/{justfile,dump.json} rust/just-panel/tests/fixtures/
cd rust && cargo test -p just-panel
```
