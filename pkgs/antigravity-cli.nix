# Keep nixpkgs' Antigravity CLI current through flake updates. Disable its
# self-updater because it cannot replace executables in the Nix store.
{
  antigravity-cli,
  makeWrapper,
}:

antigravity-cli.overrideAttrs (prevAttrs: {
  nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ makeWrapper ];

  postInstall = (prevAttrs.postInstall or "") + ''
    wrapProgram "$out/bin/agy" --set-default AGY_CLI_DISABLE_AUTO_UPDATE true
  '';
})
