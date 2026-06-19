# squid-digest — Squid access-log accountability digest + tamper watcher.
#
# Built straight from the `accountability_script` flake input (a private repo
# consumed as a plain source tree). The crate lives in the `squid-digest/`
# subdir and carries its OWN Cargo.lock, so it is packaged here standalone
# rather than through rust/nix/default.nix (which hardcodes the rust/ workspace
# src + lockfile).
#
# Usage (from flake.nix):
#   pkgs.callPackage ./modules/security/squid-digest/package.nix {
#     accountability_script = inputs.accountability_script;
#   };
{
  lib,
  rustPlatform,
  makeWrapper,
  # Runtime tools the binary shells out to (verified in src/main.rs):
  #   gzip (rotated logs), id/systemctl/date (coreutils/systemd), ss (iproute2),
  #   gsettings (glib + schemas), curl (heartbeat ping).
  gzip,
  coreutils,
  systemd,
  iproute2,
  glib,
  curl,
  gsettings-desktop-schemas,
  # The flake input (a store path to the repo source tree).
  accountability_script,
}:

rustPlatform.buildRustPackage {
  pname = "squid-digest";
  version = "0.1.0";

  src = accountability_script + "/squid-digest";
  cargoLock.lockFile = accountability_script + "/squid-digest/Cargo.lock";

  # lettre uses rustls (pure Rust) -> NO openssl / pkg-config needed. The only
  # native build is `ring`, which needs a C compiler (provided by stdenv cc).
  nativeBuildInputs = [ makeWrapper ];

  # The tool has no meaningful unit tests and the checks would need live logs /
  # network, so skip them in the sandbox.
  doCheck = false;

  # Put the shelled-out tools on PATH regardless of the unit's PATH, and make
  # the GNOME proxy gsettings schema resolvable for the per-user watch-proxy.
  postInstall = ''
    wrapProgram $out/bin/squid-digest \
      --prefix PATH : ${lib.makeBinPath [ gzip coreutils systemd iproute2 glib curl ]} \
      --prefix XDG_DATA_DIRS : ${glib}/share:${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}
  '';

  meta = {
    description = "Squid access-log accountability digest + tamper watcher";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "squid-digest";
  };
}
