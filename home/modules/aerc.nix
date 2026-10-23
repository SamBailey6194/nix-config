{ lib, pkgs, ... }:

# Email in the terminal (aerc), the default mail client
#
#   SUPER + E          aerc on workspace 6 (3 on devtower-intel), with this
#                      keybind sheet beside it
#                      (config/hypr/60-keybinds.lua). Claws Mail, the GUI
#                      client in email.nix, moved to SUPER + SHIFT + E.
#   ?  inside aerc     aerc's own :help keys, for the live bindings
#
# ACCOUNTS
#
#   personal   samabailey6194@gmail.com      Gmail          (oama: google)
#   premier    sam.bailey@premier.org.uk     Microsoft 365, a client's tenant
#                                            (oama: microsoft)
#   syntek     sam.bailey@syntekstudio.com   Infomaniak     (device password)
#   syntek-<mailbox>  <mailbox>@syntekstudio.com, the same: contact, dev,
#                     finance, git, info, support
#
# AUTHENTICATION - INFOMANIAK
#
# Infomaniak has no OAuth2 for IMAP/SMTP: each mailbox signs in with a
# device password, one per mailbox and device, which agenix decrypts to
# /run/agenix/mail-<mailbox>-aerc (modules/core/mail-aerc-secrets.nix) and
# aerc reads with `cat`. Full-stage hosts only; without the file that account
# shows a login error. Readable by the user aerc runs as, so by any process
# running as that user too: they are never the root-only passwords the
# syntek-business-docs mail scripts use.
#
# AUTHENTICATION - WHY oama IS HERE BUT NOT IN email.nix
#
# Gmail and Microsoft 365 are OAuth2-only for IMAP/SMTP. aerc speaks XOAUTH2
# but cannot sign in or renew a token itself; oama does both. aerc runs
# `oama access <address>` (source-cred-cmd / outgoing-cred-cmd) and uses its
# output as the access token: with no token_endpoint in the URL, aerc does no
# refresh of its own (aerc-imap(5)). oama renews an expired token when asked,
# and keeps the tokens in GNOME Keyring (services.gnome.gnome-keyring, enabled
# by the Hyprland module), never on disk in the clear.
#
# The OAuth CLIENT (the app registration oama signs in as) is a separate,
# per-device secret: modules/core/oama-secret.nix decrypts
# secrets/oama-clients-<host>.age to /run/agenix/oama-clients, and the
# *_cmd entries below read it. Full-stage hosts only, like every agenix
# secret; without it oama has no client and aerc shows a login error per
# account. One-time setup (app registrations, the secret, `oama authorize`):
# docs/EMAIL.md.
#
# CONFIGURATION IS DECLARATIVE, UNLIKE CLAWS
#
# aerc only ever READS aerc.conf, binds.conf and accounts.conf, so all three
# come from the store. accounts.conf holds no secret - every credential is a
# command (`oama access` or a `cat` of an agenix file) - which is what makes `unsafe-accounts-conf` (below) safe.
#
# KEYBINDS ARE DECLARATIVE TOO
#
# `keybinds` below is the single source of truth, the same pattern as
# file-manager.nix for Yazi: it renders binds.conf AND the
# ~/.config/aerc/KEYBINDS.md sheet SUPER + E opens beside aerc, so the sheet
# cannot drift from what aerc runs. A binds.conf REPLACES aerc's built-in
# defaults rather than adding to them (aerc-binds(5)), so the list starts as a
# full copy of aerc 0.22's default binds.conf (share/aerc/binds.conf), plus
# the per-account delete overrides (trashBinds); change or add rows here. After an aerc update, diff that file against this list to
# pick up new defaults - nothing breaks if you don't, the new key just stays
# unbound.

