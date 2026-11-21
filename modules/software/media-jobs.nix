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

  # Thread count for render scripts (e.g. ffmpeg -threads "$MEDIA_THREADS"),
  # derived from the CPU quota the ffmpeg wrapper below runs under: "400%" is
  # four logical CPUs, so 4. Changing workloads.cpuQuota changes this with it,
  # so encoders never start more threads than the slice lets them run. Set
  # system-wide (pam_env) so it reaches GUI-launched apps, not just zsh.
  config.environment.sessionVariables.MEDIA_THREADS = toString (lib.max 1
    (lib.toInt (lib.removeSuffix "%" config.workloads.cpuQuota) / 100));

  # Every device/stage: ffprobe is supplied by the FFmpeg distribution.
  config.environment.systemPackages = [
    (contained "ffmpeg" "${pkgs.ffmpeg}/bin/ffmpeg")
    (pkgs.writeShellScriptBin "ffprobe" ''
      exec ${pkgs.ffmpeg}/bin/ffprobe "$@"
    '')
  ] ++ lib.optional config.software.heavyMediaTools.enable
    # Rhubarb itself finds res/ beside its real binary, but tools that look for
    # res/sphinx/cmudict-en-us.dict beside the `rhubarb` on PATH (syntek-media's
    # lipsync and check --setup) resolve to this wrapper's directory instead,
    # so link the release's res/ in beside the wrapper too. The script is a real
    # file here (not a link to another wrapper), so it resolves to this directory.
    (pkgs.runCommand "rhubarb" { } ''
      mkdir -p "$out/bin"
      cp ${contained "rhubarb" "${rhubarb}/bin/rhubarb"}/bin/rhubarb "$out/bin/rhubarb"
      ln -s ${rhubarb}/bin/res "$out/bin/res"
    '');
}
