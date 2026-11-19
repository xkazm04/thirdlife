"""Windowed capture readout. One inner 4-connected contour pixel = one vote."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

out = Path(__file__).resolve().parent / sys.argv[1]


def read(place, kind):
    return np.array(Image.open(out / f"{place}-{kind}.png").convert("RGB"))


def depth(place, kind):
    rgb = read(place, kind)
    # Each nibble is encoded as one of 16 sRGB values 17 apart.
    digits = np.rint(rgb / 17).astype(np.int32)
    return digits @ np.array([256, 16, 1])


def coverage(pixels, ink):
    count = pixels.sum()
    return f"{100 * ink[pixels].mean():.2f}%({count})" if count else "empty"


expected = {"bank", "behind", "behind_wall", "bluff", "frozen", "grazing", "side", "side_wall", "three", "three_wall"}
if out.name == "plane":
    expected = {"bank", "behind_wall", "grazing"}
paths = sorted(out.glob("*-signal.png"))
if {p.name.removesuffix("-signal.png") for p in paths} != expected:
    raise ValueError(f"{out}: incomplete or unexpected view set")
for path in paths:
    place = path.name.removesuffix("-signal.png")
    signal = read(place, "signal") > 127
    ink = signal[:, :, 1]
    if place == "grazing":
        # Empty part of the concrete review floor, slightly below the horizon.
        roi = np.s_[585:655, 820:1100]
        print(place, "outer", coverage(np.ones_like(ink[roi]), ink[roi]),
              "graze<=.20", coverage(np.ones_like(ink[roi]), signal[:, :, 2][roi]))
        continue
    # Any other rig (and the roughness clear value on sky) is present in both images.
    gap = depth(place, "back") - depth(place, "front")
    body = signal[:, :, 0] & ((gap > 0) | (read(place, "hidden")[:, :, 0] < 128))
    padded = np.pad(body, 1)
    edge = body & ~(padded[1:-1, :-2] & padded[1:-1, 2:] & padded[:-2, 1:-1] & padded[2:, 1:-1])
    if edge.sum() < 100:
        raise ValueError(f"{place}: missing figure ({edge.sum()} edge pixels)")
    grazing = signal[:, :, 2]
    print(place, "all", coverage(edge, ink), "gap<0.5m", coverage(edge & (gap < 50), ink),
          "0.5-2m", coverage(edge & (gap >= 50) & (gap < 200), ink),
          ">=2m", coverage(edge & (gap >= 200), ink),
          "graze<=.20", coverage(edge & grazing, ink), "graze>.20", coverage(edge & ~grazing, ink))
