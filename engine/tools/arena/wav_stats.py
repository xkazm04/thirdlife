#!/usr/bin/env python3
"""Peak, RMS, first and last sound of wav files (16-bit PCM). usage: python wav_stats.py <file or folder> ..."""
import glob
import os
import sys
import wave

import numpy as np


def read(path):
    w = wave.open(path)
    n = w.getnframes()
    a = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768.0
    return a.reshape(-1, w.getnchannels()), w.getframerate()


if __name__ == "__main__":
    files = []
    for a in sys.argv[1:]:
        files += sorted(glob.glob(os.path.join(a, "*.wav"))) if os.path.isdir(a) else [a]
    for f in files:
        a, sr = read(f)
        env = np.abs(a).max(axis=1)
        nz = np.nonzero(env > 1e-3)[0]
        print("%-34s %d Hz %d ch %6.2f s peak %.3f rms %.4f sound %s .. %s" % (
            os.path.basename(f), sr, a.shape[1], len(a) / sr, env.max() if len(env) else 0.0, float(np.sqrt((a ** 2).mean())) if len(a) else 0.0,
            ("%.3f" % (nz[0] / sr)) if len(nz) else "-", ("%.3f" % (nz[-1] / sr)) if len(nz) else "-"))
