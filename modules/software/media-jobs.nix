{ pkgs, ... }:

let
  rhubarb = pkgs.callPackage ../../pkgs/rhubarb.nix { };
  contained = name: executable: pkgs.writeShellScriptBin name ''
    exec /run/current-system/sw/bin/resource-run ${executable} "$@"
  '';
in
{
  # Every device/stage: ffprobe is supplied by the FFmpeg distribution.
  environment.systemPackages = [
    (contained "ffmpeg" "${pkgs.ffmpeg}/bin/ffmpeg")
    (pkgs.writeShellScriptBin "ffprobe" ''
      exec ${pkgs.ffmpeg}/bin/ffprobe "$@"
    '')
    (contained "rhubarb" "${rhubarb}/bin/rhubarb")
  ];
}
