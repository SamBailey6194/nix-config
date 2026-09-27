# Lesson 27 — Fix: review Claude's edits in Neovim

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

In [lesson 13](13-CLAUDE-CODE-AND-CODEX.md) you learnt to read Claude's mode line before anything
else, because on this config Claude will very likely start in **auto** mode, and auto mode writes files
without showing you a diff. Checking and pressing `Shift+Tab` every session works until the day you
forget. This lesson makes Manual mode the starting point for every Claude on the machine, with one
setting in `home/modules/claude.nix`. You check the generated settings file before and after the
rebuild, then prove on laptop-intel that a fresh Claude asks first and that its edit arrives in Neovim
as a diff you accept or reject.

**Part**: 8 — Making the config yours · **Time**: ~35 min · **Previous**: [Lesson 26 — Fix: a close-buffer key that does not wait](26-FIX-CLOSE-BUFFER-KEY.md) · **Next**: [Lesson 28 — Going further](28-GOING-FURTHER.md)

## Objectives

By the end of this lesson you can:

- say which permission mode a new Claude starts in, and why: the flag, then `permissions.defaultMode`,
  then Claude Code's built-in default;
- trace `~/.claude/settings.json` back to the `settings` set in `claude.nix`, and explain why you cannot
  change it from inside Claude;
- choose between a machine-wide, a per-project and a per-session fix;
- add `permissions.defaultMode = "default"` to `claude.nix`, prove it with `nix eval` before the
  rebuild and `jq` after it;
- verify on laptop-intel that `<leader>cc` opens Claude in Manual mode and that an edit opens as a diff.

## Before you start

- **Lesson 13 is done** and `claude` is signed in on laptop-intel. You know the diff keys: `<C-s>`
  accepts, `<C-q>` rejects, `]c` jumps to the next change.
- **The change loop** from [lesson 22](22-MAKING-THE-CONFIG-YOURS.md). This lesson edits
  `home/modules/claude.nix`, not `neovim.nix`, so Neovim itself needs no restart; any running Claude
  does.
- **A clean tree and a branch for this change:**

  ```bash
  # in ~/Repos/personal/nix-config
  git status                          # expect: nothing to commit, working tree clean
  git switch -c config/claude-manual-mode
  ```

