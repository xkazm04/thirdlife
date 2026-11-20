"""Compare native RGB8 sequences from exe-motion.mjs. Run with two or more profile-route directories."""
import json
import sys
from pathlib import Path

import numpy as np

CROPS = {
    "mid": (0, 300, 1920, 620),
    "fence": (1080, 310, 1450, 470),
    "near": (0, 700, 1920, 1040),
    "figure": (840, 570, 1080, 1000),
}
CAMERA = ("frame", "size", "stage", "cam", "look", "fov", "player")


def measure(directory):
    records = [json.loads(line) for line in (directory / "frames.jsonl").read_text().splitlines()]
    if len(records) != 61 or any(r["n"] != i or r["frame"] != 100 + i for i, r in enumerate(records)):
        raise ValueError(f"{directory} needs consecutive physics ticks 100 through 160")
    rows = {name: [] for name in CROPS}
    previous = None
    for record in records:
        if record["size"] != [1920, 1080]:
            raise ValueError(f"{directory} contains a non-native frame")
        file = directory / ("f%05d.raw" % record["n"])
        rgb = np.fromfile(file, dtype=np.uint8).reshape(1080, 1920, 3).astype(np.float32)
        y = .2126 * rgb[:, :, 0] + .7152 * rgb[:, :, 1] + .0722 * rgb[:, :, 2]
        for name, (left, top, right, bottom) in CROPS.items():
            if previous is None:
                continue
            band = y[top:bottom, left:right]
            change = np.abs(band - previous[top:bottom, left:right])
            lap = (band[1:-1, :-2] + band[1:-1, 2:] + band[:-2, 1:-1] + band[2:, 1:-1]
                   - 4 * band[1:-1, 1:-1])
            rows[name].append((change.mean(), 100 * (change > 24).mean(), lap.var()))
        previous = y
    print(directory.name)
    for name, values in rows.items():
        mean, flips, sharp = np.mean(values, axis=0)
        print(f"  {name}: mean {mean:.3f}/255, flips {flips:.3f}%, Laplacian variance {sharp:.1f}")
    return [[r[key] for key in CAMERA] for r in records]


if __name__ == "__main__":
    paths = [Path(arg) for arg in sys.argv[1:]]
    if len(paths) < 2:
        sys.exit("Pass two or more capture directories for the same route")
    reference = measure(paths[0])
    for path in paths[1:]:
        if measure(path) != reference:
            sys.exit(f"Camera, player, stage or frame mismatch in {path}")
    print("All 61 logged camera poses, player positions and stages agree at log precision.")
