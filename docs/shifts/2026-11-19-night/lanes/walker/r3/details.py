"""Crop the production stills and draw measured inner-boundary pixels beside them."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

here = Path(__file__).resolve().parent
sheet = Image.new("RGB", (1024, 1196), "#18161a")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("segoeui.ttf", 19)
small = ImageFont.truetype("segoeui.ttf", 16)
draw.text((16, 8), "Walker silhouette coverage", font=font, fill="white")
draw.text((16, 38), "Green pixels carry at least half-strength contour ink. Magenta pixels fall below it.", font=small, fill="white")
for row, (place, title) in enumerate([("behind_wall", "Review wall, rear view"), ("bank", "Village bank, walking uphill")]):
    y = 70 + 562 * row
    draw.text((16, y), title, font=font, fill="white")
    for index, stage in enumerate(["before", "after"]):
        out = here / stage
        sig = np.array(Image.open(out / f"{place}-signal.png"))
        mask = (sig[:, :, 0] > 127) & (np.array(Image.open(out / f"{place}-hidden.png"))[:, :, 0] < 128)
        ys, xs = np.where(mask)
        pad = np.pad(mask, 1)
        edge = mask & ~(pad[1:-1, :-2] & pad[1:-1, 2:] & pad[:-2, 1:-1] & pad[2:, 1:-1])
        visible = sig[:, :, 1] > 127
        beauty = np.array(Image.open(out / f"{place}-beauty.png").convert("RGB"))
        overlay = beauty // 3
        overlay[edge & visible] = (91, 249, 130)
        overlay[edge & ~visible] = (255, 78, 187)
        cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
        box = (cx - 60, cy - 122, cx + 60, cy + 122)
        for k, arr in enumerate([beauty, overlay]):
            x = 16 + (index*2+k)*252
            sheet.paste(Image.fromarray(arr).crop(box).resize((240, 488), Image.Resampling.NEAREST), (x, y+54))
            pct = 100 * visible[edge].mean()
            label = stage.capitalize() if k == 0 else f"{pct:.1f}% covered"
            draw.text((x, y+29), label, font=small, fill="white")
sheet.save(here / "comparison.png")
