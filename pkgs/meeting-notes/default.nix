{ lib, pkgs, makeWrapper, runCommand, ffmpeg, pipewire, addDriverRunpath
, cudaCapabilities ? [ "7.5" ]
, settings ? { }
}:

# meeting-notes: two-track meeting capture -> GPU transcription -> CPU speaker
# labelling of the remote track -> confirmed names -> LLM notes.
#
# Two Python environments, kept apart on purpose:
#   asrPython      faster-whisper on a CUDA CTranslate2. No Torch on this path,
#                  so only CTranslate2 is compiled for the GPU.
#   diarisePython  nixpkgs' CPU-only WhisperX, used for its Pyannote speaker
#                  labelling alone. Switching Torch to CUDA wheels would drag
#                  torchaudio and every Torch dependant into rebuilds that break
#                  on most nixpkgs updates.
#
# CUDA architectures are per package, as in modules/software/local-llm.nix:
# only this CTranslate2's view of the CUDA package set changes, so nvcc,
# cudart, cuBLAS and cuDNN stay the cached default derivations.

let
  dropDot = lib.replaceStrings [ "." ] [ "" ];
  # SASS for each listed GPU, plus PTX for the newest so a later card can JIT it
  gencode =
    map (c: "-gencode=arch=compute_${dropDot c},code=sm_${dropDot c}") cudaCapabilities
    ++ [ "-gencode=arch=compute_${dropDot (lib.last cudaCapabilities)},code=compute_${dropDot (lib.last cudaCapabilities)}" ];

  cudaPackages = pkgs.cudaPackages.overrideScope (
    _: prev: {
      flags = prev.flags // { inherit gencode; };
    }
  );

  ctranslate2-cpp = pkgs.ctranslate2.override {
    withCUDA = true;
    withCuDNN = true;
    inherit cudaPackages;
  };

  python = pkgs.python3.override {
    self = python;
    packageOverrides = _: super: {
      ctranslate2 = super.ctranslate2.override { inherit ctranslate2-cpp; };
    };
  };

  asrPython = python.withPackages (ps: [ ps.faster-whisper ]);
  diarisePython = pkgs.python3.withPackages (ps: [ ps.whisperx ]);

  settingsFile = pkgs.writeText "meeting-notes-settings.json" (builtins.toJSON settings);
in
runCommand "meeting-notes"
  {
    nativeBuildInputs = [ makeWrapper ];
    passthru = { inherit asrPython diarisePython ctranslate2-cpp; };
    meta = {
      description = "Record, transcribe, label and summarise meetings locally";
      mainProgram = "meeting-notes";
    };
  }
  ''
    mkdir -p $out/share/meeting-notes $out/bin
    cp ${./meeting_notes.py} $out/share/meeting-notes/meeting_notes.py
    cp ${./transcribe.py} $out/share/meeting-notes/transcribe.py
    cp ${./diarise.py} $out/share/meeting-notes/diarise.py

    makeWrapper ${pkgs.python3}/bin/python3 $out/bin/meeting-notes \
      --add-flags "-I $out/share/meeting-notes/meeting_notes.py" \
      --set MEETING_NOTES_SETTINGS ${settingsFile} \
      --set MEETING_NOTES_SHARE $out/share/meeting-notes \
      --set MEETING_NOTES_ASR_PYTHON ${asrPython}/bin/python3 \
      --set MEETING_NOTES_DIARISE_PYTHON ${diarisePython}/bin/python3 \
      --set MEETING_NOTES_DRIVER_LIB ${addDriverRunpath.driverLink}/lib \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg pipewire ]}
  ''
