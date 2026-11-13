{ ... }:

# meeting-notes in room mode: the built-in microphone hears the whole table,
# for in-person D&D sessions (`just dnd`). CPU only (Intel UHD, no CUDA):
# transcription runs in INT8 on the cached nixpkgs CTranslate2, so nothing is
# compiled. See docs/MEETING-NOTES.md#dd-sessions-in-person.
{
  software.meetingNotes = {
    enable = true;

    # Built-in Audio Analog Stereo capture (the internal microphone). Recorded
    # as 16 kHz mono. Its input volume drives Capture (+30 dB) and Internal Mic
    # Boost (+30 dB) together: 90% clips, so start near 30% and tune the level
    # with `meeting-notes mic-check`.
    micSource = "alsa_input.pci-0000_00_1f.3.analog-stereo";

    # No call outputs: room mode only, which defaultMode follows. Add e.g.
    # `speakers = "alsa_output.pci-0000_00_1f.3.analog-stereo";` to record
    # online sessions from this laptop too.
    remoteSinks = { };

    # i5-10210U: four physical cores. Recording itself barely uses the CPU;
    # transcription and labelling run afterwards, inside workload.slice.
    threads = 4;
  };
}
