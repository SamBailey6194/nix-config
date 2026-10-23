{ config, lib, ... }:

let
  hostname = config.networking.hostName;
  owner = if config.users.users ? sam-desktop then "sam-desktop"
    else if config.users.users ? sam-laptop then "sam-laptop"
    else "sam-framework";

  # Infomaniak mailboxes aerc signs in to (home/modules/aerc.nix).
  mailboxes = [ "sam-bailey" "info" "support" "contact" "dev" "git" "finance" ];

  name = mailbox: "mail-${mailbox}-aerc";
  file = mailbox: ../../secrets + "/${name mailbox}-${hostname}.age";
in
{
  # Infomaniak device passwords for aerc, one per mailbox and per device, at
  # /run/agenix/mail-<mailbox>-aerc. Readable by the user, because aerc runs
  # as the user: so is every LLM session running as that user, the same
  # exposure as the oama tokens. Never the passwords the syntek-business-docs
  # mail jobs use (root-only, hosts/devtower-intel/secrets.nix), so revoking or
  # leaking one does not touch the other. Plain password on one line; create
  # with `just edit-secret mail-<mailbox>-aerc-<host>`. Each is declared only
  # once its .age file exists.
  age.secrets = lib.listToAttrs (map
    (mailbox: lib.nameValuePair (name mailbox) {
      file = file mailbox;
      inherit owner;
      mode = "0400";
    })
    (lib.filter (mailbox: builtins.pathExists (file mailbox)) mailboxes));
}
