"""Pair sheets for the skater's surface: thirdjam's own render (look_reference.py, files <clip>_k<key>_<cam>_t<team>.png)
above ours (engine/rigs/skater/look/look_gym.tscn --mode=shots, one folder a team: <ours>/t<team>/<clip>_k<key>_<cam>.png).
  python look_pairs.py <ref dir> <ours dir> <out prefix> <team> <clip> <key> <cam> [<cam> ...] [--px=N] [--crop=x0,y0,x1,y1]
--crop is in shares of the frame (0..1), applied to both rows."""
import sys
from PIL import Image, ImageDraw

args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--"))
ref_dir, our_dir, out, team, clip, key = args[:6]
cams = args[6:]
px = int(opts.get("px", "480"))
crop = [float(v) for v in opts["crop"].split(",")] if "crop" in opts else None
rows = []
for label, folder, name in (("thirdjam", ref_dir, "%s_k%03d_%%s_t%s.png" % (clip, int(key), team)), ("ours", "%s/t%s" % (our_dir, team), "%s_k%03d_%%s.png" % (clip, int(key)))):
    tiles = []
    for cam in cams:
        im = Image.open("%s/%s" % (folder, name % cam)).convert("RGB")
        if crop:
            im = im.crop((int(crop[0] * im.width), int(crop[1] * im.height), int(crop[2] * im.width), int(crop[3] * im.height)))
        im = im.resize((round(im.width * px / im.height), px), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 150, 16), fill=(0, 0, 0))
        d.text((4, 2), "%s  %s" % (label, cam), fill=(255, 255, 255))
        tiles.append(im)
    rows.append(tiles)
w = sum(t.width for t in rows[0])
sheet = Image.new("RGB", (w, px * 2))
for r, tiles in enumerate(rows):
    x = 0
    for t in tiles:
        sheet.paste(t, (x, r * px))
        x += t.width
sheet.save(out, quality=90)
print(out, sheet.size)
