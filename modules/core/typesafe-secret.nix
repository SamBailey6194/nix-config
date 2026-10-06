{ config, lib, ... }:

let
  file = ../../secrets + "/typesafe-api-key-${config.networking.hostName}.age";
  owner = if config.users.users ? sam-desktop then "sam-desktop"
    else if config.users.users ? sam-laptop then "sam-laptop"
    else "sam-framework";
in
{
  # Provision with scripts/set-typesafe-api-key.py before rebuilding. Optional
  # while absent, since existing bundles may already contain TYPESAFE_API_KEY.
  age.secrets = lib.optionalAttrs (builtins.pathExists file) {
    typesafe-api-key = {
      inherit file owner;
      mode = "0400";
    };
  };
}
