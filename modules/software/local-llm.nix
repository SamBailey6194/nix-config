{ config, lib, pkgs, ... }:

# Local LLM inference: llama.cpp built with CUDA (nvcc) + OpenBLAS, for hosts
# with an NVIDIA GPU. Imported by modules/software/development.nix, so the
# options exist from the dev stage upward on every host (off unless the host
# enables them); the minimal and desktop stages never have them.
#
#   devtower-intel  RTX 2080 Ti (Turing)                    cudaCapabilities = [ "7.5" ]
#                   enabled in hosts/devtower-intel/local-llm.nix, which
#                   mkDevtowerIntel (flake.nix) adds to dev/productivity/
#                   creative/full only
#   AI-02/devtower  RTX PRO 6000 Blackwell                  cudaCapabilities = [ "12.0" ]
#                   once its NVIDIA card is configured (NVIDIA driver alongside
#                   amd-desktop.nix, nvtopPackages.full), add to
#                   hosts/devtower/configuration-{dev,productivity,creative,full}.nix:
#                     services.localLlm = { enable = true; cudaCapabilities = [ "12.0" ]; };
#                   devtower-intel layers on those same files, which is why its
#                   own file sets the capability with mkForce.
#
# WHY A LOCAL BUILD
#
# cache.nixos-cuda.org has nixpkgs' CUDA llama-cpp, but that build has BLAS
# off: nixpkgs defaults blasSupport to false whenever any GPU backend is on.
# CUDA + OpenBLAS is not cached anywhere, so this is compiled locally with nvcc
# (a deliberate choice over the cached CUDA-only build). The CUDA
# redistributables themselves — nvcc, cudart, cuBLAS — are unchanged and are
# never compiled: cache.nixos.org does not carry unfree packages, so they are
# fetched from NVIDIA and only unpacked and patched locally (add
# cache.nixos-cuda.org to nix-settings.nix to skip even that). nixpkgs' default
# would also compile the CUDA kernels for every capability CUDA 12.9 targets by
# default (7.5 through 12.1, nine architectures); one architecture is a
# fraction of that nvcc time and of libggml-cuda.so's size.
#
# BUILD MEMORY
#
# Every nixpkgs bump rebuilds this locally, and each nvcc/cicc job takes about
# 2 GB of RAM. nix-settings.nix sets `cores = 0` (all of them), which would run
# `ninja -j16` over the CUDA objects on the i9-9900K: roughly 25-30 GB on a
# 32 GB machine, the same kind of out-of-memory kill that once took the whole
# desktop session down. preBuild below caps this one package at `buildJobs` jobs (4
# peaked at about 8 GiB) however high nix.settings.cores or --cores is.
#
# Where the build runs decides what else can cap it. `sudo nixos-rebuild` (what
# `just rebuild` runs) builds as root, and root uses the store directly rather
# than the daemon, so the builders stay in the calling terminal's cgroup; for a
# hard ceiling on top, run it as
#   sudo systemd-run --scope -p MemoryMax=16G -p MemorySwapMax=0 -- \
#     nixos-rebuild switch --flake .#devtower-intel-dev --max-jobs 1
# (stop llama-server first). Builds started as a user (`nix build`,
# `nixos-rebuild --sudo`) run inside nix-daemon.service instead, which
# hosts/devtower-intel/local-llm.nix caps; a `systemd-run --user --scope`
# wrapper does not reach those.
#
# CUDA ARCHITECTURES ARE PER PACKAGE
#
# Setting nixpkgs.config.cudaCapabilities (or cudaSupport) globally would
# rebuild every CUDA-aware package in the system for that GPU and lose the
# cache for all of them. Instead only this package's view of the CUDA package
# set is changed: `flags.cmakeCudaArchitecturesString`, the one value
# llama-cpp's derivation reads for CMAKE_CUDA_ARCHITECTURES. overrideScope
# leaves every other member of the set untouched, so nvcc, cudart and cuBLAS
# evaluate to the same derivations as the default set. "12.0" becomes "120",
# which llama.cpp's CMake turns into 120a (the architecture-specific target the
# Blackwell FP4 tensor-core instructions need).
#
# CPU side: GGML_NATIVE stays off and GGML_CPU_ALL_VARIANTS stays on (nixpkgs'
# defaults), so the CPU backend picks its AVX2/AVX-512/… variant at runtime
# instead of being compiled for the build machine with -march=native.
#
# OPENBLAS
#
# nixpkgs' `blas` is a generic wrapper, which leaves llama.cpp's
# GGML_BLAS_VENDOR at "Generic". Built against OpenBLAS directly with the
# vendor set to "OpenBLAS" instead, the BLAS backend calls
# openblas_set_num_threads() with llama.cpp's own thread count before every
# BLAS matrix multiplication, so OpenBLAS follows -t/-tb rather than starting
# one thread per logical CPU on top of ggml's. openblasCompat, not openblas: on
# x86_64 nixpkgs' `openblas` is ILP64 (64-bit integers); openblasCompat is the
# LP64 build that `blas` itself wraps. It is threaded with OpenMP, like ggml's
# CPU backend.
#
# Leave OPENBLAS_NUM_THREADS (and OMP_NUM_THREADS) unset: ggml sets OpenBLAS's
# thread count itself before every BLAS matrix multiplication, so the variable
# would only change the size of the pool OpenBLAS starts with. Tune threads
# with llama-server's -t/-tb instead (8 physical cores on the i9-9900K).
#
# The trade-off with a GPU present: BLAS takes plain matrix multiplications of
# at least 32×32×32 whose weights are in CPU memory, which is exactly the work
# ggml would otherwise hand to the GPU. The scheduler only offloads a
# CPU-resident weight's batch to CUDA when that weight belongs to the CPU
# backend, and BLAS (an "accelerator" backend, ranked between the GPU and the
# CPU) claims those weights first. For a dense model that does not fit in VRAM
# (partial -ngl, -ot …=CPU, or --fit shrinking -ngl), prompt processing then
# runs on OpenBLAS: 2.2-2.5× slower than without the BLAS backend, measured
# with a small F32 test model on the RTX 2080 Ti, and likely worse with
# quantised weights, which BLAS first converts to F32. Generation (one token at
# a time) never qualifies. An alternative Qwen3.6-35B-A3B tuning strategy
# avoids this:
# -ngl 99 puts every dense weight on the GPU, and the experts that --n-cpu-moe
# keeps on the CPU run through MUL_MAT_ID, which the BLAS backend does not
# take, so they are handled exactly as in a CUDA-only build. That placement
# is an optional tuning example, not the full-context configuration here:
# automatic fitting requires leaving explicit placement overrides unset.
# llama.cpp has no
# runtime switch for this; `blas = false` builds CUDA only.
#
# SERVING: llama-swap loads one model on demand behind the loopback endpoint.
# Model weights are runtime cache data, not part of a Nix rebuild. See
# docs/LOCAL-LLM.md for memory estimates, migration and full-context validation.

