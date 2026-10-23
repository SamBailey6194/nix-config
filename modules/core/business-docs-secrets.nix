{ config, lib, ... }:

let
  hostname = config.networking.hostName;

  # Infomaniak mailboxes and the jobs the syntek-business-docs mail scripts
  # run on each. sort is the one-off history move (it deletes mail): once a
  # mailbox's move is done, delete its .age file, its secrets.nix line and its
  # device in Infomaniak.
  mailboxes = [ "sam-bailey" "info" "support" "contact" "dev" "git" "finance" ];
  jobs = [ "read" "drafts" "sort" ];

  names =
    lib.concatMap (mailbox: map (job: "mail-${mailbox}-${job}") jobs) mailboxes
    # Infomaniak calendar over CalDAV (https://sync.infomaniak.com): an
    # application password for the Infomaniak user, from Manager > My account
    # > Security > Application passwords. It is the account's sync login, so
    # it reaches the contacts (CardDAV) as well as the calendars.
    ++ [ "calendar-caldav" ];

  file = name: ../../secrets + "/${name}-${hostname}.age";
in
{
  # Credentials for the syntek-business-docs scripts, one per mailbox, job and
  # device, plus the calendar, at /run/agenix/<name>. Root-only, unlike most
  # secrets: the jobs are systemd services that receive theirs with
  # LoadCredential=<name>:/run/agenix/<name>, so no process running as the
  # user, an LLM session included, can read them. Not proof against the docker
  # and libvirtd groups, which are root-equivalent (gap accepted for now).
  # Never the passwords aerc uses (mail-aerc-secrets.nix). Plain password on
  # one line; create with `just edit-secret <name>-<host>`. Each is declared
  # only once its .age file exists.
  age.secrets = lib.genAttrs
    (lib.filter (name: builtins.pathExists (file name)) names)
    (name: {
      file = file name;
      owner = "root";
      group = "root";
      mode = "0400";
    });
}
