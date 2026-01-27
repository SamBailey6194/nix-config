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
      libva-vdpau-driver  # Renamed from vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # AMD GPU driver
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Laptop Power Management (AMD-specific)
  # Note: power-profiles-daemon and tlp conflict - use only one
  services.thermald.enable = false; # Intel only
  services.power-profiles-daemon.enable = false; # Disabled - using TLP instead
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

  # Note: hardware.opengl options have been removed as they are deprecated.
  # DRI support is now automatically enabled when hardware.graphics.enable = true.
  # The hardware.graphics block at the top handles all graphics configuration.
}
