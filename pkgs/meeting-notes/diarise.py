"""Label who speaks when on the remote track with Pyannote (via WhisperX, CPU).

Run by meeting_notes.py inside the WhisperX environment. The Hugging Face token
arrives in HF_TOKEN; the gated model's terms must have been accepted once.
Writes [{"start": s, "end": s, "speaker": "SPEAKER_00"}, ...].
"""

import argparse
import json
import os
import sys

import torch
from whisperx.diarize import DiarizationPipeline


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--audio", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--model", required=True)
    p.add_argument("--min-speakers", type=int, default=None)
    p.add_argument("--max-speakers", type=int, default=None)
    p.add_argument("--threads", type=int, default=4)
    args = p.parse_args()

    torch.set_num_threads(args.threads)
    try:
        pipeline = DiarizationPipeline(model_name=args.model, token=os.environ.get("HF_TOKEN"), device="cpu")
    except Exception as e:  # mostly a bad token or unaccepted model terms
        first = str(e).strip().splitlines()
        print(f"    could not load {args.model}: {type(e).__name__}: {first[-1] if first else ''}",
              file=sys.stderr)
        print(f"    check the token, and accept the terms at https://huggingface.co/{args.model}",
              file=sys.stderr)
        sys.exit(2)

    last = [-10.0]

    def progress(pct):
        if pct - last[0] >= 10 or pct >= 100:
            last[0] = pct
            print(f"    diarisation: {pct:.0f}%", file=sys.stderr, flush=True)

    df = pipeline(
        args.audio,
        min_speakers=args.min_speakers,
        max_speakers=args.max_speakers,
        progress_callback=progress,
    )
    turns = [
        {"start": float(row.start), "end": float(row.end), "speaker": str(row.speaker)}
        for row in df.itertuples()
    ]
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(turns, f)


if __name__ == "__main__":
    main()
