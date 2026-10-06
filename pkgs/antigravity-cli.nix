# antigravity-cli — Google's Antigravity CLI (`agy`), the successor to Gemini CLI.
#
# nixpkgs carries it (pkgs/by-name/an/antigravity-cli), but the pinned nixpkgs is
# at 1.2.3, well behind the 1.3.0 that Google's installer and
# auto-updater currently serve (1.2.4–1.2.11 alone fixed MCP schema handling,
# plugin MCP lifecycle and OAuth error reporting). This bumps nixpkgs' own
# derivation rather than re-packaging it — same prebuilt tarball layout, same
# autoPatchelfHook, same versionCheckHook — so the bump itself only moves
# `version` and `src`. The wrapper, passthru.wholeVersion and meta.platforms
# changes below are separate.
# Unfree, so Hydra never builds it and there is no cache hit to lose by bumping:
# it is patched locally either way.
#
# Pinned to 1.3.0, which is both GCS's `/latest` and what the auto-updater
# manifest that installed CLIs follow currently serves. The two can disagree for
# a while (at 1.2.12 `/latest` was already 1.2.13), and nixpkgs' update.sh reads
# `/latest`, so bump to what the auto-updater serves, not what `/latest` says.
#
# The built-in self-updater checks a manifest every 15 minutes and, on a newer
# version, downloads it and renames it over its own executable. Under the store
# that rename can only fail, so the wrapper sets AGY_CLI_DISABLE_AUTO_UPDATE
# (the documented opt-out, antigravity.google/docs/cli/troubleshooting), with
# --set-default so a shell export still wins. Updates come from bumping this file.
#
# Drop the version/src/passthru overrides and go back to plain
# `pkgs.antigravity-cli` (keeping the wrapper) once nixpkgs is at 1.3.0 or
# newer; every eval warns when it is, since the self-updater is off and this
# file would otherwise quietly hold agy back after a `nix flake update`.
#
# Consumer: modules/software/development.nix (PATH), the only callPackage of this
# file. home/modules/antigravity.nix does not use it: it only imports
# home/modules/mcp-activation.nix with client = "antigravity", which writes the
# shared MCP server list to ~/.gemini/config/mcp_config.json and never runs agy.
#
# To bump: change `version`, `buildId` and `hash`. The build id is in
#   https://storage.googleapis.com/antigravity-public/antigravity-cli/<VERSION>/manifest.json
# (.platforms."linux-x64".url); get the hash with `nix store prefetch-file <url>`.
{
  lib,
  antigravity-cli,
  fetchurl,
  makeWrapper,
}:

let
  version = "1.3.0";
  buildId = "6233328509124608";
in
lib.warnIf (lib.versionAtLeast antigravity-cli.version version)
  "pkgs/antigravity-cli.nix: nixpkgs now has antigravity-cli ${antigravity-cli.version}; drop the version/src/passthru overrides (keep the wrapper)"
(antigravity-cli.overrideAttrs (finalAttrs: prevAttrs: {
  inherit version;

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${finalAttrs.version}-${buildId}/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-VHMcyO2P5KGEDDhia34yUcbcRIQ4f5gAXbpoJQf0lb4=";
  };

  nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ makeWrapper ];

  postInstall = (prevAttrs.postInstall or "") + ''
    wrapProgram "$out/bin/agy" --set-default AGY_CLI_DISABLE_AUTO_UPDATE true
  '';

  # nixpkgs' wholeVersion is a let binding in its package.nix, so it would
  # otherwise still report 1.2.3's build id.
  passthru = prevAttrs.passthru // {
    wholeVersion = "${finalAttrs.version}-${buildId}";
  };

  # Only the x86_64 tarball is pinned above; every host here is x86_64.
  meta = prevAttrs.meta // {
    platforms = [ "x86_64-linux" ];
  };
}))
