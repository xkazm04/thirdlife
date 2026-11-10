"""Terrain (2 tiers), collision heightmap, layout.json. Usage: python gen/build_world.py [--plot]"""
import sys, os, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import vox, world as W, layout as LY
from vox import MATS
ROOT = vox.ROOT
t0 = time.time()
LOGP = os.path.join(ROOT, "assets", "build_log.json")
LOG = json.load(open(LOGP)) if os.path.exists(LOGP) else {}

# ---- tier 0 (0.5 m)
G, hq, top_y, org, arrs = W.terrain(0.5)
print("tier0 grid", G.shape, "%.1fs" % (time.time() - t0), flush=True)
m0 = W.bake_terrain(G, org[0], org[1], org[2], org[3], "terrain0")
LOG["terrain0"] = dict(m0, sec=round(time.time() - t0, 1))
nx, nz = top_y.shape
np.concatenate([np.array([nx, nz, org[0], org[1], org[3]], np.float32), top_y.T.astype(np.float32).ravel()]).tofile(os.path.join(ROOT, "assets", "terrain_h.bin"))
del G

# ---- tier 1 (2 m, hollowed where tier 0 exists)
t1 = time.time()
G1, hq1, top1, org1, arrs1 = W.terrain(2.0, -420.0, -440.0, 420.0, 125.0, -24.0, 72.0, skip=(-120.0, 110.0, -150.0, 45.0))
m1 = W.bake_terrain(G1, org1[0], org1[1], org1[2], org1[3], "terrain1", chunk=64)
LOG["terrain1"] = dict(m1, sec=round(time.time() - t1, 1))
# far trees on slopes (tier1 region only)
X1, Z1, h1, d1, s1, rd1, tp1, L1, slope1, forest1, top1m = arrs1
rr = np.random.default_rng(9)
far = []
for _ in range(60000):
    if len(far) >= 1700:
        break
    ix = rr.integers(0, top1.shape[0]); iz = rr.integers(0, top1.shape[1])
    x, z = X1[ix, iz] + rr.uniform(-1, 1), Z1[ix, iz] + rr.uniform(-1, 1)
    if -120 < x < 110 and -150 < z < 45:
        continue
    y = top1[ix, iz]
    if y < -12 or y > 20 or slope1[ix, iz] > 3.5:
        continue
    if top1m[ix, iz] in (MATS("snow"), MATS("water"), MATS("sand")):
        continue
    if rr.random() > (0.35 + 0.65 * float(forest1[ix, iz])):
        continue
    far.append({"x": float(x), "z": float(z), "y": float(y), "yaw": float(rr.uniform(0, 6.28)), "s": float(rr.uniform(0.8, 1.4))})
print("far trees", len(far))

lay = LY.make_layout(arrs, top_y, org, far)
json.dump(lay, open(os.path.join(ROOT, "data", "layout.json"), "w"))
json.dump(LOG, open(LOGP, "w"), indent=1)
print("layout: trees=%d rocks=%d tufts=%d far=%d lamps=%d wall=%d track=%.1fm  total %.1fs" % (
    len(lay["trees"]), len(lay["rocks"]), len(lay["tufts"]), len(far), len(lay["lamps"]), len(lay["wall"]), lay["track"]["length"], time.time() - t0))
if "--plot" in sys.argv:
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.figure(figsize=(10, 8))
    plt.imshow(top_y.T, origin="upper", extent=(org[0], org[0] + nx * 0.5, org[1] + nz * 0.5, org[1]), cmap="terrain")
    tr = np.array(lay["track"]["points"]); plt.plot(tr[:, 0], tr[:, 2], "r-")
    for t in lay["trees"]: plt.plot(t["x"], t["z"], "g.", ms=2)
    for b in lay["wall"]: plt.plot(b["x"], b["z"], "ks", ms=3)
    plt.savefig(os.path.join(ROOT, "scratch", "world.png"), dpi=80)
