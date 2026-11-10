"""Builds every voxel asset into assets/*.vxm (+ .json stats) and data/layout.json. Usage: python gen/build.py [names...]"""
import sys, time, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import vox, kit_nature as kn, kit_struct as ks, kit_chars as kc
ROOT = vox.ROOT
LOGP = os.path.join(ROOT, "assets", "build_log.json")
LOG = json.load(open(LOGP)) if os.path.exists(LOGP) else {}
only = set(sys.argv[1:])

def want(n):
    return not only or n in only or any(n.startswith(o) for o in only)

def go(name, g, **kw):
    if not want(name):
        return
    t = time.time()
    m = vox.bake(g() if callable(g) else g, os.path.join(ROOT, "assets", name + ".vxm"), **kw)
    LOG[name] = dict(m, sec=round(time.time() - t, 2))
    print("%-16s vox=%-8d tris=%-8d %5.1fs" % (name, m["voxels"], m["tris"], time.time() - t), flush=True)

def go_parts(name, g, rig, **kw):
    if not want(name):
        return
    t = time.time()
    gg = g() if callable(g) else g
    piv = {b: p for b, _, p in rig}
    m = vox.bake_parts(gg, os.path.join(ROOT, "assets", name + ".vxm"), piv)
    LOG[name] = dict(m, sec=round(time.time() - t, 2))
    print("%-16s vox=%-8d tris=%-8d %5.1fs (parts)" % (name, m["voxels"], m["tris"], time.time() - t), flush=True)

def go_clusters(name, g, k, seed):
    if not want(name):
        return
    t = time.time()
    gg = g() if callable(g) else g
    lab = vox.voronoi_clusters(gg, k, seed)
    m = vox.bake_clusters(gg, lab, os.path.join(ROOT, "assets", name + ".vxm"))
    LOG[name] = dict(m, sec=round(time.time() - t, 2))
    print("%-16s vox=%-8d tris=%-8d %5.1fs (%d clusters)" % (name, m["voxels"], m["tris"], time.time() - t, k), flush=True)

# --- nature
for i in range(1, 5):
    go("oak%d" % i, lambda i=i: kn.oak(i, 5.0 + i * 0.7))
for i in range(1, 4):
    go("pine%d" % i, lambda i=i: kn.pine(i, 7.0 + i * 1.3))
    go("rock%d" % i, lambda i=i: kn.rock(i, 0.8 + 0.4 * i))
go("pine_far", lambda: kn.pine(9, 13.0, vs=0.75, base_r=3.0))
go("oak_big", lambda: kn.oak(11, 11.5, vs=0.5, crown=4.6, trunk=1.5))
go("tuft1", lambda: kn.tuft(1)); go("tuft2", lambda: kn.tuft(2))
go("cloud1", lambda: kn.cloud(1)); go("cloud2", lambda: kn.cloud(2))
# --- arena
go("rib", ks.rib); go("rib_holo", ks.rib_holo); go("rib_skin", ks.rib_holo_skin)
go("roof_skin", ks.roof_skin); go("purlin", ks.purlin); go("boards", ks.boards); go("ice", ks.ice); go("goal", ks.goal)
go("stands", ks.stands); go("bench", ks.bench)
# --- site
go("scaffold", lambda: ks.scaffold(3.0, 6.0, 1.5, bays=2)); go("scaffold_s", lambda: ks.scaffold(3.0, 4.0, 1.5, bays=1))
go("crane_mast", ks.crane_mast); go("crane_head", ks.crane_head)
go("crane_load_a", lambda: ks.crane_load(9.0, kind="slab")); go("crane_load_b", lambda: ks.crane_load(11.0, kind="blocks"))
go("pallet_blocks", ks.pallet_blocks); go("crate", ks.crate); go("barrier_stripe", ks.barrier_stripe)
go("lumber", ks.lumber); go("lamp", ks.lamp); go("fence", ks.fence)
go("house", ks.house); go("house_frame", ks.house_frame)
# --- wall + debris
go("wall_block", ks.wall_block)
for v in range(3):
    go_clusters("wall_debris%d" % v, lambda v=v: ks.wall_block(seed=v + 1), 9, 10 + v)
for v in range(4):
    go("shard%d" % v, lambda v=v: ks.shard(seed=v + 1, n=2 + v))
# --- characters
go_parts("avatar", kc.avatar, kc.BIPED)
go("tablet", kc.tablet)
go_parts("bot", kc.bot, kc.BOT)
go("car_red", lambda: kc.car_body(body="car_red", accent="car_white"))
go("car_blue", lambda: kc.car_body(body="car_blue", accent="car_white", lightbar=True))
go("car_wheel", kc.car_wheel)
json.dump(LOG, open(LOGP, "w"), indent=1)
print("build done")

# rigs (standard skeletons shared with the Godot side)
json.dump({"biped": [[b, p, list(x)] for b, p, x in kc.BIPED], "bot": [[b, p, list(x)] for b, p, x in kc.BOT],
           "vehicle": [[b, p, list(x)] for b, p, x in kc.CAR_RIG]}, open(os.path.join(ROOT, "data", "rigs.json"), "w"), indent=1)
