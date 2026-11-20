"""Lane cel-fable: two sharpness figures per picture, over three fixed crops (near ground, the middle, the far edge)
of the same shot in two folders: `var` = the variance of a 4-neighbour Laplacian of the grey picture (it counts
paper grain and hatching as sharpness: a flat field scores low), and `edge` = the mean of the strongest 1 % of the
grey steps between neighbouring pixels (how hard the hardest edges are: 255 = a full step in one pixel).
  python sharp.py <dir a> <dir b> [picture name, default 07_parkour_road.png and others]"""
import os
import sys
import numpy as np
from PIL import Image

a, b = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or ["01_walker_road.png", "07_parkour_road.png", "13_lot_river_road.png", "15_lot_bluff_road.png"]
CROPS = {"near ground": (480, 760, 1440, 1060), "middle": (480, 420, 1440, 720), "far edge": (480, 260, 1440, 420)}


def lap_var(path, box):
    g = np.asarray(Image.open(path).convert("L"), dtype=np.float64)[box[1]:box[3], box[0]:box[2]]
    lap = -4.0 * g[1:-1, 1:-1] + g[:-2, 1:-1] + g[2:, 1:-1] + g[1:-1, :-2] + g[1:-1, 2:]
    step = np.maximum(np.abs(np.diff(g, axis=0))[:, :-1], np.abs(np.diff(g, axis=1))[:-1, :]).ravel()
    top = np.sort(step)[-max(1, step.size // 100):]
    return "var %.0f edge %.0f" % (float(lap.var()), float(top.mean()))


for f in names:
    pa, pb = os.path.join(a, f), os.path.join(b, f)
    if not (os.path.exists(pa) and os.path.exists(pb)):
        continue
    print(f + ":  " + ";  ".join("%s: %s -> %s" % (k, lap_var(pa, v), lap_var(pb, v)) for k, v in CROPS.items()))
