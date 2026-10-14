# Handover: devtower-intel storage work

**Updated**: 13/10/2026, after the home move and the store config.
**Branch**: `main`; see `git log` for the latest commit.

## Where things stand

### Done and pushed

| Commit | What |
| --- | --- |
| `bacfe9d` | Secrets: devtower-intel's editing key is the master key; per-device recipient lists |
| `c8ba4e9` | Download sorter: layered scans over ClamAV's 2 GiB limit, `just approve-download` |
| `03e5a55` | zsh: pasting no longer restores a stale autosuggestion |
| `ba60e8e` | Hyprland: ws2 terminal grid, workspace renumbering, overflow from 41 |
| `3608b99` | Hyprland: SUPER + comma moves a workspace between centre and left |
| `133866f` | Hyprland: login opens Yazi (ws3), aerc + sheet (ws4), Teams (ws11), silently |
| `4f4e318` | Docs: the whole storage plan below |

Tests run before committing: download-sorter (70, 34 skipped by the suite),
Hyprland Lua tests (22), `dev-layout` crate (20). **No `just check` or rebuild
has been run on these commits yet.**

### Decisions made (do not reopen)

- **OS drive** (Intel NVMe 256GB, `cryptroot`): keeps `/`, the system `/nix`
  and all generations, `/var/log`, `/.snapshots`.
- **Home** (Samsung 512GB, serial `S1X1NYAG302936`; `sde` on 13/10, not `sdd`): LUKS2 `crypthome`, `@home` at `/home`.
- **Store** (870 EVO 2TB = 1,863 GiB, serial `S6PPNX0T910090T`): one
  partition, one LUKS2 container `cryptstore`, three btrfs subvolumes with
  simple-quota caps, unlocked after boot (crypttab, `nofail`), not needed to
  boot:
  - `@docker` -> `/var/lib/docker`, 950 GiB
  - `@vm` -> `/var/lib/libvirt/images`, 450 GiB (`chattr +C`)
  - `@clients` -> `/srv/clients`, 400 GiB; `~60 GiB` left free
- **Client servers**: separate Nix store at `/srv/clients/nix-root` (plain
  directory in `@clients`). `just deploy-client <name> <host>` records each
  server's current generation; the weekly job deletes only **old**
  generations, then GCs that store. Never touches the system `/nix`.
- **Generations**: keep the newest 5 system generations (no 90-day rule), also
  prune home-manager generations. Shared `nix-gc.nix`, so laptop-intel too.
- **4TB pair**: VeraCrypt mirror as in `docs/SHARED-DATA-DRIVES.md`, not RAID1.
- **LUKS escrow secrets**: `luks-passphrase-devtower-intel-{os,home,store}.age`,
  recovery copies only (agenix can never unlock a drive at boot), never in
  `age.secrets`, recipients `devtowerIntelKeys` only (devtower-intel is the
  authority, no sam-laptop). Keep the `-os` name.
- **Recovery key**: `sam-keys-recovery` (KEYS stick,
  `agenix/id_ed25519_recovery`, passphrase-protected) in `allUsers`, so it
  opens every secret. For recovery and new-device bootstrap; used from the
  stick only, never in `age.identityPaths`. Replaces copying the master key
  offline. If lost: drop it from `allUsers`, rekey, rotate what matters.
- **Remote work from laptop-intel**: dedicated WireGuard link (`wg-lan`),
  SSH / Zed remote to run things on devtower-intel, Docker context over SSH,
  Samba bound to the tunnel only.
- **Repos on the SSD** (replaces "Syntek repos on the data drive"):
  `syntek-business-docs`, `syntek-content`, `neovim-course` and the later
  book repos stay in `~/Repos`. On NTFS-3G the templates' symlinks
  (`.agents` -> `.claude`) are unreliable, exec bits are lost and git is
  slower; Windows cannot see the repos (clone from GitHub there if needed).
- **Data layout, lowercase** (`/mnt/data` = `~/Data`): `business/` and
  `personal/` (each `docs/ photos/ videos/ audio/`), `craft/`, `archive/`
  (rename the step 3 `Archive/` by hand), DavinciProj unchanged at the root.
  NTFS ignores case, git's `gitdir` does not. Finished media go to
  `~/Data/<area>/{videos,audio,photos,docs}/<repo>/<piece>/`; repos hold only
  what GitHub needs.

## Next steps, in order

1. **Rebuild**: done (store switch-over, 13/10 17:15). Not re-checked: that
   the login apps land on ws3/4/11 with focus on ws2. If Teams steals focus,
   its window belongs to a child process and the silent rule missed it.
2. **OS drive TPM2 + escrow secret**: done (TPM2 PCR 7 in keyslot 1,
   `-os.age` verified and committed, header backup
   `luks/cryptroot-header-2026-10-13-tpm2.age` on KEYS). Reboots at 11:34 and
   17:15 unlocked `cryptroot` without a prompt.
