# Candidates for the i9-9900K / 32GiB / RTX 2080 Ti (11GiB).
# GGUF filenames and sizes checked against upstream on 2026-10-05.
# Native context is preserved; successful full-context inference still needs
# testing on the actual GPU. Larger requested models are assessed in docs.
{
  "qwen3.8-27b" = {
    name = "Qwen3.8 27B (UD-IQ4_XS)";
    repo = "unsloth/Qwen3.8-27B-GGUF";
    file = "Qwen3.8-27B-UD-IQ4_XS.gguf";
    contextSize = 262144;
  };
  "qwen3.6-27b" = {
    name = "Qwen3.6 27B (Q4_K_M)";
    repo = "unsloth/Qwen3.6-27B-GGUF";
    file = "Qwen3.6-27B-Q4_K_M.gguf";
    contextSize = 262144;
  };
  "qwen3.6-35b-a3b" = {
    name = "Qwen3.6 35B-A3B (UD-IQ4_XS)";
    repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
    file = "Qwen3.6-35B-A3B-UD-IQ4_XS.gguf";
    contextSize = 262144;
    aliases = [ "unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS" ];
    # Leave GPU layers and tensor placement unset: either override disables
    # llama.cpp's --fit, which must account for the desktop's VRAM usage.
  };
  "glm-4.7-flash" = {
    name = "GLM 4.7 Flash (Q4_K_M, full context experimental)";
    repo = "unsloth/GLM-4.7-Flash-GGUF";
    file = "GLM-4.7-Flash-Q4_K_M.gguf";
    contextSize = 202752;
    # MLA cache support differs from ordinary GQA; keep the native cache type.
    cacheType = "f16";
  };
  "gpt-oss-20b" = {
    name = "GPT OSS 20B (Q4_K_M / MXFP4 experts)";
    repo = "unsloth/gpt-oss-20b-GGUF";
    file = "gpt-oss-20b-Q4_K_M.gguf";
    contextSize = 131072;
  };
  "devstral-small-24b" = {
    name = "Devstral Small 2507 24B (Q4_K_M)";
    repo = "unsloth/Devstral-Small-2507-GGUF";
    file = "Devstral-Small-2507-Q4_K_M.gguf";
    contextSize = 131072;
  };
  "gemma4-26b-a4b" = {
    name = "Gemma 4 26B-A4B (UD-IQ4_XS)";
    repo = "unsloth/gemma-4-26B-A4B-it-GGUF";
    file = "gemma-4-26B-A4B-it-UD-IQ4_XS.gguf";
    contextSize = 262144;
  };
}
