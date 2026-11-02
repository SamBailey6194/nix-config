# Trust this machine's DDEV mkcert CA (modules/software/ddev-ca.nix) in the
# user's NSS store, ~/.pki/nssdb. Chromium-based browsers on Linux read that
# store rather than the system bundle, whatever profile they start with: Brave,
# and the Chromium that the Playwright MCP launches with a fresh profile.
#
# The entry is replaced only when it differs from the host's certificate, and
# removed once the host has none. `mkcert -install` adds its own entry
# ("mkcert development CA ..."), which this leaves alone. A failure here only
# warns: it must not stop the rest of the activation.
{ lib, pkgs, osConfig ? { }, ... }:
let
  cert = osConfig.software.ddevCA.certificate or null;
  certutil = "${pkgs.nssTools}/bin/certutil";
  nick = lib.escapeShellArg "DDEV mkcert CA (nix-config)";
  # DER form, to compare byte for byte with `certutil -L -r`.
  certDer = pkgs.runCommand "ddev-ca.der" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    openssl x509 -in ${cert} -outform DER -out "$out"
  '';
in
{
  home.activation.ddevCA = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ddevDb="$HOME/.pki/nssdb"
    ddevHas() { ${certutil} -d "sql:$ddevDb" -L -n ${nick} >/dev/null 2>&1; }
    ${if cert == null then ''
      if [ -f "$ddevDb/cert9.db" ] && ddevHas; then
        run ${certutil} -d "sql:$ddevDb" -D -n ${nick} \
          || warnEcho "ddevCA: could not remove the CA from $ddevDb"
      fi
    '' else ''
      if [ ! -f "$ddevDb/cert9.db" ]; then
        run mkdir -p "$ddevDb"
        run ${certutil} -d "sql:$ddevDb" -N --empty-password \
          || warnEcho "ddevCA: could not create $ddevDb"
      fi
      if ! ${certutil} -d "sql:$ddevDb" -L -n ${nick} -r 2>/dev/null | cmp -s - ${certDer}; then
        # One delete per entry; DRY_RUN deletes nothing, so stop after one.
        while ddevHas; do
          run ${certutil} -d "sql:$ddevDb" -D -n ${nick} || break
          if [ -n "''${DRY_RUN:-}" ]; then break; fi
        done
        run ${certutil} -d "sql:$ddevDb" -A -t "C,," -n ${nick} -i ${cert} \
          || warnEcho "ddevCA: could not add the CA to $ddevDb"
      fi
    ''}
  '';
}
