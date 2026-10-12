{ config, lib, ... }:

let
  file = ../../secrets + "/oama-clients-${config.networking.hostName}.age";
  owner = if config.users.users ? sam-desktop then "sam-desktop"
    else if config.users.users ? sam-laptop then "sam-laptop"
    else "sam-framework";
in
{
  # OAuth client registrations oama signs in as, for aerc (home/modules/aerc.nix):
  #
  #   GOOGLE_CLIENT_ID=...       Google Cloud "Desktop app" client; serves both
  #   GOOGLE_CLIENT_SECRET=...   the Gmail and the Workspace account
  #   MICROSOFT_CLIENT_ID=...    Entra app registration (device code flow)
  #
  # Create with `just edit-secret oama-clients-<host>`; docs/EMAIL.md.
  # Optional while absent so a host builds before the file exists.
  age.secrets = lib.optionalAttrs (builtins.pathExists file) {
    oama-clients = {
      inherit file owner;
      mode = "0400";
    };
  };
}
