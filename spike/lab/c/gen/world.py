"""World generator: terrain heightfield -> voxel columns -> chunked greedy meshes (tier0 0.5 m near, tier1 2 m far),
track spline, river, collision heightmap and data/layout.json (placements of every kit part)."""
import json
import math
import os
import time

import numpy as np

import vox
from vox import MATS

ROOT = vox.ROOT
rng = np.random.default_rng(42)

# ------------------------------------------------------------------ small helpers
def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def vnoise(x, z, scale, seed):
    """Cheap value noise (bilinear on a hashed lattice), range 0..1."""
    r = np.random.default_rng(seed)
    n = 256
    lat = r.random((n, n))
    u = x / scale
    v = z / scale
    iu = np.floor(u).astype(int)
    iv = np.floor(v).astype(int)
    fu = smooth(u - iu)
    fv = smooth(v - iv)
    a = lat[iu % n, iv % n]
    b = lat[(iu + 1) % n, iv % n]
    c = lat[iu % n, (iv + 1) % n]
    d = lat[(iu + 1) % n, (iv + 1) % n]
    return (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv


def fbm(x, z, scale, seed, oct=4):
    s = 0
    amp = 1.0
    tot = 0
    for o in range(oct):
        s = s + amp * vnoise(x, z, scale / (2 ** o), seed + o * 17)
        tot += amp
        amp *= 0.5
    return s / tot


def catmull(pts, n_per=24, closed=True):
    pts = np.array(pts, float)
    out = []
    N = len(pts)
    for i in range(N if closed else N - 1):
        p0, p1, p2, p3 = pts[(i - 1) % N], pts[i % N], pts[(i + 1) % N], pts[(i + 2) % N]
        for t in np.linspace(0, 1, n_per, endpoint=False):
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return np.array(out)


def dist_to_polyline(X, Z, poly, closed=False):
    """min distance + arc-length param of nearest point (poly: (n,2))."""
    best = np.full(X.shape, 1e9)
    bests = np.zeros(X.shape)
    acc = 0.0
    n = len(poly)
    segs = n if closed else n - 1
    for i in range(segs):
        a = poly[i]
        b = poly[(i + 1) % n]
        d = b - a
        L2 = float(d @ d)
        L = math.sqrt(L2)
        t = np.clip(((X - a[0]) * d[0] + (Z - a[1]) * d[1]) / L2, 0, 1)
        px = a[0] + t * d[0]
        pz = a[1] + t * d[1]
        dd = np.hypot(X - px, Z - pz)
        m = dd < best
        best = np.where(m, dd, best)
        bests = np.where(m, acc + t * L, bests)
        acc += L
    return best, bests


# ------------------------------------------------------------------ world constants
FLOOR = -14.0
WATER = -14.65
ROAD_Y = -12.0
HOUSE_Y = -10.0
ARENA = (-40.0, -75.0)

# track polygon (clockwise seen from above, north = -z). Corner B at ~(28,-42) is the walled bend nearest the avatar.
TRACK_PTS = [(80, -45), (56, -44), (32, -45), (14, -55), (6, -74), (10, -96), (24, -119), (52, -126), (80, -121), (96, -106),
             (86, -90), (76, -84), (75, -70), (86, -64), (94, -54)]


def track_poly():
    p = catmull(TRACK_PTS, 20, True)
    # resample at 1 m
    seg = np.hypot(*(np.roll(p, -1, 0) - p).T)
    s = np.concatenate([[0], np.cumsum(seg)])
    L = s[-1]
    n = int(L)
    ss = np.linspace(0, L, n, endpoint=False)
    pp = np.concatenate([p, p[:1]])
    x = np.interp(ss, s, pp[:, 0])
    z = np.interp(ss, s, pp[:, 1])
    return np.stack([x, z], 1), L


RIVER = [(-130, -26), (-90, -30), (-60, -27), (-30, -30), (-6, -28), (16, -31), (40, -30), (66, -28), (96, -31), (130, -27)]


def height_fn(X, Z, extra=None):
    """Continuous (un-quantised) ground height + masks."""
    # ridge: plateau at y=0 for z >= -2 stepping down in ledges to the valley floor
    t = np.clip((-2.0 - Z) / 20.0, 0, 1)
    sc = t * 3.0
    st = (np.floor(sc) + smooth((sc - np.floor(sc) - 0.55) / 0.45)) / 3.0
    st = np.where(t >= 1, 1.0, st)
    h = FLOOR * st + 0.9 * fbm(X, Z, 22, 3, 3) * st + 1.0 * (fbm(X, Z, 18, 11, 3) - 0.5) * (1 - st)
    # terrace under the house (x 17..48, z -27..-3) at HOUSE_Y
    box = smooth((np.minimum(X - 15.0, 50.0 - X)) / 5.0) * smooth((np.minimum(Z + 26.5, -2.5 - Z)) / 5.0)
    h = h * (1 - box) + HOUSE_Y * box
    # arena pad flat at FLOOR
    padx = smooth((46.0 - np.abs(X - ARENA[0])) / 8.0)
    padz = smooth((31.0 - np.abs(Z - ARENA[1])) / 8.0)
    pad = padx * padz
    h = h * (1 - pad) + FLOOR * pad
    # mountains: back (z<-105), left (x<-105), right (x>100)
    mz = smooth((-105.0 - Z) / 70.0)
    mxl = smooth((-95.0 - X) / 55.0)
    mxr = smooth((X - 98.0) / 50.0)
    mm = np.maximum(mz, np.maximum(mxl, mxr))
    ridgey = 0.55 + 0.45 * fbm(X, Z, 38, 21, 4)
    peak = 52.0 * ridgey * mm ** 1.15 + 14.0 * fbm(X, Z, 9, 33, 3) * mm
    h = h + peak
    return h


def build_heights(x0, z0, nx, nz, res):
    xs = x0 + (np.arange(nx) + 0.5) * res
    zs = z0 + (np.arange(nz) + 0.5) * res
    X, Z = np.meshgrid(xs, zs, indexing="ij")
    return X, Z


def terrain(res=0.5, x0=-120.0, z0=-150.0, x1=110.0, z1=45.0, ymin=-23.0, ymax=40.0, name="terrain0", skip=None, lower=0.0, vs_name=None):
    t0 = time.time()
    nx, nz = int((x1 - x0) / res), int((z1 - z0) / res)
    X, Z = build_heights(x0, z0, nx, nz, res)
    h = height_fn(X, Z)
    # track corridor
    tp, L = track_poly()
    d, s = dist_to_polyline(X, Z, tp, closed=True)
    w_road = 1 - smooth((d - 6.5) / 9.0)
    h = h * (1 - w_road) + ROAD_Y * w_road
    # river carve
    rv = np.array(RIVER, float)
    # meander jitter
    rd, rs = dist_to_polyline(X, Z, rv)
    rd = rd + 1.4 * np.sin(rs * 0.11) + 0.8 * np.sin(rs * 0.27 + 1.0)
    chan = 1 - smooth((rd - 2.6) / 3.2)
    bed = -16.2
    h = np.where(chan > 0.02, h * (1 - chan) + bed * chan, h)
    water_mask = (rd < 3.1) & (h < WATER - 0.2)
    # quantise to voxel layers
    hq = np.ceil((h - ymin) / res - 1e-6).astype(int) - 1      # top voxel index
    hq = np.clip(hq, 1, int((ymax - ymin) / res) - 1)
    top_y = ymin + (hq + 1) * res                    # world y of the surface
    ny = int((ymax - ymin) / res)
    # slope / material fields
    slope = np.zeros(hq.shape)
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(hq, (dx, dz), (0, 1))
        slope = np.maximum(slope, np.abs(hq - sh) * res)
    hy = top_y
    snow = hy > 22 + 5 * fbm(X, Z, 12, 5, 3)
    rock = (hy > 7.0) | (slope > 1.6)
    forest = fbm(X, Z, 30, 8, 3) > 0.52
    top = np.full(hq.shape, MATS("grass"), np.uint8)
    top = np.where(forest, MATS("grass_dark"), top).astype(np.uint8)
    top = np.where(rock, np.where(fbm(X, Z, 6, 4, 2) > 0.5, MATS("stone"), MATS("stone_dark")), top).astype(np.uint8)
    top = np.where(hy > 14.0, np.where(fbm(X, Z, 5, 9, 2) > 0.45, MATS("mountain"), MATS("stone_dark")), top).astype(np.uint8)
    top = np.where(snow, MATS("snow"), top).astype(np.uint8)
    # sand around water level
    sandy = (hy < WATER + 0.9) & (hy > WATER - 3) & (np.abs(rd) < 5.6)
    top = np.where(sandy, MATS("sand"), top).astype(np.uint8)
    # arena pad: dirt, concrete slab under rink
    padmask = (np.abs(X - ARENA[0]) < 49) & (np.abs(Z - ARENA[1]) < 33) & (np.abs(hy - FLOOR) < 0.8)
    dirt_noise = fbm(X, Z, 4, 77, 2)
    top = np.where(padmask, np.where(dirt_noise > 0.62, MATS("sand"), MATS("dirt")), top).astype(np.uint8)
    slab = (np.abs(X - ARENA[0]) < 34) & (np.abs(Z - ARENA[1]) < 17.5)
    top = np.where(slab & padmask, MATS("concrete_dark"), top).astype(np.uint8)
    # house terrace + yard: dirt path
    # road
    in_road = d < 5.0
    curb = (d >= 5.0) & (d < 6.2)
    cb = ((s / 2.0).astype(int) % 2 == 0)
    top = np.where(curb, np.where(cb, MATS("curb_red"), MATS("curb_white")), top).astype(np.uint8)
    top = np.where(in_road, MATS("asphalt"), top).astype(np.uint8)
    # dashed centre line + edge lines
    dash = in_road & (np.abs(d) < 0.3) & ((s / 4.0).astype(int) % 2 == 0)
    top = np.where(dash, MATS("road_line"), top).astype(np.uint8)
    edge = in_road & (d > 4.1) & (d < 4.5)
    top = np.where(edge, MATS("road_line"), top).astype(np.uint8)
    # gravel verge (dirt) just outside curb
    verge = (d >= 6.2) & (d < 8.0) & (slope < 1.0)
    top = np.where(verge, np.where(fbm(X, Z, 3, 6, 2) > 0.45, MATS("dirt"), MATS("grass_dark")), top).astype(np.uint8)

    # ---- fill 3D
    G = np.zeros((nx, ny, nz), np.uint8)
    kk = np.arange(ny)[None, :, None]
    depth = hq[:, None, :] - kk                                   # 0 = surface voxel
    matc = np.where(depth <= 0, top[:, None, :], np.where(depth <= 2, MATS("dirt"), MATS("stone")))
    # stone below, dirt in the middle; road/pad keep top mat only (surface)
    solid = depth >= 0
    G[solid] = matc[solid].astype(np.uint8)
    # water
    wl = int(math.floor((WATER - ymin) / res))
    for k in range(ny):
        pass
    wmask = water_mask[:, None, :] & (kk > hq[:, None, :]) & (kk <= wl)
    G[wmask] = MATS("water")
    if skip is not None:
        sx0, sx1, sz0, sz1 = skip   # tier-1 only: hollow out (lower) the interior covered by tier 0
        ix0, ix1 = int((sx0 - x0) / res), int((sx1 - x0) / res)
        iz0, iz1 = int((sz0 - z0) / res), int((sz1 - z0) / res)
        G[ix0:ix1, int(lower / res) if False else 0:ny, iz0:iz1] = 0
    return G, hq, top_y, (x0, z0, ymin, res), (X, Z, h, d, s, rd, tp, L, slope, forest, top)


def bake_terrain(G, x0, z0, ymin, res, name, chunk=64):
    g = vox.Grid.__new__(vox.Grid)
    g.vs = res
    g.a = G
    g.lo = np.array([x0, ymin, z0])
    g.part_names, g.p, g.cur = [], None, None
    t = time.time()
    m = vox.bake(g, os.path.join(ROOT, "assets", name + ".vxm"), chunk=(chunk, 10 ** 6, chunk), cull_bottom=True,
                 extra={"origin": [x0, ymin, z0]})
    print("%s: vox=%d tris=%d chunks=%d %.1fs" % (name, m["voxels"], m["tris"], m["chunks"], time.time() - t), flush=True)
    return m
