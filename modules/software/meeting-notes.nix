{ config, lib, options, pkgs, ... }:

# software.meetingNotes: the `meeting-notes` command (pkgs/meeting-notes).
# Records the user's microphone and the call output as separate tracks,
# transcribes them on the GPU, labels remote speakers, asks for name
# confirmation and writes notes with action points. See docs/MEETING-NOTES.md.
#
# Off by default: it compiles CTranslate2 with CUDA for the listed GPU, and
# the PipeWire node names are specific to each machine's audio hardware.

let
  cfg = config.software.meetingNotes;
  llm = config.services.localLlm or { };
in
{
  options.software.meetingNotes = {
    enable = lib.mkEnableOption "meeting recording, transcription and notes";

    cudaCapabilities = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      example = [ "7.5" ];
      description = "GPU compute capabilities CTranslate2 is compiled for.";
    };

    micSource = lib.mkOption {
      type = lib.types.str;
      description = "PipeWire source with only the user's voice (node.name).";
    };

    remoteSinks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      example = { chat = "alsa_output.usb-…Headphones__sink"; };
      description = ''
        PipeWire sinks the call may play on, keyed by a short name for
        `--output`. Their monitors are recorded; `auto` records all of them and
        mixes them, so moving between headphones and speakers mid-call is fine.
      '';
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
              inherit (cfg) micSource remoteSinks selfName outputDir asrModel language
                diariseModel summariser;
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
