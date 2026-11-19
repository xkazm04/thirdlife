"""Grey-level change on the fixed rear silhouette, after the moving rig freezes its pose."""
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

out = Path(__file__).resolve().parent / sys.argv[1]
signal = np.array(Image.open(out / "frozen-signal.png"))[:, :, 0] > 127
hidden = np.array(Image.open(out / "frozen-hidden.png"))[:, :, 0] > 127
mask = signal & ~hidden
ys, xs = np.where(mask)
assert len(ys) > 1000
x, y = xs.min(), ys.min()
w, h = xs.max() - x + 1, ys.max() - y + 1
pad = np.pad(mask, 1)
inside = mask & pad[1:-1, :-2] & pad[1:-1, 2:] & pad[:-2, 1:-1] & pad[2:, 1:-1]
vf = f"select=between(n\\,95\\,145),format=gray,crop={w}:{h}:{x}:{y}"
raw = subprocess.check_output(["ffmpeg", "-loglevel", "error", "-i", str(out / "runner.mp4"),
                               "-vf", vf, "-fps_mode", "passthrough", "-f", "rawvideo", "-"])
frames = np.frombuffer(raw, np.uint8).reshape(51, h, w)
diff = np.abs(np.diff(frames.astype(np.int16), axis=0))
for label, region in [("outline", mask & ~inside), ("interior", inside)]:
    values = diff[:, region[y:y+h, x:x+w]]
    print(f"{label} pixels={region.sum()} pairs={len(diff)} mean={values.mean():.3f} flips_pct={100*(values>24).mean():.3f}")
