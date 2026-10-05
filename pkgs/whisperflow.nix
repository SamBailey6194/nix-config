{ lib, python3Packages, fetchurl, qt6, ffmpeg, wl-clipboard, wtype, xclip, xdotool }:

python3Packages.buildPythonApplication {
  pname = "whisperflow";
  version = "2.0.0";
  pyproject = true;

  # Same revision as the Ubuntu installation being migrated.
  src = fetchurl {
    url = "https://github.com/konsti-web/whisper-flow-linux/archive/9a98098527da5d97843f756ed6843b2f47e9ab8c.tar.gz";
    hash = "sha256-PJseFyZRB+If8PhlDhcVdmaHRXElt8HZV3qbxIYcFIQ=";
  };

  build-system = [ python3Packages.setuptools ];
  dependencies = with python3Packages; [
    numpy sounddevice pynput pyside6 platformdirs psutil faster-whisper evdev
  ];
  nativeBuildInputs = [ qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtwayland ];
  # Upstream's NumPy upper bound predates the version in pinned nixpkgs.
  # Audio segmentation tests below exercise the packaged NumPy version.
  pythonRelaxDeps = [ "numpy" ];
  dontWrapQtApps = true;
  preFixup = ''
    makeWrapperArgs+=( "''${qtWrapperArgs[@]}" )
  '';
  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ ffmpeg wl-clipboard wtype xclip xdotool ]}"
  ];

  # Upstream assumes a mutable checkout with run.sh and a venv. Installed
  # autostart entries must invoke the contained system command instead.
  postPatch = ''
    substituteInPlace whisperflow/autostart.py \
      --replace-fail 'run_sh = Path(__file__).resolve().parent.parent / "run.sh"' \
        'run_sh = Path("/run/current-system/sw/bin/whisperflow")'
  '';

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];
  # No display, microphone or model downloads are needed for these tests.
  pytestFlags = [
    "tests/test_state.py" "tests/test_config.py" "tests/test_dictionary.py"
    "tests/test_vad.py" "tests/test_transcription.py"
  ];

  meta = {
    description = "Local Whisper-based speech-to-text dictation";
    homepage = "https://github.com/konsti-web/whisper-flow-linux";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "whisperflow";
  };
}
