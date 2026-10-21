{ ... }:

{
  # Dev stage and up (mkDevtowerIntel in flake.nix), alongside local-llm.nix:
  # it compiles CTranslate2 with CUDA and summarises with Claude Code for now,
  # the local llama.cpp models later (summariser = "local").
  software.meetingNotes = {
    enable = true;
    cudaCapabilities = [ "7.5" ]; # RTX 2080 Ti

    # GoXLR Mini "Chat Mic": the routing matrix sends only the microphone here.
    micSource = "alsa_input.usb-TC-Helicon_GoXLRMini-00.HiFi__Headset__source";

    # Where the call plays: headphones through the GoXLR Chat channel, or the
    # centre AG271QG4's speakers on HDMI 2 (see audio.nix for that sink).
    remoteSinks = {
      chat = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Headphones__sink";
      hdmi = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1";
    };
  };
}
