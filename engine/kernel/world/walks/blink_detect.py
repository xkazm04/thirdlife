"""Walker-feel T1: find blinks in a folder of per-frame pictures (boot.gd TL_EXE_FRAMES).

    python blink_detect.py <frames dir> [--min=<px>] [--json] [--skymask]

--skymask: the capture ran with boot.gd TL_EXE_SKYMASK=1 (magenta = nothing drawn). Without it the mask is recognised
by its magenta (more than 50 pixels in some picture); a mask capture that looks down at the ground nearly all the time
may show less sky than that, and then only --skymask keeps the court from being read as sky. Pictures may change size.

A blink is a patch of the picture that shows sky (or anything else) for a few frames where the frames before and
after agree on something else. Two tests per frame t, on the picture at half size:
  a patch (3x3 eroded) whose colour at t is far from t-k and t+k (k = 1..4) while t-k and t+k agree:
  something shown for 1 to 4 frames where the frames around it agree (sky through the ground, a pop, a flash).
A second test needs no neighbours: sky-coloured patches below the horizon (from the camera's pitch and fov in
frames.jsonl) are a hole in the ground in that frame ("HOLE" lines).
The key line at the bottom and the build tag in the top right corner are masked. Prints one line per frame with
an event (the count, the box, the camera from frames.jsonl) and a last line with the totals, `"report": "blinks"`.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image


HORIZON_MARGIN = 8     # rows (of the half-size picture) below the horizon before sky counts as a hole


def load(path, scale):
    im = Image.open(path).convert("RGB")
    if scale != 1:
        im = im.resize((im.width // scale, im.height // scale), Image.BILINEAR)
    return np.asarray(im)


def sky(a):
    a = a.astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (b > 110) & (b * 100 > r * 62) & (b + 10 > g * 0.85)


def magenta(a):
    a = a.astype(np.int32)
    return (a[..., 0] > 190) & (a[..., 1] < 70) & (a[..., 2] > 190)


def erode(a):
    """a pixel stays when it and its eight neighbours are all set: single pixels and edges of moving things go"""
    o = a.copy()
    o[1:, :] &= a[:-1, :]
    o[:-1, :] &= a[1:, :]
    o[:, 1:] &= a[:, :-1]
    o[:, :-1] &= a[:, 1:]
    o[1:, 1:] &= a[:-1, :-1]        # the four diagonals too (bugfix-37: a 5-pixel cross passed a 4-neighbour test)
    o[1:, :-1] &= a[:-1, 1:]
    o[:-1, 1:] &= a[1:, :-1]
    o[:-1, :-1] &= a[1:, 1:]
    return o


def main():
    d = sys.argv[1]
    min_px = 12
    as_json = False
    force_mask = False
    for a in sys.argv[2:]:
        if a.startswith("--min="):
            min_px = int(a.split("=", 1)[1])
        elif a == "--json":
            as_json = True
        elif a == "--skymask":
            force_mask = True
    cams = {}
    fl = os.path.join(d, "frames.jsonl")
    if os.path.exists(fl):
        for line in open(fl):
            try:
                j = json.loads(line)
                cams[j.get("n", j["frame"])] = j
            except Exception:
                pass
    names = sorted(n for n in os.listdir(d) if n.startswith("f") and (n.endswith(".png") or n.endswith(".raw")))
    frames = [int(n[1:6]) for n in names]
    imgs = []
    for n, k in zip(names, frames):
        if n.endswith(".raw"):
            wh = cams[k]["size"]
            a = np.fromfile(os.path.join(d, n), np.uint8).reshape(wh[1], wh[0], 3)
            imgs.append(np.ascontiguousarray(a[::2, ::2]) if wh[0] > 500 else a)
        else:
            imgs.append(load(os.path.join(d, n), 2))
    if not imgs:
        print("no pictures in %s" % d)
        sys.exit(2)
    # A capture may change size mid-run (a window resized; each picture's size is in frames.jsonl): every picture gets the
    # mask of its own size, and pictures of different sizes are never compared (a cut, like a gap in the frame numbers).
    def mask_of(shape):
        m = np.ones(shape, bool)
        m[int(shape[0] * 0.90):, :] = False                       # the key line
        m[: int(shape[0] * 0.05), int(shape[1] * 0.85):] = False  # the build tag
        return m

    def same_size(*ts):
        return all(imgs[t].shape == imgs[ts[0]].shape for t in ts)

    # boot.gd TL_EXE_SKYMASK=1 paints every pixel where nothing was drawn magenta: then "sky" is exact. --skymask says so;
    # without it the mask is recognised by its magenta, more than 50 pixels in any picture (every one, not one in twenty).
    painted = force_mask or any(int(magenta(a).sum()) > 50 for a in imgs)
    skies = [(magenta(a) if painted else sky(a)) & mask_of(a.shape[:2]) for a in imgs]
    events = []
    K = 4
    for t in range(1, len(imgs) - 1):
        h, w = imgs[t].shape[:2]
        mask = mask_of((h, w))
        c = imgs[t].astype(np.int16)
        ev = np.zeros((h, w), bool)
        for k in range(1, K + 1):
            if t - k < 0 or t + k >= len(imgs):
                break
            if frames[t] - frames[t - k] != k or frames[t + k] - frames[t] != k or not same_size(t, t - k, t + k):
                break
            p, n = imgs[t - k].astype(np.int16), imgs[t + k].astype(np.int16)
            a = (np.abs(c - p).sum(-1) > 100) & (np.abs(c - n).sum(-1) > 100) & (np.abs(n - p).sum(-1) < 45)
            ev |= erode(a)
        ev &= mask
        nf = int(ev.sum())
        if nf >= min_px:
            ys, xs = np.nonzero(ev)
            ns = int((ev & skies[t]).sum())
            e = {"n": frames[t], "frame": cams.get(frames[t], {}).get("frame", frames[t]), "px": nf, "sky_px": ns,
                 "box": [int(xs.min()) * 2, int(ys.min()) * 2, int(xs.max()) * 2, int(ys.max()) * 2]}
            cj = cams.get(frames[t])
            if cj:
                for k in ("cam", "look", "player", "stage"):
                    if k in cj:
                        e[k] = cj[k]
            events.append(e)
    # the second test: sky below the horizon (the camera does not roll; the horizon row follows from its pitch and fov)
    holes = []
    for t in range(len(imgs)):
        cj = cams.get(frames[t])
        if not cj or "look" not in cj or "fov" not in cj:
            continue
        h = imgs[t].shape[0]
        pitch = math.asin(max(-1.0, min(1.0, cj["look"][1])))
        f = (h / 2.0) / math.tan(math.radians(cj["fov"]) / 2.0)
        y_h = int(h / 2.0 + math.tan(pitch) * f) + HORIZON_MARGIN
        if y_h >= h:
            continue
        below = skies[t].copy()
        below[: max(0, y_h), :] = False
        below = erode(below)
        nb = int(below.sum())
        if nb >= min_px:
            ys, xs = np.nonzero(below)
            holes.append({"n": frames[t], "frame": cj.get("frame"), "hole_px": nb, "horizon_row": y_h * 2,
                          "box": [int(xs.min()) * 2, int(ys.min()) * 2, int(xs.max()) * 2, int(ys.max()) * 2],
                          "cam": cj.get("cam"), "look": cj.get("look"), "stage": cj.get("stage")})
    # the third test (exact with the sky mask): nothing drawn at t, for 1 to 6 frames, where the frames around agree
    # that something was drawn: a blink of dead space
    blinks = []
    for t in range(1, len(imgs) - 1):
        h, w = imgs[t].shape[:2]
        ev = np.zeros((h, w), bool)
        for k in range(1, 7):
            if t - k < 0 or t + k >= len(imgs) or frames[t] - frames[t - k] != k or frames[t + k] - frames[t] != k                     or not same_size(t, t - k, t + k):
                break
            ev |= skies[t] & ~skies[t - k] & ~skies[t + k]
        cj = cams.get(frames[t], {})
        if "look" in cj and "fov" in cj:      # below the horizon only: above it a flag or a branch uncovers real sky
            pitch = math.asin(max(-1.0, min(1.0, cj["look"][1])))
            y_h = int(h / 2.0 + math.tan(pitch) * (h / 2.0) / math.tan(math.radians(cj["fov"]) / 2.0)) + HORIZON_MARGIN
            ev[: max(0, min(h, y_h)), :] = False
        ev = erode(ev)
        nb = int(ev.sum())
        if nb >= min_px:
            ys, xs = np.nonzero(ev)
            cj = cams.get(frames[t], {})
            blinks.append({"n": frames[t], "frame": cj.get("frame"), "blink_px": nb,
                           "box": [int(xs.min()) * 2, int(ys.min()) * 2, int(xs.max()) * 2, int(ys.max()) * 2],
                           "cam": cj.get("cam"), "look": cj.get("look"), "stage": cj.get("stage")})
    for e in blinks:
        print(json.dumps(e) if as_json else "BLINK n %5d frame %5d px %5d box %s cam %s look %s" % (
            e["n"], e["frame"], e["blink_px"], e["box"], e.get("cam"), e.get("look")))
    for e in holes:
        print(json.dumps(e) if as_json else "HOLE n %5d frame %5d px %5d box %s cam %s look %s" % (
            e["n"], e["frame"], e["hole_px"], e["box"], e.get("cam"), e.get("look")))
    for e in events:
        print(json.dumps(e) if as_json else "n %5d frame %5d px %5d sky %5d box %s cam %s look %s" % (
            e["n"], e["frame"], e["px"], e["sky_px"], e["box"], e.get("cam"), e.get("look")))
    print(json.dumps({"report": "blinks", "dir": d, "frames": len(imgs), "first": frames[0], "last": frames[-1],
                      "events": len(events), "sky_mask": painted, "blink_frames": len(blinks), "blink_px_max": max([e["blink_px"] for e in blinks] or [0]), "hole_frames": len(holes), "hole_px_max": max([e["hole_px"] for e in holes] or [0]), "sky_events": sum(1 for e in events if e["sky_px"] * 2 >= e["px"])}))


if __name__ == "__main__":
    main()
