# Practice files

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

The kata files for Part 1 of the course (lessons 01-04). Each one is built for its lesson's drills: the line
numbers, recipe names, brackets and quotes are where the drills expect them. The recipe names come from the
repository's `justfile` and the session titles from the course's synthetic session fixtures, so the words are
already familiar when the capstones start in lesson 06.

## Always practise on a copy

Never edit these files in place. The lessons' line numbers and the recordings assume they are unchanged.
Copy them to `/tmp` once and work there:

```bash
# from ~/Repos/personal/nix-config
mkdir -p /tmp/nvim-practice
cp docs/NEOVIM-COURSE/practice/0* /tmp/nvim-practice/
cd /tmp/nvim-practice
nvim 01-survival.txt
```

- **Start a drill again:** repeat the `cp` line, or copy just the one file.
- **Edited a file in the repository by mistake?** `git checkout -- docs/NEOVIM-COURSE/practice/` restores the
  committed versions.
- **Open files by name** (`nvim 02-motions.txt`). A bare `nvim` opens the dock layout with the tree and a
  terminal, which Part 1 does not use.

## Saving can reformat a file

Saving runs format on save (conform, `home/modules/neovim.nix:974-977`):

| File type | On save |
| --- | --- |
| `.txt` | nothing: there is no formatter for plain text, so the file is written exactly as it is |
| `.py` | ruff format rewrites it (`neovim.nix:953`) |
| `.md` | prettier rewrites it (`neovim.nix:951`) |

That is why three of the four katas are plain text. The Python kata passes `ruff check`, `ruff format --check`
and pyright as shipped, but after your edits ruff may reflow lines. You never need to save it to practise:
`:q!` and a fresh `cp` reset everything. `:noautocmd w` saves without formatting (lesson 11 explains why).

## The files

| File | Lesson | What it is for |
| --- | --- | --- |
| `01-survival.txt` | [01 — Modes and survival](../lessons/01-MODES-AND-SURVIVAL.md) | Seven short exercises for `i` `a` `I` `A` `o` `O`, `.`, undo and redo, saving, quitting and `:help`. The instructions are inside the file. |
| `02-motions.txt` | [02 — Motions](../lessons/02-MOTIONS.md) | A 162-line justfile-shaped text: real recipe names, invented bodies, nothing runs. Long enough for paging, with indented bodies (`0` vs `^`), hyphenated names (`w` vs `W`), brackets (`%`), blank-line paragraphs (`{` `}`) and the long `fuzz` line for `f`/`t`. |
| `03-text-objects.py` | [03 — Operators and text objects](../lessons/03-OPERATORS-AND-TEXT-OBJECTS.md) | Session-browser-style Python: nested brackets, quoted titles, a dict, an HTML-ish string for `it`/`at`, a list for block `I` and a class whose fields suit block `A`. Clean under ruff and pyright, so no diagnostic signs appear. |
| `04-recipes.txt` | [04 — Search, registers and macros](../lessons/04-SEARCH-REGISTERS-MACROS.md) | A recipe table for search and `:s` (with `needs sudo` / `needs SUDO` for the case rules), a `TODO` list for `cgn`, and two lists that macros turn into a Rust `vec![…]` and a just-panel-style caution table. |

From [lesson 05](../lessons/05-YOUR-KEYBINDINGS.md) on, the course works on real files and, from lesson 06, on the
capstones themselves.

## For course maintainers

Each lesson's VHS tape records an exact copy of its kata, stored in `fixtures/<lesson-slug>/`:

| Kata | Tape fixture |
| --- | --- |
| `01-survival.txt` | `fixtures/01-modes-and-survival/01-survival.txt` |
| `02-motions.txt` | `fixtures/02-motions/02-motions.txt` |
| `03-text-objects.py` | `fixtures/03-operators-and-text-objects/03-text-objects.py` |
| `04-recipes.txt` | `fixtures/04-search-registers-macros/04-recipes.txt` |

If you change a kata, copy it over its fixture and check the lesson's line numbers, drill answers and tape
together: all three depend on the exact lines.

```bash
# from docs/NEOVIM-COURSE
cp practice/01-survival.txt fixtures/01-modes-and-survival/
cp practice/02-motions.txt fixtures/02-motions/
cp practice/03-text-objects.py fixtures/03-operators-and-text-objects/
cp practice/04-recipes.txt fixtures/04-search-registers-macros/
```
