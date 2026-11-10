"""Placement of every kit part (data/layout.json). Positions are world metres; y comes from the terrain surface."""
import math

import numpy as np

from vox import MATS
import world as W


def surf_y(top_y, x, z, x0, z0, res):
    ix = np.clip(((np.asarray(x) - x0) / res).astype(int), 0, top_y.shape[0] - 1)
    iz = np.clip(((np.asarray(z) - z0) / res).astype(int), 0, top_y.shape[1] - 1)
    return top_y[ix, iz]


def poisson(n, zone, min_d, rng, tries=60000, weight=None, bbox=(-118, -148, 108, 8), occupied=None):
    pts = []
    cell = min_d
    grid = {} if occupied is None else occupied
    for _ in range(tries):
        if len(pts) >= n:
            break
        x = rng.uniform(bbox[0], bbox[2])
        z = rng.uniform(bbox[1], bbox[3])
        if not zone(x, z):
            continue
        if weight is not None and rng.random() > weight(x, z):
            continue
        ci, cj = int(x // cell), int(z // cell)
        ok = True
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                for q in grid.get((ci + di, cj + dj), []):
                    if (q[0] - x) ** 2 + (q[1] - z) ** 2 < min_d * min_d:
                        ok = False
        if ok:
            grid.setdefault((ci, cj), []).append((x, z))
            pts.append((x, z))
    return pts, grid


def outward_normal(tp, i, cen):
    tn = tp[(i + 1) % len(tp)] - tp[(i - 1) % len(tp)]
    tn = tn / np.linalg.norm(tn)
    nrm = np.array([tn[1], -tn[0]])
    if nrm @ (tp[i] - cen) < 0:
        nrm = -nrm
    return tn, nrm


def make_layout(arrs, top_y, org, far_trees):
    X, Z, h, d, s, rd, tp, L, slope, forest, top = arrs
    x0, z0, ymin, res = org
    r = np.random.default_rng(5)
    lay = {}
    ax, az = W.ARENA
    FT = -14.0

    def sy(x, z):
        return float(surf_y(top_y, x, z, x0, z0, res))

    def idx(x, z):
        return int((x - x0) / res), int((z - z0) / res)
    lay["arena"] = {"centre": [ax, FT, az], "ice_y": FT + 0.1,
                    "ribs": [{"x": ax + (i - 3.5) * 8.5, "built": i < 5} for i in range(8)]}
    lay["track"] = {"points": [[round(float(x), 2), W.ROAD_Y, round(float(z), 2)] for x, z in tp[::2]], "length": float(L), "width": 10.0}
    cen = np.array([40.0, -75.0])
    dd = np.hypot(tp[:, 0] - 36.0, tp[:, 1] + 45.0)
    i0 = int(np.argmin(dd))
    # direction of travel along tp: index increasing = clockwise (starts at x=80 heading west)
    blocks = []
    for k in range(12):
        i = (i0 + int(round(k * 2.4 + 1.2))) % len(tp)
        tn, nrm = outward_normal(tp, i, cen)
        c = tp[i] + nrm * 7.3
        blocks.append({"x": float(c[0]), "z": float(c[1]), "yaw": float(math.atan2(-tn[0], -tn[1])), "y": W.ROAD_Y, "tn": [float(tn[0]), float(tn[1])]})
    lay["wall"] = blocks
    lay["wall_station"] = int(i0)
    lay["house"] = {"pos": [30.0, W.HOUSE_Y, -15.0], "frame_pos": [39.4, W.HOUSE_Y, -15.2]}
    lamps = []
    for i in range(7, len(tp), 26):
        tn, nrm = outward_normal(tp, i, cen)
        c = tp[i] + nrm * 8.8
        if math.hypot(c[0] - 24, c[1] + 40) < 16:
            continue
        lamps.append({"x": float(c[0]), "z": float(c[1]), "y": sy(c[0], c[1]), "yaw": float(math.atan2(-nrm[0], -nrm[1]))})
    lay["lamps"] = lamps

    def free(x, z, extra=0.0):
        ix, iz = idx(x, z)
        if ix < 0 or iz < 0 or ix >= d.shape[0] or iz >= d.shape[1]:
            return False
        if d[ix, iz] < 10.5 + extra or rd[ix, iz] < 5.6:
            return False
        if abs(x - ax) < 53 and abs(z - az) < 37:
            return False
        if 10 < x < 58 and -31 < z < -2:
            return False
        if abs(x) < 16 and z > -6:
            return False
        return slope[ix, iz] < 1.2
    forestw = lambda x, z: 0.25 + 0.75 * float(forest[idx(x, z)])
    occ = {}
    oaks, occ = poisson(150, lambda x, z: free(x, z) and sy(x, z) < -10 and z > -112, 5.5, r, weight=forestw, occupied=occ)
    pines, occ = poisson(280, lambda x, z: free(x, z, 1.0) and sy(x, z) < 20, 4.2, r, weight=forestw, occupied=occ)
    trees = []
    for (x, z) in oaks:
        trees.append({"k": "oak%d" % r.integers(1, 5), "x": x, "z": z, "y": sy(x, z), "yaw": float(r.uniform(0, 6.28)), "s": float(r.uniform(0.85, 1.25))})
    for (x, z) in pines:
        trees.append({"k": "pine%d" % r.integers(1, 4), "x": x, "z": z, "y": sy(x, z), "yaw": float(r.uniform(0, 6.28)), "s": float(r.uniform(0.85, 1.35))})
    trees.append({"k": "oak_big", "x": -7.6, "z": -2.6, "y": sy(-7.6, -2.6), "yaw": 0.6, "s": 1.0})
    for (x, z, k) in ((-24, 6, "oak2"), (22, 9, "oak1"), (-34, -1, "pine2"), (30, 3, "pine3"), (-13, 11, "oak3")):
        trees.append({"k": k, "x": x, "z": z, "y": sy(x, z), "yaw": 1.0, "s": 1.1})
    lay["trees"] = trees
    rocks, _ = poisson(70, lambda x, z: (free(x, z) or (3.6 < rd[idx(x, z)] < 9)) and abs(x - ax) > 50, 6.0, r, bbox=(-100, -90, 100, 8))
    lay["rocks"] = [{"k": "rock%d" % r.integers(1, 4), "x": x, "z": z, "y": sy(x, z) - 0.25, "yaw": float(r.uniform(0, 6.28)), "s": float(r.uniform(0.8, 1.6))} for x, z in rocks]
    for (x, z, k, sc) in ((3.0, -4.6, "rock3", 1.7), (6.2, -5.3, "rock2", 1.2), (-2.0, -4.4, "rock1", 1.1), (9.0, -4.2, "rock2", 1.0)):
        lay["rocks"].append({"k": k, "x": x, "z": z, "y": sy(x, z) - 0.25, "yaw": 0.5, "s": sc})
    tufts = []
    for _ in range(3200):
        x = float(r.uniform(-26, 26)); z = float(r.uniform(-14, 14))
        if top[idx(x, z)] not in (MATS("grass"), MATS("grass_dark")) or (abs(x) < 0.5 and abs(z) < 0.5):
            continue
        tufts.append({"k": "tuft%d" % r.integers(1, 3), "x": x, "z": z, "y": sy(x, z), "yaw": float(r.uniform(0, 6.28)), "s": float(r.uniform(0.8, 1.6))})
    for _ in range(2600):
        x = float(r.uniform(-100, 105)); z = float(r.uniform(-110, -2))
        if not free(x, z, -3.0) or top[idx(x, z)] not in (MATS("grass"), MATS("grass_dark")):
            continue
        tufts.append({"k": "tuft%d" % r.integers(1, 3), "x": x, "z": z, "y": sy(x, z), "yaw": float(r.uniform(0, 6.28)), "s": float(r.uniform(0.8, 1.7))})
    lay["tufts"] = tufts
    lay["far_trees"] = far_trees
    return lay
