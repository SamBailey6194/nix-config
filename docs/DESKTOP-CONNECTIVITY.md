# Desktop VPN, SSH and accountability

The Intel configuration imports `hosts/devtower-intel/connectivity.nix` in all
stages. Its WireGuard link uses the existing Ubuntu desktop peer:

- Desktop address: `10.100.0.2/32`; server SSH address: `10.100.0.1`.
- Server endpoint: `65.109.70.23:51820`; pinned server public key and SSH host key
  come from the existing arwyn module and local deployment configuration.
- SSH alias: `arwyn-1`, user `admin`, identity `~/.ssh/id_ed25519_admin`.
- Only `10.100.0.1/32` is routed into the admin tunnel. This does not route
  ordinary Internet traffic to arwyn-1.

The local deployment repo identifies this peer as `sam-ubuntu-pc`. This migration
preserves its key pair and PSK; no remote peer changes are required if those
existing keys remain correct. Do not run Ubuntu and NixOS with that identity at
the same time. A later new key pair needs a corresponding server-side change
performed from another working admin connection.

### Prepared replacement desktop peer

A separate `sam-desktop` key pair and PSK have now been generated. Its public
key is `03zo6BzI/IyaWxna57fisYJ3HbrWvlSNF07tCIX42Ac=`; the proposed address is
`10.100.0.8/32`, unused in the checked arwyn-1 configuration. Add it alongside
`sam-ubuntu-pc` so Ubuntu retains its working connection during migration.
The server needs that public key and `wireguard-psk-sam-desktop.age`, encrypted
from the same PSK as this repository's
`wireguard-arwyn-devtower-intel-psk.age`. The private key belongs only on the
desktop and is encrypted as `wireguard-arwyn-devtower-intel-private.age`.

These new secrets currently target the laptop agenix editor key. After installing
NixOS, add the verified desktop SSH host public key to `devtowerIntelKeys` in
`secrets/secrets.nix`, and re-encrypt the desktop secrets using an existing
recipient identity. WireGuard public keys cannot serve as age recipients.
The checked-in connectivity configuration still uses the exported Ubuntu keys
at `.2`: the new peer is not active merely because its `.age` files exist.
Switch to `.8` and the new credentials only after the server peer is deployed;
keep a working laptop admin connection while checking the new handshake and SSH.

## Before shutting down Ubuntu

Run the export helper manually, while Ubuntu's `wg0` is still available:

```sh
cd /home/sam-dev/Repos/personal/nix-config
sudo python3 scripts/export-ubuntu-migration-secrets.py
```

It checks the desktop public key against the recorded server peer and exports
three root-only files into `/etc/nixos-migration`. It does not print keys, run
email, ping Healthchecks, or modify the current VPN. It refuses to overwrite an
existing export. The exported accountability environment contains only SMTP
credentials, recipient and heartbeat URL; Ubuntu-specific paths/user names are
replaced by the NixOS module's defaults.

Keep `.ssh/id_ed25519_admin`, its public key and relevant known_hosts entries in
the home backup as well. The VPN keys and SSH key are different credentials;
both are needed. Never commit these files to Git or put them in a Nix string.
Follow the [offline encrypted backup procedure](INSTALL-INTEL-MANUALLY.md).

## Restore on the encrypted NixOS installation

The installation guide restores the exported credential directory to the live
installer's `/tmp/restore-check`, then copies it into encrypted NixOS storage.
If restoring after first boot instead, use Restic as root with the recorded
`before-nixos` snapshot and include `/media/ubuntu-root/etc/nixos-migration`.
Restore into a private temporary directory, then install the resulting files:

```sh
sudo install -d -m 0750 -o root -g sam-desktop /var/lib/desktop-secrets
# Set this to the directory restored by Restic, not the repository itself.
read -r -p 'Restored nixos-migration directory: ' restored_secrets
sudo install -m 0400 -o root -g root "$restored_secrets/arwyn-private.key" /var/lib/desktop-secrets/arwyn-private.key
sudo install -m 0400 -o root -g root "$restored_secrets/arwyn-psk.key" /var/lib/desktop-secrets/arwyn-psk.key
sudo install -m 0640 -o root -g sam-desktop "$restored_secrets/squid-digest.env" /var/lib/desktop-secrets/squid-digest.env
install -d -m 0700 ~/.ssh
install -m 0600 /mnt/ubuntu-home/sam-dev/.ssh/id_ed25519_admin ~/.ssh/id_ed25519_admin
```

