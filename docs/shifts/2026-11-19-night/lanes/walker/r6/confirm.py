"""Cross-check the selected shader against its live render, then compare fixed pixels with r3c."""
import subprocess
import sys

import numpy as np
from PIL import Image

from probe import RAW, run

sys.argv[1:] = ["baseline"]
run("measure", module="measure")
import measure

for stage in ("baseline", "crest_cap", "after"):
    for place in ("bluff", "bank"):
        log = (RAW / f"{stage}-{place}.log").read_text()
        assert f"TERRAIN_DONE {place} frames=32" in log and "ERROR:" not in log

trial = RAW / "captures" / "crest_cap"
live = RAW / "captures" / "after"
names = sorted(p.name for p in trial.glob("*.png"))
assert len(names) == 335 and names == sorted(p.name for p in live.glob("*.png"))
different = [name for name in names if (trial / name).read_bytes() != (live / name).read_bytes()]
print(f"Selected trial vs live production shader: {len(names)-len(different)}/{len(names)} PNGs byte-identical")
for name in different:
    # At the last tick, r3 saves the whole beauty/noink render. Its motion
    # census uses only the same fixed crop as the preceding 31 frames.
    assert name in {f"{view}-{kind}.png" for view in ("bluff_120", "bank_310") for kind in ("beauty", "noink")}
    with Image.open(trial / name) as a, Image.open(live / name) as b:
        diff = np.any(np.asarray(a) != np.asarray(b), axis=2)
    y, x = np.where(diff)
    print(f"{name}: {len(x)} pixels differ, bounds x={x.min()}..{x.max()}, y={y.min()}..{y.max()}")
    assert not diff[555:975, 48:848].any()
print("Every motion sample and full-frame diagnostic agrees")

for stage in ("head", "baseline", "after"):
    data = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(RAW / f"{stage}-bluff-band.mkv"),
                                    "-vf", "format=gray", "-vsync", "0", "-f", "rawvideo", "-"])
    grey = np.frombuffer(data, np.uint8).reshape(32, 90, 240).astype(np.int16)
    delta = np.abs(np.diff(grey, axis=0))
    flips = np.count_nonzero(delta > 24)
    print(f"{stage} bluff: {flips}/{delta.size} flips ({100*flips/delta.size:.6f}%), mean={delta.mean():.6f}")
    if stage == "after":
        assert 100 * flips / delta.size <= 2.010


def channel(stage, view, kind, index):
    with Image.open(RAW / "captures" / stage / f"{view}-{kind}.png") as image:
        return np.asarray(image)[:, :, index]


for view in ("bank_310", "bluff_120", "shoulder", "plane"):
    ground, crest, _, _, _ = measure.masks(view)
    strong = ground & (channel("head", view, "live-weight", 1) > 127)
    old_weight = channel("baseline", view, "live-weight", 0)[strong]
    new_weight = channel("after", view, "live-weight", 0)[strong]
    old_ink = channel("baseline", view, "ink", 0)[crest] > 127
    new_ink = channel("after", view, "ink", 0)[crest] > 127
    print(f"{view}: {np.sum(old_weight != new_weight)}/{strong.sum()} strong opacity codes changed, "
          f"{np.sum(old_ink != new_ink)}/{crest.sum()} crest decisions changed across all gap bands")
    assert strong.any() and new_weight.mean() / 255 >= 0.95
    assert np.array_equal(old_weight, new_weight) and np.array_equal(old_ink, new_ink)
