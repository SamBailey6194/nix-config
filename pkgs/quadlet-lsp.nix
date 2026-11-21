# quadlet-lsp — language server for Podman Quadlet unit files (.container,
# .volume, .network, .pod, .image, .kube, .build, .artifact): key/value
# completion, hover docs, go-to-definition/references between units, syntax
# checks, and built-in commands (e.g. pull image, list job dependencies).
#
# Not packaged in nixpkgs (verified against the pinned nixpkgs: no
# `quadlet-lsp` attribute), so it is built from source here. Upstream vendors
# its Go modules (vendor/ is committed), hence `vendorHash = null`; the ldflags
# mirror upstream's own flake.nix / RPM spec so `quadlet-lsp version` reports
# the release rather than an empty string.
#
# Run with no arguments it speaks LSP over stdio; any argument is treated as a
# CLI subcommand instead. Consumers: modules/software/development.nix (PATH),
# home/modules/neovim.nix (the `quadlet` filetypes and server) and
# home/modules/editor.nix (Zed's `quadlet` extension, pointed at this binary).
#
# To bump: change `version`, set `hash` to lib.fakeHash, build, and copy the
# hash nix reports back in. If upstream ever stops committing vendor/, switch
# `vendorHash` to lib.fakeHash too and copy that hash in as well.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "quadlet-lsp";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "onlyati";
    repo = "quadlet-lsp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+C5igLRjA/syVu4oZWQE35XhSjFkh0MonQdKxyVnvO8=";
  };

  vendorHash = null;

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/onlyati/quadlet-lsp/internal/data.ProgramVersion=${finalAttrs.version}"
  ];

  meta = {
    description = "Language server for Podman Quadlet unit files";
    homepage = "https://github.com/onlyati/quadlet-lsp";
    changelog = "https://github.com/onlyati/quadlet-lsp/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "quadlet-lsp";
  };
})
