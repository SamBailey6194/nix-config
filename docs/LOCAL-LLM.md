# Local models on the Intel desktop

Audited on 2026-10-05: Intel i9-9900K (8 cores / 16 threads), about 31GiB
usable RAM, RTX 2080 Ti (11GiB VRAM). Ubuntu's desktop was using about 4GiB
VRAM during the audit. Active MoE parameter counts describe computation;
all expert weights still need storage and memory. Swap is not a substitute
for enough RAM to run these models responsively.

The Intel **dev, productivity, creative and full** stages build llama.cpp
with CUDA capability 7.5 and LP64 OpenBLAS. CUDA and OpenBLAS were both
detected in the built binary. Ubuntu testing needs its NVIDIA driver exposed
to Nix's loader; NixOS supplies `/run/opengl-driver/lib` through its driver
configuration. Do not add Ubuntu library directories globally on NixOS.

## Requested models and full native contexts

These are estimates for one sequence, not performance guarantees. GGUF sizes
come from the linked repositories; cache estimates depend on the architecture,
cache precision and llama.cpp implementation. Compute buffers, the desktop,
OS and other applications need additional memory. Full context means the
native limit, including the output budget, rather than a YaRN extension.

| Requested model | Native context | Selected weight size | Assessment on this PC |
| --- | ---: | ---: | --- |
| [Qwen3.8 27B](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF) | 262,144 | 13.27GiB IQ4 | Candidate; roughly 8.5GiB Q8 cache, partial CUDA offload needed |
| [Qwen3.6 27B](https://huggingface.co/unsloth/Qwen3.6-27B-GGUF) | 262,144 | 15.66GiB Q4 | Marginal; roughly 8.5GiB Q8 cache plus buffers |
| [Qwen3.6 35B-A3B](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF) | 262,144 | 16.51GiB IQ4 | Default candidate; roughly 2.66GiB Q8 cache |
| [Qwen3-Coder-Next](https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF) | 262,144 | 45.20GiB Q4; 35.79GiB IQ4 | Four-bit full-context use exceeds a safe budget; ~24.92GiB Q2 is a quality/latency compromise requiring separate testing |
| [GLM 4.7 Flash](https://huggingface.co/unsloth/GLM-4.7-Flash-GGUF) | 202,752 | 17.06GiB Q4 | Experimental/marginal; compressed MLA F16 cache can approach 10.22GiB before buffers |
| [GLM 5.2](https://huggingface.co/zai-org/GLM-5.2), [5.3](https://huggingface.co/zai-org/GLM-5.3) | 1,048,576 | Hundreds of GB | Requires remote serving or substantially larger hardware; 753B weights alone are ~188GB even at an idealised two bits |
| [GLM 5.3 Flash](https://huggingface.co/zai-org/GLM-5.3-Flash) | 1,048,576 | Tens/hundreds of GB | 320B total, 18B active still needs ~80GB raw two-bit weights, before cache; remote/larger hardware |
| [GPT OSS 120B](https://huggingface.co/unsloth/gpt-oss-120b-GGUF) | 131,072 | 58.46GiB Q4/MXFP4 | Weight size alone exceeds this machine; remote/larger hardware |
| [GPT OSS 20B](https://huggingface.co/unsloth/gpt-oss-20b-GGUF) | 131,072 | 10.83GiB Q4/MXFP4 | Strong candidate; hybrid sliding/full attention keeps cache relatively small |
| [Devstral Small 2507 24B](https://huggingface.co/unsloth/Devstral-Small-2507-GGUF) | 131,072 | 13.35GiB Q4 | Marginal and likely slow at full context; roughly 10.63GiB Q8 cache |
| [Gemma 4 26B-A4B](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF) | 262,144 | 12.66GiB IQ4 | Candidate; hybrid attention, global KV heads and K=V sharing affect cache; verify measured allocation |

The seven candidates are registered in `modules/software/local-llm-models.nix`.
The larger models are assessed here rather than offered as local working models.
Only the already cached Qwen model has been exercised locally; registration
does not mean every architecture, tool template or full-length prompt is tested.
With automatic fitting and desktop VRAM use present, it loaded with CUDA,
reported `n_ctx=262144` and answered a 19-token test prompt under the 20GiB
host-memory cap. Fixed GPU-layer and expert-placement overrides had previously
disabled fitting and caused VRAM allocation failures, so they are omitted.

## Serving and resource budgets

`llama-swap` listens at `127.0.0.1:8080`, loads one model on demand and unloads
it after five idle minutes. Weights download on first selection, outside the
Nix store, into the service cache under `/var/cache/llama-swap`. Each model has
one slot and its full native context; `--fit-ctx` equals `--ctx-size` so automatic
fitting cannot silently reduce context. GPU layers and tensor placement stay
unset so the fitter can reserve 2GiB VRAM for the desktop. KV caches use host
RAM, Q8 except for GLM's F16 cache. A failure to fit or allocate fails the job.

The server starts reclaiming at 18GiB and is capped at 20GiB RAM with no swap.
It shares `compute.slice` (20GiB high, 22GiB hard) with Nix builds (14/16GiB).
These bounds prevent the two full allocations being additive. The service does
not restart automatically after a failure. Other media jobs use a separate
per-user 3/4GiB budget on these Intel stages; desktop/minimal stages retain
10/12GiB. CPU/I/O weights favour interactive work. Standard cgroups cannot
cap VRAM, so desktop GPU consumption can still cause allocation failures.

Loading a full context is not the same as filling it. Long prefill and decoding
on an eight-core CPU can be impractical even when memory allocation succeeds.
Keep large batches and other model servers stopped while testing.

```sh
llama-server --list-devices
systemctl status llama-swap
journalctl -u llama-swap -f
curl http://127.0.0.1:8080/v1/models
systemctl show llama-swap -p MemoryHigh -p MemoryMax -p Slice
```

After loading a model, inspect its llama-server `/props` endpoint and logs for
the actual context and GPU allocation. Confirm tool calls with a small scratch
repository before trusting a model with substantial edits. API-compatible
transport does not guarantee a model follows tool instructions correctly.

## Just commands: select a model and tune flags

From this repository on the installed NixOS development stage or above:

```sh
just llama-models
just llama-plan qwen3.6-35b-a3b --threads 6 --batch-size 128
just llama-start qwen3.6-35b-a3b --threads 6 --batch-size 128
just llama-start gpt-oss-20b --threads 8 --ubatch-size 64
just llama-status
just llama-logs
just llama-stop
just llama-auto
just llama-flags
```

`llama-plan` prints the exact command without starting or downloading anything.
`llama-start` asks for sudo as needed, installs a runtime-only service override,
restarts llama-swap and loads the selected model through its upstream health
endpoint. The previous model and active requests are stopped. This mode exposes
only the selected model through the unchanged loopback endpoint
`http://127.0.0.1:8080/v1`; select `llama-cpp/<model-id>` in OpenCode too.
A first weight download/full-context allocation can take a long time.

Extra flags are passed literally, including quoted values, and appended to that
model's default command. Thread counts, batch sizes, GPU layers and cache types
can be tuned. Model identity, host/port, one slot and native context are managed
so those flags cannot silently break the OpenCode route or lower its advertised
context. Credentials must use runtime environment/config files rather than flags.
Use `just llama-flags` for the pinned build's supported tuning options.
Explicit GPU/tensor placement can disable automatic fitting and cause a model
load to fail; the existing cgroup limits still apply. No portable VRAM cap exists.

This keeps the same CUDA/OpenBLAS package, service cache, DynamicUser sandbox
and `compute.slice`/18GiB high/20GiB hard memory policy. It does not start an
uncontained second server. Overrides last until `llama-stop`, `llama-auto`, or
reboot. Run `llama-auto` after a NixOS rebuild to clear any older runtime override
and use the newly generated catalogue again. It restores on-demand switching
across all candidates; the five-minute idle unloading policy remains active.
No model has been downloaded or started by testing these recipes.

## OpenCode and Neovim

OpenCode uses the same model IDs and context limits as llama-swap, defaults to
`llama-cpp/qwen3.6-35b-a3b`, and allows file edits by default. Existing explicit
permission rules are retained. Missing candidate models are added to an existing
provider; the old generated Qwen 32K entry is upgraded to the native context.
Other customised model entries and an existing default model are retained.

Neovim toggles terminals in the current project: `<leader>cc` Claude Code,
`<leader>co` Codex, `<leader>cp` OpenCode, `<leader>cg` Antigravity. Buffer
reload checks pick up agent edits while preserving unsaved editor buffers.
All four clients use the [shared MCP inventory](SHARED-MCP.md).

The implementation follows the pinned [llama.cpp server flags](https://github.com/ggml-org/llama.cpp/blob/v0.4.1/tools/server/README.md)
and [llama-swap routing](https://github.com/mostlygeek/llama-swap).
