# Phone Photo Sync (Pixel 8 Pro → devtower-intel)

Weekly, wireless upload of the Pixel 8 Pro's photos and videos into
`~/Data/personal/photos/pixel-8-pro/` on devtower-intel, over a private
WireGuard tunnel, using Syncthing.

| Piece | Where | What it does |
|-------|-------|--------------|
| `modules/network/wireguard-home.nix` | module | `wg-home` WireGuard server, phone as the only peer, firewall, Mullvad exclusion |
| `hosts/devtower-intel/photo-sync.nix` | host | Enables the module, Syncthing (receive-only), weekly timer |
| WireGuard (Android app) | phone | Split tunnel to `10.200.0.1/32` only |
| Syncthing-Fork (Android) | phone | Send-only folders for DCIM, Pictures, Movies |

## How it works

```
Pixel 8 Pro                                devtower-intel
Syncthing-Fork (send-only)                 Syncthing (receive-only, ignoreDelete)
  10.200.0.2 ──── WireGuard, UDP 51821 ────► wg-home 10.200.0.1:22000
                  via router port forward     └─► ~/Data/personal/photos/pixel-8-pro/
                                                    DCIM/  Pictures/  Movies/
```

- **Weekly window**: `photo-sync.timer` starts Syncthing every Sunday at 02:00
  (at the next boot if the PC was off). `photo-sync-stop.timer` stops it 6
  hours after any start. Syncthing is not started at boot.
- **Archive, not mirror**: the desktop folders are receive-only with
  `ignoreDelete`, so deleting photos on the phone to free space never deletes
  them here. Files you delete on the desktop are not re-sent unless they change
  on the phone. Anything Syncthing would remove or overwrite on the desktop (a
  photo edited on the phone, a new file reusing an old name such as `1.jpg`, or
  **Revert Local Changes** in the GUI) is first moved into that folder's
  `.stversions/` (simple versioning, up to 10 versions per file, never expired).
  `.stversions/` is never synced. Prune it by hand if it grows.
- **Reachable only through the tunnel**: Syncthing listens on
  `tcp://10.200.0.1:22000` only; global/local discovery, relays and NAT
  traversal are off; the GUI is on `127.0.0.1:8384`.
- **Tunnel is locked down**: `wg-home` is not a trusted interface. The only new
  connection the phone may open is TCP 22000 to `10.200.0.1`; everything else
  arriving on `wg-home` is dropped (before Docker, Tailscale or any other
  allowed port can see it). The phone's tunnel is split: only `10.200.0.1/32`
  goes through it, everything else on the phone is unaffected.
- **Mullvad**: when `services.mullvad-vpn` is on, the `wg-home-mullvad-bypass`
  service adds an nftables table that marks the tunnel's traffic with Mullvad's
  split-tunnel marks (`ct mark 0x00000f41`, `meta mark 0x6d6f6c65`), so the
  Mullvad firewall accepts it and its replies leave via the LAN, not Mullvad.
  The `wg-home` interface also uses `fwmark 0x6d6f6c65` for the same reason.
  The table only exists while `wireguard-wg-home` is running, the outgoing rule
  also requires that fwmark, and UDP 51821 is a reserved local port
  (`net.ipv4.ip_local_reserved_ports`), so no other program's traffic can
  match it and bypass Mullvad.

Until the phone's WireGuard public key and Syncthing device ID are set, rebuilds
work and print warnings; nothing is half-configured.

## Setup

### 1. Desktop WireGuard keys

Root-only files on the encrypted disk, never in the repo or a Nix string:

```bash
sudo bash -c 'umask 077
  wg genkey > /var/lib/desktop-secrets/home-wg-private.key
  wg genpsk > /var/lib/desktop-secrets/home-wg-phone-psk.key
  chmod 0400 /var/lib/desktop-secrets/home-wg-private.key /var/lib/desktop-secrets/home-wg-phone-psk.key'

# Public key, for the phone (not secret):
sudo wg pubkey < /var/lib/desktop-secrets/home-wg-private.key
```

`wg` comes from `wireguard-tools`, already installed by `connectivity.nix`.

### 2. Phone WireGuard tunnel

In the **WireGuard** Android app: **+** → **Create from scratch**.

- **Name**: `home`
- **Interface**
  - **Private key**: tap the generate icon (the key never leaves the phone)
  - **Addresses**: `10.200.0.2/32`
  - **Listen port**, **DNS servers**, **MTU**: leave empty
