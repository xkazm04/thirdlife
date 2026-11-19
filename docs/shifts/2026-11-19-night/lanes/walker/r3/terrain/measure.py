"""Coverage of visible land against farther land, and terrain-owned pixel pairs during the walk."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

here = Path(__file__).resolve().parent
stage = sys.argv[1]
out = here / "captures" / stage
bands = [(0.01, .05), (.05, .15), (.15, .50), (.50, np.inf)]


def read(name, kind, crop=False):
    with Image.open(out / f"{name}-{kind}.png") as im:
        if crop and im.width == 1920:
            im = im.crop((48, 555, 848, 975))
        return np.asarray(im.convert("RGB"))


def depths(name, kind, crop):
    rgb = read(name, kind, crop)
    digits = np.rint(rgb.astype(np.float32) * (63/255)).astype(np.int32)
    return (digits[:, :, 0]*4096 + digits[:, :, 1]*64 + digits[:, :, 2]) * .002


def masks(name, crop=False):
    z = depths(name, "depth", crop)
    hidden = depths(name, "removed", crop)
    ground = hidden > z + .02
    safe = np.maximum(z, .01)
    inv = 1/safe
    far = np.roll(z, 1, axis=0)
    gap = (far-z)/safe
    # Four vertical samples, from near land to far land upwards. Inverse depth along a plane
    # is affine in screen space. Compare the jump with the local slope on BOTH sides.
    jump = inv - np.roll(inv, 1, axis=0)
    slope = np.maximum(np.abs(np.roll(jump, 1, axis=0)), np.abs(np.roll(jump, -1, axis=0)))
    crest = (ground & np.roll(ground, -1, axis=0) & np.roll(ground, 1, axis=0) & np.roll(ground, 2, axis=0)
             & (z <= 80) & (far < 500) & (far-z >= .25) & (gap >= .01) & (jump > 3*slope))
    crest[:2] = False
    crest[-1] = False
    ink = read(name, "ink", crop) > 127
    return ground, crest, gap, ink, z


def near(mask, radius):
    return np.asarray(Image.fromarray(mask.astype(np.uint8)).filter(ImageFilter.MaxFilter(2*radius+1))) > 0


def grey(rgb):
    return np.rint(rgb @ np.array([.299, .587, .114])).astype(np.int16)


def motion(place, last):
    totals = np.zeros((5, 5), dtype=np.int64)
    previous = None
    for tick in range(last-31, last+1):
        name = f"{place}_{tick}"
        ground, crest, _, ink, _ = masks(name, True)
        current = (ground, near(crest, 3), near(ink[:, :, 1], 2), near(ink[:, :, 0], 2),
                   grey(read(name, "beauty", True)), grey(read(name, "noink", True)))
        if previous is not None:
            region = ground & previous[0]
            delta = np.abs(current[4]-previous[4])
            bare = np.abs(current[5]-previous[5])
            def add(i, region):
                flips = (delta > 24) & region
                totals[i] += (region.sum(), delta[region].sum(), flips.sum(), ((bare > 24) & region).sum(),
                              (flips & (bare <= 24)).sum())
            add(0, region)
            for i in range(1, 4):
                feature = current[i] | previous[i]
                add(i, region & feature)
                region = region & ~feature
            add(4, region)
        previous = current
    if totals[0,0] == 0 or np.any(totals[0] != totals[1:].sum(axis=0)):
        raise ValueError("empty or incomplete motion census")
    for label, (n, absolute, flips, bare, extra) in zip(["all", "crest", "crease", "other_outer", "elsewhere"], totals):
        if n == 0:
            print(f"{place} motion {label} pairs=0 empty")
            continue
        print(f"{place} motion {label} pairs={n} mean={absolute/n:.4f} flips={flips} "
              f"pct={100*flips/max(1,n):.5f} noink_flips={bare} crossed_only_with_ink={extra}")


if __name__ == "__main__":
    for place in ("bank", "bluff"):
        log = (here / f"{stage}-{place}.log").read_text(errors="replace")
        if f"TERRAIN_DONE {place} frames=32" not in log or "ERROR:" in log:
            raise ValueError(f"{stage} {place}: capture did not complete cleanly")
    for name in ("bank_310", "bluff_120", "shoulder", "plane"):
        ground, crest, gap, ink, z = masks(name)
        outer = ink[:, :, 0]
        print(name, "crest", int(crest.sum()), "ink", int((crest & outer).sum()),
              "grazing", int((crest & ink[:, :, 2]).sum()))
        for lo, hi in bands:
            sel = crest & (gap >= lo) & (gap < hi)
            print(f"  {100*lo:g}..{100*hi:g}% n={sel.sum()} ink={(sel & outer).sum()} "
                  + (f"covered={100*outer[sel].mean():.2f}% median_z={np.median(z[sel]):.1f}m" if sel.any() else "empty"))
        if name == "plane":
            sel = ground & (z >= 8) & (z <= 80) & ink[:, :, 2]
            sel[:, :10] = sel[:, -10:] = False
            print(f"flat grazing false pixels={(sel & outer).sum()}/{sel.sum()}")
            if sel.sum() < 10000:
                raise ValueError("empty grazing plane control")
    for p,last in [("bank",310), ("bluff",120)]:
        motion(p,last)
