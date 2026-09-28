# opencode — OpenCode v2, the terminal AI coding agent (`opencode`). Used here
# for agent work against the local Qwen model that llama-server serves on
# devtower-intel (modules/software/local-llm.nix), as well as hosted models.
#
# nixpkgs carries it (pkgs/by-name/op/opencode), but the pinned nixpkgs is at
# 1.18.31: the v1 line. v2 (2.0.18, the release the Ubuntu install runs) is a
# rewrite with its own config schema (`providers`, `mcp.servers`), which is what
# home/modules/opencode.nix writes — v2 still reads v1 configs, v1 cannot read
# v2's. nixpkgs builds v1 from source with Bun; that recipe does not carry over
# (the node_modules FOD hash, the --replace-fail patches to v1's build script
# and the models.dev snapshot would all need re-deriving), and v2 is not on
# GitHub releases at all — anomalyco/opencode's releases stop at v1.18.x. v2
# ships only through npm: @opencode/cli is a stub whose postinstall picks the
# per-platform package, @opencode/cli-<os>-<arch>, which holds nothing but the
# prebuilt Bun-compiled binary. The curl installer downloads that same tarball.
# So this wraps it, like pkgs/perplexity-cli.nix. `hash` is the npm registry's
# own `dist.integrity` for the tarball, so it can be checked against
#   https://registry.npmjs.org/@opencode/cli-linux-x64/<VERSION>
#
# The binary is linked only against glibc; autoPatchelfHook repoints its
# interpreter. Bun keeps the bundled JavaScript in a `.bun` ELF section, so
# patchelf is safe, but stripping is not (it would leave the bare Bun runtime),
# hence dontStrip. linux-x64 needs AVX2 (every host here has it); the
# `-baseline` package is the fallback for CPUs without.
#
# Self-update: `opencode upgrade`, and the client's own update check (config
# `update`, default "notify"), would reinstall through npm/curl/brew — none of
# which can write into the store. OPENCODE_DISABLE_AUTOUPDATE skips the check
# entirely (it is tested before the config policy), so the wrapper sets it with
# --set: unlike agy's --set-default, there is nothing for an export to switch
# back on. Updates come from bumping this file.
#
# ripgrep: OpenCode looks for `rg` on PATH, then in its cache
# ($XDG_CACHE_HOME/opencode/bin), and otherwise downloads a static build from
# GitHub into that cache. The wrapper puts nixpkgs' ripgrep on PATH so it never
# downloads one (same as nixpkgs' own wrapper).
#
# Go back to nixpkgs' `opencode` (keeping nothing from here) once it reaches
# 2.0.18 or newer; every eval warns when it does.
#
# Consumer: modules/software/development.nix (PATH). home/modules/opencode.nix
# only merges keys into the config with jq and never runs the binary.
#
# To bump: change `version` and `hash`. The hash is `.dist.integrity` from
#   curl -s https://registry.npmjs.org/@opencode/cli-linux-x64/<VERSION>
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  ripgrep,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  opencode,
}:

let
  version = "2.0.18";
in
lib.warnIf (lib.versionAtLeast opencode.version version)
  "pkgs/opencode.nix: nixpkgs now has opencode ${opencode.version}; switch back to pkgs.opencode"
(stdenv.mkDerivation (finalAttrs: {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${finalAttrs.version}.tgz";
    hash = "sha512-94dH7lwB+tpmzI1/NIfzFxLBIeshZSNtyx2sskL0C0kgYjMaiVMIHvQLYIECUOWSuVz5/dH/KPUIOGn7ML311g==";
  };

  # npm tarballs unpack to ./package
  sourceRoot = "package";

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode "$out/bin/opencode"
    wrapProgram "$out/bin/opencode" \
      --set OPENCODE_DISABLE_AUTOUPDATE true \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
    runHook postInstall
  '';

  # `opencode --version` prints "opencode v2.0.18" without touching the network
  # or starting the background service; it does create its XDG directories,
  # hence the throwaway HOME.
  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "AI coding agent built for the terminal (v2, prebuilt npm binary)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencode";
  };
}))
