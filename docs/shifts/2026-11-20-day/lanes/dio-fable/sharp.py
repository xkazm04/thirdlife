# Lane dio-fable (day of 20 Nov 2026): the sharpness figure of COMMON.md.
#   python docs/shifts/2026-11-20-day/lanes/dio-fable/sharp.py <dir A> <dir B> [...]
# For each of the fixed shots and crops below: the variance of the Laplacian of the luma (0..255), per directory.
# A higher figure = more fine contrast in that crop (texture that is resolved, edges that are clean). It is a relative
# measure between two pictures of the SAME view; it does not tell detail from noise, so the crops are also looked at.
import sys, os
import numpy as np
import cv2

# shot, name of the crop, x, y, w, h (1920x1080 pictures)
CROPS = [
    ("01_walker_road",     "near ground",   200, 760, 640, 300),
    ("01_walker_road",     "middle (bush, fence)", 420, 560, 520, 260),
    ("07_parkour_road",    "near ground",   900, 760, 700, 300),
    ("07_parkour_road",    "middle (yard)", 700, 300, 700, 300),
    ("13_lot_river_road",  "near meadow",   100, 650, 800, 400),
    ("13_lot_river_road",  "far (crane, pines)", 760, 100, 700, 260),
    ("15_lot_bluff_road",  "middle (road, fence)", 500, 520, 700, 330),
]


def lapvar(path, x, y, w, h):
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    if img is None:
        return None
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float64)[y:y + h, x:x + w]
    return float(cv2.Laplacian(g, cv2.CV_64F).var())


def main():
    dirs = sys.argv[1:]
    print("%-20s %-22s " % ("shot", "crop") + " ".join("%14s" % os.path.basename(os.path.normpath(d))[:14] for d in dirs))
    for shot, name, x, y, w, h in CROPS:
        vals = []
        for d in dirs:
            v = None
            for ext in (".png", ".jpg"):
                p = os.path.join(d, shot + ext)
                if os.path.exists(p):
                    v = lapvar(p, x, y, w, h)
                    break
            vals.append(v)
        print("%-20s %-22s " % (shot, name) + " ".join("%14s" % ("-" if v is None else "%.1f" % v) for v in vals))


if __name__ == "__main__":
    main()
