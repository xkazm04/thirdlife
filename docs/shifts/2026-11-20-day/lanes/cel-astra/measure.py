"""Lane cel-astra (20 Nov day): the operator's measurements of a shot set.
  python measure.py sharp <dir> [<dir2>]        sharpness per shot and crop: variance of a 3x3 Laplacian of luma (0..255)
                                                over fixed crops of the 1920x1080 frame; with <dir2>, the ratio dir2/dir
  python measure.py diff <dirA> <dirB>          per shot: max |A-B| over RGB (0..255), share of pixels differing > 1/255
  python measure.py bands <img> x0 y0 x1 y1     luma histogram modes in a crop (64 bins, modes with >= 3 % of the crop)
Crops (x0, y0, x1, y1 at 1920x1080): top (sky/far) 0,0,1920,300; mid 0,300,1920,620; centre (subject) 660,320,1260,860;
near (bottom) 0,800,1920,1080."""
import os
import sys
import numpy as np
from PIL import Image

CROPS = {"top": (0, 0, 1920, 300), "mid": (0, 300, 1920, 620), "centre": (660, 320, 1260, 860), "near": (0, 800, 1920, 1080)}


def luma(path):
    im = Image.open(path).convert("RGB")
    if im.size != (1920, 1080):
        im = im.resize((1920, 1080), Image.LANCZOS)
    a = np.asarray(im, dtype=np.float32)
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def lap_var(y):
    l = -4 * y[1:-1, 1:-1] + y[:-2, 1:-1] + y[2:, 1:-1] + y[1:-1, :-2] + y[1:-1, 2:]
    return float(l.var())


def sharp(d):
    out = {}
    for f in sorted(os.listdir(d)):
        if not f.endswith(".png"):
            continue
        y = luma(os.path.join(d, f))
        out[f] = {k: lap_var(y[c[1]:c[3], c[0]:c[2]]) for k, c in CROPS.items()}
    return out


def main():
    cmd = sys.argv[1]
    if cmd == "sharp":
        a = sharp(sys.argv[2])
        b = sharp(sys.argv[3]) if len(sys.argv) > 3 else None
        print("shot".ljust(28) + "".join(k.rjust(18) for k in CROPS))
        for f, v in a.items():
            if b is None:
                print(f.ljust(28) + "".join(("%.1f" % v[k]).rjust(18) for k in CROPS))
            elif f in b:
                print(f.ljust(28) + "".join(("%.1f>%.1f x%.2f" % (v[k], b[f][k], b[f][k] / max(v[k], 1e-6))).rjust(18) for k in CROPS))
    elif cmd == "diff":
        A, B = sys.argv[2], sys.argv[3]
        for f in sorted(os.listdir(A)):
            if not f.endswith(".png") or not os.path.exists(os.path.join(B, f)):
                continue
            x = np.asarray(Image.open(os.path.join(A, f)).convert("RGB"), dtype=np.int16)
            y = np.asarray(Image.open(os.path.join(B, f)).convert("RGB"), dtype=np.int16)
            if x.shape != y.shape:
                print(f.ljust(28), "size differs", x.shape, y.shape)
                continue
            dd = np.abs(x - y).max(axis=2)
            print(f.ljust(28), "max %3d/255  >1: %.4f %%" % (dd.max(), 100.0 * (dd > 1).mean()))
    elif cmd == "bands":
        y = luma(sys.argv[2])
        x0, y0, x1, y1 = map(int, sys.argv[3:7])
        h, _ = np.histogram(y[y0:y1, x0:x1], bins=64, range=(0, 256))
        h = h / h.sum()
        modes = [i for i in range(64) if h[i] >= 0.03 and h[i] >= h[max(i - 1, 0)] and h[i] >= h[min(i + 1, 63)]]
        print("modes (luma bin centres):", [int(i * 4 + 2) for i in modes], "shares:", ["%.2f" % h[i] for i in modes])


if __name__ == "__main__":
    main()
