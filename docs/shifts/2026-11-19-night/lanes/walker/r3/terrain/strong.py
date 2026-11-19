"""Measure the same HEAD-selected terrain silhouettes in all three versions."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

sys.argv = [sys.argv[0], "head"]
import measure

stages = ("head", "r3b", "after")
for s in stages:
    for place in ("bank", "bluff"):
        log = (measure.here / f"{s}-{place}.log").read_text(errors="replace")
        if f"TERRAIN_DONE {place} frames=32" not in log or "ERROR:" in log:
            raise ValueError(f"{s} {place} incomplete")

base = measure.here / "captures"
for name, x, y in [("bank_310", 1200, 380), ("bluff_120", 480, 565), ("shoulder", 120, 260), ("plane", 0, 0)]:
    ground, crest, gap, _, _ = measure.masks(name)
    for kind in ("depth", "removed"):
        ref = (base / "head" / f"{name}-{kind}.png").read_bytes()
        if any((base / s / f"{name}-{kind}.png").read_bytes() != ref for s in stages):
            raise ValueError(f"unmatched {name} geometry")
    weights = [np.asarray(Image.open(base / s / f"{name}-live-weight.png")) for s in stages]
    # The head shader sets green by thresholding *before* its continuous opacity is quantized.
    strong = ground & (weights[0][:, :, 1] > 127)
    if not strong.any():
        raise ValueError(f"{name}: no strong HEAD terrain silhouette")
    crop = np.zeros_like(ground)
    crop[y:y+194, x:x+420] = True
    for label, mask in [("terrain", strong), ("review crop", strong & crop), ("crest", strong & crest)]:
        print(f"{name} {label} HEAD_pixels={mask.sum()}", end="")
        for s, image in zip(stages, weights):
            if mask.any():
                alpha = image[:, :, 0][mask] / 255.
                retained = (image[:, :, 1][mask] > 127).mean()
                print(f" {s} mean={alpha.mean():.4f} retained={retained:.2%}", end="")
                if s == "after" and (alpha.mean() < 0.9 or retained != 1):
                    raise ValueError(f"{name} {label}: lost a strong HEAD silhouette")
        print()
