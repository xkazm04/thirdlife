"""Side-by-side sheets: thirdjam's own render (engine/tools/skater/reference_capture.py) over ours (the gym's
--mode=shots) for the same shot list, and the pose numbers of the two held against each other.
  python pair_sheets.py <ref dir> <ours dir> <out dir>
Writes <out>/pair_<group>.jpg (top row thirdjam, bottom row ours) and prints one line per compared point set, then
`tl.skater.pairs/1 {...}`: the largest distance between Unreal's and our position of the same bone in the same shot.
Unreal: centimetres, x forward, y right, z up. Ours: metres, [forward, right, up]."""
import json
import math
import os
import sys

from PIL import Image, ImageDraw

ref_dir, our_dir, out_dir = sys.argv[1:4]
os.makedirs(out_dir, exist_ok=True)
ref = json.load(open(os.path.join(ref_dir, "reference.json"), encoding="utf-8"))
ours = json.load(open(os.path.join(our_dir, "ours.json"), encoding="utf-8"))
our_by = {r["file"]: r for r in ours["shots"] if "file" in r}
PX = int(os.environ.get("PAIR_PX", "480"))
BONES = ["pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket", "puck_socket", "head_socket"]

groups = {}
worst = 0.0
worst_at = ""
compared = 0
missing = []
for r in ref["shots"]:
    o = our_by.get(r["file"])
    if o is None or not os.path.isfile(os.path.join(our_dir, r["file"])) or not os.path.isfile(os.path.join(ref_dir, r["file"])):
        missing.append(r["file"])
        continue
    key = r["clip"] if r["clip"] in ("rest",) else "%s_%s" % (r["clip"], "turn" if (r["clip"] == "Stride" and r["key"] == 0) else r["cam"])
    groups.setdefault(key, []).append(r)
    for b in BONES:
        if r.get(b) is None or o.get(b) is None:
            continue
        d = math.dist([v * 0.01 for v in r[b]], o[b])
        compared += 1
        if d > worst:
            worst = d
            worst_at = "%s %s" % (r["file"], b)

sheets = []
for key, rows in groups.items():
    cols = min(len(rows), 10)
    lines = math.ceil(len(rows) / cols)
    sheet = Image.new("RGB", (cols * PX, lines * 2 * PX), (20, 20, 24))
    draw = ImageDraw.Draw(sheet)
    for i, r in enumerate(rows):
        x = (i % cols) * PX
        y = (i // cols) * 2 * PX
        a = Image.open(os.path.join(ref_dir, r["file"])).convert("RGB").resize((PX, PX), Image.LANCZOS)
        b = Image.open(os.path.join(our_dir, r["file"])).convert("RGB").resize((PX, PX), Image.LANCZOS)
        sheet.paste(a, (x, y))
        sheet.paste(b, (x, y + PX))
        for yy, who in ((y, "thirdjam"), (y + PX, "ours")):
            text = "%s  %s key %d  %s" % (who, r["clip"], r["key"], r["cam"])
            draw.rectangle([x + 2, yy + 2, x + 8 + 7 * len(text), yy + 18], fill=(0, 0, 0))
            draw.text((x + 5, yy + 4), text, fill=(255, 255, 255))
    name = "pair_%s.jpg" % key
    sheet.save(os.path.join(out_dir, name), quality=88)
    sheets.append(name)
    print("sheet %s (%d shots)" % (name, len(rows)))

rep = {"schema": "tl.skater.pairs/1", "shots_ref": len(ref["shots"]), "shots_paired": sum(len(v) for v in groups.values()), "missing": missing,
       "points_compared": compared, "worst_m": round(worst, 5), "worst_at": worst_at, "sheets": sheets}
stale = [r["file"] for r in ref["shots"] if r.get("stale", True)]     # a reference shot whose pose Unreal had not refreshed
rep["stale_reference_shots"] = stale
ok = not missing and not stale and rep["shots_paired"] == rep["shots_ref"] and compared > 0
print("%s skater pairs" % ("PASS" if ok else "FAIL"))
print("tl.skater.pairs/1 " + json.dumps(rep))
sys.exit(0 if ok else 1)
