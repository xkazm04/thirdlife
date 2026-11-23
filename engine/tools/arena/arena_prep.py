#!/usr/bin/env python3
"""Step 2 of the arena bake: the played world export_arena.py wrote (world.json, materials.json, meshes/*.glb) ->
one file build_arena.gd reads, in OUR axes and units (metres; thirdjam's rink x -> x, rink y -> z, up -> y, the mapping
lane K3's gen/tj_rink.gd uses and Unreal's glTF exporter writes: Unreal (x, y, z) cm -> (x, z, y) / 100).

usage: python arena_prep.py <export folder> <out json>

What is taken: every static mesh component the game draws (visible, not hidden in game) on the light rig's level
(LR_P3_Clay: the barn, the stands, the crowd, the lamp shades, the dressing) and ARinkActor's arena pieces (its
components named Arena*: benches, boxes, table, goal lights, board caps, box doors and clock hands, the goals and their
nets). What is left out, and why, is counted in the output's "left_out".
Pieces with the same mesh and the same materials are one group (one draw): its instances keep their order and every
instance names its Unreal source (actor label . component [index]).
Nothing is re-modelled or moved: a transform is Unreal's world transform under the change of axes P = swap(y, z),
M' = P M P; a vertex is the glb's own."""
import json
import math
import os
import struct
import sys

import numpy as np

SRC, OUT = sys.argv[1], sys.argv[2]
world = json.load(open(os.path.join(SRC, "world.json"), encoding="utf-8"))
mats = json.load(open(os.path.join(SRC, "materials.json"), encoding="utf-8"))
MATS = mats["materials"]
P = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])


def short(path):
    return path.split(".")[-1] if path else ""