- **Recording the course?** Record tape 13 **before** this fix: its first screenshot shows the mode
  Claude starts in, which is the trap lesson 13 teaches
  ([Appendix B, Record in this order](../appendices/B-RECORDING-WITH-VHS.md#record-in-this-order)).
- **Cost.** Steps 1 and 6 each send Claude one short prompt, so they use a little of your plan's
  allowance. Nothing private goes into them.
- **A playground,** a throwaway copy of one Markdown file:

  ```bash
  # in ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
  L=/tmp/nvim-course/27-fix-claude-diff-review
  rm -rf "$L" && mkdir -p "$L" && cp -r fixtures/27-fix-claude-diff-review/. "$L" && cd "$L"
  nvim -i NONE notes.md
  ```

  The first time Claude starts in this folder it asks whether you trust it: accept.

## Keys in this lesson

| Keys | Mode | Action | Where it comes from |
|---|---|---|---|
| `<leader>cc` (Space c c) | n | Toggle the Claude split; start `claude` if none is running | config (neovim.nix:40) |
| `Shift+Tab` | Claude prompt | Cycle permission modes | Claude Code default |
| `/exit` | Claude prompt | End the Claude session (the split closes) | Claude Code default |
| `<C-\><C-n>` | t | Leave Terminal mode | Neovim default |
| `<C-h>` / `<C-l>` | n | Window left / right: from Claude back to your file, and back | config (neovim.nix:68, :71) |
| `]c` / `[c` | n (diff) | Next / previous change | Neovim default |
| `<C-s>` | n (proposed buffer) | `:w`, which accepts the proposal | config (neovim.nix:64) |
| `<C-q>` | n (proposed buffer) | `:q`, which rejects the proposal | config (neovim.nix:65) |
| `:ClaudeCode --permission-mode manual` | command | Start Claude in Manual mode for this session only | claudecode.nvim default |
| `:checktime` | command | Reload buffers whose files changed on disk | Neovim default |
| `:noautocmd w` | command | Save without format-on-save, for the Nix file you edit | Neovim default |

## Walkthrough

### 1. See the problem

On the config as it is now, in the playground from **Before you start**, press Space c c
(`<leader>cc`). Claude opens in a split on the right, in Terminal mode. Before you type, read the
mode line under its input box.

**What you should see:** on a Pro, Max or Team plan, very likely `⏵⏵ auto mode on`. On other plans
Claude Code 2.1.278 may start in `⏸ manual mode on`, and then this lesson changes nothing you can see
today. Claude Code 2.1.283 and later start in auto in a terminal for everyone, so the fix still
protects you after the next `just update`.

**If the mode line says auto,** type this prompt and press `Enter`:

```text
In notes.md, change the word draft on the Status line to reviewed. Change nothing else.
```

**What you should see:** no diff. Claude writes the file and reports that it did. Your `notes.md`
window may still show `Status: draft`, because the change happened on disk behind the buffer. Leave
Terminal mode (`<C-\><C-n>`), go back with `<C-h>` and run `:checktime`: the buffer reloads with
`Status: reviewed`. Nothing asked you first, and nothing showed you what changed.

Type `/exit` in Claude when you are done (`<C-l>`, `i`, then `/exit`), and recreate the playground
with the commands from **Before you start** so `notes.md` says `draft` again.

### 2. Why it happens

Claude decides its starting mode once, when the process starts, in this order:

1. a `--permission-mode` flag on the command line;
2. `permissions.defaultMode` from the settings files;
3. Claude Code's built-in default. For 2.1.278, the version the flake pins, that is `auto` on Pro, Max
   and Team plans in sessions that fetch feature flags, and `default` (Manual) otherwise.

Neither of the first two is set here:

- `<leader>cc` runs `:ClaudeCode` (neovim.nix:40), and `claudecode.setup` leaves `terminal_cmd` unset
  (neovim.nix:826-833), so the plugin starts plain `claude`: no flag.
- `home/modules/claude.nix` builds `~/.claude/settings.json` from its `settings` set
  (claude.nix:70-165, written at :176). That set has `permissions.allow` (claude.nix:72) and no
  `permissions.defaultMode`.

So the built-in default wins. One more setting hides it:
`skipAutoPermissionPrompt = true` (claude.nix:123). In the pinned Claude Code its description is
"Whether the user has accepted the auto mode opt-in dialog". With it set, the notice that would have
told you about auto mode never appears.

**Why auto mode means no diff.** claudecode.nvim only opens a diff when Claude asks permission to
edit. In Manual mode an edit needs your permission, and the plugin turns that question into the
side-by-side diff. In `acceptEdits`, `auto` and `bypassPermissions` there is no question, so there is
no diff. (Claude Code's documentation states this for its VS Code extension; the Neovim plugin speaks
the same protocol, and step 6 checks it on laptop-intel.)

**Why you cannot fix it from inside Claude.** `~/.claude/settings.json` is a read-only link into
`/nix/store`, generated by Home Manager on every rebuild. The comment at claude.nix:135-139 says so,
for the same reason, about `autoMode`. Anything you save from inside a session, from `/config` or a
"make this my default" question, either fails on the read-only file or is undone by the next rebuild
(Home Manager moves a file that is in its way aside as `settings.json.hm-backup`, the config's
`backupFileExtension` in flake.nix). The fix belongs in the Nix file.

**The value.** The pinned Claude Code 2.1.278 knows six modes: `acceptEdits`, `auto`,
`bypassPermissions`, `default`, `dontAsk` and `plan`. Manual mode's name is `default`; the mode line
calls it Manual. The settings schema in 2.1.278 describes `permissions.defaultMode` as "Default
permission mode when Claude Code needs access ('manual' is accepted as an alias for 'default')".

### 3. Decide

| Where | How | Verdict |
|---|---|---|
| **Machine-wide**, in `claude.nix` | `permissions.defaultMode = "default";` in the `settings` set | **take.** Every Claude on the machine starts in Manual: in Neovim, in the dev-layout shell, anywhere. `Shift+Tab` still switches for one session |
| Per project | A `.claude/settings.json` in the project with `{"permissions": {"defaultMode": "default"}}` | Works, but only in that project. Project files accept every mode except `auto` and `bypassPermissions` |
| Per session | `Shift+Tab` until `⏸ manual mode on`, or `:ClaudeCode --permission-mode manual` before Claude is running | What lesson 13 taught. Correct, and easy to forget |

**`"default"` or `"manual"`?** Both work in 2.1.278. Write `"default"`: it is the mode's own name,
the one the list of modes uses, and it does not depend on the alias, which the command-line flag has
only accepted since 2.1.200.

**Recommendation:** the machine-wide default. It makes the safe mode the one you get without
thinking, and every other choice is still one `Shift+Tab` away.

### 4. Make the change

Open `home/modules/claude.nix` (Space f f, type `claude.nix`) and go to line 72 with `:72`. Add the
new line, with a comment, straight after `permissions.allow`:

```diff
--- a/home/modules/claude.nix
+++ b/home/modules/claude.nix
@@ -70,6 +70,9 @@
   settings = {
     env."ENABLE_LSP_TOOL" = "1";
     permissions.allow = [ "mcp__claude-in-chrome__*" ];
+    # Start every session in Manual mode ("default"; "manual" is an alias), so
+    # edits reach Neovim as claudecode.nvim diffs. Shift+Tab still switches.
+    permissions.defaultMode = "default";
     model = "opus";
 
     hooks = {
```

On line 72 press `o` to open a line below, type the three lines, and `<Esc>`.

**Save with `:noautocmd w`**, not `<C-s>`: format-on-save would hand the file to `nil`, which
reformats all of it ([lesson 22](22-MAKING-THE-CONFIG-YOURS.md), step 7). Check that only your lines
changed:

```bash
# in ~/Repos/personal/nix-config
git diff --stat     # expect: 1 file changed, 3 insertions(+)
```

If you saved with `<C-s>` by mistake, press `u` once in Neovim (it undoes the formatting and keeps your
edit), then `:noautocmd w`.

> **Why:** `permissions.allow = …;` and `permissions.defaultMode = …;` are two attribute paths into the
> same set. Nix merges them into one `permissions` attribute, and `builtins.toJSON` (claude.nix:176)
> writes one `"permissions"` object with both keys. Step 5 shows the result.

### 5. Check and rebuild

Check the syntax:

```bash
# in ~/Repos/personal/nix-config
nix-instantiate --parse home/modules/claude.nix > /dev/null && echo OK
```

Then evaluate the settings file Home Manager would write, straight from your working tree, before
you install anything:

```bash
# in ~/Repos/personal/nix-config
nix eval --raw '.#nixosConfigurations.laptop-intel.config.home-manager.users.sam-laptop.home.file.".claude/settings.json".text' | jq .permissions
```

Before the edit it prints:

```json
{
  "allow": [
    "mcp__claude-in-chrome__*"
  ]
}
```

After the edit:

```json
{
  "allow": [
    "mcp__claude-in-chrome__*"
  ],
  "defaultMode": "default"
}
```

Nix may warn that the Git tree is dirty: your edit is not committed yet, which is expected. Now
rebuild, and give your sudo password:

```bash
# in ~/Repos/personal/nix-config
just rebuild
```

Check the installed file. It is the same text, now behind the link Claude reads:

```bash
# anywhere
jq .permissions ~/.claude/settings.json
```

You should see the "after" output above.

### 6. Verify

> **Live, verify on laptop-intel.** This step runs the real, signed-in Claude and sends one short
> prompt. The exact words Claude uses differ from run to run.

1. **End every running Claude.** The mode is chosen when the process starts, so a Claude that was
   already open keeps its old mode. In each Neovim with a Claude split, show it with Space c c, then
   type `/exit`. (Quitting that Neovim ends its Claude too.)
2. **Recreate the playground** from **Before you start** and open `notes.md`.
3. **Space c c.** The mode line should say `⏸ manual mode on` without a `Shift+Tab` and without any
   `--permission-mode`. If it says anything else, see **Gotchas** 1 to 3.

   If Claude asks "Make auto mode your default permission mode?", answer No ("No, keep …"). This
   lesson's point is to keep Manual, and your settings file is read-only anyway (verify on
   laptop-intel what a Yes would report).
4. **Ask for the same edit** as in step 1:

   ```text
   In notes.md, change the word draft on the Status line to reviewed. Change nothing else.
   ```

5. **A diff opens.** `notes.md` on the left, a buffer called `notes.md (proposed)` on the right, and
   the cursor on the right-hand side. `]c` jumps to the changed line: `Status: reviewed`.
6. **Accept with `<C-s>`** (or reject with `<C-q>`). After an accept, `notes.md` reloads with
   `Status: reviewed`. After a reject, Claude is told no, and the file keeps `draft`.

The recording shows the whole check:

![Lesson 27: the generated settings, Claude starting in Manual mode, the proposed edit as a diff, and the accepted change](../media/27-fix-claude-diff-review/27-fix-claude-diff-review.gif)

[MP4](../media/27-fix-claude-diff-review/27-fix-claude-diff-review.mp4)

![jq .permissions ~/.claude/settings.json inside Neovim, showing "defaultMode": "default"](../media/27-fix-claude-diff-review/settings.png)

![A fresh Claude opened with <leader>cc: the mode line says manual mode on](../media/27-fix-claude-diff-review/claude-manual.png)

![The diff: notes.md on the left, notes.md (proposed) on the right with Status: reviewed](../media/27-fix-claude-diff-review/diff.png)

![After <C-s>: notes.md shows Status: reviewed](../media/27-fix-claude-diff-review/accepted.png)

`Shift+Tab` still cycles the modes for a session. The setting only decides where every new session
starts.

### 7. What else changes

- **Every Claude on the machine starts in Manual,** not only the one in Neovim. A Claude started from
  the dev layout's shell or any Kitty terminal now asks before it edits a file or runs a command that
  is not already allowed. When you trust a batch of edits, `Shift+Tab` to `⏵⏵ accept edits on` for that
  session, and back again after.
- **Lesson 13's gotcha** ("on this config Claude will very likely start in auto mode") no longer
  applies to you. Keep the habit of reading the mode line: the other ways into auto are still there
  (Gotchas).
- **Tape 13** records a different first screenshot: `claude-first-launch.png` shows Manual instead of
  auto. The rest of it still runs: it exits Claude and restarts it with
  `:ClaudeCode --permission-mode manual`, which waits for `manual mode on`. Record it before this
  lesson if you want the trap on camera.
- **[Appendix C](../appendices/C-TROUBLESHOOTING.md)**'s entry on Claude's auto mode now describes the
  config as shipped. The mode line is still the first thing to check when a diff does not appear.
- **Codex is not affected.** Its approvals are its own (`/permissions`, lesson 13).
- **Nothing in Neovim changes:** no key, no `KEYBINDS.md` row, no restart.

### 8. Commit

With Neogit (Space g g, `s` on `claude.nix`, `c` `c`, the message, `<c-c><c-c>`) or from the shell:

```bash
# in ~/Repos/personal/nix-config
git add home/modules/claude.nix
git commit -m "fix(claude): start sessions in Manual mode so edits arrive as diffs in Neovim"
```

Then fold the branch into the one you rebuild from, as lesson 22 does. The tree is the same after the
merge, so no rebuild is needed:

```bash
# in ~/Repos/personal/nix-config
git switch main && git merge --ff-only config/claude-manual-mode
```

To undo it later, `git revert` that commit and `just rebuild`.

## Gotchas in this config

1. **A running Claude keeps its mode.** The setting is read when `claude` starts. After the rebuild,
   `/exit` every Claude that was already open.
2. **A flag beats the setting.** `:ClaudeCode --permission-mode auto`, or any `claude
   --permission-mode …` in a shell, starts in that mode whatever `settings.json` says.
3. **Resumed sessions keep their mode.** `claude -c` and `claude -r <id>` bring a session back in the
   mode it had. A session that was in auto returns in auto: read the mode line. (The `/resume` picker
   does not restore the mode.)
4. **A project can choose another mode.** A project's `.claude/settings.json` takes precedence over
   your user file, and may set `acceptEdits` or `plan` (not `auto` or `bypassPermissions`). The mode
   line tells you.
5. **`accept edits` skips the diff too.** Only Manual asks before editing. Plan mode edits nothing
   until you approve the plan, and then it switches mode.
6. **Settings changed inside Claude do not stick.** `~/.claude/settings.json` is read-only and
   regenerated on every rebuild. Change `claude.nix` and rebuild.
7. **`skipAutoPermissionPrompt = true` is not the mode.** It records that the auto-mode opt-in dialog
   was accepted. This lesson leaves it alone.
8. **`<C-s>` reformats `claude.nix`.** Save it with `:noautocmd w` and check `git diff --stat`
   before you rebuild.
9. **A dirty buffer blocks the diff.** "Cannot create diff: file has unsaved changes": save the file
   (`<C-s>`) or discard with `:e!` before you ask Claude for an edit to it (lesson 13).

## Drills

1. `settings.json` says `"defaultMode": "default"`, and you start Claude with
   `:ClaudeCode --permission-mode plan`. Which mode do you get, and why?
   <details><summary>Answer</summary>

   Plan mode. The command-line flag comes first, then `permissions.defaultMode`, then the built-in
   default.
   </details>

2. You rebuilt, but the Claude split you had open all morning still shows `⏵⏵ auto mode on`. What
   now?
   <details><summary>Answer</summary>

   The mode was chosen when that process started, before the rebuild. `<C-l>`, `i`, `/exit`, then
   Space c c for a fresh Claude, which reads the new settings and starts in Manual.
   </details>

3. Why not press `Shift+Tab` to Manual and let Claude save that as the default?
   <details><summary>Answer</summary>

   `~/.claude/settings.json` is a read-only link into `/nix/store`, generated from `claude.nix`, so a
   write from inside Claude either fails or is undone by the next rebuild. Besides, `Shift+Tab` only
   changes the running session. The source of truth is the Nix file.
   </details>

4. `"manual"` or `"default"` in `claude.nix`, and why?
   <details><summary>Answer</summary>

   `"default"`. It is the mode's own name in Claude Code's list of modes. `"manual"` is accepted as an
   alias in 2.1.278's settings, but the canonical name does not depend on an alias.
   </details>

5. Write the per-project alternative for `python/session-browser` only.
   <details><summary>Answer</summary>

   ```json
   {
     "permissions": {
       "defaultMode": "default"
     }
   }
   ```

   saved as `python/session-browser/.claude/settings.json`. It only applies to Claude sessions started
   in that project.
   </details>

6. You are in Manual mode, you ask for an edit, and Claude's own pane asks "Do you want to make this
   edit?" while Neovim shows no diff. What do you check?
   <details><summary>Answer</summary>

   Whether this Claude is connected to Neovim at all. `:ClaudeCodeStatus` should report the server
   running, and `/ide` in Claude shows the integration's status. A Claude started in a plain shell is
   not connected until you run `/ide` or start it with `claude --ide` (lesson 13).
   </details>

7. Name two ways a Claude can still start in auto mode after this fix.
   <details><summary>Answer</summary>

   Any two of: a `--permission-mode auto` flag (from `:ClaudeCode --permission-mode auto` or a shell);
   resuming, with `claude -c` or `claude -r <id>`, a session that was saved in auto mode. (A project's
   settings cannot set `auto`, but they can set `acceptEdits`, which also skips the diff.)
   </details>

## Recap

- Claude picks its mode at start: the `--permission-mode` flag, then `permissions.defaultMode`, then
  the built-in default, which on this config is usually auto. Auto and accept-edits mean no diff.
- `~/.claude/settings.json` is generated from the `settings` set in `claude.nix` and is read-only, so
  the fix goes into Nix.
- `permissions.defaultMode = "default";` next to `permissions.allow` (claude.nix:72) makes Manual the
  start for every session. `"manual"` is only an alias.
- Save with `:noautocmd w`, check with `git diff --stat`, `nix-instantiate --parse` and a
  `nix eval … | jq .permissions` before the rebuild, and `jq .permissions ~/.claude/settings.json`
  after.
- Verify live: `/exit` old sessions, Space c c shows `⏸ manual mode on`, an edit opens
  `notes.md (proposed)`, `<C-s>` accepts, `<C-q>` rejects.
- Flags, resumed sessions and project settings can still choose another mode. Read the mode line.

## Recording

- **Tape:** `tapes/27-fix-claude-diff-review.tape`. **LIVE:** it runs your real, signed-in Claude Code,
  **submits one short prompt** (billed, with a few lines of model output on screen) and differs from
  run to run. Record it by hand, never in a render-all loop, exactly like tape 13
  ([lesson 13, Recording](13-CLAUDE-CODE-AND-CODEX.md#recording)).
- **Record it after the fix:** apply the change, `just rebuild`, `/exit` every running Claude, then
  render. Without the fix, the installed `settings.json` has no `defaultMode`, so the tape's wait
  for it times out after 20 s, before Claude starts, and VHS writes nothing. If the setting is there
  but Claude still starts in another mode, the wait for `manual mode on` times out after 60 s
  instead.
- **Render** from `docs/NEOVIM-COURSE` with VHS 0.12.1, which the config builds
  ([Appendix B](../appendices/B-RECORDING-WITH-VHS.md#first-make-sure-vhs-is-0121)):
  `vhs tapes/27-fix-claude-diff-review.tape`.
- **Manual step, once, before the first recording:** answer the folder-trust question by hand. Claude
  remembers it for this path, and the tape's `rm -rf` does not undo that:

  ```bash
  # in a Kitty terminal
  mkdir -p /tmp/nvim-course/27-fix-claude-diff-review
  cd /tmp/nvim-course/27-fix-claude-diff-review
  claude    # accept the folder-trust question, then /exit
  ```

- **Fixture:** `fixtures/27-fix-claude-diff-review/notes.md`, copied to
  `/tmp/nvim-course/27-fix-claude-diff-review`. Claude edits only that copy.
- **Privacy:** the tape does **not** redirect `CLAUDE_CONFIG_DIR`, because it checks your real
  `~/.claude/settings.json` and Claude would otherwise start logged out. It shows only the
  `permissions` object of that file. `IS_DEMO=1` and `CLAUDE_CODE_HIDE_CWD=1` keep your e-mail,
  organisation and folder out of Claude's header (verify on laptop-intel that 2.1.278 honours both).
  No shell is typed into, so no history can appear.
- **Outputs** in `media/27-fix-claude-diff-review/`:
  - `27-fix-claude-diff-review.gif` and `.mp4`: the whole run;
  - `settings.png`: `:!jq .permissions ~/.claude/settings.json` with `"defaultMode": "default"`;
  - `claude-manual.png`: the Claude split after Space c c, mode line `⏸ manual mode on`;
  - `diff.png`: `notes.md` and `notes.md (proposed)` side by side, with `Status: reviewed` on the
    right;
  - `accepted.png`: after `<C-s>`, `notes.md` with `Status: reviewed` and Claude's short report.
- **Check after rendering:**
  1. `ls -l media/27-fix-claude-diff-review/` lists the GIF, the MP4 and all four PNGs, none of them
     empty.
  2. Step through every frame: no account name, e-mail, organisation or plan name, no path outside
     `/tmp/nvim-course`, and nothing in Claude's reply you would not publish.
  3. `ls ~/.claude/ide/` lists no lock file for the Neovim the tape started.
  4. The rest of [Appendix B's checklist](../appendices/B-RECORDING-WITH-VHS.md#checklist-for-every-recording).