- **Add peer**
  - **Public key**: the desktop public key from step 1
  - **Pre-shared key**: contents of `/var/lib/desktop-secrets/home-wg-phone-psk.key`
    (`sudo cat` it in a terminal and type it in by hand). Do not send it through
    a messaging app, the clipboard sync, or a generic QR-scanner app; those can
    keep a copy.
  - **Persistent keepalive**: `25`
  - **Endpoint**: `<public IP or DDNS name>:51821`
  - **Allowed IPs**: `10.200.0.1/32` (split tunnel: nothing else goes through it)

Save, then copy the phone's **Public key** shown under Interface.

### 3. Router port forward

On the home router, forward **UDP 51821** to devtower-intel's LAN address
(currently `192.168.1.183` on `eno1`; give it a DHCP reservation so it does not
change). If the home public IP is not static, set up dynamic DNS and use that
name as the phone's endpoint. Without this step the tunnel only works while the
phone is on the home Wi-Fi (with the LAN IP as endpoint).

**Home Wi-Fi and NAT loopback**: at Sunday 02:00 the phone is most likely at
home on Wi-Fi, where it will still dial the public IP or DDNS name. That only
works if the router supports NAT loopback (hairpin NAT). Test it: on home Wi-Fi,
turn the `home` tunnel on and check that `sudo wg show wg-home` shows a recent
handshake. If it does not, either:

- add a local DNS entry on the router that resolves the DDNS name to
  `192.168.1.183` while on the LAN (split DNS), or
- create a second tunnel on the phone (`home-lan`, same keys, endpoint
  `192.168.1.183:51821`) and use that one at home. The WireGuard app has no
  per-network endpoint, so you have to switch between them yourself.

### 4. Phone Syncthing device ID

Install **Syncthing-Fork** (F-Droid or Play Store; package
`com.github.catfriend1.syncthingandroid`) and open it once. Copy its device ID:
menu → **Show device ID**.

### 5. Phone always-on requirements

The weekly window opens without anyone touching the phone, so the phone has to
be ready all the time:

- **Always-on VPN**: Android Settings → Network & internet → VPN → WireGuard
  (gear icon) → **Always-on VPN** on. Leave "Block connections without VPN"
  **off**: the tunnel is split, so other traffic still uses the normal network.
  The WireGuard app must have the `home` tunnel turned on.
- **One VPN at a time**: Android allows only one active VPN app. While `home`
  is always on, you cannot also run the Mullvad app (or any other VPN) on the
  phone. If you do, the tunnel drops and that week's upload is missed until
  the next window or a manual sync.
- **Battery**: Android Settings → Apps → Syncthing-Fork → Battery →
  **Unrestricted**, and do the same for WireGuard. Otherwise Android may stop
  them overnight.
- **Syncthing-Fork run conditions** (Settings → Run conditions): make sure
  they allow syncing at 02:00 on Sunday. If you limit it to Wi-Fi and/or
  charging, the phone must be on home Wi-Fi (or charging) then. Check whether
  "run on mobile data" is on if you want uploads while away; it may be off by
  default.

### 6. Fill in the two public identifiers and rebuild

In `hosts/devtower-intel/photo-sync.nix`:

```nix
photoSync.phoneSyncthingId = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";

networking.wireguard-home = {
  enable = true;
  phonePublicKey = "<phone public key from step 2>";
};
```

Commit, then rebuild (`just rebuild`). The warnings about `wg-home` and the
Syncthing device ID should be gone. Check the tunnel side:

```bash
sudo wg show wg-home            # listening port 51821, peer = phone
systemctl status wireguard-wg-home wg-home-mullvad-bypass
```

### 7. Syncthing-Fork on the phone

Give Syncthing-Fork access to all files when it asks. Then:

1. **Settings → Connections**: turn **off** Global discovery, Local discovery,
   Enable relaying and Enable NAT traversal. (Run conditions: see step 5.)
2. **Devices → +**:
   - **Device ID**: the desktop's ID (on the desktop:
     `sudo systemctl start syncthing`, then the GUI at
     <http://127.0.0.1:8384> → Actions → Show ID, or the `myID` field of
     `/rest/system/status` with the `curl` command under [Verify](#verify),
     replacing the URL with `http://127.0.0.1:8384/rest/system/status` and the
     `jq` filter with `.myID`)
   - **Name**: `devtower-intel`
   - **Addresses**: `tcp://10.200.0.1:22000`
3. **Folders → +**, three times:

   | Folder label | Folder ID | Directory | Folder type |
   |--------------|-----------|-----------|-------------|
   | Pixel 8 Pro DCIM | `pixel-8-pro-dcim` | `/storage/emulated/0/DCIM` | Send only |
   | Pixel 8 Pro Pictures | `pixel-8-pro-pictures` | `/storage/emulated/0/Pictures` | Send only |
   | Pixel 8 Pro Movies | `pixel-8-pro-movies` | `/storage/emulated/0/Movies` | Send only |

   The IDs must match exactly. Share each with `devtower-intel`. In each
   folder's **Ignore patterns**, add:

   ```
   .thumbnails
   .trashed-*
   .pending-*
   ```

   (Android's thumbnail cache, items in the Photos bin, and half-written
   captures. The desktop ignores these too.)

