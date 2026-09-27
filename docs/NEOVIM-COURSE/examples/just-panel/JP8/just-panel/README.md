# just-panel

**Last Updated**: 27/09/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
A terminal control panel for a justfile. It lists the recipes under the justfile's own `# ====`
section banners, shows what the selected recipe does, and runs it in the real terminal, with a
prompt for parameters and a confirmation step for recipes that use sudo or end your session.

Built with [ratatui](https://ratatui.rs) 0.30 as the Rust capstone of the Neovim course
(`docs/NEOVIM-COURSE/`, lessons 06 to 17).

## Usage

```bash
just-panel                                  # ./justfile, or $JUST_JUSTFILE when it is set
just-panel --justfile ~/Repos/personal/nix-config/justfile
just-panel -f docs/NEOVIM-COURSE/fixtures/just/justfile    # the harmless demo justfile
```

The justfile is resolved from `--justfile` (`-f`), then `$JUST_JUSTFILE`, then `./justfile`.
Recipes always run in the justfile's own directory: just-panel passes `--justfile` and
`--working-directory` explicitly, so an inherited `JUST_WORKING_DIRECTORY` cannot redirect them.
A symlinked justfile runs in the directory of the link, as it does with `just` itself, not in the
directory the link points to (home-manager links files in from the Nix store).
`just` itself must be on `PATH`.

## Keys

| Keys | Action |
|------|--------|
| `j` / `Down`, `k` / `Up` | Next / previous recipe (section headers are skipped) |
| `g` / `G` | First / last recipe |
| `Enter` | Run the selected recipe |
| `/` | Filter by name or description; `Enter` keeps the filter, `Esc` clears it |
| `Esc` | Clear a kept filter, or quit when there is none |
| `?` | Show the keys; any key closes the popup |
| `q`, `Ctrl+C` | Quit |

Apart from `Ctrl+C`, a key held with `Ctrl` or `Alt` does nothing: `Ctrl+Q` is not `q`, and
`Ctrl+U` types nothing into the filter or a prompt.

In the parameter prompt: type into the highlighted field, `Tab` / `Down` and `Shift+Tab` / `Up`
move between fields, `Enter` runs, `Esc` cancels. In a confirmation: `y` runs, `n` or `Esc`
cancels. `Enter` never confirms, so a double press cannot run a sudo recipe by accident.

## Running recipes

1. **Parameters.** A recipe with parameters opens a prompt with one field per parameter. String
   defaults start out typed in. Required parameters must be filled in, `+NAME` needs at least one
   word, and `*NAME` takes any number of space-separated words. Blank values at the end are left
   off, so just applies its own defaults.
2. **Confirmation.** The panel asks before running a recipe that
   - has a `[confirm]` attribute (it then passes `--yes`, so just does not ask a second time),
   - mentions `sudo` in its body, or
   - matches the `CAUTION` table in `src/runner.rs`: `lock`, `sleep`, `logout`, `clean-*`,
     `rekey-*`, `fuzz-clean`, `quarantine-delete`, `restic-prune`, `zfs-pool`, `raid-create`,
     `raid-fail`, `raid-remove`, `install-nixos` and `gen-hardware`. Add a line there for any new
     recipe you would hate to run by accident.
3. **The real terminal.** The panel leaves the alternate screen and raw mode, shows the cursor
   and runs `just --justfile … --working-directory … <recipe> <args…>` with the terminal
   inherited, so sudo password prompts, editors and `fzf` work normally. When just exits, the
   panel prints the exit status and waits for `Enter` before drawing the TUI again, and the status
   line keeps the last exit code. Keys that reached the panel before the run but were not handled
   yet are thrown away when it comes back, so a double-tapped `Enter` runs a recipe once.
4. **Ctrl+C.** While a recipe runs, `Ctrl+C` interrupts the recipe (just reports exit code 130)
   and the panel carries on. It installs a do-nothing SIGINT handler for this; a handler, unlike
   `SIG_IGN`, is reset to the default when a child program starts.

## How it works

| Module | Job |
|--------|-----|
| `justfile.rs` | The recipe model, parsed leniently from `just --dump --dump-format json` (works with just 1.46 and 1.58), plus helpers: `signature`, `needs_sudo`, `group`, `confirm_prompt`, `body_lines`. |
| `sections.rs` | Reads the justfile source for `# ====` banners and `# ----` sub-sections, giving the source order that the dump does not have. |
| `app.rs` | All state and key handling. Pure: no terminal, so every key is unit-tested. |
| `ui.rs` | Draws the state with ratatui: list, detail pane, status line and popups. |
| `runner.rs` | Caution rules, turning prompt values into arguments, and handing the terminal to `just`. |
| `main.rs` | Command line, loading, and the draw / read key / update loop. |

## Development

Run these from `rust/`:

```bash
cargo run -p just-panel -- -f ../docs/NEOVIM-COURSE/fixtures/just/justfile
cargo test -p just-panel
cargo clippy -p just-panel --all-targets -- -D warnings
cargo fmt -p just-panel --check
```

The tests never run `just`, need a terminal, or read `$HOME`, because the Nix build runs them in
its sandbox. They use copies of the course fixtures in `tests/fixtures/`, compiled in with
`include_str!`. See `docs/NEOVIM-COURSE/fixtures/just/README.md` for how to regenerate them.

### Snapshot test

`ui::tests::main_screen` compares the first screen with `src/snapshots/*.snap` using
[insta](https://insta.rs). After a deliberate layout change:

```bash
cargo insta test -p just-panel --review       # with cargo-insta (nixpkgs: cargo-insta)
INSTA_UPDATE=always cargo test -p just-panel   # without it: rewrites the .snap file
```

Commit the updated `.snap` file. A missing or stale snapshot fails the Nix build.

## Nix packaging

just-panel is built by `buildWorkspaceCrate` in `rust/nix/default.nix`, like the other tools in
the workspace, and installed on every host that uses the full configuration. The flake only sees
files that git knows about, so `git add` the crate (including `tests/fixtures/` and
`src/snapshots/`), `rust/Cargo.toml` and `rust/Cargo.lock` before `nix build .#just-panel` or
`just rebuild`.

## Limitations

- Parameters that `[arg(…)]` turns into options (`--name VALUE`) are passed positionally, so just
  rejects the run with a clear error. Neither the repo's justfile nor the demo one has any.
- Recipes from `mod` modules are not listed; recipes from `import`ed files appear under "Other".
- `needs_sudo` looks at the recipe's own body only, not at its dependencies.
- A key typed after the panel has handed the terminal over goes to the recipe, or answers the
  "Press Enter to return" pause. A second `Enter` pressed just too late therefore skips the pause.
  The output is not lost: it stays on the terminal's normal screen, which you see after quitting.
- Parameter prompts show the end of a value that is too long for the field, and only a value's
  start when the field is not selected.
