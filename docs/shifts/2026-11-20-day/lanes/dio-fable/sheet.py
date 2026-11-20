"""Lane dio-fable (day of 20 Nov 2026): the stills and the contact sheet of the lane folder, from raw captures.
  python sheet.py <raw base dir (round 0)> <raw now dir> <lane dir> [label of now]
Writes stills/<name>.jpg (1920x1080, the pictures of <raw now dir>), stills/base/<name>.jpg (1280x720, round 0) and
contact-sheet.jpg: board 4 beside this arm's board frame, then every shot as base | now."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

base, now, lane = sys.argv[1:4]
label = sys.argv[4] if len(sys.argv) > 4 else "now"
BEST = "52_chase_b.png"
names = sorted(f for f in os.listdir(now) if f.endswith(".png"))
os.makedirs(os.path.join(lane, "stills", "base"), exist_ok=True)
for f in names:
    Image.open(os.path.join(now, f)).convert("RGB").save(os.path.join(lane, "stills", f[:-4] + ".jpg"), quality=90)
    p = os.path.join(base, f)
    if os.path.exists(p):
        Image.open(p).convert("RGB").resize((1280, 720), Image.LANCZOS).save(os.path.join(lane, "stills", "base", f[:-4] + ".jpg"), quality=86)

try:
    font = ImageFont.truetype("arial.ttf", 22)
    small = ImageFont.truetype("arial.ttf", 15)
except OSError:
    font = small = ImageFont.load_default()
BG = (24, 22, 30)


def tile(path, w, h):
    if not os.path.exists(path):
        im = Image.new("RGB", (w, h), (40, 40, 40))
        ImageDraw.Draw(im).text((10, 10), "missing", fill=(255, 80, 80), font=font)
        return im
    return Image.open(path).convert("RGB").resize((w, h), Image.LANCZOS)


w, per_row = 640, 2
h, pad, head, gap = w * 9 // 16, 4, 30, 14
group = 2 * w + pad
tw = per_row * group + (per_row - 1) * gap + 2 * pad
bw = (tw - 3 * pad) // 2
bh = bw * 9 // 16
th = bh + head + pad
rows = (len(names) + per_row - 1) // per_row
im = Image.new("RGB", (tw, th + head + rows * (h + pad) + pad), BG)
d = ImageDraw.Draw(im)
d.text((pad, 4), "target: board 4, toy diorama", fill=(255, 255, 255), font=font)
d.text((pad * 2 + bw, 4), "dio-fable: %s, %s" % (BEST[:-4], label), fill=(255, 255, 255), font=font)
im.paste(tile(os.path.join(lane, "..", "..", "..", "2026-11-20-night", "target", "4-toy-diorama.jpg"), bw, bh), (pad, head))
im.paste(tile(os.path.join(now, BEST), bw, bh), (pad * 2 + bw, head))
for g in range(per_row):
    for c, lab in enumerate(("base (round 0, d20-dio)", label)):
        d.text((pad + g * (group + gap) + c * (w + pad), th + 4), lab, fill=(255, 255, 255), font=small)
for i, f in enumerate(names):
    r, g = divmod(i, per_row)
    y = th + head + r * (h + pad)
    x0 = pad + g * (group + gap)
    for c, src in enumerate((base, now)):
        im.paste(tile(os.path.join(src, f), w, h), (x0 + c * (w + pad), y))
    d.text((x0 + 5, y + 3), f[:-4], fill=(255, 255, 255), font=small, stroke_width=2, stroke_fill=(0, 0, 0))
im.save(os.path.join(lane, "contact-sheet.jpg"), quality=86)
print("contact-sheet.jpg", im.size)
