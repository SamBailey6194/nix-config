{ config, lib, pkgs, ... }:

{
  # Intel desktop CPU + NVIDIA desktop GPU (devtower-intel: i9-9900K + RTX 2080 Ti)
  # Counterpart of amd-desktop.nix

  # CPU - Intel
  hardware.cpu.intel.updateMicrocode = true;

  # GPU - NVIDIA
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Must be set explicitly for drivers >= 560; open modules support Turing
    open = true;
    # Fallback if Hyprland misbehaves on the default (stable) branch:
    # branch = "legacy_580"; # 580.178.04, same as Ubuntu
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
  };

  # nixpkgs only adds nvidia_drm when services.xserver.enable is true, which
  # this repo never sets; load the stack early for Hyprland (greetd) and KMS
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # NVIDIA Wayland session variables
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia"; # drop if Discord/Zoom screen sharing misbehaves
    NVD_BACKEND = "direct";
  };

  # Performance mode (desktop - no battery concerns)
  powerManagement.cpuFreqGovernor = "performance";

  # Low-latency audio (same as amd-desktop.nix, so stages 2-4 keep it)
  services.pipewire.extraConfig.pipewire."context.properties" = {
    "default.clock.rate" = 48000;
    "default.clock.quantum" = 256;
    "default.clock.min-quantum" = 128;
  };

  environment.systemPackages = [ pkgs.nvtopPackages.nvidia ];
}
