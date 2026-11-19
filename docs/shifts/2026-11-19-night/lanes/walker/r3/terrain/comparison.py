"""Production still crops and the independently measured 1–15% terrain crest mask."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.argv = [sys.argv[0], "head"]
import measure

sheet = Image.new("RGB", (1720, 880), "#1b191b")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("segoeui.ttf", 18)
title = ImageFont.truetype("segoeui.ttf", 24)
draw.text((18, 9), "Terrain crests against nearby land", font=title, fill="white")
draw.text((18, 48), "Green carries at least half-strength outer ink. Magenta falls below it. The mask shows depth gaps of 1–15%.",
          font=font, fill="white")
for j, label in enumerate(("HEAD", "Reviewed 3b", "Revised", "Revised with crest mask")):
    draw.text((18+426*j, 90), label, font=font, fill="white")
for row, (name, label, x, y) in enumerate([("bank_310", "Bank approach · tick 310", 1200, 380),
                                         ("bluff_120", "Bluff walk · tick 120", 480, 565),
                                         ("shoulder", "Bluff shoulder · eye-height camera", 120, 260)]):
    top = 122 + row*248
    draw.text((18, top), label, font=font, fill="white")
    for col, stage in enumerate(("head", "r3b", "after", "after")):
        measure.out = measure.here / "captures" / stage
        rgb = measure.read(name, "beauty").copy()
        if col == 3:
            _, crest, gap, ink, _ = measure.masks(name)
            close = crest & (gap < .15)
            rgb = (rgb.astype(np.float32)*.52).astype(np.uint8)
            rgb[close & ink[:, :, 0]] = (70,255,125)
            rgb[close & ~ink[:, :, 0]] = (255,60,181)
        sheet.paste(Image.fromarray(rgb[y:y+194,x:x+420]), (18+col*426, top+36))
sheet.save(measure.here / "crest-comparison.png")
