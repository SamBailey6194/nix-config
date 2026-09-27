# Lesson 28 fixtures

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Files for lesson 28 (`lessons/28-GOING-FURTHER.md`) and its tape (`tapes/28-going-further.tape`).

| Path | What it is |
| --- | --- |
| `v1/justfile` | The demo justfile the tape (and section 1's Try it) commits in a throwaway repo |
| `v2/justfile` | The working copy copied over it: three hunks, one changed, one deleted, one added |
| `patches/gitsigns-keys.diff` | Section 1's change to `home/modules/neovim.nix` |
| `patches/terminal-alt-keys.diff` | Section 2's change to `home/modules/neovim.nix` |
| `patches/drop-vhs-override.diff` | Section 3's future change to `home/stages/dev.nix`, for when nixpkgs has VHS 0.12.1 |
| `patches/vhs-recipes.diff` | Section 4's change to `justfile` |
| `NEOVIM-SETUP.md` | Section 5's finished `docs/NEOVIM-SETUP.md` |

The diffs are against the files as they are at the start of lesson 28, before lessons 23 to 27. They are
for comparing, not for skipping the lesson: after you make an edit by hand, this command (run from the
repository root) succeeds only when your edit matches the lesson's exactly:

```bash
# in ~/Repos/personal/nix-config
git apply --check -R docs/NEOVIM-COURSE/fixtures/28-going-further/patches/gitsigns-keys.diff
```

If you applied lessons 23 to 27 first, the line numbers differ. `git apply` still finds the hunks by their
context, as long as the lines next to them are unchanged.
