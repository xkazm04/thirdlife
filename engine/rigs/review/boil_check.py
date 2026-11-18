"""python engine/rigs/review/boil_check.py: boil.py's own check (bugfix-37 D12). Needs ffmpeg and numpy.
Makes two lossless 1280x720 clips (look.sh's default size), measures them through boil.py with its DEFAULT band (an odd
height of 147 rows at 720p) and prints one PASS/FAIL line per claim; exit 0 only when every claim held.
  still:   12 identical frames of horizontal stripes   -> mean 0, flips 0 % (was 222 and 100 % with the crop before grey)
  flicker: the stripes swap every frame                -> flips 100 % (the meter still sees a real change)"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

BOIL = Path(__file__).with_name("boil.py")


def clip(path: Path, lum: str) -> None:
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-f", "lavfi", "-i",
                    "nullsrc=size=1280x720,geq=lum='%s':cb=128:cr=128" % lum,
                    "-frames:v", "12", "-pix_fmt", "yuv420p", "-c:v", "ffv1", str(path)], check=True)


def measure(path: Path) -> tuple:
    out = subprocess.run([sys.executable, str(BOIL), str(path), "0", "11"], capture_output=True, text=True).stdout
    m = re.search(r"frames=(\d+) band=\S+ mean=([0-9.]+) flips_pct=([0-9.]+)", out)
    return (int(m.group(1)), float(m.group(2)), float(m.group(3))) if m else (0, -1.0, -1.0)


fails = 0
with tempfile.TemporaryDirectory(prefix="boil_check_") as tmp:
    still, flicker = Path(tmp) / "still.mkv", Path(tmp) / "flicker.mkv"
    clip(still, "if(mod(Y,2),220,30)")
    clip(flicker, "if(mod(Y+N,2),220,30)")
    for name, path, ok in (("boil.still_720p", still, lambda n, m, f: n == 12 and m == 0.0 and f == 0.0),
                           ("boil.flicker_720p", flicker, lambda n, m, f: n == 12 and f == 100.0)):
        n, m, f = measure(path)
        good = ok(n, m, f)
        fails += 0 if good else 1
        print("%s %s  (frames %d, mean %.3f, flips %.3f %%)" % ("PASS" if good else "FAIL", name, n, m, f))
print("boil_check: %d of 2 passed" % (2 - fails))
sys.exit(0 if fails == 0 else 1)
