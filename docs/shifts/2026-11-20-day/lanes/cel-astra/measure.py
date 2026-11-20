"""Lane cel-astra (20 Nov day): the operator's measurements of a shot set.
  python measure.py sharp <dir> [<dir2>]        sharpness per shot and crop: variance of a 3x3 Laplacian of luma (0..255)
                                                over fixed crops of the 1920x1080 frame; with <dir2>, the ratio dir2/dir
  python measure.py diff <dirA> <dirB>          per shot: max |A-B| over RGB (0..255), share of pixels differing > 1/255
  python measure.py shoulder <walk160.png> ...   native release road shoulder: luma transitions over 24 levels
  python measure.py fence <west-road.png> ...    right edge of the left rail's cast in the native visitor view
  python measure.py grass <dir> [--fine] <profile> ...    27 matched pan crops; --fine selects small distant silhouettes
  python measure.py rgb <img> <radius> <x,y> ...  RGB median and standard deviation in native square patches
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


def fence_edge(red, first_row, end_row):
    """Measure a continuous stretch between fence posts, away from the visitor and HUD."""
    positions, widths = [], []
    excess = 0
    for y in range(first_row, end_row):
        centre = round(807 - (y - 700) * .363)
        left = centre - 17
        row = red[y, left:centre + 19]
        dark, light = np.median(row[:5]), np.median(row[-5:])
        if light - dark < 52:
            raise ValueError(f"Expected shade and lit road on row {y}. Check the west-facing camera pose.")
        row = (row - dark) / (light - dark)

        def crossings(level):
            i = np.flatnonzero((row[:-1] <= level) & (row[1:] > level))
            return i + (level - row[i]) / (row[i + 1] - row[i])

        half = crossings(.5)
        positions.append(left + np.median(half))
        widths.append(crossings(.9)[-1] - crossings(.1)[0])
        excess += len(half) - 1
    ordinate = np.arange(first_row, end_row) - first_row
    fitted = np.polyval(np.polyfit(ordinate, positions, 2), ordinate)
    rms = np.mean((positions - fitted) ** 2) ** .5
    return rms, np.median(widths), excess


def grass_motion(directory, profiles, fine=False):
    """Compare sampled grass pixels and their changes with the same poses at higher sampling."""
    def crop(profile, frame):
        path = os.path.join(directory, profile, f"{frame:02d}.png")
        with Image.open(path) as image:
            if image.size != (1920, 440):
                raise ValueError(f"Expected the native crop from rows 230 to 669 in {path}")
            return np.asarray(image.convert("RGB"), dtype=np.float32)

    def luminance(rgb):
        return .2126 * rgb[:, :, 0] + .7152 * rgb[:, :, 1] + .0722 * rgb[:, :, 2]

    previous = {}
    stats = {p: [] for p in profiles}
    for i in range(27):
        target = crop("ref", i)
        mask = np.max(np.abs(target - crop("ref-mask", i)), axis=2) > 9
        if fine:
            import cv2
            _, labels, components, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), connectivity=8)
            width, height, area = components[:, 2:].T
            small = (width <= 16) & (height <= 16) & (area >= 2)
            small[0] = False
            mask &= small[labels]
            # The native horizon patch is x750..1189, y300..389.
            mask[:70] = mask[160:] = False
            mask[:, :750] = mask[:, 1190:] = False
        else:
            mask[260:] = False  # The distant field is above native row 490.
        reference = luminance(target)
        for profile in profiles:
            value = luminance(crop(profile, i))
            error = value - reference
            if i:
                union = mask | previous_mask
                if not union.any():
                    raise ValueError("Grass removal changed no pixels in the measured field")
                prior_value, prior_error = previous[profile]
                stats[profile].append((union.sum(), np.abs(error[union]).mean(),
                                       np.abs((error - prior_error)[union]).mean(),
                                       100 * (np.abs((value - prior_value)[union]) > 24).mean()))
            previous[profile] = value, error
        previous_mask = mask
    print("profile  grass pixels  image MAE  change MAE  changes >24 (%)")
    for name, rows in stats.items():
        print(name, *(f"{n:.3f}" for n in np.mean(rows, axis=0)))


def main():
    cmd = sys.argv[1]
    if cmd == "rgb":
        with Image.open(sys.argv[2]) as image:
            rgb = np.asarray(image.convert("RGB"))
        radius = int(sys.argv[3])
        height, width = rgb.shape[:2]
        for point in sys.argv[4:]:
            x, y = map(int, point.split(","))
            if radius < 0 or min(x, y) < radius or x + radius >= width or y + radius >= height:
                raise ValueError(f"Patch at {point} extends outside {width} × {height}")
            patch = rgb[y-radius:y+radius+1, x-radius:x+radius+1]
            median = np.median(patch, axis=(0, 1)).astype(int)
            print(point, "median", median.tolist(), "SD", patch.std(axis=(0, 1)).round(2).tolist())
    elif cmd == "grass":
        profiles = [p for p in sys.argv[3:] if p != "--fine"]
        if not profiles:
            raise ValueError("Expected a sweep directory and at least one profile")
        grass_motion(sys.argv[2], profiles, "--fine" in sys.argv[3:])
    elif cmd == "fence":
        for path in sys.argv[2:]:
            with Image.open(path) as image:
                if image.size != (1920, 1080):
                    raise ValueError("The fence measure needs a native 1920x1080 west-road view")
                red = np.asarray(image.convert("RGB"), dtype=float)[:, :, 0]
            for y0, y1 in [(690, 807), (900, 1020)]:
                rms, width, excess = fence_edge(red, y0, y1)
                print(f"{path}, rows {y0}-{y1-1}: RMS {rms:.3f}px, median 10-90% width {width:.3f}px, "
                      f"{excess} extra 50% crossings")
    elif cmd == "shoulder":
        for path in sys.argv[2:]:
            with Image.open(path) as image:
                if image.size != (1920, 1080):
                    raise ValueError("The road shoulder needs the native 1920x1080 walk frame")
            y = luma(path)
            line = np.abs(np.diff(y[875, 450:610]))
            patch = np.abs(np.diff(y[740:1005, 325:690], axis=0))
            print(f"{path}: {np.count_nonzero(line > 24)}/{line.size} horizontal,"
                  f" {np.count_nonzero(patch > 24)}/{patch.size} vertical")
    elif cmd == "sharp":
        a = sharp(sys.argv[2])
        b = sharp(sys.argv[3]) if len(sys.argv) > 3 else None
        print("shot".ljust(28), "  ".join(k.rjust(18) for k in CROPS))
        for f, v in a.items():
            if b is None:
                print(f.ljust(28), "  ".join(("%.1f" % v[k]).rjust(18) for k in CROPS))
            elif f in b:
                print(f.ljust(28), "  ".join(("%.1f>%.1f x%.2f" % (v[k], b[f][k], b[f][k] / max(v[k], 1e-6))).rjust(18) for k in CROPS))
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
