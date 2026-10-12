{ pkgs, ... }:

# ArtCraft "Craft" apps (https://getartcraft.com/apps): PhotoCraft,
# VectorCraft, LightCraft, PdfCraft, DesignCraft, EffectCraft, FilmCraft,
# SoundCraft, WordCraft and DeckCraft.
# Native Rust/wgpu apps shipped as AppImages, wrapped in pkgs/craft-apps.
#
# Imported next to the Affinity apps, i.e. by every creative and full stage:
#   hosts/{laptop-intel,framework,devtower}/configuration-{creative,full}.nix
# devtower-intel builds on the devtower stage files (flake.nix mkDevtowerIntel),
# so devtower-intel-creative and devtower-intel get them from there.
#
# Not in modules/software/creative.nix: laptop-intel's creative stages skip
# that module (DaVinci Resolve needs a dedicated GPU) but should still get these.
#
# Update pins with `just update-craft`; see modules/software/README.md.
let
  craftApps = pkgs.callPackages ../../pkgs/craft-apps { };
in
{
  environment.systemPackages = builtins.attrValues craftApps;
}
