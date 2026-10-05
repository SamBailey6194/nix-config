{ pkgs, ... }:

let
  whisperflow = pkgs.callPackage ../../pkgs/whisperflow.nix { };
  contained = name: executable: pkgs.writeShellScriptBin name ''
    exec /run/current-system/sw/bin/resource-run ${executable} "$@"
  '';
in
{
  # Imported by the shared desktop module, so stages 2-6 on every device get
  # both tools, while minimal installation images avoid the Python/Qt closure.
  environment.systemPackages = [
    # The standard nixpkgs package is CPU-only. A later --device argument can
    # override this when substituting a CUDA-enabled package.
    (contained "whisperx" "${pkgs.whisperx}/bin/whisperx --device cpu --compute_type int8 --batch_size 4")
    (contained "whisperflow" "${whisperflow}/bin/whisperflow")
    (contained "whisper-flow" "${whisperflow}/bin/whisperflow")
    (pkgs.makeDesktopItem {
      name = "whisper-flow";
      desktopName = "Whisper Flow";
      comment = "Local speech-to-text dictation";
      exec = "/run/current-system/sw/bin/whisperflow";
      icon = "audio-input-microphone";
      categories = [ "Utility" "Audio" "Accessibility" ];
      terminal = false;
    })
  ];
}
