"""Lane cel-astra (20 Nov day): stills and the contact sheet from raw captures.
  python sheet.py <raw classic dir> <raw crisp dir> <lane dir> [shot, ...]
Writes <lane>/stills/<name>_classic.jpg and <name>_crisp.jpg (1280x720) for the shots named (default: the board set) and
<lane>/contact-sheet.jpg: board 2 beside the crisp road frame on top, then classic | crisp pairs, two pairs to a row."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

classic, crisp, lane = sys.argv[1:4]
shots = sys.argv[4:] or ["51_road_visitor", "07_parkour_road", "01_walker_road", "13_lot_river_road", "08_parkour_above",
                         "23_flight_bluff", "21_flight_climb", "31_parkour_run", "32_hockey_rink", "41_figure_back", "42_figure_front"]
here = os.path.dirname(os.path.abspath(__file__))
board = os.path.join(here, "..", "..", "..", "2026-11-20-night", "target", "2-crisp-cel.jpg")
os.makedirs(os.path.join(lane, "stills"), exist_ok=True)
try:
    font = ImageFont.truetype("arial.ttf", 22)
except OSError:
    font = ImageFont.load_default()
W, H, PAD, LBL = 640, 360, 8, 30


def tile(path):
    return Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS)


pairs = []
for s in shots:
    a, b = os.path.join(classic, s + ".png"), os.path.join(crisp, s + ".png")
    if os.path.exists(a) and os.path.exists(b):
        for lab, p in (("classic", a), ("crisp", b)):
            Image.open(p).convert("RGB").resize((1280, 720), Image.LANCZOS).save(os.path.join(lane, "stills", "%s_%s.jpg" % (s, lab)), quality=88)
        pairs.append((s, a, b))
rows = 1 + (len(pairs) + 1) // 2
sheet = Image.new("RGB", (4 * W + 5 * PAD, rows * (H + LBL + PAD) + PAD), (24, 22, 30))
d = ImageDraw.Draw(sheet)
top = [("board 2 (target)", board), ("crisp: road visitor", os.path.join(crisp, "51_road_visitor.png")),
       ("board 2 (target)", board), ("crisp: parkour from the road", os.path.join(crisp, "07_parkour_road.png"))]
for i, (lab, p) in enumerate(top):
    if os.path.exists(p):
        x = PAD + i * (W + PAD)
        sheet.paste(tile(p), (x, PAD + LBL))
        d.text((x, PAD + 4), lab, fill=(240, 240, 240), font=font)
for n, (s, a, b) in enumerate(pairs):
    r, c = 1 + n // 2, (n % 2) * 2
    y = PAD + r * (H + LBL + PAD)
    for k, (lab, p) in enumerate((("classic", a), ("crisp", b))):
        x = PAD + (c + k) * (W + PAD)
        sheet.paste(tile(p), (x, y + LBL))
        d.text((x, y + 4), "%s  %s" % (s, lab), fill=(240, 240, 240), font=font)
sheet.save(os.path.join(lane, "contact-sheet.jpg"), quality=85)
print("contact sheet: %d pairs" % len(pairs))
