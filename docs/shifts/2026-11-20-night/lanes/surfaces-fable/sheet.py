"""Lane surfaces-fable (night of 20 Nov 2026): the stills and contact sheets of the lane folder, from raw captures.
  python sheet.py <raw classic dir> <raw diorama dir> <raw preview dir> <lane dir> [best village frame, a file name]
Writes stills/<style>/<name>.jpg (1280x720) for the three styles, contact-sheet.jpg (the target board beside the best
village frame, then every shot as classic | diorama | preview, two shots to a row) and contact-sheet-pairs.jpg
(classic | diorama only, larger).
"diorama" is this arm's tree as it is (the frame pillar's ink and paper untouched); "preview" is the same tree with
PATCHES.md frame 1 and 2 applied (TL_STYLE=surfaces)."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

classic, diorama, preview, lane = sys.argv[1:5]
best = sys.argv[5] if len(sys.argv) > 5 else "51_road_visitor.png"
styles = [("classic", classic), ("diorama", diorama), ("preview", preview)]
names = sorted(f for f in os.listdir(diorama) if f.endswith(".png"))
for label, src in styles:
    os.makedirs(os.path.join(lane, "stills", label), exist_ok=True)
    for f in names:
        p = os.path.join(src, f)
        if os.path.exists(p):
            Image.open(p).convert("RGB").resize((1280, 720), Image.LANCZOS).save(os.path.join(lane, "stills", label, f[:-4] + ".jpg"), quality=88)

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


def sheet(cols, out, top, w, per_row):
    h, pad, head, gap = w * 9 // 16, 4, 30, 14
    group = len(cols) * w + (len(cols) - 1) * pad
    tw = per_row * group + (per_row - 1) * gap + 2 * pad
    # the target board beside the best village frame, across the full width
    bw = (tw - 3 * pad) // 2
    bh = bw * 9 // 16
    th = bh + head + pad
    rows = (len(names) + per_row - 1) // per_row
    im = Image.new("RGB", (tw, th + head + rows * (h + pad) + pad), BG)
    d = ImageDraw.Draw(im)
    d.text((pad, 4), "target: board 4, toy diorama", fill=(255, 255, 255), font=font)
    d.text((pad * 2 + bw, 4), "this arm: %s, %s" % (best[:-4], top[0]), fill=(255, 255, 255), font=font)
    im.paste(tile(os.path.join(lane, "..", "..", "target", "4-toy-diorama.jpg"), bw, bh), (pad, head))
    im.paste(tile(os.path.join(top[1], best), bw, bh), (pad * 2 + bw, head))
    for g in range(per_row):
        for c, (label, _) in enumerate(cols):
            d.text((pad + g * (group + gap) + c * (w + pad), th + 4), label, fill=(255, 255, 255), font=small)
    for i, f in enumerate(names):
        r, g = divmod(i, per_row)
        y = th + head + r * (h + pad)
        x0 = pad + g * (group + gap)
        for c, (label, src) in enumerate(cols):
            im.paste(tile(os.path.join(src, f), w, h), (x0 + c * (w + pad), y))
        d.text((x0 + 5, y + 3), f[:-4], fill=(255, 255, 255), font=small, stroke_width=2, stroke_fill=(0, 0, 0))
    im.save(os.path.join(lane, out), quality=86)
    print(out, im.size)


sheet([("classic", classic), ("diorama: this arm as it is", diorama), ("preview: + ink and paper off (PATCHES)", preview)],
      "contact-sheet.jpg", ("preview (TL_STYLE=surfaces: this arm with the frame pillar's ink and paper off)", preview), 480, 2)
sheet([("classic (TL_STYLE=classic)", classic), ("diorama (this arm as it is; ink and paper as on the base)", diorama)],
      "contact-sheet-pairs.jpg", ("diorama (this arm as it is)", diorama), 640, 2)
