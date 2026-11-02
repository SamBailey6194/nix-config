# DDEV HTTPS (mkcert CA)

**Last Updated**: 02/11/2026
**Version**: 1.5.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## What needs a CA

DDEV runs on Docker, and its router serves every project over HTTPS with
certificates signed by **one mkcert CA per machine** (`mkcert -CAROOT`,
`~/.local/share/mkcert`). Trust that CA once and every DDEV project on the
machine is covered: `*.ddev.site`, `additional_hostnames` and any
`project_tld`. Nothing is done per project.

Docker projects that are not DDEV and are served over `http://localhost` need
none of this. A non-DDEV project that serves HTTPS with mkcert certificates is
covered too, because it signs with the same CA.

## Set up a machine (once)

```bash
just ddev-ca                          # creates the CA if missing, writes certs/mkcert/<host>.pem
git add certs/mkcert/$(hostname).pem  # flake evaluation only sees tracked files
just rebuild
ddev poweroff && ddev start           # router re-issues certificates from the CA
```

Run `ddev start` in each project you use. Check with:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<project>.ddev.site/   # 200, no -k
```

`just ddev-ca` re-encodes the certificate with `openssl x509`, so only the
public certificate reaches the repository. `rootCA-key.pem` stays in
`mkcert -CAROOT`. Each machine has its own CA and trusts only its own
certificate (`networking.hostName` selects the file). If a host has no file,
nothing is trusted and evaluation still succeeds.

The certificate is public and needs no agenix. The key is deliberately not
in agenix either. It can sign a certificate for any domain, and every
machine trusts its own CA, so it stays on its own machine. After a
reinstall, `just ddev-ca` makes a new CA; commit the changed file.

Do not run `mkcert -install` yourself. The recipe creates the CA with
`TRUST_STORES=none`, since the NixOS system bundle is read-only and the
configuration below installs the trust instead.

## Where it is trusted

| Consumer | Mechanism | File |
|----------|-----------|------|
| curl, Python, Go, git (system bundle) | `security.pki.certificateFiles` | `modules/software/ddev-ca.nix` |
| Firefox Developer Edition, LibreWolf, Zen, and the Firefox DevTools MCP's fresh profiles | Gecko policy `Certificates.Install` | `modules/security/browser-policies/default.nix` |
| Brave, and Chromium launched by the Playwright MCP (isolated profile) | `~/.pki/nssdb`, written on every Home Manager activation | `home/modules/ddev-ca.nix` |

The Gecko policies also add `.ddev.site` to the locked proxy's
`Passthrough`, matching Brave's existing `ProxyBypassList`. Through Squid,
DDEV sites end in its "Access Denied" page. `*.ddev.site` resolves to
`127.0.0.1` in public DNS, so the bypass reaches nothing off this machine. The
proxy and its lock are unchanged, but the policy files' hashes change, so the
squid-digest watcher reports the first rebuild that includes this change.

Node.js ignores the system bundle by default. For host-side Node scripts that
call a DDEV site, use `NODE_EXTRA_CA_CERTS=$(mkcert -CAROOT)/rootCA.pem` or
`node --use-system-ca`.

## Replacing the CA

If `mkcert -CAROOT` is deleted or the CA expires (mkcert issues it for ten
years), run `just ddev-ca` again, commit the changed file and rebuild. The NSS
entry is replaced on activation. Old CAs that Gecko profiles already imported
stay in those profiles but sign nothing new.