def quat_mat(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def xform(t):
    """Unreal {t_cm, q, s} -> 12 floats: the three basis columns and the origin of a Godot Transform3D."""
    a = quat_mat(t["q"]) @ np.diag(t["s"])
    a2 = P @ a @ P
    o = P @ np.array(t["t_cm"]) / 100.0
    return [round(float(v), 6) for v in list(a2[:, 0]) + list(a2[:, 1]) + list(a2[:, 2]) + list(o)]


def direction(q):
    """The way an Unreal light looks (its +x) in our axes."""
    d = P @ (quat_mat(q) @ np.array([1.0, 0, 0]))
    return [round(float(v), 6) for v in d]


# ---------------------------------------------------------------- pieces
groups = {}
order = []
left_out = {}


def leave(why):
    left_out[why] = left_out.get(why, 0) + 1


def group_name(actor, comp, mesh):
    if actor["class"] == "RinkActor":
        return comp["name"]
    return mesh[3:] if mesh.startswith("SM_") else actor["label"].replace("Con_P3_Clay_", "Barn")


for a in world["actors"]:
    rig = "LR_P3_Clay" in a["package"]
    rink = a["class"] == "RinkActor"
    for c in a["components"]:
        if not c.get("mesh"):
            continue
        mesh = short(c["mesh"])
        if not (rig or rink):
            leave("not the hall (figures, the puck, the engine's own actors)")
            continue
        if not c.get("visible", True) or c.get("hidden_in_game"):
            leave("hidden in the game")
            continue
        if rink and not c["name"].startswith("Arena"):
            leave("RinkActor's own (beacons)")
            continue
        if a["label"] == "SkyCap_P3_Clay":
            leave("the sky light's capture dome (350 m sphere outside the barn, never seen)")
            continue
        inst = c["instances"] if "instances" in c else [c["world"]]
        if not inst:
            leave("no instance")
            continue
        mnames = [short(m) for m in c["materials"]]
        key = mesh + "|" + ",".join(mnames)
        if key not in groups:
            name = group_name(a, c, mesh)
            base, n = name, 2
            while any(g["name"] == name for g in groups.values()):
                name = "%s_%d" % (base, n)
                n += 1
            groups[key] = {"name": name, "mesh": mesh, "materials": mnames, "instances": [], "sources": [],
                           "cast_shadow": bool(c.get("cast_shadow", False)),
                           "layer": "rink" if rink else ("crowd" if a["class"] == "BP_ArenaCrowd_C" else "barn")}
            order.append(key)
        g = groups[key]
        cf = int(c.get("custom_floats", 0) or 0)
        for i, t in enumerate(inst):
            g["instances"].append(xform(t))
            g["sources"].append("%s.%s%s" % (a["label"], c["name"], "[%d]" % i if "instances" in c else ""))
            if cf:
                g.setdefault("custom", []).append([round(v, 5) for v in c["custom_data"][i * cf:(i + 1) * cf]])
        if cf:
            g["custom_floats"] = cf
            g["custom_names"] = ["weight", "coat", "accent", "end", "delay", "pose"]   # ASSETS.md row LR_P3_Clay, M_ClayCrowd


# ---------------------------------------------------------------- meshes
def read_glb(path):
    b = open(path, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", b[off:off + 4])[0]
    blob = b[off + 8:off + 8 + bl]
    CT = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
    NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

    def acc(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        dt = np.dtype(CT[a["componentType"]])
        n = NC[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0) or dt.itemsize * n
        if stride == dt.itemsize * n:
            arr = np.frombuffer(blob, dtype=dt, count=a["count"] * n, offset=start).reshape(a["count"], n)
        else:
            arr = np.stack([np.frombuffer(blob, dtype=dt, count=n, offset=start + k * stride) for k in range(a["count"])])
        arr = arr.astype(np.float64) if a["componentType"] == 5126 else arr
        if a.get("normalized"):
            arr = arr.astype(np.float64) / {5121: 255.0, 5123: 65535.0}[a["componentType"]]
        return arr
    assert len(j["meshes"]) == 1 and all("matrix" not in n and "rotation" not in n and "scale" not in n and "translation" not in n for n in j["nodes"]), path
    out = []
    for p in j["meshes"][0]["primitives"]:
        at = p["attributes"]
        s = {"slot_material": j["materials"][p["material"]]["name"] if "material" in p else "",
             "v": acc(at["POSITION"]), "n": acc(at["NORMAL"]), "i": acc(p["indices"]).reshape(-1).astype(np.int64)}
        if "TEXCOORD_0" in at:
            s["uv"] = acc(at["TEXCOORD_0"])
        if "COLOR_0" in at:
            s["c"] = acc(at["COLOR_0"])
        if "TEXCOORD_7" in at:
            # M_ClayCrowd: UV2..UV4 = the offset in cm to cheering pose A, UV5..UV7 = pose B (their u), in Unreal's local axes
            A = np.stack([acc(at["TEXCOORD_%d" % k])[:, 0] for k in (2, 3, 4)], axis=1)
            B = np.stack([acc(at["TEXCOORD_%d" % k])[:, 0] for k in (5, 6, 7)], axis=1)
            s["pose_a"] = (A @ P.T) / 100.0
            s["pose_b"] = (B @ P.T) / 100.0
        out.append(s)
    return out


def flat(arr, nd):
    return [round(float(x), nd) for x in np.asarray(arr).reshape(-1)]


mesh_out = {}
tri_total = 0
for key in order:
    g = groups[key]
    if g["mesh"] in mesh_out:
        continue
    surf = read_glb(os.path.join(SRC, "meshes", g["mesh"] + ".glb"))
    rows = []
    for s in surf:
        idx = s["i"].reshape(-1, 3)[:, [0, 2, 1]].reshape(-1)        # glTF winds counter-clockwise, Godot clockwise
        r = {"slot_material": s["slot_material"], "v": flat(s["v"], 5), "n": flat(s["n"], 4), "i": [int(x) for x in idx]}
        if "uv" in s:
            r["uv"] = flat(s["uv"], 5)
        if "c" in s:
            r["c"] = flat(s["c"], 4)
        if "pose_a" in s:
            r["pose_a"] = flat(s["pose_a"], 5)
            r["pose_b"] = flat(s["pose_b"], 5)
        rows.append(r)
    mesh_out[g["mesh"]] = {"surfaces": rows, "triangles": int(sum(len(r["i"]) for r in rows) // 3)}
for key in order:
    g = groups[key]
    n_surf = len(mesh_out[g["mesh"]]["surfaces"])
    if len(g["materials"]) != n_surf:
        # a component may carry fewer overrides than slots: the mesh's own slot materials fill the rest
        own = [s["slot_material"] for s in mesh_out[g["mesh"]]["surfaces"]]
        g["materials"] = (g["materials"] + own[len(g["materials"]):])[:n_surf]
    g["triangles"] = mesh_out[g["mesh"]]["triangles"] * len(g["instances"])
    tri_total += g["triangles"]

# ---------------------------------------------------------------- materials (raw parameters, by short name)
# ARinkActor's own procedural surfaces (the ice, the boards, the kick plate, the trim, the markings): their geometry is
# built from the cartridge (lane K3's gen/tj_rink.gd), their materials are listed here by component.
rink_surfaces = {}
for a in world["actors"]:
    if a["class"] != "RinkActor":
        continue
    for c in a["components"]:
        if c["class"] == "ProceduralMeshComponent" and c.get("materials"):
            rink_surfaces[c["name"]] = {"materials": [short(m) for m in c["materials"]],
                                        "shown": bool(c.get("visible", True) and not c.get("hidden_in_game")),
                                        "cast_shadow": bool(c.get("cast_shadow", False)),
                                        "extent_cm": c.get("bounds_cm", {}).get("extent")}
used = sorted({m for g in groups.values() for m in g["materials"]} | {m for r in rink_surfaces.values() for m in r["materials"]})
by_short = {short(k): v for k, v in MATS.items()}
mat_out = {}
for m in used:
    v = by_short.get(m)
    if v is None:
        mat_out[m] = {"master": "", "missing": True}
        continue
    mat_out[m] = {"master": short(v.get("base", "")), "parent": short(v.get("parent", "")), "scalars": v.get("scalars", {}),
                  "vectors": v.get("vectors", {}), "textures": {k: short(t) for k, t in v.get("textures", {}).items()},
                  "switches": v.get("switches", {}), "shading": v.get("shading_model", "")}

# ---------------------------------------------------------------- lights, sky, post, the look's collection
lights = []
sky = None
post = None
for a in world["actors"]:
    if "LR_P3_Clay" not in a["package"]:
        continue
    for c in a["components"]:
        p = c.get("props")
        if p is None:
            continue
        if c["class"] == "SpotLightComponent":
            lights.append({
                "name": a["label"], "pos": [round(float(v), 4) for v in P @ np.array(c["world"]["t_cm"]) / 100.0],
                "dir": direction(c["world"]["q"]), "candela": p["intensity"], "units": p["intensity_units"],
                "color_srgb8": p["light_color"]["srgb8"][:3], "radius_m": p["attenuation_radius"] / 100.0,
                "inner_deg": p["inner_cone_angle"], "outer_deg": p["outer_cone_angle"], "shadows": bool(p["cast_shadows"]),
                "source_radius_m": p["source_radius"] / 100.0, "specular": p["specular_scale"]})
        elif c["class"] == "SkyLightComponent":
            sky = {"name": a["label"], "intensity": p["intensity"], "color_srgb8": p["light_color"]["srgb8"][:3],
                   "source": p.get("source_type"), "real_time_capture": p.get("real_time_capture"),
                   "lower_hemisphere_is_black": p.get("lower_hemisphere_is_black")}
    if a["class"] == "PostProcessVolume":
        post = {"name": a["label"], "unbound": a.get("unbound"), "settings": a.get("post")}


def lin(c8):
    return [(v / 255.0 / 12.92) if v / 255.0 <= 0.04045 else ((v / 255.0 + 0.055) / 1.055) ** 2.4 for v in c8]


def lux_at(x, z):
    """Illuminance on the ice (lux, per colour channel in linear light) at rink point (x, z): Unreal's spot light,
    inverse square with its radius window, the cone's smooth edge (SpotLight falloff: ((cos - cos_outer) / (cos_inner -
    cos_outer))^2), times the cosine on a level surface."""
    e = np.zeros(3)
    for L in lights:
        d = np.array([x, 0.0, z]) - np.array(L["pos"])
        r = float(np.linalg.norm(d))
        if r >= L["radius_m"]:
            continue
        w = d / r
        cosd = float(np.dot(w, np.array(L["dir"])))
        co, ci = math.cos(math.radians(L["outer_deg"])), math.cos(math.radians(L["inner_deg"]))
        cone = min(max((cosd - co) / max(ci - co, 1e-6), 0.0), 1.0) ** 2
        window = max(0.0, 1.0 - (r / L["radius_m"]) ** 4) ** 2
        cos_surf = max(0.0, -w[1])
        e += np.array(lin(L["color_srgb8"])) * (L["candela"] / (r * r)) * cone * window * cos_surf
    return e


xs = np.linspace(-44, 44, 45)
zs = np.linspace(-21.5, 21.5, 23)
grid = np.array([[lux_at(x, z) for x in xs] for z in zs])
lum = grid @ np.array([0.2126, 0.7152, 0.0722])
ev100 = None
if post and post["settings"]:
    ev100 = post["settings"].get("auto_exposure_min_brightness")
light_sum = {
    "note": "the rig's spots summed on the ice plane (lux per linear channel; a 2 m grid inside the boards). exposure = 1 / (1.2 * 2^EV100): "
            "what a surface of albedo a shows is a * lux / pi * exposure before the tone curve.",
    "mean_lux_rgb": [round(float(v), 3) for v in grid.reshape(-1, 3).mean(axis=0)],
    "centre_lux_rgb": [round(float(v), 3) for v in lux_at(0.0, 0.0)],
    "lum_min": round(float(lum.min()), 2), "lum_mean": round(float(lum.mean()), 2), "lum_max": round(float(lum.max()), 2),
    "ev100": ev100, "exposure": round(1.0 / (1.2 * 2 ** ev100), 6) if ev100 is not None else None,
}

out = {
    "schema": "tl.arena.src/1",
    "source": {"world": world["world"], "thirdjam": "HEAD 8dc713c6 content on the t5 build, hockey.regular (p3_clay), played in the editor"},
    "groups": [groups[k] for k in order], "meshes": mesh_out, "materials": mat_out,
    "rink_surfaces": rink_surfaces, "lights": lights, "sky": sky, "post": post, "light_sum": light_sum,
    "collections": world.get("collections", {}), "left_out": left_out,
    "totals": {"groups": len(order), "instances": sum(len(g["instances"]) for g in groups.values()), "triangles": tri_total,
               "meshes": len(mesh_out), "materials": len(mat_out), "lights": len(lights)},
}
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(out, f, separators=(",", ":"))
print(json.dumps(out["totals"]), json.dumps(left_out))
print(json.dumps(light_sum))
for k in order:
    g = groups[k]
    print("%-22s %-28s x%-4d tris %-7d %s" % (g["name"], g["mesh"], len(g["instances"]), g["triangles"], ",".join(g["materials"])))
