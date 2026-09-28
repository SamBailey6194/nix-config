{ config, pkgs, ... }:

{
  # AMD desktop-specific hardware configuration
  # For: devtower (AMD Ryzen + Radeon, no battery)

  # AMD CPU Microcode
  hardware.cpu.amd.updateMicrocode = true;

  # AMD Graphics (Radeon)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
      libva
      libva-vdpau-driver  # Renamed from vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # AMD GPU driver
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Desktop: Full performance mode (no power management)
  powerManagement.cpuFreqGovernor = "performance";

  # Note: hardware.opengl options have been removed as they are deprecated.
  # DRI support is now automatically enabled when hardware.graphics.enable = true.
  # The hardware.graphics block at the top handles all graphics configuration.

  # Low latency audio (desktop/workstation)
  services.pipewire.extraConfig.pipewire = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 256;
      "default.clock.min-quantum" = 128;
    };
  };

  # System monitoring
  # AI-02: switch to nvtopPackages.full (AMD + NVIDIA in one) once its NVIDIA
  # card (RTX PRO 6000 Blackwell) is added; .amd cannot see NVIDIA GPUs.
  environment.systemPackages = with pkgs; [
    nvtopPackages.amd # GPU monitoring (nvtop was renamed to nvtopPackages.*)
  ];
}
