{ lib, ... }:

{
  # Dev stage and up only: mkDevtowerIntel (flake.nix) adds this file for dev,
  # productivity, creative and full, never minimal or desktop. The option itself
  # comes from modules/software/local-llm.nix via development.nix.
  #
  # llama.cpp with CUDA + OpenBLAS, kernels for the RTX 2080 Ti (Turing, compute
  # 7.5) only. mkForce because the devtower stage files underneath will set
  # [ "12.0" ] for AI-02's Blackwell card once it is configured, and list
  # definitions concatenate rather than override.
  services.localLlm = {
    enable = true;
    cudaCapabilities = lib.mkForce [ "7.5" ];
    # CUDA + OpenBLAS by choice. With the GPU present, BLAS takes dense
    # CPU-side matrix multiplications away from GPU offload (OPENBLAS in
    # local-llm.nix); the MoE setup served today is unaffected. false = CUDA only.
    blas = true;
    serverEnable = true;
    models = import ../../modules/software/local-llm-models.nix;
  };

  # Backstop for builds that run inside nix-daemon.service (started as a user:
  # `nix build`, `nix develop`, `nixos-rebuild --sudo`), since this machine
  # also holds a model in RAM. A build that outgrows the cap is killed inside
  # the daemon's cgroup, rather than the kernel picking llama-server or the
  # desktop session. No swap into zram, or the cap would not be a cap;
  # OOMPolicy=continue so one killed builder fails its own build instead of
  # systemd stopping the daemon (and every other client's build) with it.
  # `sudo nixos-rebuild` builds as root outside the daemon; local-llm.nix's own
  # job cap covers llama.cpp there (see BUILD MEMORY in that file).
  nix.daemonCPUSchedPolicy = "batch";
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "14G";
    MemoryMax = "16G";
    MemorySwapMax = "0";
    OOMPolicy = "continue";
    Slice = "compute.slice";
  };

  # Inference and Nix builds share a parent ceiling: their individual maxima
  # are not additive. Reserve RAM for the desktop and separately limited media.
  systemd.slices.compute.sliceConfig = {
    MemoryHigh = "20G";
    MemoryMax = "22G";
    MemorySwapMax = "0";
    CPUQuota = "1200%";
    CPUWeight = 25;
    IOWeight = 25;
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "60%";
  };
  systemd.services.llama-swap.serviceConfig.Slice = "compute.slice";
  workloads.memoryHigh = lib.mkForce "3G";
  workloads.memoryMax = lib.mkForce "4G";
  workloads.memorySwapMax = "0";
}
