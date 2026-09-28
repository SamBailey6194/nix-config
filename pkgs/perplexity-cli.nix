# perplexity-cli — `pplx`, Perplexity's Search API in the terminal: grounded web
# search and query-relevant page snippets, printed as JSON for agents to consume.
#
# Not packaged in nixpkgs (verified against the pinned nixpkgs: no `perplexity-cli`
# or `pplx` attribute). github:perplexityai/perplexity-cli carries only the
# installer, a README and the release binaries — the Rust source lives in
# Perplexity's private monorepo and the repository grants no licence — so the
# prebuilt release binary is wrapped, same approach as pkgs/opengrep.nix, and
# marked unfree (allowUnfree is on in modules/core/nix-settings.nix).
#
# The release asset is a stripped Rust binary linked only against glibc (librt,
# libpthread, libm, libdl, libc); TLS is rustls with the platform verifier, which
# reads /etc/ssl/certs/ca-certificates.crt. autoPatchelfHook only has to repoint
# the interpreter at the Nix glibc.
#
# Auth: `pplx auth login` (interactive) writes `api_key` to
# $XDG_CONFIG_HOME/perplexity/credentials.json (0600), or set PERPLEXITY_API_KEY,
# which takes precedence. `pplx update` only runs when asked and cannot write
# into the store — bump it here instead. This is the Search API client; the
# perplexity-computer MCP server (home/modules/mcp-servers.nix) is separate and
# signs in with OAuth, not this key.
#
# `pplx --version` prints a build stamp (2026.07.30.1785394496+1b7382b for
# v0.2.3), not the tag; the release's manifest.json maps one to the other.
#
# To bump: change `version` and `hash`. Get the new hash with:
#   nix store prefetch-file \
#     https://github.com/perplexityai/perplexity-cli/releases/download/v<VERSION>/pplx-x86_64-linux-gnu.bin
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "perplexity-cli";
  version = "0.2.3";

  src = fetchurl {
    url = "https://github.com/perplexityai/perplexity-cli/releases/download/v${finalAttrs.version}/pplx-x86_64-linux-gnu.bin";
    hash = "sha256-UAInXZR/nQbtLnzceoFf0ercG6HrmBmVx4nhNyG4//4=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/pplx"
    runHook postInstall
  '';

  # Offline and credential-free, so it is safe in the sandbox; proves the patched
  # interpreter resolves before anything lands on PATH. Not versionCheckHook:
  # --version prints the build stamp, not "0.2.3".
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/pplx" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Perplexity Search API in the terminal: web search and page snippets as JSON";
    homepage = "https://github.com/perplexityai/perplexity-cli";
    changelog = "https://github.com/perplexityai/perplexity-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "pplx";
  };
})