Do not overwrite an existing SSH identity without preserving it first. After a
runtime WireGuard key is changed, explicitly restart its service: it is not a
Nix store input and a rebuild cannot detect a change to its contents.

These checks contact only the admin server when you run them:

```sh
sudo systemctl restart wg-quick-wg-arwyn
sudo wg show wg-arwyn
ssh -G arwyn-1 | rg '^(hostname|user|identityfile) '
ssh arwyn-1
```

The VPN unit skips startup until both runtime key files exist. A skipped unit
is not proof of connectivity: check a recent handshake and successful SSH.
The same alias exists from the minimal stage, so admin access does not depend
on the full desktop build. Preserve an independently working laptop admin
connection while validating the new desktop.

## Mullvad when renewed

Graphical stages include the official Mullvad daemon, CLI and GUI. A fresh
installation has no account or connection configured; renewal, login and
connection are manual. Do not restore Ubuntu's old auto-connect/lockdown state
before ordinary networking and arwyn SSH have passed their checks.

After renewing, log into the Mullvad GUI locally, connect, and check its account
status and connection. Do not put the account number into this repository.
The `arwyn-mullvad-bypass` service applies narrow exceptions for the WireGuard
handshake to `65.109.70.23:51820/UDP` and SSH inside that tunnel to
`10.100.0.1:22/TCP`. These exceptions remain available during Mullvad's blocked
state. They follow [Mullvad's documented Linux mark mechanism](https://mullvad.net/en/help/split-tunneling-with-linux-advanced),
with route-hook priority -100, before Mullvad's filtering. They do not exempt
browsers, DNS, Squid, or an entire private network. The admin connection still
uses WireGuard encryption. The old custom Mullvad WireGuard/kill-switch module
is not enabled on this host alongside the app.

```sh
systemctl status mullvad-daemon arwyn-mullvad-bypass
mullvad status
sudo nft list table inet arwyn_mullvad_bypass
ip route get 10.100.0.1
sudo wg show wg-arwyn
ssh arwyn-1
```

Verify ordinary traffic uses Mullvad, and verify SSH both connected and
disconnected. Recheck exclusions after upgrading Mullvad. Actual account login,
VPN handshakes and blocked-state behaviour have not been tested during this
configuration preparation.

## Accountability to Healthchecks.io and your wife

Ubuntu's current environment has all four required credentials and a heartbeat
host of `hc-ping.com` (Healthchecks.io). The existing email recipient and
heartbeat URL are preserved privately; their values are not copied into Git.
Verify in the Healthchecks dashboard that this desktop check notifies your
wife and that its expected period/grace allow the five-minute watch interval.
The local environment alone cannot prove who receives dashboard notifications.

Graphical stages enable the pinned `accountability_script` tool with:

- A Sunday 18:00 weekly adult-domain digest to the existing email recipient.
- A root tamper/heartbeat check every five minutes, starting after two minutes.
- A per-user check of the managed browser policies every five minutes.
- Weekly adult-domain list refresh and fourteen rotations of Squid logs.

The units skip when the runtime environment file is absent. Once it has been
restored, enabled timers can begin sending their configured reports/alerts and
heartbeat pings. This is part of activating the requested accountability setup;
no test message was sent while preparing the configuration.

The NixOS Squid configuration has a loopback-only listener and one log stream
in the expected format. The obsolete Ubuntu `dns_v4_first` directive is omitted
for Squid 7, which [does not support it](https://www.squid-cache.org/Doc/config/dns_v4_first/).
The per-user watcher is patched to check browser policies rather than GNOME
settings because this desktop uses Hyprland.

Inspect service state, root/user timers and logs after the graphical-stage
rebuild. Do not publish logs or credentials:

```sh
systemctl list-timers 'squid-digest-*'
systemctl --user list-timers 'squid-digest-*'
systemctl status squid squid-digest-watch.service
systemctl --user status squid-digest-watch-proxy.service
sudo journalctl -u squid-digest-watch.service -n 20
```

Check the next scheduled heartbeat in the Healthchecks dashboard and the next
weekly email with your wife. A successful configuration evaluation is not a
proof of email delivery. You can explicitly run a test email later, knowing it
sends to the configured recipient; it is not included in the automatic audit.
