# Email: aerc and Claws Mail

Two mail clients, both on workspace 6 (4 on devtower-intel), from the
productivity stage up:

| Key                 | Client                                   | Configured in                |
|---------------------|------------------------------------------|------------------------------|
| `SUPER + E`         | aerc (terminal), with its keybind sheet  | `home/modules/aerc.nix`      |
| `SUPER + SHIFT + E` | Claws Mail (GUI, no browser engine)      | `home/modules/email.nix`     |

aerc is the default. `SUPER + E` opens it with `~/.config/aerc/KEYBINDS.md`
next to it (`q` closes the sheet, `SUPER + E` brings it back). The sheet and
aerc's `binds.conf` come from the same list in `aerc.nix`, so they always
match. HTML mail is rendered as text by w3m with network access blocked, so
no JavaScript runs and no remote content loads.

Claws keeps its own accounts and OAuth sign-in, set up through its GUI
(see the header of `email.nix`). The rest of this page is about aerc.

## Deleting

aerc's own delete expunges, which does the wrong thing on both providers: on
Gmail it only removes the Inbox label (the message is archived, not binned),
and on Microsoft 365 it skips Deleted Items. So in this setup:

| Where                          | `d` / `D`                                        |
|--------------------------------|--------------------------------------------------|
| Any folder, Gmail accounts     | Move to `[Gmail]/Bin`                            |
| Any folder, `premier`          | Move to `Deleted Items`                          |
| Inside the Bin / Deleted Items | Delete for good (`d` asks first)                 |

Gmail names the Bin after the account's display language: `[Gmail]/Bin` in
English (UK), `[Gmail]/Trash` in English (US). If an account shows the other
one (`:cf ` then Tab lists the folders), change its `trash` in `aerc.nix`.
A move to a folder that does not exist just fails, so nothing is lost.

## Accounts

| aerc tab   | Address                       | Provider                  | oama service |
|------------|-------------------------------|---------------------------|--------------|
| `personal` | samabailey6194@gmail.com      | Gmail                     | `google`     |
| `syntek`   | sam.bailey@syntekstudio.com   | Google Workspace          | `google`     |
| `premier`  | sam.bailey@premier.org.uk     | Microsoft 365 (client)    | `microsoft`  |

To add or change one, edit `accounts.email.accounts` in `aerc.nix`.

## How sign-in works

Gmail and Microsoft 365 accept only OAuth2 for IMAP and SMTP. aerc can use an
OAuth2 token but cannot get or renew one, so **oama** does that:

- aerc runs `oama access <address>` whenever it needs a token.
- oama stores the tokens in GNOME Keyring and renews the access token when
  it has expired.
- oama signs in as an **OAuth client** (an app registration). Its ID and
  secret are per device, in agenix: `secrets/oama-clients-<host>.age`,
  decrypted to `/run/agenix/oama-clients`.

The secret exists only on the **full** stage of each host, like every other
agenix secret. On earlier stages aerc starts, but every account shows a login
error.

## One-time setup

### 1. Google OAuth client (covers both Google accounts)

In the [Google Cloud console](https://console.cloud.google.com/), signed in as
the personal Gmail account:

1. Create a project, e.g. `aerc-mail`.
2. **Google Auth Platform → Branding**: app name and contact emails.
   **Audience**: user type **External**. **Data Access → Add or remove
   scopes**: add `https://mail.google.com/`.
3. **Audience → Publish app** (move it to *In production*). In *Testing*,
   Google expires refresh tokens after 7 days and you would have to sign in
   again every week. The app stays unverified. That is fine for your own
   accounts: at sign-in, choose *Advanced → Go to aerc-mail (unsafe)*.
4. **Clients → Create client → Desktop app**. Keep the client ID and secret.

For syntekstudio.com, if the Workspace limits third-party apps, allow this
client in the Admin console: **Security → Access and data control → API
controls → Manage App Access → Configure new app**, find it by client ID and set
its access to *Trusted*.

### 2. Microsoft client (Premier's Microsoft 365)

Premier's tenant decides whether an outside app may read the mailbox, so start
with their IT:

- **Ask first** whether they already have an approved mail client
  registration you can use. If they do, use its client ID and skip the rest of
  this step.
- Otherwise, register an app in an Entra tenant you control
  ([Entra admin centre](https://entra.microsoft.com/) → App registrations):
  - Supported account types: **Accounts in any organizational directory**
    (multitenant).
  - **Authentication → Allow public client flows: Yes**. oama uses the device
    code flow, which needs this setting and no client secret.
  - **API permissions**, delegated: Office 365 Exchange Online
    `IMAP.AccessAsUser.All` and `SMTP.Send`, plus `offline_access`. These are
    exactly the scopes oama asks for (`aerc.nix` narrows oama's default,
    which would also request POP).
  - Keep the **Application (client) ID**.
- Premier's admin may have to **grant consent** for the app in their tenant.
  The device-code sign-in tells you if consent is missing.
- Sending also needs **Authenticated SMTP** turned on for the mailbox. It is
  off by default in newer tenants. Without it, reading works but sending fails
  with `5.7.139`.

### 3. Store the client IDs (per device)

```bash
just edit-secret oama-clients-devtower-intel   # or oama-clients-laptop-intel
```

with exactly these three lines (no quotes):

```text
GOOGLE_CLIENT_ID=....apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=...
MICROSOFT_CLIENT_ID=...
```

The recipients are already set in `secrets/secrets.nix`, and
`modules/core/oama-secret.nix` picks the file up as soon as it exists. Then
`git add` the `.age` file and rebuild the full stage (`just rebuild`).

### 4. Sign in to each account (per device)

The tokens are stored in that device's keyring, so do this once on each
machine:

```bash
oama authorize google samabailey6194@gmail.com
oama authorize google sam.bailey@syntekstudio.com --nohint      # Workspace account
oama authorize microsoft sam.bailey@premier.org.uk --device     # prints a code + URL
```

Google opens a browser consent page. Microsoft shows a code to enter at the
printed URL. Sign in as the matching account each time. Then open aerc with
`SUPER + E`.

## Troubleshooting

| Symptom                                    | Check                                                                     |
|--------------------------------------------|---------------------------------------------------------------------------|
| Every account fails to log in              | `ls /run/agenix/oama-clients`. Missing means not the full stage, or the `.age` file is not committed |
| One account fails                          | `oama access <address>` should print a token. If not, run `oama authorize` again |
| Google: `invalid_grant` after a week       | The consent screen is still in *Testing*. Publish it (step 1.3), then authorise again |
| Microsoft: `AADSTS65001` / consent needed  | Premier's admin has to consent to the app (step 2)                        |
| Microsoft: sending fails, `5.7.139`        | Authenticated SMTP is off for the mailbox (step 2)                        |
| Keyring prompts or `secret-tool` errors    | GNOME Keyring is locked or not running. It unlocks at login              |

oama logs through syslog, so its messages are in the journal:
`journalctl --identifier oama -e`.

## Where things are

| What                          | File                                     |
|-------------------------------|------------------------------------------|
| aerc accounts, settings, keys | `home/modules/aerc.nix`                  |
| oama config                   | `home/modules/aerc.nix` (`oamaConfig`)   |
| OAuth client secret           | `modules/core/oama-secret.nix`, `secrets/secrets.nix` |
| `SUPER + E` layout            | `config/hypr/60-keybinds.lua`            |
| Workspace 6 rules             | `config/hypr/00-vars.lua`                |
| devtower-intel's ws 4 rules   | `config/hypr/devices/devtower-intel.lua` |
| Claws Mail                    | `home/modules/email.nix`                 |
