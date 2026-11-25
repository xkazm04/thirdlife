#!/usr/bin/env python3
"""Loudness per second of two recordings of a match's sound, side by side: thirdjam's own (render_match.py) and ours
(the pack through Godot's movie writer). No ear is in this: it is level over time, and where the two differ.
usage: python loudness.py <thirdjam.wav> <ours.wav> <out prefix> [seconds]

Per second: RMS in dBFS of all channels, and the peak. Summary: the median second (the bed: music, crowd, skates), the
loudest tenth (events), the quietest tenth, the whole file's RMS, and the level in three bands (under 300 Hz, 300 Hz to
3 kHz, over 3 kHz) so that a missing layer shows as a band. Writes <out prefix>.csv and <out prefix>.png."""
import sys
import wave

import numpy as np


def read(path):
    w = wave.open(path)
    sw = w.getsampwidth()
    raw = w.readframes(w.getnframes())
    if sw == 2:
        a = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    elif sw == 4:
        a = np.frombuffer(raw, dtype=np.int32).astype(np.float64) / 2147483648.0
    else:
        raise SystemExit("unsupported sample width %d in %s" % (sw, path))
    return a.reshape(-1, w.getnchannels()), w.getframerate()


def db(x):
    return 20.0 * np.log10(np.maximum(x, 1e-9))


def per_second(a, sr, seconds):
    rows = []
    for s in range(seconds):
        seg = a[s * sr:(s + 1) * sr]
        if len(seg) == 0:
            break
        rows.append((float(db(np.sqrt((seg ** 2).mean()))), float(db(np.abs(seg).max()))))
    return rows


def bands(a, sr):
    mono = a.mean(axis=1)
    n = 1 << 15
    hop = n // 2
    win = np.hanning(n)
    acc = np.zeros(n // 2 + 1)
    k = 0
    for i in range(0, len(mono) - n, hop):
        acc += np.abs(np.fft.rfft(mono[i:i + n] * win)) ** 2
        k += 1
    f = np.fft.rfftfreq(n, 1.0 / sr)
    acc /= max(k, 1) * (win ** 2).sum() * n / 2.0
    out = []
    for lo, hi in ((0, 300), (300, 3000), (3000, sr / 2)):
        out.append(float(10.0 * np.log10(max(acc[(f >= lo) & (f < hi)].sum(), 1e-18))))
    return out


def summary(rows, a, sr):
    r = np.array([x[0] for x in rows])
    srt = np.sort(r)
    n = max(1, len(srt) // 10)
    return {"seconds": len(rows), "median_db": round(float(np.median(r)), 1), "loud_tenth_db": round(float(srt[-n:].mean()), 1),
            "quiet_tenth_db": round(float(srt[:n].mean()), 1), "whole_db": round(float(db(np.sqrt((a ** 2).mean()))), 1),
            "peak_db": round(float(db(np.abs(a).max())), 1), "bands_db": [round(v, 1) for v in bands(a, sr)]}


if __name__ == "__main__":
    tj, sr1 = read(sys.argv[1])
    ours, sr2 = read(sys.argv[2])
    seconds = int(sys.argv[4]) if len(sys.argv) > 4 else int(min(len(tj) / sr1, len(ours) / sr2))
    tj, ours = tj[:seconds * sr1], ours[:seconds * sr2]
    ra, rb = per_second(tj, sr1, seconds), per_second(ours, sr2, seconds)
    with open(sys.argv[3] + ".csv", "w", encoding="utf-8") as f:
        f.write("second,thirdjam_rms_db,thirdjam_peak_db,ours_rms_db,ours_peak_db\n")
        for i in range(min(len(ra), len(rb))):
            f.write("%d,%.1f,%.1f,%.1f,%.1f\n" % (i, ra[i][0], ra[i][1], rb[i][0], rb[i][1]))
    sa, sb = summary(ra, tj, sr1), summary(rb, ours, sr2)
    print("thirdjam", sa)
    print("ours    ", sb)
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(12, 4.2), dpi=100)
        ax.step(range(len(ra)), [x[0] for x in ra], where="post", color="#b3541e", label="thirdjam (median %.1f dB)" % sa["median_db"])
        ax.step(range(len(rb)), [x[0] for x in rb], where="post", color="#1d4ed8", label="ours (median %.1f dB)" % sb["median_db"])
        ax.set_xlabel("second of the recording (two different hands: the shapes are not expected to coincide)")
        ax.set_ylabel("RMS, dBFS")
        ax.set_ylim(-60, 0)
        ax.grid(True, alpha=0.3)
        ax.legend(loc="lower right")
        ax.set_title("Loudness per second: thirdjam's own recording against ours (no ear has heard either)")
        fig.tight_layout()
        fig.savefig(sys.argv[3] + ".png")
        print(sys.argv[3] + ".png")
    except Exception as e:  # noqa: BLE001
        print("no chart:", e)
