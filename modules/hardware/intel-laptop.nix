{ config, pkgs, ... }:

{
  # Intel laptop-specific hardware configuration
  # For: laptop-intel (i5-10210U, Intel UHD Graphics)

  # Intel CPU Microcode
  hardware.cpu.intel.updateMicrocode = true;

  # Intel Graphics (UHD Graphics CML GT2)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver  # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver  # LIBVA_DRIVER_NAME=i965
    ];
  };

  # Laptop Power Management
  services.thermald.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    };
  };

  # Backlight Control
  programs.light.enable = true;
}
