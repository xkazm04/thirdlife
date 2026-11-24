# K6 round 3: the gain and the time of each commentator line inside a recording (thirdjam's own, render_match.py with
# TL_MATCH_VOICE=1, or ours): the line's wave decoded at the recording's rate, found by cross-correlation within +-0.6 s of
# its logged frame, its least-squares gain and the residual's share. The source of voice.json's out_gain (0.345).
# usage: python vo_gain.py <recording.wav> <log with JAMVO id=.. frame=..> <vo dir (ogg)> <seconds offset of frame 0>
import re, subprocess, sys, wave
import numpy as np
rec, log, vodir, off = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
w = wave.open(rec); sr = w.getframerate()
a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float).reshape(-1, w.getnchannels()) / 32768
m = a.mean(axis=1)
lines = []
for ln in open(log, encoding="utf-8", errors="replace"):
    x = re.search(r"JAMVO id=(\S+) event=\w+ frame=(\d+)", ln)
    if x: lines.append((x.group(1), int(x.group(2))))
out = []
for lid, f in lines:
    t = off + f / 60.0
    if t > len(m) / sr - 1: break
    p = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", "%s/VO_Commentator_%s.ogg" % (vodir, lid.replace(".", "_")), "-ar", str(sr), "-ac", "1", "-f", "s16le", "-"], capture_output=True)
    v = np.frombuffer(p.stdout, dtype=np.int16).astype(float) / 32768
    i0 = max(0, int((t - 0.6) * sr)); i1 = min(len(m), int((t + 0.6) * sr) + len(v))
    seg = m[i0:i1]
    n = 2 ** int(np.ceil(np.log2(len(seg) + len(v))))
    c = np.fft.irfft(np.fft.rfft(seg, n) * np.conj(np.fft.rfft(v, n)))[:len(seg) - len(v)]
    k = int(np.argmax(c))
    s = seg[k:k + len(v)]; g = float(np.dot(s, v) / np.dot(v, v))
    r = np.sqrt(((s - g * v) ** 2).mean()) / max(np.sqrt((s ** 2).mean()), 1e-9)
    out.append((lid, f, (i0 + k) / sr, g, r))
    print("%-28s frame %5d found %.3f s (logged %.3f) gain %.3f (%.2f dB) residual %.2f" % (lid, f, (i0 + k) / sr, t, g, 20 * np.log10(max(abs(g), 1e-6)), r))
good = [o for o in out if o[4] < 0.8]
if good: print("median gain of %d clear lines: %.3f (%.2f dB)" % (len(good), float(np.median([o[3] for o in good])), 20 * np.log10(float(np.median([o[3] for o in good])))))
