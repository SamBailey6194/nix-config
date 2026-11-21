# django-language-server (djls) — Django-aware language server for templates:
# {% %} tag/filter completion and hover, block-structure and argument
# diagnostics, {% extends %}/{% include %}/{% load %} navigation and document
# links, folding, and optional djangofmt formatting.
#
# Not packaged in nixpkgs (verified against the pinned nixpkgs: no
# `django-language-server` attribute, top level or under python3Packages), so it
# is built here from the upstream release tag. Upstream is a plain Cargo
# workspace (crates/*); the `djls` crate is the binary. The PyPI wheel is only
# that same binary repackaged by maturin, so building the crate directly avoids
# a Python wrapper. djls does not execute Python at runtime: it statically reads
# the project's settings module and the venv's site-packages, and falls back to
# Django 5.2/6.0/6.1 sources embedded in the binary when Django is not installed.
#
# rust-toolchain.toml pins 1.97.1; nixpkgs' rustc is newer and builds it fine.
# Only the `djls` package is built and tested: the workspace also holds a
# benchmark crate and corpus tests that want network-fetched Django checkouts.
#
# Consumers: modules/software/development.nix (PATH), home/modules/neovim.nix
# (the pinned `cmd` for the `djls` server) and home/modules/editor.nix (Zed's
# `django-language-server` binary path).
#
# To bump: change `version`, set `hash` and `cargoHash` to lib.fakeHash, build,
# and copy the hashes nix reports back in.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "django-language-server";
  version = "6.1.1";

  src = fetchFromGitHub {
    owner = "joshuadavidthomas";
    repo = "django-language-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pEXO3hpA/uy4wfNncL33JWXkcAqkIjTZkODarpbpY2Y=";
  };

  cargoHash = "sha256-+wQCD/P4novQNpth8Jl80YhoUQDG4dnAynSdHni8tjQ=";

  cargoBuildFlags = [ "--package" "djls" ];
  cargoTestFlags = [ "--package" "djls" ];

  meta = {
    description = "Language server for the Django web framework";
    homepage = "https://github.com/joshuadavidthomas/django-language-server";
    changelog = "https://github.com/joshuadavidthomas/django-language-server/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "djls";
  };
})
