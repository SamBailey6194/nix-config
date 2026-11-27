{ lib, stdenvNoCC, fetchurl, binutils, zstd, makeWrapper, electron }:

# Replit desktop app (devtower and devtower-intel only; the laptops use the
# browser). Not in nixpkgs, and github.com/replit/desktop is archived at
# v1.0.14, so this repackages the official .deb.
#
# Only resources/app.asar is kept: it has no native .node modules, so it runs
# on nixpkgs' current Electron instead of patching Replit's prebuilt Chromium.
# The .deb bundles Electron 41 (usr/lib/replit/version), which nixpkgs marks
# insecure (end of life); 1.1.18 was checked to start and load replit.com on
# Electron 45. If a release breaks on the newer Electron, pin electron_<N> to
# the bundled major instead.
#
# It reports "not packaged" (it runs under the electron binary), so Replit's
# auto-updater stays off; that is the official Linux behaviour anyway.
#
# Replit only publishes a "latest" link, with no versioned URL. When a new
# release lands the hash below stops matching on machines that have not
# already fetched it; update with:
#   nix store prefetch-file https://desktop.replit.com/download/deb
# then bump version and hash together.
stdenvNoCC.mkDerivation rec {
  pname = "replit-desktop";
  version = "1.1.18";

  src = fetchurl {
    url = "https://desktop.replit.com/download/deb";
    name = "replit_${version}_amd64.deb";
    hash = "sha256-M5sJSDChLL3F0tNCCMOAkOAqsw9jqNJR3LmSnVgxXAY=";
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
