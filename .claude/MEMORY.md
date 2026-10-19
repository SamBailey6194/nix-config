# Project memory

Notes that are not derivable from the code or git history. One entry per fact; newest last.

## Deferred: VHS social media and Claude Code prompting content (2026-09-27)

The plan is to use VHS tapes for social media content: clips of learning Neovim and the terminal with a face cam or
voiceover, Claude Code "how to prompt properly" demos, and promotional content for Syntek. On 2026-09-27 the user
said not to build any of it yet: "we will create those another time".

- **Why:** that session was about recording the Neovim course tapes and changing the Neovim layout. The content work
  was put off, not dropped.
- **How to apply:** do not start social media or demo tapes unprompted. When it resumes, the groundwork discussed was:
  VHS records terminal apps only (Zed needs OBS or wf-recorder); OBS, DaVinci Resolve and the Go XLR are on devtower;
  aspect ratio per platform; MP4 output; a Syntek-branded `Set Theme` and `MarginFill`; live Claude Code tapes follow
  the course's tape 13/27 privacy rules (`IS_DEMO`, `CLAUDE_CODE_HIDE_CWD`, a throwaway project); never fake Claude output.

## Deferred: Local model performance tuning with all MCP servers (2026-10-19)

- **User intent:** resume this coming weekend. Tune local inference on devtower-intel with all configured MCP servers
  available, including graphify alongside code-review-graph. Do not treat disabling MCP servers as the final solution.
  This is runtime/backend tuning, not training or fine-tuning model weights. No automation or reminder was scheduled.
- **Sudo:** the user explicitly said they should always run sudo commands themselves. Give them the exact command;
  do not execute sudo, including `sudo -n`, on their behalf.
- **Stopped state:** the user successfully ran `just llama-stop` after testing. It stopped the service and cleared
  runtime overrides; the Qwen3.8 27B weights and multimodal projector remain cached under `/var/cache/llama-swap`.
  Recheck service state when resuming; this was a session observation, not a permanent service disablement.
- **Tested startup:** Qwen3.8 27B UD-IQ4_XS took about 21m25s on first download/start, then about 21s when cached.
  It loaded with one inference slot and 262,144 context tokens. Loading succeeded, but useful coding/tool-call
  performance was not demonstrated before the user stopped it.
- **Observed speed:** prompt processing was approximately 1.8–2.0 tokens/s. The active request was only about
  600 tokens; progress `0.42` means 42%, not 0.42%. Do not infer a 60K-token prompt from that log line.
  The last inspected generation counter was zero. Investigate raw inference before blaming MCP prompt size.
- **Observed resource use:** roughly 966% CPU, 13% GPU utilisation in one snapshot, about 7.3 GiB VRAM for llama-server,
  and about 18 GiB service memory. The service had 1,178 memory-high events and no OOM kills. A later 10-second
  sample had 268 major faults and 49,542 file-page refaults, but no new memory-high events or measurable current
  memory-pressure stall average. This suggests CPU/memory bottlenecks; it does not establish continuous throttling.
- **Retry fix completed:** commit `3540cc6` is pushed to main. Router admission increased from one to ten outstanding
  requests, while inference remains `--parallel 1`. The control script migrates an old installed limit of one on
  model selection. Eight control-script tests and Nix parsing passed; the user reported retries stopped after
  applying the helper. More than ten pending requests can still get 429, and queueing does not accelerate inference.
- **Routing issue:** `just llama-start <model>` exposes only that model. OpenCode initially selected the default
  Qwen3.6 35B-A3B while only Qwen3.8 was served, causing "no router for requested model". Match session/provider
  selection to the running model, including any background request model choices.
- **Next experiments:** compare CUDA-only (`blas = false`) against the current CUDA/OpenBLAS build, holding model,
  prompt and context fixed. Existing comments describe a BLAS/partial-GPU-offload slowdown measured on a smaller
  test model; gains on Qwen3.8 are unmeasured. Then test placement, batch/microbatch sizes and thread counts one
  variable at a time, without running a second uncontained model server.
- **Context tradeoff:** full native context is currently intentional and protected by the helper. A 32K/64K
  performance profile is a proposed experiment only, not an approved replacement. Qwen3.8's estimated full-context
  Q8 host KV cache is about 8.5 GiB. Preserve accurate advertised context and explain any reduction to the user.
- **Other models:** benchmark the registered candidates, especially Qwen3.6 35B-A3B and GPT OSS 20B, rather than
  assuming a dense 27B model is best on the i9-9900K / 32 GiB / RTX 2080 Ti 11 GiB. Additional downloads may be needed.
- **MCP baseline:** OpenCode had eight managed servers configured without disable flags: context7, elevenlabs,
  mcp-mermaid, perplexity-computer, playwright, scrapling, code-review-graph and graphify. Both graph servers are
  already registered; inspect their actual connection/tool-call behaviour before adding duplicate registrations.
  Tool discovery/filtering can be investigated, but the final workflow must retain all servers.
- **Success criteria:** record time to first token, prompt/generation throughput, CPU/GPU and RAM/VRAM use,
  memory faults/pressure, and reliable tool calls with all MCP servers available. Save measured per-model Nix
  settings while preserving the current host memory limits and desktop responsiveness. No performance tuning
  changes were made during this session.
- **Resume files:** `docs/LOCAL-LLM.md`, `modules/software/local-llm.nix`, `hosts/devtower-intel/local-llm.nix`,
  `modules/software/local-llm-models.nix`, `scripts/local-llm-control.py`, `scripts/tests/test_local_llm_control.py`,
  `home/modules/opencode.nix`, `home/modules/opencode-merge.jq`, and `home/modules/mcp-servers.nix`.

## Deferred: Firebase schema confirmation (2026-10-19)

- Separate handoff: `docs/FIREBASE-SCHEMA-HANDOFF.md`. The user wants sampled schema only, without document values
  or document IDs. Reads were blocked by project quota; requested Owner access was not confirmed granted.
- The schema checker is preserved at `scripts/firestore-schema-export.py`; do not depend on the old `/tmp` copy.
