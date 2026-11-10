{ config, lib, ... }:

# Server SSH Login Keys (per-device, WITH passphrases)
#
# For each server <name> in security.serverSshKeys.servers, this host gets:
#   secrets/server-<name>-<host>-key.age        -> ~/.ssh/server-<name>-<host>-key
#   secrets/server-<name>-<host>-passphrase.age -> /run/agenix/server-<name>-passphrase
# plus a `Host <name>` alias in /etc/ssh/ssh_config that uses the key.
# The private key is itself passphrase-protected: the passphrase file is the
# escrow copy to type or paste at ssh's prompt (AddKeysToAgent caches it).
#
# Until BOTH files exist and are git-tracked (flakes only see tracked files),
# the server is left out (no secrets, no alias), so a host builds before they
# are created and picks them up on the next rebuild with no Nix edit. Owner
# steps and recovery: docs/SECRETS.md#server-login-keys-devtower-intel.

let
  inherit (lib) mkOption types;

  cfg = config.security.serverSshKeys;
  hostname = config.networking.hostName;
  home = config.users.users.${cfg.user}.home;

  base = name: "server-${name}-${hostname}";
  keyFile = name: ../../secrets + "/${base name}-key.age";
  passphraseFile = name: ../../secrets + "/${base name}-passphrase.age";

  hasKey = name: builtins.pathExists (keyFile name);
  hasPassphrase = name: builtins.pathExists (passphraseFile name);

  ready = lib.filterAttrs (name: _: hasKey name && hasPassphrase name) cfg.servers;
  # One file created or tracked without the other: say so rather than skip silently.
  partial = lib.filter (name: hasKey name != hasPassphrase name) (lib.attrNames cfg.servers);
in
{
  options.security.serverSshKeys = {
    user = mkOption {
      type = types.str;
      description = "Login user who owns the decrypted keys and runs ssh";
    };

    servers = mkOption {
      default = { };
      description = "Servers this host logs in to with its own per-device key";
      type = types.attrsOf (types.submodule {
        options = {
          hostName = mkOption {
            type = types.str;
            example = "10.66.0.1";
            description = "Address ssh connects to for the alias";
          };
          user = mkOption {
            type = types.str;
            default = "root";
            description = "Remote login user";
          };
          aliases = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra Host patterns, e.g. the address itself so `ssh root@<address>` uses the key too";
          };
          hostKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Server's SSH host public key, pinned so the first login is not trust-on-first-use";
          };
        };
      });
    };
  };

  config = lib.mkIf (cfg.servers != { }) {
    warnings = map (name: ''
      security.serverSshKeys.servers.${name}: only one of ${base name}-key.age and
      ${base name}-passphrase.age exists or is git-tracked, so the key and its
      `${name}` SSH alias are NOT configured. Create the other, `git add` both,
      then rebuild (docs/SECRETS.md#server-login-keys-devtower-intel).
    '') partial;

    age.secrets = lib.concatMapAttrs (name: _: {
      "server-${name}-key" = {
        file = keyFile name;
        path = "${home}/.ssh/${base name}-key";
        owner = cfg.user;
        group = "users";
        mode = "0600";
      };

      "server-${name}-passphrase" = {
        file = passphraseFile name;
        owner = cfg.user;
        mode = "0400";
      };
    }) ready;

    # Same place as the GitHub aliases (modules/core/ssh-config.nix): the
    # NixOS-generated ssh_config does not Include /etc/ssh/ssh_config.d/*.
    programs.ssh.extraConfig = lib.mkIf (ready != { }) (lib.mkAfter
      (lib.concatStrings (lib.mapAttrsToList (name: server: ''
        # ${name}: per-device key (modules/core/server-ssh-keys.nix)
        Host ${lib.concatStringsSep " " ([ name ] ++ server.aliases)}
          HostName ${server.hostName}
          User ${server.user}
          IdentityFile ~/.ssh/${base name}-key
          IdentitiesOnly yes
          AddKeysToAgent yes
      '') ready)));

    programs.ssh.knownHosts = lib.mapAttrs' (name: server:
      lib.nameValuePair name {
        hostNames = lib.unique ([ name server.hostName ] ++ server.aliases);
        publicKey = server.hostKey;
      }) (lib.filterAttrs (_: server: server.hostKey != null) ready);
  };
}
