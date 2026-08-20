# laravel-ls — language server for Laravel projects (routes, views, config keys,
# env vars, translations, Eloquent relations) on top of PHP/Blade.
#
# Not packaged in nixpkgs (verified against the pinned nixpkgs: no `laravel-ls`
# attribute), so the prebuilt release binary is wrapped, same approach as
# pkgs/opengrep.nix. Upstream ships a plain dynamically-linked Go binary, so
# autoPatchelfHook only has to repoint the interpreter at the Nix glibc.
#
# Intelephense covers PHP itself; this adds the Laravel-aware completions on top,
# and is what Neovim's `laravel_ls` lspconfig entry and Zed's `laravel-official`
# extension both expect on PATH.
#
# To bump: change `version` and `hash`. Get the new hash with:
#   nix store prefetch-file \
#     https://github.com/laravel-ls/laravel-ls/releases/download/v<VERSION>/laravel-ls-v<VERSION>-linux-amd64
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "laravel-ls";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/laravel-ls/laravel-ls/releases/download/v${finalAttrs.version}/laravel-ls-v${finalAttrs.version}-linux-amd64";
    hash = "sha256-9HolrGHEiSQKdm8S13p+YKGu2esAFOpqwpYoxRoWzec=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/laravel-ls"
    runHook postInstall
  '';

  meta = {
    description = "Language server for Laravel projects";
    homepage = "https://github.com/laravel-ls/laravel-ls";
    changelog = "https://github.com/laravel-ls/laravel-ls/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "laravel-ls";
  };
})