let
  # ── Accounts ─────────────────────────────────────────────────────────────

  realName = "Sam Bailey";

  oama = "${pkgs.oama}/bin/oama";

  # Gmail exposes labels as IMAP folders under "[Gmail]/"; archiving means
  # leaving the inbox, which on Gmail is "All Mail". The Bin's folder name
  # follows the account's display language: "[Gmail]/Bin" in English (UK),
  # "[Gmail]/Trash" in English (US). Check with `:cf ` + Tab in aerc and
  # change `trash` below if an account shows the other one.
  gmail = {
    flavor = "gmail.com";
    drafts = "[Gmail]/Drafts";
    archive = "[Gmail]/All Mail";
    trash = "[Gmail]/Bin";
  };

  microsoft365 = {
    flavor = "outlook.office365.com";
    drafts = "Drafts";
    archive = "Archive";
    trash = "Deleted Items";
  };

  # Infomaniak: IMAP 993 (SSL/TLS) and SMTP 587 (STARTTLS), as Infomaniak
  # recommends, signing in with a device password (`secret`). Unlike Gmail
  # and Microsoft 365 it files no copy of mail sent over SMTP, so aerc copies
  # each sent message to `sent` itself.
  infomaniak = mailbox: {
    flavor = "plain";
    address = "${lib.replaceStrings [ "-" ] [ "." ] mailbox}@syntekstudio.com";
    secret = "mail-${mailbox}-aerc";
    imap = { host = "mail.infomaniak.com"; port = 993; tls.enable = true; };
    smtp = { host = "mail.infomaniak.com"; port = 587; tls = { enable = true; useStartTls = true; }; };
    # Folder names as Infomaniak's IMAP LIST shows them (checked 23/10/2026);
    # the archive is "Archives", plural.
    drafts = "Drafts";
    sent = "Sent";
    archive = "Archives";
    trash = "Trash";
  };

  # The aerc tab names. aerc orders tabs as accounts.conf lists them, which
  # Home Manager sorts by name, so the syntek-* mailboxes sit together.
  mailAccounts = {
    personal = gmail // { address = "samabailey6194@gmail.com"; primary = true; };
    premier = microsoft365 // { address = "sam.bailey@premier.org.uk"; };
    syntek = infomaniak "sam-bailey";
  } // lib.listToAttrs (map
    (mailbox: lib.nameValuePair "syntek-${mailbox}" (infomaniak mailbox))
    [ "contact" "dev" "finance" "git" "info" "support" ]);

  # OAuth2 via oama, or a device password for accounts with a `secret`.
  #
  # `sent = null` on the OAuth2 accounts is deliberate: HM turns folders.sent
  # into aerc's copy-to, and Gmail and Microsoft 365 both file a copy of
  # everything sent over SMTP themselves, so copying it again would leave
  # every message in Sent twice.
  #
  # `trash` is NOT an aerc setting (HM's folders.trash goes nowhere either):
  # it is used by the delete keybinds further down.
  mkAccount = _: a:
    let password = a ? secret; in
    {
      inherit (a) address flavor;
      inherit realName;
      primary = a.primary or false;
      userName = a.address;
      # A list, not a string: HM splits a string on spaces itself, and aerc
      # gets the command joined back with spaces either way.
      passwordCommand =
        if password then [ "${pkgs.coreutils}/bin/cat" "/run/agenix/${a.secret}" ]
        else [ oama "access" a.address ];
      folders = {
        inbox = "INBOX";
        sent = a.sent or null;
        inherit (a) drafts;
      };
      aerc = {
        enable = true;
        imapAuth = if password then null else "xoauth2";
        smtpAuth = if password then "plain" else "xoauth2";
        extraAccounts.archive = a.archive;
      };
    }
    // lib.optionalAttrs (a ? imap) { inherit (a) imap smtp; };

  # ── oama ────────────────────────────────────────────────────────────────

  # /run/agenix/oama-clients, written by modules/core/oama-secret.nix:
  #
  #   GOOGLE_CLIENT_ID=...
  #   GOOGLE_CLIENT_SECRET=...
  #   MICROSOFT_CLIENT_ID=...
  #
  # Read by key so the order of lines does not matter. The path is fixed, so
  # the config is the same on stages without the secret; oama then simply
  # finds no client ID.
  oamaClients = "/run/agenix/oama-clients";
  clientValue = key: "${pkgs.gnused}/bin/sed -n 's/^${key}=//p' ${oamaClients}";

  oamaConfig = {
    encryption.tag = "KEYRING";
    services = {
      google = {
        client_id_cmd = clientValue "GOOGLE_CLIENT_ID";
        client_secret_cmd = clientValue "GOOGLE_CLIENT_SECRET";
      };
      # oama's built-in Microsoft service points at the `common` tenant's
      # device-code endpoint (`oama printenv`); the flow itself is picked per
      # run, so authorise with `oama authorize microsoft <address> --device`.
      # Device code needs a client ID but no secret.
      #
      # The scope is narrowed from oama's default, which also asks for
      # POP.AccessAsUser.All: aerc never uses POP, and requesting only what
      # the app registration lists (docs/EMAIL.md) keeps the tenant's consent
      # prompt to IMAP + SMTP.
      microsoft = {
        client_id_cmd = clientValue "MICROSOFT_CLIENT_ID";
        auth_scope = lib.concatStringsSep " " [
          "https://outlook.office.com/IMAP.AccessAsUser.All"
          "https://outlook.office.com/SMTP.Send"
          "offline_access"
        ];
      };
    };
  };

  # ── Keybinds ─────────────────────────────────────────────────────────────
  #
  # { section; key; cmd; desc; } per binding, in binds.conf order.
  #   section  binds.conf context; "" = global (before any [section])
  #   desc     the sheet's wording; null keeps the row out of the sheet
  #            ($noinherit, which is a setting, not a key)
  #   sheetKey what the sheet shows as the key, when that is not `key` itself
  #            ($ex and $complete name the key in their value)

  sectionTitles = {
    "" = "Everywhere";
    "messages" = "Message list";
    "messages:folder=Drafts" = "Message list, in Drafts";
    "view" = "Reading a message";
    "view::passthrough" = "Reading, key passthrough on";
    "compose" = "Composing (header fields)";
    "compose::editor" = "Composing (in the editor)";
    "compose::review" = "Review before sending";
    "terminal" = "Embedded terminal";
  } // trashTitles;

  # ── Delete = move to the account's trash ────────────────────────────────
  #
  # aerc's :delete flags and expunges; it has no trash setting. On Gmail that
  # only drops the Inbox label (the message stays in All Mail, so `d` would
  # archive), and on Microsoft 365 it skips Deleted Items. So `d`/`D` move to
  # each account's trash folder instead, through per-account contexts, and
  # inside a trash folder they delete for good again: aerc layers folder
  # contexts over account ones (ForAccount(..).ForFolder(..)), so the folder
  # section wins there.
  #
  # Accounts that share a trash folder share one section. Section names
  # avoid `[` and `]` (the ini header's own brackets), so "[Gmail]/Bin" is
  # matched as ".Gmail./Bin".
  trashGroups = lib.groupBy (n: mailAccounts.${n}.trash) (lib.attrNames mailAccounts);
  accountsRegex = names: "^(${lib.concatStringsSep "|" names})$";
  folderRegex = folder: lib.replaceStrings [ "[" "]" ] [ "." "." ] folder;
  trashFoldersSection = "messages:folder=^(${lib.concatMapStringsSep "|" folderRegex (lib.attrNames trashGroups)})$";

  trashBinds = {
    messages =
      lib.concatLists (lib.mapAttrsToList (trash: names:
        let section = "messages:account=${accountsRegex names}"; in [
          { inherit section; key = "d"; cmd = '':move "${trash}"<Enter>''; desc = "Delete: move to ${trash}"; }
          { inherit section; key = "D"; cmd = '':move "${trash}"<Enter>''; desc = "Delete: move to ${trash}"; }
        ]) trashGroups)
      ++ [
        { section = trashFoldersSection; key = "d"; cmd = ":choose -o y 'Delete this message for good' delete-message<Enter>"; desc = "Delete for good (asks first)"; }
        { section = trashFoldersSection; key = "D"; cmd = ":delete<Enter>"; desc = "Delete for good, no question"; }
      ];
    view = lib.concatLists (lib.mapAttrsToList (trash: names: [
      { section = "view:account=${accountsRegex names}"; key = "D"; cmd = '':move "${trash}"<Enter>''; desc = "Delete: move to ${trash}"; }
    ]) trashGroups);
  };

  trashTitles =
    lib.concatMapAttrs (trash: names: {
      "messages:account=${accountsRegex names}" = "Message list: ${lib.concatStringsSep ", " names}";
      "view:account=${accountsRegex names}" = "Reading a message: ${lib.concatStringsSep ", " names}";
    }) trashGroups
    // { ${trashFoldersSection} = "Message list, in ${lib.concatStringsSep " / " (lib.attrNames trashGroups)}"; };

  # Bindings shared by the contexts that set $noinherit and so would
  # otherwise lose tab switching.
  tabBinds = section: [
    { inherit section; key = "<C-p>";    cmd = ":prev-tab<Enter>"; desc = "Previous tab"; }
    { inherit section; key = "<C-PgUp>"; cmd = ":prev-tab<Enter>"; desc = "Previous tab"; }
    { inherit section; key = "<C-n>";    cmd = ":next-tab<Enter>"; desc = "Next tab"; }
    { inherit section; key = "<C-PgDn>"; cmd = ":next-tab<Enter>"; desc = "Next tab"; }
  ];

  keybinds =
    let
      g = "";
      m = "messages";
      v = "view";
    in
    [
      # Global
      { section = g; key = "<C-p>";    cmd = ":prev-tab<Enter>"; desc = "Previous tab"; }
      { section = g; key = "<C-PgUp>"; cmd = ":prev-tab<Enter>"; desc = "Previous tab"; }
      { section = g; key = "<C-n>";    cmd = ":next-tab<Enter>"; desc = "Next tab"; }
      { section = g; key = "<C-PgDn>"; cmd = ":next-tab<Enter>"; desc = "Next tab"; }
      { section = g; key = "\\[t";     cmd = ":prev-tab<Enter>"; desc = "Previous tab"; sheetKey = "[t"; }
      { section = g; key = "\\]t";     cmd = ":next-tab<Enter>"; desc = "Next tab"; sheetKey = "]t"; }
      { section = g; key = "<C-t>";    cmd = ":term<Enter>"; desc = "Open a shell in a new tab"; }
      { section = g; key = "?";        cmd = ":help keys<Enter>"; desc = "aerc's live key list"; }
      { section = g; key = "<C-c>";    cmd = ":prompt 'Quit?' quit<Enter>"; desc = "Quit (asks first)"; }
      { section = g; key = "<C-q>";    cmd = ":prompt 'Quit?' quit<Enter>"; desc = "Quit (asks first)"; }
      { section = g; key = "<C-z>";    cmd = ":suspend<Enter>"; desc = "Suspend to the shell (fg to return)"; }

      # Message list
      { section = m; key = "q"; cmd = ":prompt 'Quit?' quit<Enter>"; desc = "Quit (asks first)"; }
      { section = m; key = "."; cmd = ":repeat"; desc = "Repeat the last command"; }

      { section = m; key = "j";      cmd = ":next<Enter>"; desc = "Next message"; }
      { section = m; key = "<Down>"; cmd = ":next<Enter>"; desc = "Next message"; }
      { section = m; key = "<C-d>";  cmd = ":next 50%<Enter>"; desc = "Down half a page"; }
      { section = m; key = "<C-f>";  cmd = ":next 100%<Enter>"; desc = "Down a page"; }
      { section = m; key = "<PgDn>"; cmd = ":next 100%<Enter>"; desc = "Down a page"; }

      { section = m; key = "k";      cmd = ":prev<Enter>"; desc = "Previous message"; }
      { section = m; key = "<Up>";   cmd = ":prev<Enter>"; desc = "Previous message"; }
      { section = m; key = "<C-u>";  cmd = ":prev 50%<Enter>"; desc = "Up half a page"; }
      { section = m; key = "<C-b>";  cmd = ":prev 100%<Enter>"; desc = "Up a page"; }
      { section = m; key = "<PgUp>"; cmd = ":prev 100%<Enter>"; desc = "Up a page"; }
      { section = m; key = "g";      cmd = ":select 0<Enter>"; desc = "First message"; }
      { section = m; key = "G";      cmd = ":select -1<Enter>"; desc = "Last message"; }

      { section = m; key = "J";         cmd = ":next-folder<Enter>"; desc = "Next folder"; }
      { section = m; key = "<C-Down>";  cmd = ":next-folder<Enter>"; desc = "Next folder"; }
      { section = m; key = "K";         cmd = ":prev-folder<Enter>"; desc = "Previous folder"; }
      { section = m; key = "<C-Up>";    cmd = ":prev-folder<Enter>"; desc = "Previous folder"; }
      { section = m; key = "H";         cmd = ":collapse-folder<Enter>"; desc = "Collapse folder"; }
      { section = m; key = "<C-Left>";  cmd = ":collapse-folder<Enter>"; desc = "Collapse folder"; }
      { section = m; key = "L";         cmd = ":expand-folder<Enter>"; desc = "Expand folder"; }
      { section = m; key = "<C-Right>"; cmd = ":expand-folder<Enter>"; desc = "Expand folder"; }
      { section = m; key = "tf";        cmd = ":toggle-folder<Enter>"; desc = "Collapse / expand folder"; }

      { section = m; key = "v";       cmd = ":mark -t<Enter>"; desc = "Mark / unmark message"; }
      { section = m; key = "<Space>"; cmd = ":mark -t<Enter>:next<Enter>"; desc = "Mark / unmark, then next"; }
      { section = m; key = "V";       cmd = ":mark -v<Enter>"; desc = "Visual mark mode (select a range)"; }

      { section = m; key = "T";     cmd = ":toggle-threads<Enter>"; desc = "Threaded view on / off"; }
      { section = m; key = "zc";    cmd = ":fold<Enter>"; desc = "Fold thread"; }
      { section = m; key = "zo";    cmd = ":unfold<Enter>"; desc = "Unfold thread"; }
      { section = m; key = "za";    cmd = ":fold -t<Enter>"; desc = "Toggle thread fold"; }
      { section = m; key = "zM";    cmd = ":fold -a<Enter>"; desc = "Fold all threads"; }
      { section = m; key = "zR";    cmd = ":unfold -a<Enter>"; desc = "Unfold all threads"; }
      { section = m; key = "<tab>"; cmd = ":fold -t<Enter>"; desc = "Toggle thread fold"; }

      { section = m; key = "zz"; cmd = ":align center<Enter>"; desc = "Scroll: selection to centre"; }
      { section = m; key = "zt"; cmd = ":align top<Enter>"; desc = "Scroll: selection to top"; }
      { section = m; key = "zb"; cmd = ":align bottom<Enter>"; desc = "Scroll: selection to bottom"; }

      { section = m; key = "<Enter>"; cmd = ":view<Enter>"; desc = "Open message"; }
      # aerc's own d/D delete for good. Every account overrides them with a
      # move to its trash folder, and the trash folders restore them
      # (trashBinds), so they are left off the sheet here.
      { section = m; key = "d"; cmd = ":choose -o y 'Really delete this message' delete-message<Enter>"; desc = null; }
      { section = m; key = "D"; cmd = ":delete<Enter>"; desc = null; }
      { section = m; key = "a"; cmd = ":archive flat<Enter>"; desc = "Archive"; }
      { section = m; key = "A"; cmd = ":unmark -a<Enter>:mark -T<Enter>:archive flat<Enter>"; desc = "Archive the whole thread"; }

      { section = m; key = "C"; cmd = ":compose<Enter>"; desc = "New message"; }
      { section = m; key = "m"; cmd = ":compose<Enter>"; desc = "New message"; }

      { section = m; key = "b"; cmd = ":bounce<space>"; desc = "Bounce (redirect) to ..."; }

      { section = m; key = "rr"; cmd = ":reply -a<Enter>"; desc = "Reply all"; }
      { section = m; key = "rq"; cmd = ":reply -aq<Enter>"; desc = "Reply all, quoting"; }
      { section = m; key = "Rr"; cmd = ":reply<Enter>"; desc = "Reply to sender"; }
      { section = m; key = "Rq"; cmd = ":reply -q<Enter>"; desc = "Reply to sender, quoting"; }

      { section = m; key = "c";  cmd = ":cf<space>"; desc = "Change folder: type its name"; }
      { section = m; key = "$";  cmd = ":term<space>"; desc = "Run a command in a new tab"; }
      { section = m; key = "!";  cmd = ":term<space>"; desc = "Run a command in a new tab"; }
      { section = m; key = "|";  cmd = ":pipe<space>"; desc = "Pipe message to a command"; }

      { section = m; key = "/";     cmd = ":search<space>"; desc = "Search"; }
      { section = m; key = "\\";    cmd = ":filter<space>"; desc = "Filter the list"; }
      { section = m; key = "n";     cmd = ":next-result<Enter>"; desc = "Next search result"; }
      { section = m; key = "N";     cmd = ":prev-result<Enter>"; desc = "Previous search result"; }
      { section = m; key = "<Esc>"; cmd = ":clear<Enter>"; desc = "Clear search / filter"; }

      { section = m; key = "s"; cmd = ":split<Enter>"; desc = "Preview pane below"; }
      { section = m; key = "S"; cmd = ":vsplit<Enter>"; desc = "Preview pane beside"; }

      { section = m; key = "pl"; cmd = ":patch list<Enter>"; desc = "Patches: list"; }
      { section = m; key = "pa"; cmd = ":patch apply <Tab>"; desc = "Patches: apply"; }
      { section = m; key = "pd"; cmd = ":patch drop <Tab>"; desc = "Patches: drop"; }
      { section = m; key = "pb"; cmd = ":patch rebase<Enter>"; desc = "Patches: rebase"; }
      { section = m; key = "pt"; cmd = ":patch term<Enter>"; desc = "Patches: terminal in the repo"; }
      { section = m; key = "ps"; cmd = ":patch switch <Tab>"; desc = "Patches: switch project"; }

      # Message list, in a Drafts folder
      { section = "messages:folder=Drafts"; key = "<Enter>"; cmd = ":recall<Enter>"; desc = "Reopen the draft"; }
    ]
    ++ trashBinds.messages
    ++ [
      # Message viewer
      { section = v; key = "/"; cmd = ":toggle-key-passthrough<Enter>/"; desc = "Search in the message"; }
      { section = v; key = "q"; cmd = ":close<Enter>"; desc = "Close message"; }
      { section = v; key = "O"; cmd = ":open<Enter>"; desc = "Open part in its app"; }
      { section = v; key = "o"; cmd = ":open<Enter>"; desc = "Open part in its app"; }
      { section = v; key = "S"; cmd = ":save<space>"; desc = "Save part to ..."; }
      { section = v; key = "|"; cmd = ":pipe<space>"; desc = "Pipe part to a command"; }
      { section = v; key = "D"; cmd = ":delete<Enter>"; desc = null; } # see trashBinds
      { section = v; key = "A"; cmd = ":archive flat<Enter>"; desc = "Archive"; }

      { section = v; key = "<C-y>"; cmd = ":copy-link <space>"; desc = "Copy a link"; }
      { section = v; key = "<C-l>"; cmd = ":open-link <space>"; desc = "Open a link"; }

      { section = v; key = "f";  cmd = ":forward<Enter>"; desc = "Forward"; }
      { section = v; key = "rr"; cmd = ":reply -a<Enter>"; desc = "Reply all"; }
      { section = v; key = "rq"; cmd = ":reply -aq<Enter>"; desc = "Reply all, quoting"; }
      { section = v; key = "Rr"; cmd = ":reply<Enter>"; desc = "Reply to sender"; }
      { section = v; key = "Rq"; cmd = ":reply -q<Enter>"; desc = "Reply to sender, quoting"; }

      { section = v; key = "H";         cmd = ":toggle-headers<Enter>"; desc = "Show / hide all headers"; }
      { section = v; key = "<C-k>";     cmd = ":prev-part<Enter>"; desc = "Previous part"; }
      { section = v; key = "<C-Up>";    cmd = ":prev-part<Enter>"; desc = "Previous part"; }
      { section = v; key = "<C-j>";     cmd = ":next-part<Enter>"; desc = "Next part"; }
      { section = v; key = "<C-Down>";  cmd = ":next-part<Enter>"; desc = "Next part"; }
      { section = v; key = "J";         cmd = ":next<Enter>"; desc = "Next message"; }
      { section = v; key = "<C-Right>"; cmd = ":next<Enter>"; desc = "Next message"; }
      { section = v; key = "K";         cmd = ":prev<Enter>"; desc = "Previous message"; }
      { section = v; key = "<C-Left>";  cmd = ":prev<Enter>"; desc = "Previous message"; }
    ]
    ++ trashBinds.view
    ++ [
      # Viewer, with key passthrough on (the pager gets every key)
      { section = "view::passthrough"; key = "$noinherit"; cmd = "true"; desc = null; }
      { section = "view::passthrough"; key = "$ex"; cmd = "<C-x>"; desc = "Command prompt"; sheetKey = "<C-x>"; }
      { section = "view::passthrough"; key = "<Esc>"; cmd = ":toggle-key-passthrough<Enter>"; desc = "Back to aerc's keys"; }
    ]
    # Composer, header fields selected
    ++ [
      { section = "compose"; key = "$noinherit"; cmd = "true"; desc = null; }
      { section = "compose"; key = "$ex"; cmd = "<C-x>"; desc = "Command prompt"; sheetKey = "<C-x>"; }
      { section = "compose"; key = "$complete"; cmd = "<C-o>"; desc = "Complete an address"; sheetKey = "<C-o>"; }
      { section = "compose"; key = "<C-k>";    cmd = ":prev-field<Enter>"; desc = "Previous field"; }
      { section = "compose"; key = "<C-Up>";   cmd = ":prev-field<Enter>"; desc = "Previous field"; }
      { section = "compose"; key = "<C-j>";    cmd = ":next-field<Enter>"; desc = "Next field"; }
      { section = "compose"; key = "<C-Down>"; cmd = ":next-field<Enter>"; desc = "Next field"; }
      { section = "compose"; key = "<A-p>";    cmd = ":switch-account -p<Enter>"; desc = "Send from the previous account"; }
      { section = "compose"; key = "<A-n>";    cmd = ":switch-account -n<Enter>"; desc = "Send from the next account"; }
      { section = "compose"; key = "<tab>";    cmd = ":next-field<Enter>"; desc = "Next field"; }
      { section = "compose"; key = "<backtab>"; cmd = ":prev-field<Enter>"; desc = "Previous field"; }
    ]
    ++ tabBinds "compose"
    # Composer, the editor (Neovim) selected
    ++ [
      { section = "compose::editor"; key = "$noinherit"; cmd = "true"; desc = null; }
      { section = "compose::editor"; key = "$ex"; cmd = "<C-x>"; desc = "Command prompt"; sheetKey = "<C-x>"; }
      { section = "compose::editor"; key = "<C-k>";    cmd = ":prev-field<Enter>"; desc = "To the header fields"; }
      { section = "compose::editor"; key = "<C-Up>";   cmd = ":prev-field<Enter>"; desc = "To the header fields"; }
      { section = "compose::editor"; key = "<C-j>";    cmd = ":next-field<Enter>"; desc = "Next field"; }
      { section = "compose::editor"; key = "<C-Down>"; cmd = ":next-field<Enter>"; desc = "Next field"; }
    ]
    ++ tabBinds "compose::editor"
    # Review before sending. The ` # ...` comment is the label aerc shows on
    # the review screen (aerc-binds(5)), so desc is reused for it.
    ++ map (b: b // { section = "compose::review"; inlineLabel = true; }) [
      { key = "y"; cmd = ":send<Enter>"; desc = "Send"; }
      { key = "n"; cmd = ":abort<Enter>"; desc = "Abort (discard message, no confirmation)"; }
      { key = "s"; cmd = ":sign<Enter>"; desc = "Toggle signing"; }
      { key = "x"; cmd = ":encrypt<Enter>"; desc = "Toggle encryption to all recipients"; }
      { key = "v"; cmd = ":preview<Enter>"; desc = "Preview message"; }
      { key = "p"; cmd = ":postpone<Enter>"; desc = "Postpone"; }
      { key = "q"; cmd = ":choose -o d discard abort -o p postpone postpone<Enter>"; desc = "Abort or postpone"; }
      { key = "e"; cmd = ":edit<Enter>"; desc = "Edit (body and headers)"; }
      { key = "a"; cmd = ":attach<space>"; desc = "Add attachment"; }
      { key = "d"; cmd = ":detach<space>"; desc = "Remove attachment"; }
    ]
    # Embedded terminal (:term, and the composer's editor runs in one)
    ++ [
      { section = "terminal"; key = "$noinherit"; cmd = "true"; desc = null; }
      { section = "terminal"; key = "$ex"; cmd = "<C-x>"; desc = "Command prompt"; sheetKey = "<C-x>"; }
    ]
    ++ tabBinds "terminal";

  sections = lib.unique (map (k: k.section) keybinds);
  inSection = section: lib.filter (k: k.section == section) keybinds;

  # ── binds.conf ───────────────────────────────────────────────────────────

  # aerc's ini parser would read a bare `#` key as a comment; quoting is how
  # aerc-binds(5) says to bind it. None of ours needs it today.
  renderBinding = k:
    let
      key = if lib.hasPrefix "#" k.key then "\"${k.key}\"" else k.key;
      label = lib.optionalString (k.inlineLabel or false) " # ${k.desc}";
    in
    "${key} = ${k.cmd}${label}";

  renderSection = section:
    lib.optionalString (section != "") "[${section}]\n"
    + lib.concatMapStringsSep "\n" renderBinding (inSection section);

  # The global section has to come first, before any [header].
  bindsConf = lib.concatMapStringsSep "\n\n" renderSection
    ([ "" ] ++ lib.filter (s: s != "") sections) + "\n";

  # ── KEYBINDS.md ──────────────────────────────────────────────────────────

  # One row per action: keys that do the same thing share a row
  # ("`j` `<Down>`  Next message").
  renderGroup = section:
    let
      rows = lib.filter (k: k.desc != null) (inSection section);
      descs = lib.unique (map (k: k.desc) rows);
      # `|` is escaped so it does not end the table cell.
      cell = lib.replaceStrings [ "|" ] [ "\\|" ];
      keysFor = d: lib.concatMapStringsSep " " (k: "`${cell (k.sheetKey or k.key)}`")
        (lib.filter (k: k.desc == d) rows);
    in
    lib.optionalString (rows != [ ]) (
      "## ${sectionTitles.${section}}\n\n"
      + "| Keys | Action |\n|------|--------|\n"
      + lib.concatMapStringsSep "\n" (d: "| ${keysFor d} | ${d} |") descs
    );

  keybindsMarkdown = ''
    # aerc keybinds

    `q` closes this sheet; SUPER + E reopens it. `?` in aerc lists the
    live bindings. `<C-x>` is Ctrl+x, `<A-n>` is Alt+n. Type `:` for any
    command (Tab completes). Two-key sequences such as `rr` are typed in
    turn. `\|` is the | key, escaped for the table.

  '' + lib.concatStringsSep "\n\n"
    (lib.filter (s: s != "") (map renderGroup ([ "" ] ++ lib.filter (s: s != "") sections)))
  + "\n";
