"""A side-by-side film of one clip for the skater's surface: thirdjam's own render (look_reference.py, files
<clip>_k<key>_<cam>_t<team>.png) left, ours (look_gym.tscn --mode=shots, <ours>/t<team>/<clip>_k<key>_<cam>.png) right.
  python look_film.py <ref dir> <ours dir> <team> <clip> <cam> <out.mp4> <frames dir> [--crop=x0,y0,x1,y1] [--px=540]
The clip's keys in order as a loop: four times at full speed (60 keys a second), then twice at a quarter speed.
Needs ffmpeg on the PATH. Prints `tl.skater.look_film/1 {...}`; exit 0 only if every key of the reference was paired."""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--"))
ref_dir, our_dir, team, clip, cam, out, tmp = args[:7]
PX = int(opts.get("px", "540"))
crop = [float(v) for v in opts["crop"].split(",")] if "crop" in opts else [0.0, 0.0, 1.0, 1.0]
ref = json.load(open(os.path.join(ref_dir, "reference.json"), encoding="utf-8"))
keys = sorted(r["key"] for r in ref["shots"] if r["clip"] == clip and r["cam"] == cam and int(r.get("team", 0)) == int(team) and not r.get("stale", True))
shutil.rmtree(tmp, ignore_errors=True)
os.makedirs(tmp, exist_ok=True)


def tile(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    return im.resize((PX, PX), Image.LANCZOS)


frames = []
for k in keys:
    a = os.path.join(ref_dir, "%s_k%03d_%s_t%s.png" % (clip, k, cam, team))
    b = os.path.join(our_dir, "t%s" % team, "%s_k%03d_%s.png" % (clip, k, cam))
    if not (os.path.isfile(a) and os.path.isfile(b)):
        continue
    f = Image.new("RGB", (2 * PX, PX), (0, 0, 0))
    f.paste(tile(a), (0, 0))
    f.paste(tile(b), (PX, 0))
    d = ImageDraw.Draw(f)
    for x, who in ((0, "thirdjam (Unreal)"), (PX, "ours (Godot)")):
        d.rectangle((x, 0, x + 170, 16), fill=(0, 0, 0))
        d.text((x + 4, 2), "%s  key %d" % (who, k), fill=(255, 255, 255))
    frames.append(f)
n = 0
loop = frames[:-1] if len(frames) > 1 else frames          # the last key is the first again
for _rep in range(4):
    for f in loop:
        f.save(os.path.join(tmp, "f%05d.png" % n))
        n += 1
for _rep in range(2):
    for f in loop:
        for _hold in range(4):
            f.save(os.path.join(tmp, "f%05d.png" % n))
            n += 1
ok = len(frames) == len(keys) and n > 0
if n > 0:
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i", os.path.join(tmp, "f%05d.png"),
                        "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", out])
    ok = ok and r.returncode == 0
print("tl.skater.look_film/1 " + json.dumps({"ok": ok, "keys": len(keys), "paired": len(frames), "frames": n, "seconds": round(n / 60.0, 2), "out": out}))
sys.exit(0 if ok else 1)