3. **Master key backup**: done via the KEYS recovery key instead of a copy.
   All 12 devtower-intel secrets rekeyed for it (host key), and the stick key
   alone decrypted `luks-passphrase-devtower-intel-os.age`.
4. **Home drive (Samsung 512GB, by serial)**: done (`fe9f33a`). `/home` is
   `crypthome[/@home]` on the Samsung, TPM2 unlock at boot on 13/10 11:34,
   `-home.age` escrow committed, dead Ubuntu boot entry (`Boot0006`)
   removed. Skipped on purpose: selective Ubuntu file restore (home step 9)
   and the `crypthome` header backup (home step 10). Left for later: delete
   the Intel `@home` after pruning old generations (home step 12).
5. **Pending config**: done (`487b630`, `b85dcf1`; list below).
6. **4TB pair**: `docs/SHARED-DATA-DRIVES.md`, Conversion. In progress
   (13/10): step 1 copy running. The NixOS config is written, not committed
   (list below) and inert until the `dataPair` PARTUUIDs are filled in; step 7
   of the doc switches it on (passphrase files, `disks.nix`, `git add`,
   `just rebuild --boot`, reboot, checks). The WD can be switched on right
   after step 3.
7. **Store drive (870 EVO 2TB, serial `S6PPNX0T910090T`)**: done
   (`f2c0c4d`). `cryptstore` (LUKS2, TPM2 PCR 7, `-store.age` escrow checked)
   holds `@docker` -> `/var/lib/docker`, `@vm` -> `/var/lib/libvirt/images`
   (No_COW) and `@clients` -> `/srv/clients`, simple-quota caps 950G / 450G /
   400G. Unlocked after boot without a prompt; `store-quotas` and Docker
   started from it. The old Ubuntu `/nix` and Docker partitions were erased
   without a copy, on purpose. The Intel `@docker` held only 328K.
   - Skipped on purpose: the `cryptstore` header backup (store step 10).
   - Left for later: delete the Intel `@docker` (store step 11).
   - libvirtd's first idle shutdown after the switch hung 30 s and was forced
     (exit 1, 17:18:22); the next cycle (17:21:50 -> 17:23:50) stopped
     cleanly. Watch for "forcefull" in `journalctl -u libvirtd`; if it
     recurs, enable libvirt debug logging for one cycle.
   - Drive letters move between boots (the store was `sdc`, then `sda`);
     everything uses UUIDs or serials.
8. **Remote access**: `wg-lan`, sshd hardening, Samba, Docker context.

## Config changes for the storage plan (committed)

Rebuilt and running since 13/10 17:15, with `dataDrives.store` filled in.

- `hosts/devtower-intel/data-drives.nix`: no `/nix` mount and no initrd
  unlock for the store; crypttab after-boot unlock
  (`tpm2-device=auto,nofail,discard`); `nofail` mounts for `@docker`, `@vm`,
  `@clients`; `RequiresMountsFor` on docker and libvirtd; the
  `store-quotas.service` oneshot that re-applies the caps at boot.
- `hosts/devtower-intel/disks.nix`: the three caps (`storeQuotas`) and the
  store's UUIDs.
- `secrets/secrets.nix`: `-store` declared; the "fallback" comments now say
  escrow only.
- `modules/core/nix-gc.nix`: keep newest 5 system generations, no age rule,
  every user's home-manager profile pruned to 5 too.
- `justfile`: `deploy-client NAME HOST [--key FILE | --no-check-sigs]`
  (`client-store-guard --no-db`, shared `flock`, build with `--out-link` to a
  pending GC root, sign with `~/.config/nix/client-store-signing.key` by
  default, `nix copy --from`, activate on the server under `systemd-run`, then
  set the client profile and drop the pending root). `enroll-tpm2`,
  `test-luks-passphrase`, `setup-tpm2` and `backup-luks-headers` take only a
  LUKS UUID or `/dev/disk/by-uuid/` path.
- `hosts/devtower-intel/client-store.nix` (imported by `full.nix`):
  `client-store-guard`, and the weekly `client-store-gc` service + timer
  (`Persistent=true`).
- `home/modules/git.nix`: `includeIf."gitdir:/mnt/data/business/"` and
  `~/Data/business/` -> `~/.gitconfig-syntek`; `/mnt/data/personal/` and
  `~/Data/personal/` -> `~/.gitconfig-personal` (lowercase, not committed).
- `config/hypr/60-keybinds.lua`: SUPER + = / SUPER + - raise and lower the
  volume by 5% (repeat while held), a keyboard fallback for the SteelSeries
  volume roller.
- Later: `wg-lan` module and agenix keys, Mullvad bypass, sshd key-only on
  `wg-lan`, Samba, Docker published ports bound to 127.0.0.1 / tunnel IP.

## Config for the 4TB pair (committed `51640a7`, inert until step 7)

Evaluated only: with both `partUuid`s null every devtower-intel stage builds
the same system as before (`/mnt/davinci`, `/mnt/archive`); not rebuilt.

