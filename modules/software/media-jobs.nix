{ config, lib, pkgs, ... }:

let
  rhubarb = pkgs.callPackage ../../pkgs/rhubarb.nix { };
  contained = name: executable: pkgs.writeShellScriptBin name ''
    exec /run/current-system/sw/bin/resource-run ${executable} "$@"
  '';
in
{
  # Declared here rather than in transcription.nix because this module is
  # imported on every stage (via nix-settings.nix), so a host can set it even
  # on the minimal stage, which leaves the desktop modules out.
  options.software.heavyMediaTools.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install the CPU-heavy media tools: rhubarb (here) and whisperx /
      WhisperFlow (transcription.nix). Off on hosts too weak to run them
      usefully, such as laptop-intel.
    '';
  };

  # Every device/stage: ffprobe is supplied by the FFmpeg distribution.
  config.environment.systemPackages = [
    (contained "ffmpeg" "${pkgs.ffmpeg}/bin/ffmpeg")
    (pkgs.writeShellScriptBin "ffprobe" ''
      exec ${pkgs.ffmpeg}/bin/ffprobe "$@"
    '')
  ] ++ lib.optional config.software.heavyMediaTools.enable
    (contained "rhubarb" "${rhubarb}/bin/rhubarb");
}
