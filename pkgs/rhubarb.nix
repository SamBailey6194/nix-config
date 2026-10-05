{ lib, stdenv, fetchurl, unzip, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "rhubarb-lip-sync";
  version = "1.14.0";

  src = fetchurl {
    url = "https://github.com/DanielSWolf/rhubarb-lip-sync/releases/download/v${version}/Rhubarb-Lip-Sync-${version}-Linux.zip";
    hash = "sha256-qakHSGLP9HstWbi/OZpnijsLdPlFKtatlMspKRPdhmc=";
  };

  nativeBuildInputs = [ unzip autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    # Rhubarb resolves res/ beside its executable (including through symlinks).
    cp -r rhubarb res "$out/bin/"
    chmod +x "$out/bin/rhubarb"
    mkdir -p "$out/share/doc/rhubarb"
    cp LICENSE.md README.adoc "$out/share/doc/rhubarb/"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/rhubarb" --version | grep -F '${version}'
  '';

  meta = {
    description = "Generate mouth animation from recorded speech";
    homepage = "https://github.com/DanielSWolf/rhubarb-lip-sync";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "rhubarb";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