let
  cfg = config.services.localLlm;

  # "7.5" -> "75"; the same mapping nixpkgs uses to build the string itself
  cudaArchitectures = lib.concatMapStringsSep ";" (lib.replaceStrings [ "." ] [ "" ]) cfg.cudaCapabilities;

  supportedCudaCapabilities = pkgs.cudaPackages.backendStdenv.supportedCudaCapabilities;
  unsupportedCudaCapabilities = lib.subtractLists supportedCudaCapabilities cfg.cudaCapabilities;

  llama-cpp =
    (pkgs.llama-cpp.override (
      {
        cudaSupport = true;
        cudaPackages = pkgs.cudaPackages.overrideScope (
          _: prev: {
            flags = prev.flags // {
              cmakeCudaArchitecturesString = cudaArchitectures;
            };
          }
        );
      }
      # nixpkgs turns BLAS off whenever a GPU backend is on; turn it back on
      // lib.optionalAttrs cfg.blas {
        blasSupport = true;
        blas = pkgs.openblasCompat;
      }
    )).overrideAttrs
      (prev: {
        cmakeFlags = prev.cmakeFlags ++ lib.optional cfg.blas (lib.cmakeFeature "GGML_BLAS_VENDOR" "OpenBLAS");

        # At most `buildJobs` nvcc/cicc jobs at once (see BUILD MEMORY above).
        # stdenv has already turned cores = 0 into the CPU count by now, and
        # ninjaBuildPhase reads NIX_BUILD_CORES for -j after running preBuild.
        preBuild = (prev.preBuild or "") + ''
          if [ "$NIX_BUILD_CORES" -gt ${toString cfg.buildJobs} ]; then
            echo "llama-cpp: limiting the build to ${toString cfg.buildJobs} jobs (NIX_BUILD_CORES was $NIX_BUILD_CORES)"
            NIX_BUILD_CORES=${toString cfg.buildJobs}
          fi
        '';
      });
