"""boil.py <clip> <first frame> <last frame> [row0 row1]
Under a very slow pan (a quarter of a pixel a frame) a stable picture changes little from one frame to the next; a contour that
breaks up or boils changes a lot. Prints the mean |f(t+1) - f(t)| (grey levels) inside the band and the share of pixels that
change by more than 24 levels in one frame (a dash that appears or goes)."""
import subprocess
import sys
import numpy as np

clip, a, b = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
r0, r1 = (int(sys.argv[4]), int(sys.argv[5])) if len(sys.argv) > 5 else (200, 420)
probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', clip], capture_output=True, text=True).stdout.strip().split(',')
w, h = int(probe[0]), int(probe[1])
r0 = r0 * h // 1080
r1 = r1 * h // 1080
vf = "select=between(n\\,%d\\,%d),crop=%d:%d:0:%d,format=gray" % (a, b, w, r1 - r0, r0)
raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', clip, '-vf', vf, '-vsync', '0', '-f', 'rawvideo', '-'], capture_output=True).stdout
n = len(raw) // (w * (r1 - r0))
f = np.frombuffer(raw[:n * w * (r1 - r0)], dtype=np.uint8).reshape(n, r1 - r0, w).astype(np.int16)
d1 = np.abs(f[1:] - f[:-1])
print("boil frames=%d band=%d..%d mean=%.3f flips_pct=%.3f (mean change per frame, grey levels; share of pixels changing by more than 24)" % (n, r0, r1, float(d1.mean()), 100.0 * float((d1 > 24).mean())))
