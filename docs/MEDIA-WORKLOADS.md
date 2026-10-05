# Media tools and resource limits

All devices and stages include `ffmpeg`, `ffprobe` and Rhubarb Lip Sync
1.14.0. Desktop stages and above also include WhisperX and WhisperFlow 2.0.0
(the exact `konsti-web/whisper-flow-linux` revision installed on Ubuntu).
`whisperflow` and the existing command spelling `whisper-flow` both launch
the dictation app. It also has an application-menu entry.

FFmpeg, Rhubarb, WhisperX and WhisperFlow system commands automatically run
in separate systemd scopes beneath `workload.slice`. Child processes stay in
the same scope, including FFmpeg launched internally by transcription tools.
`ffprobe` is available without a scope since it is a lightweight probe.
Launch a whole script with `resource-run` to cover other tools and parallel jobs:

```sh
resource-run bash ~/bin/transcribe-batch.sh
ffmpeg -i input.mp4 output.webm
whisperx recording.wav
whisper-flow
```

The helper needs a running systemd user manager. It deliberately fails if
the scope cannot be created. Run it as your normal desktop user; root uses
an equivalent system slice. The aggregate budgets are **per user manager**
(and separately for root), not one budget shared across every login.
Commands invoked through a different Python environment or an absolute Nix
store path bypass the automatic wrapper: use `resource-run` around those.

| Limit | Default | Current Intel desktop (32GB) |
| --- | --- | --- |
| Memory reclaim starts | 50% of physical RAM | 10GiB |
| Hard RAM ceiling | 60% of physical RAM | 12GiB |
| Swap ceiling | 1GiB | 1GiB |
| CPU ceiling | Four logical CPUs | Four logical CPUs |

On Intel **dev and higher** stages, media jobs instead share a 3GiB high /
4GiB hard RAM limit and no swap, reserving room for local inference and builds.
See [Local models](LOCAL-LLM.md) for the aggregate compute slice budget.

All jobs in the slice share these ceilings. CPU and I/O weights also favour
other work during contention. CPU saturation causes throttling, not an OOM
kill. `MemoryOOMGroup=yes` and `OOMPolicy=kill` keep a failed job's children
from lingering. At the slice's hard memory ceiling the kernel can kill a
job; systemd-oomd can kill a job earlier after sustained memory pressure.
oomd monitors the workload slices only, not the entire desktop/user session.
An interrupted render or transcription can leave incomplete output.

Adjust `workloads.memoryHigh`, `memoryMax`, `memorySwapMax` and `cpuQuota`
in a host configuration. `400%` means four logical CPUs, not four times the
whole machine. Nix builders have separate 25%/30% RAM defaults and no swap;
the Intel desktop retains its existing 14GiB/16GiB build caps. These budgets
do not bound browsers, Docker containers, or programs launched
outside the helper. Allow room for those before raising the workload budget.
The local LLM has its own limits on Intel development stages and above.
Zram supplies compressed swap on early stages too; it consumes RAM and is
not additional physical memory.

## GPU and transcription

Standard cgroups do not provide a portable GPU compute or VRAM quota.
These limits cover CPU and host RAM; CUDA/ROCm allocation failures still
need smaller models, batches, reduced precision, or fewer concurrent GPU jobs.
No GPU watchdog or whole-session termination is configured.

The standard nixpkgs WhisperX package here is CPU-only. Its wrapper defaults
to `--device cpu --compute_type int8 --batch_size 4`. WhisperFlow uses the
standard faster-whisper CPU package and can fall back to CPU; choose CPU in
its settings if preserving a configuration from Ubuntu. CUDA acceleration
requires a separately configured CUDA-enabled Python package set; an Ubuntu
venv and its pip NVIDIA libraries are not reused. Models are downloaded on
first use; diarisation may also require Hugging Face credentials/access.

WhisperFlow includes evdev and Wayland clipboard/paste tools. Configured
desktop users belong to `input` so its global hotkeys can read input devices.
This also grants raw keyboard access to programs run by that user. Log in
again after a group change. Existing autostart files pointing to Ubuntu's
`/home/sam-dev/whisper-flow-linux/run.sh` must be recreated through the app
on NixOS (the desktop user is `sam-desktop`).

For local evaluation/builds, prepare a small snapshot including untracked source:

```sh
python3 scripts/prepare-nix-source.py /tmp/nix-config-source
nix eval --impure --raw 'path:/tmp/nix-config-source#nixosConfigurations.devtower-intel-dev.config.system.build.toplevel.drvPath'
```

Use a fresh empty destination after further edits. This excludes Rust targets,
including the previously tracked fuzz target. A raw `path:.` copy includes
ignored build outputs and can consume about 8GiB on every changed snapshot.
Git-backed `.#...` omits untracked new modules until added to Git but includes
already tracked build files. The helper changes neither the index nor source.
The Intel desktop's disk UUID
placeholders in `hosts/devtower-intel/disks.nix` must also be filled with the
actual installation partitions before installing.

## Verification after booting NixOS

```sh
stat -fc %T /sys/fs/cgroup        # cgroup2fs
cat /proc/pressure/memory
systemctl status systemd-oomd
resource-run sleep 60            # keep running while checking another terminal
systemctl --user show workload.slice -p MemoryHigh -p MemoryMax -p CPUQuotaPerSecUSec
systemd-cgls --user-unit workload.slice
oomctl
journalctl -u systemd-oomd
journalctl -k -g 'oom|Out of memory'
```

Sources: [systemd resource control](https://github.com/systemd/systemd/blob/main/man/systemd.resource-control.xml),
[Linux cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html),
[WhisperX](https://github.com/m-bain/whisperX), and
[WhisperFlow](https://github.com/konsti-web/whisper-flow-linux).
