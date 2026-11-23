#!/usr/bin/env python3
"""Reads the same pixel patches in thirdjam's game still, thirdjam's scene capture and ours, for a list of named spots
of one pose, and prints their mean sRGB: the numbers the eye's comparison is held to.
usage: python probe_pixels.py <game.png> <capture.png> <ours.png> name:x,y [name:x,y ...]   (1280 x 720 pixels, 13 px patches)"""
import sys

import numpy as np
from PIL import Image


def patch(path, x, y, r=6):
    im = np.array(Image.open(path).convert("RGB").resize((1280, 720))).astype(float)
    return [int(round(v)) for v in im[y - r:y + r + 1, x - r:x + r + 1].reshape(-1, 3).mean(axis=0)]


paths = sys.argv[1:4]
print("%-16s %-18s %-18s %-18s" % ("spot", "game", "capture", "ours"))
for a in sys.argv[4:]:
    name, xy = a.split(":")
    x, y = [int(v) for v in xy.split(",")]
    print("%-16s %-18s %-18s %-18s" % (name, *[str(patch(p, x, y)) for p in paths]))
