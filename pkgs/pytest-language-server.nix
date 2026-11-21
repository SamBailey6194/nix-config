# pytest-language-server — fixture-aware LSP for pytest test suites: go-to-definition
# and find-references for fixtures across conftest.py chains, completion of fixture
# parameters, hover docs, undeclared-fixture diagnostics and code actions.
#
# Not packaged in nixpkgs (verified against the pinned nixpkgs: no
# `pytest-language-server` attribute), so it is built from the upstream release
# tag here. It is a plain Rust crate with a committed Cargo.lock, so
# buildRustPackage needs nothing beyond the two hashes.
#
# It complements, not replaces, the Python type checker / LSP (Pyright, pylsp):
# those know nothing about pytest's name-based fixture injection. It parses the
# workspace and the project's site-packages itself, so it should be started from
# (or find) the project's virtualenv to see plugin fixtures.
#
# Consumers: modules/software/development.nix (PATH), home/modules/neovim.nix
# (the `pytest_language_server` lspconfig entry) and home/modules/editor.nix (Zed's
# `pytest-language-server` extension, pointed at this binary via
# lsp.pytest-language-server.binary.path).
#
# To bump: change `version`, set `hash` and `cargoHash` to lib.fakeHash, build,
# and copy the hashes nix reports back in.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "pytest-language-server";
  version = "0.26.1";

  src = fetchFromGitHub {
    owner = "bellini666";
    repo = "pytest-language-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9qJ0OP6cqnD7XdKL838jameWuOKyyIdYgHLVwiBRFJo=";
  };

  cargoHash = "sha256-UQGp1xIEK0GKTx45S9jWfjk87gGPtwJ6hP+ShLc8tRA=";

  meta = {
    description = "Language Server Protocol implementation for pytest";
    homepage = "https://github.com/bellini666/pytest-language-server";
    changelog = "https://github.com/bellini666/pytest-language-server/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "pytest-language-server";
  };
})
