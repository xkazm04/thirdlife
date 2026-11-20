# Lane dio-fable: the classic proof. python cmp.py <dir base> <dir now>: per picture the largest difference of any
# channel (0..255) and the share of pixels that differ by more than 1/255.
import sys, os
import numpy as np
import cv2
a, b = sys.argv[1:3]
worst = 0
for f in sorted(x for x in os.listdir(a) if x.endswith(".png")):
    pa, pb = os.path.join(a, f), os.path.join(b, f)
    if not os.path.exists(pb):
        print("%-24s missing in %s" % (f, b)); continue
    ia = cv2.imread(pa).astype(np.int16); ib = cv2.imread(pb).astype(np.int16)
    if ia.shape != ib.shape:
        print("%-24s sizes differ" % f); continue
    d = np.abs(ia - ib).max(axis=2)
    worst = max(worst, int(d.max()))
    print("%-24s max %3d  over 1/255: %.4f %%  mean %.5f" % (f, d.max(), 100.0 * (d > 1).mean(), d.mean()))
print("largest difference of all: %d" % worst)