in
{
  # Every section a keybind uses needs a sheet title.
  assertions = [{
    assertion = lib.all (s: sectionTitles ? ${s}) sections;
    message = "home/modules/aerc.nix: a keybinds section has no entry in sectionTitles.";
  }];

  home.packages = [ pkgs.oama ];

  accounts.email.accounts = lib.mapAttrs mkAccount mailAccounts;

  programs.aerc = {
    enable = true;

    extraConfig = {
      general = {
        # accounts.conf is a store symlink, so it cannot be 0600. It holds no
        # credentials: each account's are `oama access` or `cat` commands.
        unsafe-accounts-conf = true;
      };

      ui = {
        # Newest first, threads grouped.
        sort = "-r date";
        threading-enabled = true;
      };

      viewer = {
        # Prefer the plain-text part when a message has one.
        alternatives = "text/plain,text/html";
      };

      compose = {
        # $EDITOR is Zed (stages/dev.nix); mail is written in Neovim, in the
        # terminal aerc embeds.
        editor = "nvim";
      };

      # aerc has no built-in filters: without this section a message body is
      # an "open in an external program" menu. Copied from aerc 0.22's
      # default aerc.conf. `html` is aerc's w3m filter, run under dante with
      # all network access refused - no JavaScript and no remote content,
      # the same "no browser engine" line Claws is built to (email.nix).
      filters = {
        "text/plain" = "colorize";
        "text/calendar" = "calendar";
        "message/delivery-status" = "colorize";
        "message/rfc822" = "colorize";
        "text/html" = "! html";
        ".headers" = "colorize";
      };
    };

    extraBinds = bindsConf;
  };

  xdg.configFile = {
    # Opened beside aerc by SUPER + E (config/hypr/60-keybinds.lua).
    "aerc/KEYBINDS.md".text = keybindsMarkdown;

    "oama/config.yaml".source = (pkgs.formats.yaml { }).generate "oama-config.yaml" oamaConfig;
  };
}
