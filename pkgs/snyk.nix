# snyk — the official Snyk CLI release binary, pinned, in place of nixpkgs' `snyk`.
#
# nixpkgs does carry `snyk` (1.1308.1 at the pinned nixpkgs), but it is
# buildNpmPackage over github:snyk/cli, which builds only the legacy TypeScript
# CLI. The published `snyk-linux` is the Go "extensible CLI" (cliv2) with that
# TypeScript CLI embedded, and several commands live only in the Go layer.
# Checked against nixpkgs' 1.1308.1 on 05/11/2026:
#   - `snyk whoami --experimental` and `snyk sbom` → "Unknown command"
#   - `snyk mcp` (Snyk's MCP server for coding agents) only prints general help
# The release binary has all of them. This shadows the nixpkgs attribute in
# modules/software/development.nix, so there is one `snyk` on PATH.
#
# The release asset is a statically linked Go binary. On first run it unpacks
# the embedded TypeScript CLI (also static-pie) into
# $XDG_CACHE_HOME/snyk/snyk-cli/<version>/. Neither needs patchelf or nix-ld;
# both were run on devtower-intel. Don't strip it: the payload is embedded in
# the file.
#
# Auth: `snyk auth` (browser OAuth, tokens in
# $XDG_CONFIG_HOME/configstore/snyk.json), or set SNYK_TOKEN for CI/headless.
# Anonymous usage analytics are on by default; set SNYK_DISABLE_ANALYTICS=1 to
# turn them off.
#
# To bump: change `version` and `hash`. Snyk publishes a .sha256 alongside each
# binary; convert it with:
#   nix hash convert --hash-algo sha256 --to sri \
#     $(curl -sL https://static.snyk.io/cli/v<VERSION>/snyk-linux.sha256 | cut -d' ' -f1)
# Latest version: curl -s https://static.snyk.io/cli/latest/version
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "snyk";
  version = "1.1308.4";

  src = fetchurl {
    url = "https://static.snyk.io/cli/v${finalAttrs.version}/snyk-linux";
    hash = "sha256-l5Fy7hKJA/UOQ//yIfIqBolXnyLAhtq6oNGlQWSFubo=";
  };

  dontUnpack = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/snyk"
    runHook postInstall
  '';

  # `--version` is offline and credential-free; HOME points into the build dir
  # so nothing touches /homeless-shelter.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR" XDG_CACHE_HOME="$TMPDIR/cache" XDG_CONFIG_HOME="$TMPDIR/config"
    [ "$("$out/bin/snyk" --version)" = "${finalAttrs.version}" ]
    runHook postInstallCheck
  '';

  meta = {
    description = "Snyk CLI: scan code, dependencies, containers and IaC for vulnerabilities";
    homepage = "https://snyk.io";
    changelog = "https://github.com/snyk/cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "snyk";
  };
})
