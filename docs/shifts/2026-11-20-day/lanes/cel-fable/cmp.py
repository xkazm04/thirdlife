"""Lane cel-fable: two folders of PNG pictures compared pixel by pixel.
  python cmp.py <dir a> <dir b>
Per picture: the largest difference of any channel (0..255), the mean difference, and the share of pixels whose
largest channel difference is over 1 (the bar of rule 2: identical or within 1/255)."""
import os
import sys
import numpy as np
from PIL import Image

a, b = sys.argv[1], sys.argv[2]
names = sorted(f for f in os.listdir(a) if f.endswith(".png") and os.path.exists(os.path.join(b, f)))
same = within = 0
for f in names:
    x = np.asarray(Image.open(os.path.join(a, f)).convert("RGB"), dtype=np.int16)
    y = np.asarray(Image.open(os.path.join(b, f)).convert("RGB"), dtype=np.int16)
    if x.shape != y.shape:
        print("%-24s sizes differ %s %s" % (f, x.shape, y.shape))
        continue
    d = np.abs(x - y).max(axis=2)
    over = float((d > 1).mean()) * 100.0
    same += int(d.max() == 0)
    within += int(d.max() <= 1)
    print("%-24s max %3d  mean %.4f  over 1/255: %.3f %%" % (f, d.max(), float(d.mean()), over))
print("pictures %d, identical %d, within 1/255 %d" % (len(names), same, within))
