#!/usr/bin/env python3
"""The arena's side-by-side sheets: for each camera pose, thirdjam's own game still (its viewport, HUD and figures in
it), thirdjam's world seen by a scene capture from the logged pose (export_arena.py; no HUD), and ours (shots.gd).
usage: python pair_sheets.py <shots.json> <game stills folder> <capture folder> <ours folder> <out prefix> [rows per sheet]
shots.json rows carry "name" and "frame" (the game still is u1-p3_clay-f<frame>.png). Writes <out prefix>_<n>.jpg."""
import json
import os
import sys

from PIL import Image, ImageDraw

shots = json.load(open(sys.argv[1], encoding="utf-8"))
game, cap, ours, out = sys.argv[2:6]
per = int(sys.argv[6]) if len(sys.argv) > 6 else 4
TW, TH = 640, 360
missing = []


def tile(path, label):
    if not os.path.isfile(path):
        missing.append(path)
        im = Image.new("RGB", (TW, TH), (40, 0, 0))
    else:
        im = Image.open(path).convert("RGB").resize((TW, TH), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    d.rectangle([0, TH - 16, 7 * len(label) + 8, TH], fill=(0, 0, 0))
    d.text((4, TH - 14), label, fill=(255, 255, 255))
    return im


for n in range(0, len(shots), per):
    rows = shots[n:n + per]
    sheet = Image.new("RGB", (TW * 3, TH * len(rows)))
    for r, s in enumerate(rows):
        sheet.paste(tile(os.path.join(game, "u1-p3_clay-f%05d.png" % s["frame"]), "thirdjam, the game (frame %d): %s" % (s["frame"], s["name"])), (0, r * TH))
        sheet.paste(tile(os.path.join(cap, s["name"] + ".png"), "thirdjam, its world from the same pose"), (TW, r * TH))
        sheet.paste(tile(os.path.join(ours, s["name"] + ".png"), "ours"), (TW * 2, r * TH))
    path = "%s_%d.jpg" % (out, n // per + 1)
    sheet.save(path, quality=88)
    print(path)
if missing:
    print("MISSING", missing)
    sys.exit(1)
