"""Lane cel-fable (day of 20 Nov 2026): the stills and the contact sheet of the lane folder, from raw PNG captures.
  python sheet.py <raw classic dir> <raw crisp dir> <raw crisp views dir> <lane dir> [label of the crisp column]
Writes stills/classic/<name>.jpg and stills/crisp/<name>.jpg (1280x720; the tour and the flight), stills/views/<name>.jpg
(the lane's own eight views, cel_views.walk.json) and contact-sheet.jpg: board 2 beside the lane's road view, then the
eight views, then every shot of the set as classic | crisp."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

classic, crisp, views, lane = sys.argv[1:5]
label = sys.argv[5] if len(sys.argv) > 5 else "crisp cel (TL_STYLE=crisp), this arm as it is"
board = os.path.join(lane, "..", "..", "..", "2026-11-20-night", "target", "2-crisp-cel.jpg")


def pngs(d):
    return sorted(f for f in os.listdir(d) if f.endswith(".png")) if os.path.isdir(d) else []


for sub, src in (("classic", classic), ("crisp", crisp), ("views", views)):
    os.makedirs(os.path.join(lane, "stills", sub), exist_ok=True)
    for f in pngs(src):
        Image.open(os.path.join(src, f)).convert("RGB").resize((1280, 720), Image.LANCZOS).save(
            os.path.join(lane, "stills", sub, f[:-4] + ".jpg"), quality=88)

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


pad, head = 4, 30
vnames = pngs(views)
names = [f for f in pngs(crisp)]
W = 1920
bw = (W - 3 * pad) // 2
bh = bw * 9 // 16
vw = (W - 5 * pad) // 4
vh = vw * 9 // 16
pw = (W - 5 * pad) // 4
ph = pw * 9 // 16
vrows = (len(vnames) + 3) // 4
prows = (len(names) + 1) // 2
H = head + bh + pad + head + vrows * (vh + pad) + head + prows * (ph + pad) + pad
im = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(im)
best = vnames[0] if vnames else ""
d.text((pad, 4), "target: board 2, crisp cel", fill=(255, 255, 255), font=font)
d.text((pad * 2 + bw, 4), "this arm: %s, %s" % (best[:-4], label), fill=(255, 255, 255), font=font)
im.paste(tile(board, bw, bh), (pad, head))
im.paste(tile(os.path.join(views, best), bw, bh), (pad * 2 + bw, head))
y = head + bh + pad
d.text((pad, y + 4), "the lane's own views (cel_views.walk.json), %s" % label, fill=(255, 255, 255), font=font)
y += head
for i, f in enumerate(vnames):
    r, c = divmod(i, 4)
    x = pad + c * (vw + pad)
    im.paste(tile(os.path.join(views, f), vw, vh), (x, y + r * (vh + pad)))
    d.text((x + 5, y + r * (vh + pad) + 3), f[:-4], fill=(255, 255, 255), font=small, stroke_width=2, stroke_fill=(0, 0, 0))
y += vrows * (vh + pad)
d.text((pad, y + 4), "the shot set: classic (TL_STYLE=classic) | %s" % label, fill=(255, 255, 255), font=font)
y += head
for i, f in enumerate(names):
    r, g = divmod(i, 2)
    x0 = pad + g * 2 * (pw + pad)
    im.paste(tile(os.path.join(classic, f), pw, ph), (x0, y + r * (ph + pad)))
    im.paste(tile(os.path.join(crisp, f), pw, ph), (x0 + pw + pad, y + r * (ph + pad)))
    d.text((x0 + 5, y + r * (ph + pad) + 3), f[:-4], fill=(255, 255, 255), font=small, stroke_width=2, stroke_fill=(0, 0, 0))
im.save(os.path.join(lane, "contact-sheet.jpg"), quality=86)
print("contact-sheet.jpg", im.size)
