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
- **Syntek repos**: `syntek-business-docs` and `syntek-content` live in
  `/mnt/data/Business/` on the data drive, with the syntek-studio git config.

## Next steps, in order

1. **Rebuild** devtower-intel on `main` (`just rebuild`) and check it boots
   and the new login apps land on ws3/4/11 with focus on ws2. If Teams steals
   focus, its window belongs to a child process and the silent rule missed it.
2. **OS drive TPM2 + escrow secret**: done (TPM2 PCR 7 in keyslot 1,
   `-os.age` verified and committed, header backup
   `luks/cryptroot-header-2026-10-13-tpm2.age` on KEYS). Left: reboot and
   confirm there is no passphrase prompt.
3. **Master key backup**: done via the KEYS recovery key instead of a copy.
   All 12 devtower-intel secrets rekeyed for it (host key), and the stick key
   alone decrypted `luks-passphrase-devtower-intel-os.age`.
4. **Home drive (Samsung 512GB, by serial)**: done (`fe9f33a`). `/home` is
   `crypthome[/@home]` on the Samsung, TPM2 unlock at boot on 13/10 11:34,
   `-home.age` escrow committed, dead Ubuntu boot entry (`Boot0006`)
   removed. Skipped on purpose: selective Ubuntu file restore (home step 9)
   and the `crypthome` header backup (home step 10). Left for later: delete
   the Intel `@home` after pruning old generations (home step 12).
5. **Pending config** (below): written, not yet rebuilt or committed. Run
   `just check`, rebuild and commit it before any store-drive work.
6. **4TB pair**: `docs/SHARED-DATA-DRIVES.md`, Conversion.
7. **Store drive (870 EVO 2TB, serial `S6PPNX0T910090T`; `sdc` on 13/10,
   not `sda`, which is now a 931.5G Windows-style disk)**: same backup doc,
   Store section. Copy out anything wanted from `/mnt/ubuntu-nix` and
   `/mnt/ubuntu-docker` first (no usable backup exists).
8. **Remote access**: `wg-lan`, sshd hardening, Samba, Docker context.

## Pending config changes (written, not yet rebuilt or committed)

All in the working tree; none of it has been through `just check` or a
rebuild yet. The store parts take effect only once `dataDrives.store` is
filled in.

- Done: `hosts/devtower-intel/data-drives.nix`: no `/nix` mount and no initrd
  unlock for the store; crypttab after-boot unlock
  (`tpm2-device=auto,nofail,discard`); `nofail` mounts for `@docker`, `@vm`,
  `@clients`; `RequiresMountsFor` on docker and libvirtd; the
  `store-quotas.service` oneshot that re-applies the caps at boot.
- Done: `hosts/devtower-intel/disks.nix`: the three caps (`storeQuotas`).
- Done: `secrets/secrets.nix`: `-data` renamed to `-store` (still commented
  out until store step 7); the "fallback" comments now say escrow only.
- Done: `modules/core/nix-gc.nix`: keep newest 5 system generations, no age
  rule, every user's home-manager profile pruned to 5 too.
- Done: `justfile`: `deploy-client NAME HOST [--key FILE | --no-check-sigs]`
  (`client-store-guard --no-db`, shared `flock`, build with `--out-link` to a
  pending GC root, sign with `~/.config/nix/client-store-signing.key` by
  default, `nix copy --from`, activate on the server under `systemd-run`, then
  set the client profile and drop the pending root); `backup-luks-headers
  DEVICE` takes a LUKS UUID or `/dev/disk/by-uuid/` path.
- Done: `hosts/devtower-intel/client-store.nix` (new, imported by
  `full.nix`): `client-store-guard`, and the weekly `client-store-gc`
  service + timer (`Persistent=true`).
- Done: comments in `hardware-configuration.nix` and `disk-prevention.nix`:
  `/nix` stays on the OS drive.
- Done: `home/modules/git.nix`: `includeIf."gitdir:/mnt/data/Business/"` ->
  `~/.gitconfig-syntek`.
- Done: `config/hypr/60-keybinds.lua`: SUPER + = / SUPER + - raise and lower
  the volume by 5% (repeat while held), a keyboard fallback for the
  SteelSeries volume roller; listed in both `KEYBINDS` files.
- Later: `wg-lan` module and agenix keys, Mullvad bypass, sshd key-only on
  `wg-lan`, Samba, Docker published ports bound to 127.0.0.1 / tunnel IP.

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

## Where to read

- `docs/BACKUP-AND-DATA-ENCRYPTION.md`: OS, home and store procedures,
  config-status callout, client store, generations, remote Docker
- `docs/SHARED-DATA-DRIVES.md`: 4TB pair, Syntek repos, Samba, remote access
- `docs/DISK-PREVENTION.md`: GC, Docker limits, client store summary
- `docs/SECRETS.md`: LUKS escrow secrets section
