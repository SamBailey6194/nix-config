{ config, pkgs, ... }:

{
  # AMD laptop-specific hardware configuration
  # For: framework (AMD Ryzen + Radeon)

  # AMD CPU Microcode
  hardware.cpu.amd.updateMicrocode = true;

  # AMD Graphics (Radeon)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
      libva
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # AMD GPU driver
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Laptop Power Management (AMD-specific)
  services.thermald.enable = false; # Intel only
  services.power-profiles-daemon.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      RADEON_DPM_STATE_ON_AC = "performance";
      RADEON_DPM_STATE_ON_BAT = "battery";
    };
  };

  # Backlight Control
  programs.light.enable = true;

  # OpenGL/Vulkan
  hardware.opengl = {
    driSupport = true;
    driSupport32Bit = true;
  };
}
