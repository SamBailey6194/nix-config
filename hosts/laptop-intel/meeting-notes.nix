{ ... }:

# meeting-notes in room mode: the built-in microphone hears the whole table,
# for in-person D&D sessions (`just dnd`). CPU only (Intel UHD, no CUDA):
# transcription runs in INT8 on the cached nixpkgs CTranslate2, so nothing is
# compiled. See docs/MEETING-NOTES.md#dd-sessions-in-person.
{
  software.meetingNotes = {
    enable = true;

    # Built-in Audio Analog Stereo capture (the internal microphone), recorded
    # as 16 kHz mono.
    micSource = "alsa_input.pci-0000_00_1f.3.analog-stereo";

    # PipeWire's input volume drives Capture (up to +30 dB) and Internal Mic
    # Boost (up to +30 dB) together; at 90% everything clipped. Capture 30
    # (+5.25 dB) with no boost was tested on 13/11/2026 with two people across
    # a table: no clipping, both voices transcribed and told apart. Re-test
    # with `meeting-notes mic-check --no-mixer` while changing these by amixer.
    micMixer = {
      card = "PCH";
      controls = { Capture = 30; "Internal Mic Boost" = 0; };
    };

    # No call outputs: room mode only, which defaultMode follows. Add e.g.
    # `speakers = "alsa_output.pci-0000_00_1f.3.analog-stereo";` to record
    # online sessions from this laptop too.
    remoteSinks = { };

    # i5-10210U: four physical cores. Recording itself barely uses the CPU;
    # transcription and labelling run afterwards, inside workload.slice.
    threads = 4;
  };
}