The desktop side is fully declarative (`overrideDevices`/`overrideFolders`):
it already knows the phone and the three folders, so there is nothing to accept
in the desktop GUI. Changes made in the desktop GUI are reverted on the next
start.

**Never click "Revert Local Changes"** on these folders in the desktop GUI. On
a receive-only folder it deletes every file the phone does not have, which is
exactly what this archive is for. Versioning would move them into
`.stversions/` rather than lose them, but restoring them is tedious.

What to expect in the desktop GUI (this is normal for an archive):

- **Local Additions** before the phone first connects, and afterwards for any
  adb-copied file the phone no longer has. These files stay where they are.
- The folder may stay **Out of Sync**, or the phone may show the desktop below
  100%, once photos are deleted on the phone: `ignoreDelete` deliberately
  leaves those deletions unapplied.
- Files copied with adb that are identical to the phone's are reused without
  re-transfer (Syncthing hashes both sides on the first run). Files whose
  content differs are replaced by the phone's version, with the old copy
  moved into `.stversions/` (or kept as a `.sync-conflict-*` file).

**First start**: the very first time Syncthing starts (no
`~/.config/syncthing/config.xml` yet) it runs with Syncthing's own defaults for
a few seconds until `syncthing-init` applies the settings above. During that
window it listens on all interfaces (reachable only from trusted interfaces
such as `tailscale0`; the firewall still blocks 22000 elsewhere) and may
contact global discovery and relays. Every later start reuses the saved
config. To be on the safe side, do the first start yourself
(`sudo systemctl start syncthing`) and confirm with the GUI (Actions →
Settings → Connections) that discovery and relays are off.

## Manual sync

```bash
sudo systemctl start syncthing        # opens a 6-hour window now
sudo systemctl stop syncthing         # end it early
sudo systemctl stop photo-sync-stop.timer   # keep this run going past 6 hours
```

The phone has to be on the tunnel (WireGuard `home` on) with Syncthing-Fork
running. The first sync of a full camera roll can take longer than 6 hours on
mobile data; run it at home, and use the command above to extend the window.

## Verify

```bash
systemctl list-timers photo-sync.timer photo-sync-stop.timer
systemctl status syncthing syncthing-init
sudo wg show wg-home                  # "latest handshake" within the last ~2 min
journalctl -u syncthing -b            # "Established secure connection to ..."

# Folder state (completion %, need/inSync bytes):
curl -s -H "X-API-Key: $(grep -oP '(?<=<apikey>)[^<]+' ~/.config/syncthing/config.xml)" \
  'http://127.0.0.1:8384/rest/db/status?folder=pixel-8-pro-dcim' | jq '{state, needFiles, inSyncFiles}'
```

Or open <http://127.0.0.1:8384> while Syncthing runs: the phone should show
**Connected** and new photos should arrive in the three folders. The folders
may show **Local Additions** or **Out of Sync** for the reasons in step 7; that
is expected. Do not click **Revert Local Changes**.

Firewall checks:

```bash
sudo iptables -t mangle -S wg-home-pre          # replies, TCP 22000 from 10.200.0.2, then DROP
sudo nft list table inet wg_home_mullvad_bypass  # only with Mullvad enabled
```

## Troubleshooting

- **No handshake**: check the router forward (UDP 51821 → the desktop's current
  LAN IP), the endpoint on the phone, and that both public keys and the PSK
  match. `sudo wg show wg-home` shows the endpoint the phone last used.
- **`wireguard-wg-home` skipped**: a key file in `/var/lib/desktop-secrets` is
  missing (the units have `ConditionPathExists`).
- **Handshake but Syncthing never connects**: is Syncthing running
  (`systemctl status syncthing`)? Is `~/Data` mounted? Syncthing refuses to
  start without it (`RequiresMountsFor`).
- **Works with Mullvad off, not on**: `systemctl status wg-home-mullvad-bypass`;
  with Mullvad connected, compare `sudo nft list table inet mullvad` (its
  `ct mark 0x00000f41 accept` rules) and `ip rule` (the
  `not fwmark 0x6d6f6c65` rule) with the marks above.
- **Folder shows "Folder marker missing"**: the `.stfolder` marker is gone
  (for example `~/Data` was not mounted). Recreate it with
  `mkdir ~/Data/personal/photos/pixel-8-pro/DCIM/.stfolder` (and the others)
  once the drive is mounted.
