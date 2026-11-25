"""A side-by-side film of one clip: thirdjam's own render (reference_capture.py) left, ours (the gym's --mode=shots) right.
  python pair_film.py <ref dir> <ours dir> <clip> <cam> <out.mp4> [frames dir]
The clip's keys in order, as a loop: five times at full speed (60 keys a second), then twice at a quarter speed.
Needs ffmpeg on the PATH. Prints `tl.skater.film/1 {...}`; exit 0 only if every key of the reference list was paired."""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

ref_dir, our_dir, clip, cam, out = sys.argv[1:6]
tmp = sys.argv[6] if len(sys.argv) > 6 else os.path.join(os.path.dirname(out), "_film_frames")
PX = 540
ref = json.load(open(os.path.join(ref_dir, "reference.json"), encoding="utf-8"))
keys = sorted(r["key"] for r in ref["shots"] if r["clip"] == clip and r["cam"] == cam and not r.get("stale", True))
shutil.rmtree(tmp, ignore_errors=True)
os.makedirs(tmp, exist_ok=True)
frames = []
for k in keys:
    name = "%s_k%03d_%s.png" % (clip, k, cam)
    a, b = os.path.join(ref_dir, name), os.path.join(our_dir, name)
    if not (os.path.isfile(a) and os.path.isfile(b)):
        continue
    f = Image.new("RGB", (2 * PX, PX), (0, 0, 0))
    f.paste(Image.open(a).convert("RGB").resize((PX, PX), Image.LANCZOS), (0, 0))
    f.paste(Image.open(b).convert("RGB").resize((PX, PX), Image.LANCZOS), (PX, 0))
    d = ImageDraw.Draw(f)
    for x, who in ((0, "thirdjam (Unreal)"), (PX, "ours (Godot)")):
        text = "%s  %s key %d" % (who, clip, k)
        d.rectangle([x + 4, 4, x + 12 + 7 * len(text), 22], fill=(0, 0, 0))
        d.text((x + 8, 7), text, fill=(255, 255, 255))
    frames.append(f)
n = 0
for speed, loops in ((1, 5), (4, 2)):
    for _ in range(loops):
        for f in frames:
            for _ in range(speed):
                f.save(os.path.join(tmp, "f%05d.png" % n))
                n += 1
ok = len(frames) == len(keys) and len(frames) > 0
code = 1
if ok:
    code = subprocess.call(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i", os.path.join(tmp, "f%05d.png"),
                            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", out])
shutil.rmtree(tmp, ignore_errors=True)
rep = {"schema": "tl.skater.film/1", "clip": clip, "cam": cam, "keys": len(keys), "paired": len(frames), "frames": n,
       "seconds": round(n / 60.0, 2), "out": out, "ok": ok and code == 0}
print("%s skater film" % ("PASS" if rep["ok"] else "FAIL"))
print("tl.skater.film/1 " + json.dumps(rep))
sys.exit(0 if rep["ok"] else 1)
