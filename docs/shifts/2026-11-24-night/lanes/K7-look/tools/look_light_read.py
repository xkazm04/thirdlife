"""Reads the light probe (look_light_probe.py: thirdjam's figure in Unreal, HDR scene colour as Radiance .hdr files, one
per shot and variant) against ours (look_gym.tscn --mode=shots --linear=K: PNG files holding K times the same quantity).
  python look_light_read.py <probe dir> <ours dir> <K> <gym_rig.json>
Prints, per shot and box, the median linear RGB of every variant and of ours, and what the two grey cards should read
under the rig's spots alone (0.5 x lux / pi, from the rig's own numbers)."""
import json
import math
import statistics
import struct
import sys

from PIL import Image


def read_hdr(path):
    f = open(path, "rb")
    while True:
        line = f.readline()
        if line.strip() == b"":
            break
    dims = f.readline().split()
    h, w = int(dims[1]), int(dims[3])
    flip_y = dims[0] == b"+Y"
    data = f.read()
    out = [[None] * w for _ in range(h)]
    pos = 0
    for y in range(h):
        if data[pos] == 2 and data[pos + 1] == 2 and ((data[pos + 2] << 8) | data[pos + 3]) == w:
            pos += 4
            chans = []
            for _c in range(4):
                row = bytearray()
                while len(row) < w:
                    n = data[pos]
                    pos += 1
                    if n > 128:
                        row.extend(bytes([data[pos]]) * (n - 128))
                        pos += 1
                    else:
                        row.extend(data[pos:pos + n])
                        pos += n
                chans.append(row)
            rgbe = [(chans[0][x], chans[1][x], chans[2][x], chans[3][x]) for x in range(w)]
        else:
            rgbe = [tuple(data[pos + 4 * x:pos + 4 * x + 4]) for x in range(w)]
            pos += 4 * w
        out[h - 1 - y if flip_y else y] = rgbe
    return w, h, out


def lin_hdr(px):
    r, g, b, e = px
    if e == 0:
        return (0.0, 0.0, 0.0)
    k = math.ldexp(1.0, e - 136)
    return (r * k, g * k, b * k)


def s2l(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def med(vals):
    return tuple(statistics.median(v[i] for v in vals) for i in range(3))


def rig_lux(rig, p, n):
    e = [0.0, 0.0, 0.0]
    for l in rig["lights"]:
        d = [p[i] - l["pos"][i] for i in range(3)]
        r = math.sqrt(sum(v * v for v in d))
        if r >= l["radius_m"]:
            continue
        w = [v / r for v in d]
        co, ci = math.cos(math.radians(l["outer_deg"])), math.cos(math.radians(l["inner_deg"]))
        cone = min(1.0, max(0.0, (sum(w[i] * l["dir"][i] for i in range(3)) - co) / max(ci - co, 1e-5)))
        win = min(1.0, max(0.0, 1.0 - (r / l["radius_m"]) ** 4))
        ndl = max(0.0, -sum(n[i] * w[i] for i in range(3)))
        for i in range(3):
            e[i] += s2l(l["color_srgb8"][i]) * l["candela"] * cone * cone * win * win * ndl / (r * r)
    return e


probe_dir, ours_dir, K, rig_path = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
rep = json.load(open(probe_dir + "/probe.json", encoding="utf-8"))
rig = json.load(open(rig_path, encoding="utf-8"))
for name, p in (("card_left", [0.6, 0.02, -0.9]), ("card_right", [0.6, 0.02, 0.9])):
    e = rig_lux(rig, p, [0.0, 1.0, 0.0])
    print("expected %s under the spots alone: %s" % (name, " ".join("%.3f" % (0.5 * v / math.pi) for v in e)))
for shot in rep["shots"]:
    stem = "%s_k%03d_%s" % (shot["clip"], int(shot["key"]), shot["cam"])
    team = int(shot.get("team", 0))
    hdr = {}
    for v in "ABCDE":
        try:
            hdr[v] = read_hdr("%s/%s_t%d_%s.hdr" % (probe_dir, stem, team, v))
        except Exception as ex:  # noqa: BLE001
            print("no hdr", v, ex)
    try:
        ours = Image.open("%s/t%d/%s.png" % (ours_dir, team, stem)).convert("RGB")
    except Exception:  # noqa: BLE001
        ours = None
    print("== %s team %d (stale %s)" % (shot["cam"], team, shot.get("stale")))
    boxes = shot["boxes_px"]["A"]
    for name in sorted(boxes):
        b = boxes[name]
        row = []
        for v in "ABCDE":
            if v in hdr:
                w, h, px = hdr[v]
                m = med([lin_hdr(px[y][x]) for y in range(b[1], b[3]) for x in range(b[0], b[2])])
                row.append("%s %.3f %.3f %.3f" % (v, m[0], m[1], m[2]))
        if ours is not None and not name.startswith("card"):
            m = med([tuple(s2l(c) / K for c in ours.getpixel((x, y))) for y in range(b[1], b[3]) for x in range(b[0], b[2])])
            row.append("OURS %.3f %.3f %.3f" % (m[0], m[1], m[2]))
        print("  %-14s %s" % (name, " | ".join(row)))
