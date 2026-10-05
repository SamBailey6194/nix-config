# Ubuntu browser settings and profile transfer

All graphical NixOS stages install Zen, Brave, Firefox Developer Edition and
LibreWolf with policies imported from the pinned `browser_setup` input.
The pinned revision matches the local repository inspected on 5 October 2026:
`6e9f306f967f3c8bbe68323a931bf42020a26233`.
Updating the separate repository requires updating this flake input as well.

## Settings audited on Ubuntu

| Browser | Ubuntu policy file | Comparison with browser_setup |
| --- | --- | --- |
| Zen | `/opt/zen/distribution/policies.json` | Exact match |
| Firefox Developer | `/opt/firefox-developer/distribution/policies.json` | Exact match |
| LibreWolf | `/etc/librewolf/policies/policies.json` | Exact match |
| Brave | `/etc/brave/policies/managed/syntek-accountability.json` | Adds `*.ddev.site` and `*.localhost` proxy bypasses |

The Brave bypasses are retained. Nix-specific search engine overrides were removed
so the repository remains the policy source. Firefox Developer and LibreWolf
retain Ubuntu's vertical tabs, revamped sidebar and hidden bookmarks toolbar
as default preferences. Zen defaults to its observed collapsed sidebar.
Brave's home button and bookmarks toolbar preferences are preserved by copying
its profile; they are not imposed as new enterprise locks.

The Firefox and LibreWolf packages include their policies. Zen's policies are
attached to its unwrapped binary, where it actually reads them. Inspectable
copies remain under `/etc` for accountability checks. A loopback-only Squid proxy
is enabled without requiring the separate digest/email secrets; its logs rotate.
The existing QUIC firewall rule is shared from `browser_setup` too.

## Preserve personal browser data

Policies do not include bookmarks, passwords, tabs, extension preferences or
browser-specific workspaces. The retained Ubuntu home and encrypted backup must
include these directories. Close every browser before the final backup/copy.
Do not copy a profile while another process is using it.

| Browser | Ubuntu directory under `/home/sam-dev` | NixOS directory under `/home/sam-desktop` |
| --- | --- | --- |
| Zen | `.config/zen` | `.config/zen` |
| Firefox Developer | `.mozilla/firefox` | `.mozilla/firefox` |
| LibreWolf | `.config/librewolf/librewolf` | `.librewolf` |
| Brave | `.config/BraveSoftware/Brave-Browser` | `.config/BraveSoftware/Brave-Browser` |

Run these commands **on NixOS as sam-desktop**, before launching the browsers.
They make a separate backup of any new NixOS profiles and copy the Ubuntu files;
the retained Ubuntu directories are never modified. Ensure the encrypted root
has enough free space first. Native messaging files are excluded because Home
Manager supplies the NixOS Claude host with its correct executable path.

```sh
oldhome=/mnt/ubuntu-home/sam-dev
backup="$HOME/browser-profiles-before-import-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$backup"
python3 - "$oldhome" "$HOME" "$backup" <<'PYTHON'
from pathlib import Path
import shutil, sys
source, home, backup = map(Path, sys.argv[1:])
paths = {
    '.config/zen': '.config/zen',
    '.mozilla/firefox': '.mozilla/firefox',
    '.config/librewolf/librewolf': '.librewolf',
    '.config/BraveSoftware/Brave-Browser': '.config/BraveSoftware/Brave-Browser',
}
ignore = shutil.ignore_patterns('parent.lock', '.parentlock', 'lock',
    'Singleton*', 'Cache', 'Code Cache', 'GPUCache', 'NativeMessagingHosts')
for old, new in paths.items():
    src, dst = source / old, home / new
    if not src.is_dir():
        raise SystemExit(f'Missing source profile directory: {src}')
    if dst.exists() or dst.is_symlink():
        saved = backup / new
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(dst), str(saved))
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dst, ignore=ignore)
    print(f'Copied {old} to {new}')
PYTHON
```

Because the Brave directory backup includes Home Manager's native host, rebuild
or rerun Home Manager activation before using Claude-in-Chrome. Keep the backup
until the copied profiles and native host have been checked. Do not repeat the
copy after browsing without backing up the new data first.

Browser installation IDs change between Ubuntu and NixOS. Start Gecko browsers
with `zen --ProfileManager`, `firefox-devedition --ProfileManager` and
`librewolf --ProfileManager`, and explicitly select the copied active profile:
Zen `ow0ajrkb.Default (release)`, Firefox Developer
`8lvxol3a.dev-edition-default`, LibreWolf `fukwiahx.default-default`.
If the profile is not listed, choose an existing profile folder in the manager;
never select a profile belonging to another browser. Check Zen's installed
binary name with `command -v zen zen-beta` if necessary.

Check bookmarks, history, extensions, tabs and downloads before removing any
backup. Ubuntu download paths referencing `/home/sam-dev` need changing in browser
preferences. Brave passwords can depend on the GNOME keyring: preserve
`.local/share/keyrings` in the encrypted backup, and use a compatible secret-service
provider or import a separately prepared password export. Do not assume a profile
copy alone transfers decryptable Brave passwords. Firefox passwords require both
`key4.db` and `logins.json`, included in the full profile copy.

## First-launch verification

Open `about:policies` in all three Gecko browsers and check Active and Errors.
Open `brave://policy`, reload policies, and verify the proxy, extension and
privacy policies. Check `systemctl status squid squid-quic-block`,
`ss -ltn 'sport = :3128'` (listener must be loopback only), and ordinary browsing.
Check DDEV sites in Brave and the Claude browser extension separately.

Zen goes to workspace 7 on the left monitor. Brave, Firefox Developer and
LibreWolf go to workspace 10 on the centre monitor. See
[monitor configuration](INTEL-MONITORS.md).
