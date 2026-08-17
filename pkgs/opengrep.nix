# opengrep — open-source static analysis (SAST) engine, community fork of Semgrep.
#
# opengrep is NOT packaged in nixpkgs (verified against nixos-unstable: no
# pkgs/by-name/op/opengrep, zero `pname = "opengrep"` hits). Upstream's own
# flake.nix is a developer dev-shell, not a user-package builder, so we wrap the
# prebuilt release binary instead.
#
# The `opengrep_manylinux_x86` asset is a PyInstaller onefile bundle: a
# dynamically linked ELF that at the outer level needs only libc. autoPatchelfHook
# repoints its interpreter + rpath at the Nix glibc. Verified end-to-end on this
# NixOS host — `opengrep scan` runs the bundled opengrep-core subprocess and
# reports findings correctly after patching.
#
# To bump: change `version` and `hash`. Get the new hash with:
#   nix store prefetch-file \
#     https://github.com/opengrep/opengrep/releases/download/v<VERSION>/opengrep_manylinux_x86
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opengrep";
  version = "1.27.1";

  src = fetchurl {
    url = "https://github.com/opengrep/opengrep/releases/download/v${finalAttrs.version}/opengrep_manylinux_x86";
    hash = "sha256-WAU9p2Zyu+tbClRBAhxYM4cHBS4Q+B13cUDKh5vUkc4=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/opengrep"
    runHook postInstall
  '';

  # No in-build runtime check: this is a PyInstaller onefile that self-extracts
  # and execs at runtime, which the nix build sandbox blocks. Runtime behaviour
  # (`opengrep scan` incl. the bundled opengrep-core subprocess) was verified
  # manually on NixOS after autoPatchelfHook patched the interpreter/rpath.

  meta = {
    description = "Open-source static analysis (SAST) engine, community fork of Semgrep";
    homepage = "https://github.com/opengrep/opengrep";
    changelog = "https://github.com/opengrep/opengrep/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.lgpl21Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "opengrep";
  };
})
