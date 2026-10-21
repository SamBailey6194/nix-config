"""Transcribe meeting tracks with faster-whisper (CUDA CTranslate2, CPU fallback).

Run by meeting_notes.py inside the CUDA environment. Writes one JSON file:
{"device": ..., "tracks": {key: {"duration": s, "segments": [...]}}}
"""

import argparse
import json
import sys

import ctranslate2
from faster_whisper import WhisperModel


def log(msg):
    print(f"    {msg}", file=sys.stderr, flush=True)


def load(model_name, device, threads):
    if device == "cuda":
        return WhisperModel(model_name, device="cuda", compute_type="float16")
    return WhisperModel(model_name, device="cpu", compute_type="int8", cpu_threads=threads)


def transcribe_track(model, key, path, args):
    segments, info = model.transcribe(
        path,
        language=args.language,
        beam_size=5,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
        word_timestamps=True,
        # Stops one misheard segment from seeding the next: the usual cause of
        # repeated-phrase loops in long recordings.
        condition_on_previous_text=False,
        initial_prompt=args.prompt or None,
    )
    out = []
    last_report = 0.0
    for seg in segments:
        out.append({
            "start": seg.start,
            "end": seg.end,
            "text": seg.text.strip(),
            "words": [
                {"start": w.start, "end": w.end, "word": w.word, "probability": w.probability}
                for w in (seg.words or [])
            ],
        })
        if info.duration and seg.end - last_report >= 120:
            last_report = seg.end
            log(f"{key}: {seg.end / info.duration:.0%}")
    return {"duration": info.duration, "segments": out}


def run(device, args, tracks):
    model = load(args.model, device, args.threads)
    result = {}
    for key, path in tracks:
        log(f"{key}: transcribing on {device}")
        result[key] = transcribe_track(model, key, path, args)
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--language", default=None)
    p.add_argument("--device", choices=["auto", "cuda", "cpu"], default="auto")
    p.add_argument("--threads", type=int, default=4)
    p.add_argument("--prompt", default="")
    p.add_argument("--out", required=True)
    p.add_argument("tracks", nargs="+", help="key=path")
    args = p.parse_args()
    tracks = [tuple(t.split("=", 1)) for t in args.tracks]

    device = args.device
    if device == "auto":
        device = "cuda" if ctranslate2.get_cuda_device_count() > 0 else "cpu"
        if device == "cpu":
            log("no CUDA device visible to CTranslate2: using the CPU (slow)")

    try:
        result = run(device, args, tracks)
    except RuntimeError as e:
        # Usually CUDA out of memory because a llama.cpp model holds the VRAM
        if device != "cuda" or args.device == "cuda":
            raise
        log(f"GPU transcription failed ({e}); retrying on the CPU (slow)")
        log("free VRAM first next time, e.g. stop or unload the llama-swap model")
        device = "cpu"
        result = run(device, args, tracks)

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump({"device": device, "model": args.model, "tracks": result}, f)


if __name__ == "__main__":
    main()
