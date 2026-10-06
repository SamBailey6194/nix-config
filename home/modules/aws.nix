{ config, lib, osConfig ? { }, ... }:

# AWS CLI configuration (~/.aws/config)
#
# The AWS config holds the SSO topology — start URL, session, account IDs, role
# names — so it lives in agenix rather than in the repo. The system module
# (modules/core/secrets-laptop.nix, or hosts/devtower-intel/secrets.nix)
# decrypts it to /run/agenix/aws-config owned
# by this user; this module links it into the default location every AWS CLI and
# SDK looks for.
#
# Why a Home Manager symlink instead of agenix's own `path` option:
# agenix creates a secret's parent directory as root, which would leave ~/.aws
# unwritable — and `aws sso login` needs to write its token cache to
# ~/.aws/sso/cache. Home Manager runs as the user, so ~/.aws stays writable and
# only the config file itself is read-only.
#
# Edit the config:
#   just edit-secret aws-config-laptop-intel   # agenix -e secrets/aws-config-<host>.age
#   just rebuild
#
# Use it:
#   aws sso login --sso-session <session>
#   aws sts get-caller-identity --profile <profile>
#
# `aws configure sso` cannot write to the managed file — add profiles by editing
# the secret instead.

let
  # agenix decrypts secrets/aws-config-<host>.age to this path at activation.
  awsConfigSecret = "/run/agenix/aws-config";

  awsDir = "${config.home.homeDirectory}/.aws";
in
{
  # ~/.aws/config -> /run/agenix/aws-config (out-of-store: the target only
  # exists at runtime, so it must not be copied into the Nix store).
  home.file.".aws/config".source =
    config.lib.file.mkOutOfStoreSymlink awsConfigSecret;

  # ~/.aws/credentials -> /run/agenix/aws-credentials, only on hosts that
  # declare that secret (static IAM keys; hosts/devtower-intel/secrets.nix).
  # `aws configure` cannot write to it either — edit the secret instead.
  home.file.".aws/credentials" = lib.mkIf (osConfig.age.secrets or { } ? aws-credentials) {
    source = config.lib.file.mkOutOfStoreSymlink "/run/agenix/aws-credentials";
  };

  # ~/.aws also holds the SSO token cache written at login (~/.aws/sso/cache)
  # and the CLI cache (~/.aws/cli/cache), both of which contain short-lived
  # credentials — keep the directory private to the user. Idempotent, and safe
  # whether it runs before or after Home Manager links the config file.
  home.activation.awsConfigDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${awsDir}"
    chmod 0700 "${awsDir}"
  '';
}
