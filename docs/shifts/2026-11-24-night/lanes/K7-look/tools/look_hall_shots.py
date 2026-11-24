"""Shots for engine/cores/rink/arena/review/figure_view.tscn from stills of thirdjam's running game.
  python look_hall_shots.py <game.log with JAMCAM lines> <spec.json> <out shots.json>
spec: [{"name": "f2400", "frame": 2400, "human": {"team": 0, "number": 7, "clip": "Stride", "key": 0},
        "others": [{"px": [x, y], "team": 1, "number": 21, "yaw": 180, "clip": "Stride", "key": 10}, ...]}, ...]
The camera of a frame and the human's place and facing are thirdjam's own log (jam.camera.Log 1: fcx fcy fh fyaw fpitch,
px py hyaw). Another figure is placed where the ray through the pixel of its feet (in the 1280 x 720 still) meets the
ice; its facing is the spec's (by eye). Horizontal field of view 70 degrees (hockey.regular.cartridge.json:255)."""
import json
import math
import re
import sys

log, spec_path, out = sys.argv[1:4]
rows = {}
for line in open(log, encoding="utf-8", errors="replace"):
    if "JAMCAM" in line:
        d = dict(m.groups() for m in re.finditer(r"(\w+)=(-?[\d.]+)", line))
        rows[int(float(d["frame"]))] = {k: float(v) for k, v in d.items()}
T = math.tan(math.radians(35.0))


def ground(cam, px):
    yaw, pitch = math.radians(cam["fyaw"]), math.radians(cam["fpitch"])
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    fwd = (cy * cp, sy * cp, sp)              # Unreal: x, y, up
    right = (-sy, cy, 0.0)
    up = (-cy * sp, -sy * sp, cp)
    a = (px[0] / 640.0 - 1.0) * T
    b = (1.0 - px[1] / 360.0) * T * 720.0 / 1280.0
    d = [fwd[i] + right[i] * a + up[i] * b for i in range(3)]
    t = -cam["fh"] / d[2]
    return [round(cam["fcx"] + d[0] * t, 3), round(cam["fcy"] + d[1] * t, 3)]


shots = []
for s in json.load(open(spec_path, encoding="utf-8")):
    cam = rows[int(s["frame"])]
    figs = []
    if "human" in s:
        h = dict(s["human"])
        h["at"] = [cam["px"], cam["py"], cam["hyaw"]]
        figs.append(h)
    for o in s.get("others", []):
        f = {k: v for k, v in o.items() if k not in ("px", "yaw")}
        g = ground(cam, o["px"])
        f["at"] = [g[0], g[1], o.get("yaw", 0.0)]
        figs.append(f)
    shots.append({"name": s["name"], "cam": [cam["fcx"], cam["fcy"], cam["fh"], cam["fyaw"], cam["fpitch"]], "figures": figs})
    print(s["name"], "camera", shots[-1]["cam"], "figures", [f["at"] for f in figs])
json.dump(shots, open(out, "w", encoding="utf-8"), indent=1)
