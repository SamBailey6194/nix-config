# DDEV's local HTTPS CA, trusted per machine.
#
# DDEV signs every project's certificate (*.ddev.site, additional hostnames)
# with one mkcert CA per machine, the one in `mkcert -CAROOT`. Trusting that CA
# once covers every DDEV project on the machine; nothing is per project. Plain
# Docker projects served over http://localhost need none of this.
#
# Each machine has its own CA, so each host trusts only its own certificate:
# certs/mkcert/<hostName>.pem, written by `just ddev-ca`. Only the public
# rootCA.pem is committed. rootCA-key.pem never leaves `mkcert -CAROOT`.
#
# The certificate is used by:
#   - the system bundle (curl, Python, Go, git): below
#   - Gecko browsers, including fresh MCP profiles: browser-policies
#     (Certificates.Install)
#   - Brave, Chromium and Playwright's Chromium: ~/.pki/nssdb, written by
#     home/modules/ddev-ca.nix
{ config, lib, ... }:
let
  cfg = config.software.ddevCA;
  # Git-tracked files only: flake evaluation does not see an untracked PEM.
  hostCert = ../../certs/mkcert + "/${config.networking.hostName}.pem";
in
{
  options.software.ddevCA.certificate = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = if builtins.pathExists hostCert then hostCert else null;
    defaultText = lib.literalExpression ''certs/mkcert/''${networking.hostName}.pem, if present'';
    description = ''
      This machine's mkcert root CA (public certificate only), trusted for
      DDEV's local HTTPS. Null until `just ddev-ca` has written it.
    '';
  };

  config = lib.mkIf (cfg.certificate != null) {
    security.pki.certificateFiles = [ cfg.certificate ];
  };
}