- `hosts/devtower-intel/data-pair.nix`: crypttab `tcrypt-veracrypt` lines by PARTUUID with passphrase
  files in `/var/lib/desktop-secrets/`, `/mnt/data` at boot and `noauto`
  `/mnt/data-mirror` by `/dev/mapper/<name>`, the `data-mirror` service +
  daily timer (mounts both, guard checks, prune history, rsync, always locks
  the mirror again), smartd on both drives.
- `hosts/devtower-intel/disks.nix`: `dataPair.{data,mirror}.{partUuid,byId}`.
- `hardware-configuration.nix` / `data-drives.nix`: `/mnt/davinci` and the
  ext4 `/mnt/archive` only while their drive's `partUuid` is null.
- `home/devtower-intel.nix`, `home/modules/file-manager.nix`:
  `~/DavinciProj` and Yazi `g a` follow `/mnt/data`; `g D` goes to `~/Data`,
  the bind mount of `/mnt/data` (data-pair.nix) that keeps media projects
  inside the ElevenLabs base path.

## Queued after the drives (one flake update)

Do these together once the 4TB pair's step 7 is done, not mid-conversion:

- **Python:** keep only `python314` (default) and `python315` (opt-in, once
  the update brings 3.15.0 final; the lock has 3.15.0rc2). Remove
  `python313` from `modules/software/development.nix`. Older versions come
  per project from `uv` (nix-ld makes its interpreters run) or a one-off
  `python312` shell. Revisit 3.15 as default around 3.15.1/.2.
- **Playwright 1.64:** only once nixpkgs has it (master was 1.63.0 on
  14/10); then `just check-playwright` and bump consumers to the bundle's
  version. syntek-media's `toolkit/card.py` pins 1.62.0 and expects a
  downloaded Chromium: point it at the nixpkgs bundle before the course
  media work.
- **ElevenLabs base path:** declared in the shared MCP inventory (workflow
  in progress on 14/10); it goes live with the next rebuild, which also
  removes the hand-made `claude mcp add` entry (empty API key).
- **AI client config audit:** compare `~/.claude.json`,
  `~/.codex/config.toml`, Antigravity / `~/.gemini/*` and
  `opencode.json` with what activation declares; list anything set by
  hand and declare what should be reproducible.

## Still open

- Browser profiles: Ubuntu import skipped on purpose (settings come from
  `browser_setup`). Revisit personal data (bookmarks, passwords, extensions)
  after using the NixOS profiles for a while; the Ubuntu copies are in
  `/mnt/archive/pre-nixos-home/sam-dev/` (see `docs/BROWSER-MIGRATION.md`).
- Untested: whether Nix's automatic low-space GC (`min-free`) respects the
  400 GiB cap on `@clients`.
- Untested: a real deploy to a client server (signing key the clients trust,
  or `--no-check-sigs` as a trusted user).
- `docs/BACKUP-AND-DATA-ENCRYPTION.md` and `docs/SHARED-DATA-DRIVES.md` both
  describe remote Docker; they agree, but one could link to the other.
- laptop-intel's 20 `.age` files open only with the laptop's keys: run
  `just rekey-secrets` on the laptop (after pulling) so the master and
  recovery keys can open them.

- **Data layout and repos** (see `docs/SHARED-DATA-DRIVES.md`, Repos on the
  SSD):
  - Output root: a setting in syntek-media and syntek-author to write
    outputs straight to `~/Data/<area>/...` (review requested from those
    template sessions on 14/10).
  - syntek-business-docs: move its PDFs, scans and zips (`library/src/...`)
    to `~/Data/business/docs/`; decide whether to rewrite git history,
    which holds sensitive documents (driving licence, client contract scan,
    expenses zip).
  - neovim-course media (Git LFS now) likely follow the same pattern.
  - Off-site gap: in-progress gitignored media are only on the SSD until
    moved to `~/Data`.
  - Google Drive (personal, business Workspace): ciphertext backups only of
    `docs/ photos/ videos/ audio/` (rclone crypt or restic, a key per area,
    keys in agenix). Long term, self-hosted Forgejo and a media library
    replace the VeraCrypt drives; remote access over WireGuard from
    laptop-intel and the Framework. Keep paths host-neutral (`~/Data`): an
    AMD + NVIDIA devtower will replace devtower-intel.
  - ElevenLabs base path stays `/home/sam-desktop`; open media projects on
    the drive through `~/Data`.

## Where to read

- `docs/BACKUP-AND-DATA-ENCRYPTION.md`: OS, home and store procedures,
  config-status callout, client store, generations, remote Docker
- `docs/SHARED-DATA-DRIVES.md`: 4TB pair, repos on the SSD, Samba, remote access
- `docs/DISK-PREVENTION.md`: GC, Docker limits, client store summary
- `docs/SECRETS.md`: LUKS escrow secrets section
