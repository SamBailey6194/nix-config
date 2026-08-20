# htmx-lsp — hx-* attribute completion for markup buffers.
#
# Built from a newer upstream rev than nixpkgs carries. nixpkgs pins c45f55b
# (0.1.0-unstable-2025-06-14), which predates upstream cd53ae7, "fix(lsp):
# respond to requests with an error if no information is available". Before that
# commit htmx-lsp answered any request it had no data for — `shutdown` included —
# with both `result` and `error` set to null, which is not valid JSON-RPC. Neovim
# rejects the frame and prints
#
#   LSP[htmx]: Error INVALID_SERVER_MESSAGE: { id = 2, jsonrpc = "2.0" }
#
# into the message area every time a markup buffer is closed. Building from a rev
# that carries the fix removes the cause instead of filtering the symptom, and
# picks up four months of other fixes on the way.
#
# Drop this file and go back to plain `pkgs.htmx-lsp` once nixpkgs is at cd53ae7
# or newer. Consumers: modules/software/development.nix (PATH) and
# home/modules/neovim.nix (the pinned `cmd` for the `htmx` server).
#
# To bump: change `rev` and `version`, set `hash` and `cargoHash` to
# lib.fakeHash, build, and copy the hashes nix reports back in.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "htmx-lsp";
  version = "0.2.0-unstable-2025-10-18";

  src = fetchFromGitHub {
    owner = "ThePrimeagen";
    repo = "htmx-lsp";
    rev = "a05bf01d33710f1e86e3e4165badda9826a7a9bb";
    hash = "sha256-IX24OeYc/R9DJzWICmk5NL6HXzeAXZWjlyNa1Ehtc/w=";
  };

  cargoHash = "sha256-Z3t9MJ56k5MYNLLyrKpT8WeWc1+N4IhdhIgxsqjefCc=";

  meta = {
    description = "Language server implementation for htmx";
    homepage = "https://github.com/ThePrimeagen/htmx-lsp";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "htmx-lsp";
  };
})
