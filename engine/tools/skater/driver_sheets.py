"""Side-by-side sheets and a film of the figure gym's run: thirdjam's own figure (tools/skater/driver_oracle.py's stills)
over ours (cores/rink/view/figure_gym.gd --stills), the same frames from the same cameras.
  python driver_sheets.py <oracle dir> <ours dir> <calls.json> <out dir> [cam] [every]
Writes <out>/r2_<segment>_<cam>.jpg per segment of the hand (two rows a band: thirdjam above, ours below; a tile
every `every`-th still) and <out>/r2_run_<cam>.mp4 (every still, 20 a second = real time for stills of every third
frame). Needs ffmpeg for the film. Prints `tl.skater.driver_sheets/1 {...}`."""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

oracle_dir, ours_dir, calls_path, out_dir = sys.argv[1:5]
cam = sys.argv[5] if len(sys.argv) > 5 else "three"
every = int(sys.argv[6]) if len(sys.argv) > 6 else 1
os.makedirs(out_dir, exist_ok=True)
frames = json.load(open(calls_path, encoding="utf-8"))["frames"]
seg_of = {f["f"]: f["seg"] for f in frames}
have = sorted(int(n[len(cam) + 2:-4]) for n in os.listdir(oracle_dir) if n.startswith(cam + "_f") and n.endswith(".png")
              and os.path.isfile(os.path.join(ours_dir, n)))
PX = 300
segs = {}
for f in have:
    segs.setdefault(seg_of.get(f, "?"), []).append(f)
sheets = []
for seg, fl in segs.items():
    fl = fl[::every]
    cols = min(len(fl), 12)
    bands = (len(fl) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * PX, bands * 2 * PX), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(fl):
        x, y = (i % cols) * PX, (i // cols) * 2 * PX
        name = "%s_f%04d.png" % (cam, f)
        sheet.paste(Image.open(os.path.join(oracle_dir, name)).convert("RGB").resize((PX, PX), Image.LANCZOS), (x, y))
        sheet.paste(Image.open(os.path.join(ours_dir, name)).convert("RGB").resize((PX, PX), Image.LANCZOS), (x, y + PX))
        for yy, who in ((y, "thirdjam"), (y + PX, "ours")):
            text = "%s f%d" % (who, f)
            d.rectangle([x + 2, yy + 2, x + 8 + 6 * len(text), yy + 14], fill=(0, 0, 0))
            d.text((x + 4, yy + 2), text, fill=(255, 255, 255))
    name = "r2_%s_%s.jpg" % (seg, cam)
    sheet.save(os.path.join(out_dir, name), quality=85)
    sheets.append(name)
tmp = os.path.join(out_dir, "_film")
shutil.rmtree(tmp, ignore_errors=True)
os.makedirs(tmp)
FP = 540
for i, f in enumerate(have):
    name = "%s_f%04d.png" % (cam, f)
    fr = Image.new("RGB", (2 * FP, FP))
    fr.paste(Image.open(os.path.join(oracle_dir, name)).convert("RGB").resize((FP, FP), Image.LANCZOS), (0, 0))
    fr.paste(Image.open(os.path.join(ours_dir, name)).convert("RGB").resize((FP, FP), Image.LANCZOS), (FP, 0))
    d = ImageDraw.Draw(fr)
    for x, who in ((0, "thirdjam's own figure (Unreal)"), (FP, "ours (Godot)")):
        text = "%s  frame %d  %s" % (who, f, seg_of.get(f, ""))
        d.rectangle([x + 4, 4, x + 12 + 6 * len(text), 20], fill=(0, 0, 0))
        d.text((x + 8, 6), text, fill=(255, 255, 255))
    fr.save(os.path.join(tmp, "f%05d.png" % i))
film = os.path.join(out_dir, "r2_run_%s.mp4" % cam)
code = subprocess.call(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "20", "-i", os.path.join(tmp, "f%05d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "23", film])
shutil.rmtree(tmp, ignore_errors=True)
print("tl.skater.driver_sheets/1 " + json.dumps({"cam": cam, "stills": len(have), "sheets": sheets, "film": film if code == 0 else "", "seconds": round(len(have) / 20.0, 1)}))