in
{
  options.services.localLlm = {
    enable = lib.mkEnableOption "llama.cpp (llama-cli, llama-server, …) built locally with CUDA (and OpenBLAS, see `blas`)";

    cudaCapabilities = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "7.5" ];
      description = ''
        CUDA compute capabilities to compile llama.cpp's kernels for: the
        GPU(s) in this host only ("7.5" for an RTX 2080 Ti, "12.0" for an RTX
        PRO 6000 Blackwell). Applies to this package alone, never to
        nixpkgs.config.
      '';
    };

    blas = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Build the OpenBLAS backend alongside CUDA. With a GPU present it takes
        dense matrix multiplications whose weights are in CPU memory away from
        GPU offload (see OPENBLAS at the top of this file); false builds CUDA
        only.
      '';
    };

    buildJobs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = ''
        Most compile jobs the llama.cpp build runs at once, whatever
        nix.settings.cores says. Each nvcc/cicc job needs about 2 GB of RAM;
        4 peaked at about 8 GiB on devtower-intel (32 GB).
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address llama-swap listens on, also used by OpenCode. Loopback by
        default. Binding a WireGuard address requires ordering after its tunnel.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port llama-server listens on (its own default is 8080).";
    };

    serverEnable = lib.mkEnableOption "on-demand local models through llama-swap";

    models = lib.mkOption {
      default = { };
      description = "GGUF models offered to OpenCode through llama-swap.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          repo = lib.mkOption { type = lib.types.str; };
          file = lib.mkOption { type = lib.types.str; };
          contextSize = lib.mkOption { type = lib.types.ints.positive; };
          cacheType = lib.mkOption { type = lib.types.str; default = "q8_0"; };
          aliases = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
          extraArgs = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
        };
      });
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.6-35b-a3b";
      description = "Default local model key for OpenCode.";
    };

    memoryHigh = lib.mkOption { type = lib.types.str; default = "18G"; };
    memoryMax = lib.mkOption { type = lib.types.str; default = "20G"; };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = llama-cpp;
      defaultText = lib.literalMD "llama-cpp with CUDA (for `cudaCapabilities` only) and, with `blas`, OpenBLAS";
      description = "The llama.cpp build this module installs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.cudaCapabilities != [ ];
        message = "services.localLlm.cudaCapabilities is empty: list this host's GPU capability, e.g. [ \"7.5\" ] for an RTX 2080 Ti.";
      }
      {
        assertion = unsupportedCudaCapabilities == [ ];
        message = "services.localLlm.cudaCapabilities: ${lib.concatStringsSep ", " unsupportedCudaCapabilities} not supported by CUDA ${pkgs.cudaPackages.cudaMajorMinorVersion} (supported: ${lib.concatStringsSep ", " supportedCudaCapabilities}).";
      }
      {
        assertion = !cfg.serverEnable || builtins.hasAttr cfg.defaultModel cfg.models;
        message = "services.localLlm.defaultModel must name a configured model when serverEnable is true.";
      }
    ];

    environment.systemPackages = [ cfg.package ] ++ lib.optional cfg.serverEnable (pkgs.writeShellApplication {
      name = "local-llm-control";
      runtimeInputs = [ pkgs.python3 pkgs.systemd pkgs.sudo ];
      text = ''
        exec ${pkgs.python3}/bin/python ${../../scripts/local-llm-control.py} "$@"
      '';
    });
    environment.etc."local-llm/control.json" = lib.mkIf cfg.serverEnable {
      text = builtins.toJSON {
        defaultModel = cfg.defaultModel;
        catalog = cfg.models;
        settings = config.services.llama-swap.settings;
        swapBinary = lib.getExe config.services.llama-swap.package;
        listen = "${cfg.host}:${toString cfg.port}";
        url = "http://${cfg.host}:${toString cfg.port}";
      };
    };

    services.llama-swap = lib.mkIf cfg.serverEnable {
      enable = true;
      listenAddress = cfg.host;
      port = cfg.port;
      openFirewall = false;
      settings = {
        # Loading a 15-20GB GGUF on the CPU can be slow. Downloads may need
        # longer still: pre-populate the cache if the first request times out.
        healthCheckTimeout = 1800;
        globalTTL = 300;
        logToStdout = "both";
        # The default group router unloads the old model before loading another.
        models = lib.mapAttrs (id: model: {
          cmd = lib.escapeShellArgs ([
            "${cfg.package}/bin/llama-server"
            "--host" "127.0.0.1" "--port" "\${PORT}"
            "--hf-repo" model.repo "--hf-file" model.file
            "--alias" id
            "--ctx-size" (toString model.contextSize)
            # --fit must not silently shrink the requested context.
            "--fit-ctx" (toString model.contextSize)
            "--fit" "on" "--fit-target" "2048"
            "--parallel" "1" "--threads" "8" "--threads-batch" "8"
            "--batch-size" "256" "--ubatch-size" "128"
            "--flash-attn" "on" "--jinja"
            # Host KV avoids consuming all of the 2080 Ti's VRAM at full ctx.
            "--no-kv-offload"
            "--cache-type-k" model.cacheType "--cache-type-v" model.cacheType
          ] ++ model.extraArgs);
          proxy = "http://127.0.0.1:\${PORT}";
          concurrencyLimit = 1;
          inherit (model) aliases;
        }) cfg.models;
      };
    };

    systemd.services.llama-swap = lib.mkIf cfg.serverEnable {
      serviceConfig = {
        MemoryHigh = cfg.memoryHigh;
        MemoryMax = cfg.memoryMax;
        MemorySwapMax = "0";
        MemoryOOMGroup = true;
        OOMPolicy = "kill";
        # Stop after OOM/failure rather than repeatedly reloading a failing model.
        Restart = lib.mkForce "no";
        CPUWeight = 25;
        IOWeight = 25;
      };
    };
  };
}
