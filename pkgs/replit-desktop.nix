{ lib, stdenvNoCC, fetchurl, binutils, zstd, makeWrapper, electron }:

# Replit desktop app (devtower and devtower-intel only; the laptops use the
# browser). Not in nixpkgs, and github.com/replit/desktop is archived at
# v1.0.14, so this repackages the official .deb.
#
# Only resources/app.asar is kept: it has no native .node modules, so it runs
# on nixpkgs' current Electron instead of patching Replit's prebuilt Chromium.
# 1.1.32 bundles Electron 46.0.0-alpha.1 (usr/lib/replit/version), ahead of
# nixpkgs; it was checked to start and load replit.com on nixpkgs' Electron.
# If a release breaks on it, pin electron_<N> to the bundled major instead.
#
# It reports "not packaged" (it runs under the electron binary), so Replit's
# auto-updater stays off; Replit's minimum-version gate still applies, so a
# release can stop the app until this is bumped.
#
# Source: the stable channel's electron-updater manifest, where <stable> is
# https://desktop-updates.replit.com/desktop-app/updates/stable:
#   <stable>/linux/x64/latest-linux.yml
# which names a versioned artefact (path) and its sha512. The replit.com/desktop
# button (<stable>/downloads/linux/x64/replit_amd64.deb) is the same file
# under a moving name; desktop.replit.com/download/deb is stale (1.1.18).
# `just replit-check` reads the manifest and prints the new version, buildId
# and hash to put here.
stdenvNoCC.mkDerivation rec {
  pname = "replit-desktop";
  version = "1.1.32";
  # The artefact directory under artifacts/<version>/ in latest-linux.yml.
  buildId = "1795581582997198";

  src = fetchurl {
    url = "https://desktop-updates.replit.com/desktop-app/updates/stable/linux/x64/artifacts/${version}/${buildId}/replit_${version}_amd64.deb";
    # sha512 from latest-linux.yml, converted to SRI.
    hash = "sha512-s9/XfUCI7tTp9r7P9oQzfT8wHxb3a9cTJF/GHiepqBaOiEMQ/sWuzO609CRoGJuyWrGlWLt9IxwvZfNMTNlJbA==";
  };

  nativeBuildInputs = [ binutils zstd makeWrapper ];

  unpackPhase = ''
    runHook preUnpack
    ar x "$src"
    tar --zstd -xf data.tar.zst
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 usr/lib/replit/resources/app.asar \
      "$out/share/replit/resources/app.asar"

    # %U carries replit:// login callbacks; the .deb's entry already declares
    # x-scheme-handler/replit, and the home config makes it the default.
    install -Dm644 usr/share/applications/replit.desktop \
      "$out/share/applications/replit.desktop"
    install -Dm644 usr/share/pixmaps/replit.png \
      "$out/share/icons/hicolor/256x256/apps/replit.png"

    makeWrapper ${lib.getExe electron} "$out/bin/replit" \
      --add-flags "$out/share/replit/resources/app.asar" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    grep -qx 'Exec=replit %U' "$out/share/applications/replit.desktop"
    grep -q 'x-scheme-handler/replit' "$out/share/applications/replit.desktop"
  '';

  meta = {
    description = "Replit desktop app (official .deb on nixpkgs Electron)";
    homepage = "https://replit.com/desktop";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "replit";
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
