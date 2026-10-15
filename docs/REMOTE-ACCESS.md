# Remote access: laptop-intel working on devtower-intel

**Status**: design agreed on 15/10/2026, not implemented. This file is the
reference for it; `HANDOVER.md` step 8 and the "Later" sections of
[SHARED-DATA-DRIVES.md](SHARED-DATA-DRIVES.md) and
[BACKUP-AND-DATA-ENCRYPTION.md](BACKUP-AND-DATA-ENCRYPTION.md#remote-docker-from-laptop-intel-planned)
point here.

## Goal

laptop-intel, from anywhere, can open the files on devtower-intel and use its
computing power for work the laptop is too weak for. All work and all writes
happen on devtower-intel: the laptop keeps only its own `nix-config` clone
(the declarative OS), no project repos and no data.

The same design must carry over unchanged to the Framework laptop and to the
future AMD + NVIDIA devtower that replaces devtower-intel: shared modules,
per-device keys and addresses only, host-neutral paths (`~/Data`, `~/Repos`).

## Topology

```text
laptop-intel ──(WireGuard wg-lan, UDP, encrypted)──▶ devtower-intel
   anywhere           10.200.0.0/24                     home
                                                         ├── sshd       (wg-lan only)
                                                         ├── Samba      (wg-lan only)
                                                         ├── Docker     (over SSH)
                                                         └── llama-swap (wg-lan only)
```

- **wg-lan** is its own WireGuard interface, separate from Mullvad and from
  `wg-arwyn` (`arwyn-1` belongs to the i-had-dad-deployment project and is
  not used as a relay for personal traffic). Keys per device in agenix.
  devtower-intel's routing must bypass Mullvad for wg-lan.
- **Reaching home from anywhere:** one UDP port forwarded on the home router
  to devtower-intel, plus a dynamic-DNS name. Needs a real public IPv4 (no
  carrier-grade NAT); check before building. Fallback if the ISP uses CGNAT:
  a small personal relay VPS (e.g. Hetzner), or Tailscale/Headscale.
- Nothing listens on the LAN or the internet except the WireGuard port.

## Components

| Piece | Purpose | Access control |
| --- | --- | --- |
| WireGuard `wg-lan` | the tunnel | per-device keys in agenix; firewall opens only its UDP port |
| sshd | terminal, Zed remote, Docker context | key-only, laptop's per-device key, listens on `wg-lan` only |
| Samba | laptop file manager and apps open the shares below | `wg-lan` only, SMB3 with encryption required, `hosts allow` the tunnel subnet, one Samba login (password in agenix), files owned by `sam-desktop` |
| Zed SSH remote | edit `~/Repos/...`; language servers, terminal, tasks run on devtower | via sshd; `ssh_connections` declared in the Zed settings |
| Neovim over SSH | `ssh devtower` then `nvim` there, inside zellij (or tmux) | via sshd; yanks reach the laptop clipboard through OSC 52 (Neovim 0.10+, kitty) |
| Docker context | `docker --context devtower …` runs containers on devtower's store drive | via sshd; the Docker socket and `tcp://2375` are never exposed; published ports bound to `127.0.0.1` or the tunnel IP |
| Local LLMs | the laptop uses devtower's `llama-swap` | bound to the tunnel address or reached through SSH |

Zed's remote mode is free and open source: the laptop runs the interface,
devtower runs a headless Zed server in `~/.zed_server`, downloaded on first
connect (it runs on NixOS through nix-ld; both machines get Zed from the same
flake, so versions match). Neovim needs nothing extra: its configuration comes
from the same Home Manager modules on both machines.

Out of scope: remote Nix builds (not needed).

## Samba shares

| Share | Path on devtower-intel | Laptop access |
| --- | --- | --- |
| `business` | `/mnt/data/business` | read-write |
| `personal` | `/mnt/data/personal` | read-write |
| `archive` | `/mnt/data/archive` | read-only |
| `repos` | `~/Repos` | read-write |
| not shared | DavinciProj root (`Databases/`, `Media/`, `Projects/`, `Renders/`), the rest of `~`, `/mnt/data-mirror`, `/var/lib/desktop-secrets` | none |

- **Recycle bin** on the read-write shares: deletions from the laptop go to a
  hidden `.recycle/` for 30 days (beside the mirror's own 30-day history).
- **Dotfiles hidden** in listings (`.git`, `.data-primary`), still accessible.
- **SMB3 POSIX extensions** on the server and the `posix` mount option on the
  laptop, so the repos' symlinks (`.agents -> .claude`) and exec bits survive.
- The data shares are served only while `/mnt/data` is mounted; if the WD is
  not unlocked, Samba serves nothing rather than empty folders.

## How to work

- **Files:** open them over Samba from the laptop; saves land on devtower.
- **Repos:** edit over Samba if convenient, but run git, builds, tests and
  language servers through Zed's remote or an SSH terminal, so they run on
  devtower against its local disk (over the network they are slow, and git's
  lock files can trip on latency).
- **Never edit the same file from both sides at once** (an editor on devtower
  and an app on the laptop): Samba's locking does not cover an editor's
  in-memory copy.
- **Availability:** only while devtower-intel is booted into NixOS and awake.
  Wake-on-LAN over the tunnel is a possible later addition.

## Open decisions

- Router: can it forward a UDP port, and is the home connection behind CGNAT?
  That settles direct tunnel versus relay.
- Tunnel subnet and port (proposal: `10.200.0.0/24`, devtower `.1`,
  laptop-intel `.2`, Framework `.3`).

## Implementation order (one change)

1. `wg-lan` module and agenix keys (laptop's private key generated on the
   laptop), Mullvad bypass, firewall, dynamic DNS.
2. sshd key-only on `wg-lan`.
3. Samba with the shares above.
4. Zed `ssh_connections`, Neovim OSC 52 clipboard, zellij.
5. Docker context on the laptop; published-port binding on devtower.
6. `llama-swap` on the tunnel address.
7. Tests and evaluation for both hosts; then rebuild devtower-intel and the
   laptop, and check each piece from the laptop away from home.
