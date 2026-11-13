{ config, lib, options, pkgs, ... }:

# software.meetingNotes: the `meeting-notes` command (pkgs/meeting-notes).
# Records the user's microphone and the call output as separate tracks,
# transcribes them on the GPU, labels remote speakers, asks for name
# confirmation and writes notes with action points. See docs/MEETING-NOTES.md.
#
# Off by default: the PipeWire node names are specific to each machine's audio
# hardware, and with cudaCapabilities set it compiles CTranslate2 with CUDA.
# With no remoteSinks (laptop-intel) it records one room microphone and
# labels everyone at the table from it: in-person D&D sessions (--kind dnd).

let
  cfg = config.software.meetingNotes;
  llm = config.services.localLlm or { };
in
{
  options.software.meetingNotes = {
    enable = lib.mkEnableOption "meeting recording, transcription and notes";

    cudaCapabilities = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "7.5" ];
      description = ''
        GPU compute capabilities CTranslate2 is compiled for. Empty: CPU-only
        transcription (INT8) with the cached nixpkgs CTranslate2.
      '';
    };

    micSource = lib.mkOption {
      type = lib.types.str;
      description = ''
        PipeWire source (node.name): only the user's voice for calls, or the
        microphone that hears the whole table in room mode.
      '';
    };

    remoteSinks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { chat = "alsa_output.usb-…Headphones__sink"; };
      description = ''
        PipeWire sinks the call may play on, keyed by a short name for
        `--output`. Their monitors are recorded; `auto` records all of them and
        mixes them, so moving between headphones and speakers mid-call is fine.
      '';
    };

    micMixer = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          card = lib.mkOption {
            type = lib.types.str;
            example = "PCH";
            description = "ALSA card name or index (cat /proc/asound/cards).";
          };
          controls = lib.mkOption {
            type = lib.types.attrsOf (lib.types.either lib.types.int lib.types.str);
            example = { Capture = 30; "Internal Mic Boost" = 0; };
            description = "amixer simple controls and values, set before recording.";
          };
        };
      });
      default = null;
      description = ''
        ALSA capture levels applied at the start of every recording and
        mic-check. PipeWire maps the source volume onto these hardware controls,
        so pinning them keeps the gain the same from session to session.
      '';
    };

    defaultMode = lib.mkOption {
      type = lib.types.enum [ "call" "room" ];
      default = if cfg.remoteSinks == { } then "room" else "call";
      defaultText = lib.literalExpression ''if remoteSinks == { } then "room" else "call"'';
      description = ''
        `call`: the microphone and the call output as separate tracks.
        `room`: the microphone alone, everyone in the room on it (in person).
      '';
    };

    dndDir = lib.mkOption {
      type = lib.types.str;
      default = "~/Documents/DnD";
      description = "Campaign folders for `--kind dnd` sessions: <dndDir>/<campaign>/<session>.";
    };

    threads = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "CPU threads for CPU transcription and for speaker labelling.";
    };

    selfName = lib.mkOption {
      type = lib.types.str;
      default = "Me";
      description = "Label for the microphone track in transcripts and notes.";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "~/Documents/Meetings";
      description = "Where recordings, transcripts and notes are written.";
    };

    asrModel = lib.mkOption {
      type = lib.types.str;
      default = "large-v3-turbo";
      description = "faster-whisper model, downloaded on first use.";
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = "en";
      description = "Spoken language passed to Whisper.";
    };

    diariseModel = lib.mkOption {
      type = lib.types.str;
      default = "pyannote/speaker-diarization-community-1";
      description = "Gated Pyannote pipeline; accept its terms on Hugging Face once.";
    };

    summariser = lib.mkOption {
      type = lib.types.enum [ "claude" "local" ];
      default = "claude";
      description = ''
        LLM for speaker-name suggestions and notes. `claude` sends the
        transcript to Anthropic through `claude -p`; `local` uses the
        llama-swap endpoint and keeps everything on this machine.
      '';
    };

    localUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${llm.host or "127.0.0.1"}:${toString (llm.port or 8080)}/v1";
      description = "OpenAI-compatible endpoint for the `local` summariser.";
    };

    localModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if llm.serverEnable or false then llm.defaultModel else null;
      description = "Model name for the `local` summariser.";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      hfSecret = ../../secrets + "/huggingface-token-${config.networking.hostName}.age";
      hasHfSecret = builtins.pathExists hfSecret;
      user = if config.users.users ? sam-desktop then "sam-desktop"
        else if config.users.users ? sam-laptop then "sam-laptop"
        else "sam-framework";
    in
    lib.mkMerge [
      # Pyannote's gated model needs a Hugging Face read token. Optional: until
      # the secret exists, remote speakers stay as "Them" (or HF_TOKEN is used).
      # Only where agenix is imported (`age` must exist even under a false
      # mkIf) and has a key to decrypt with: stages before full set no
      # age.identityPaths, and agenix asserts on a secret it cannot open.
      (lib.optionalAttrs (options ? age) {
        age.secrets = lib.mkIf (hasHfSecret && config.age.identityPaths != [ ]) {
          huggingface-token = {
            file = hfSecret;
            owner = user;
            mode = "0400";
          };
        };
      })

      {
        environment.systemPackages = [
          (pkgs.callPackage ../../pkgs/meeting-notes {
            inherit (cfg) cudaCapabilities;
            settings = {
              inherit (cfg) micSource micMixer remoteSinks defaultMode dndDir threads selfName outputDir
                asrModel language diariseModel summariser;
              defaultOutput = "auto";
              hfTokenFile = "/run/agenix/huggingface-token";
              local = { url = cfg.localUrl; model = cfg.localModel; };
              resourceRun = "/run/current-system/sw/bin/resource-run";
            };
          })
        ];
      }
    ]
  );
}
