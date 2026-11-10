"""Ports a lane-B layout file (spike/lab/b/data/layout*.json, the pass-4 schema) to tl.layout/1.

    python tools/convert_laneb.py <lane-b layout.json> <lane-b cams.json> <out.json>

Standard library only. What does not carry over is listed in the `_port_notes` key of the output."""
import json
import sys

src = json.load(open(sys.argv[1], encoding='utf-8'))
cams_main = json.load(open(sys.argv[2], encoding='utf-8'))
out_path = sys.argv[3]
notes = []
L = {"schema": "tl.layout/1", "name": src["name"], "seed": src.get("seed", 7), "spawn": {"p": [0, 0]}}

rg = src["ridge"]
ridge = {"a": rg["a"], "b": rg["b"]}
if "fall" in rg:
    ridge["fall"] = rg["fall"]
if rg.get("ramps"):
    ridge["ramps"] = rg["ramps"]
L["terrain"] = {"ridges": [ridge], "pads": src["pads"]}
if src.get("mesas"):
    L["terrain"]["mesas"] = src["mesas"]
if src.get("river"):
    L["rivers"] = [{"id": "river", "points": src["river"]}]
if src.get("waterfalls"):
    L["waterfalls"] = src["waterfalls"]

c = src["circuit"]
circ = {"id": "track", "points": c["cps"]}
if "y" in c:
    circ["y"] = c["y"]
L["circuits"] = [circ]
L["walls"] = [{"id": "wall", "circuit": "track", "at": c["wall_at"], "blocks": c.get("wall_blocks", 12)}]
L["actors"] = [
    {"id": "avatar", "rig": "biped", "p": [0, 0]},
    {"id": "car_a", "rig": "vehicle", "on": {"circuit": "track", "near": c["wall_at"], "ds": c.get("car_a", 5.0), "side": 1, "off": 1.9},
     "params": {"colors": {"body": "car_blue", "stripe": "car_white"}}},
    {"id": "car_b", "rig": "vehicle", "on": {"circuit": "track", "near": c["wall_at"], "ds": c.get("car_b", -9.0), "side": -1, "off": 1.9},
     "params": {"colors": {"body": "car_red", "stripe": "car_white"}}},
]
notes.append("cars are placed actors: the lane-B sim (driving, nitro pass) is not part of the kit")

a = src["arena"]
arena = {"id": "arena", "c": a["c"], "rink": {"length": a["rink"][0], "width": a["rink"][1], "corner_r": a["rink"][2]}}
if a.get("yaw"):
    arena["yaw"] = a["yaw"]
rows = a.get("rows", 10)
if rows > 0:
    arena["stands"] = [{"side": -1, "rows": rows}]
if a["ribs"] > 0:
    arena["ribs"] = {"count": a["ribs"], "built": a["built"], "dx": a["rib_dx"], "apex": a.get("apex", 14)}
    if a.get("rib_off"):
        arena["ribs"]["off"] = a["rib_off"]
if a.get("scaffolds"):
    arena["scaffolds"] = a["scaffolds"]
bots = []
for b in a.get("bots", []):
    nb = {"p": b["p"], "clip": "weld" if b.get("state") == "work" else "idle"}
    if b.get("yaw"):
        nb["yaw"] = b["yaw"]
    bots.append(nb)
    if b.get("mobile"):
        notes.append("bots[].mobile dropped: a walking bot is behaviour, not layout")
if bots:
    arena["bots"] = bots
L["arenas"] = [arena]

if src.get("cranes"):
    L["cranes"] = src["cranes"]
houses = list(src.get("houses", []))
if "house" in src:
    houses.append(src["house"])
if houses:
    L["houses"] = houses
if "hero_tree" in src:
    L["trees"] = [{"p": src["hero_tree"], "species": "hero"}]
L["rocks"] = [{"p": [r[0], r[1]], "size": r[2], "squash": r[3], "seed": int(r[4])} for r in src.get("hero_rocks", [])]
forest = dict(src.get("forest", {}))
if src.get("clear"):
    forest["clear"] = src["clear"]
if forest:
    L["forest"] = forest

props = []
ponds = []
for p in src.get("props", []):
    k = p["k"]
    args = p.get("a", [])
    n = {}
    if "s" in p:
        on = {"circuit": "track", "s": p["s"]}
        if "side" in p:
            on["side"] = p["side"]
        if "off" in p:
            on["off"] = p["off"]
        n["on"] = on
    else:
        n["p"] = p["p"]
    if p.get("yaw"):
        n["yaw"] = p["yaw"]
    params = {}
    if k == "lumber":
        params = {"length": args[0], "width": args[1], "layers": int(args[2])}
    elif k == "pallet":
        if args:
            params = {"rows": int(args[0])}
    elif k in ("fence", "site_fence"):
        n["to"] = [args[0], args[1]]
        if k == "site_fence":
            params = {"style": "mesh"}
        k = "fence"
    elif k == "sign":
        if args:
            params = {"color": args[0]}
    elif k == "flag":
        if len(args) > 0:
            params["height"] = args[0]
        if len(args) > 1:
            params["color"] = args[1]
    elif k in ("light_mast", "watch_tower"):
        if args:
            params = {"height": args[0]}
    elif k == "tyres":
        k = "tyre_stack"
        if args:
            params = {"columns": int(args[0])}
    elif k == "marshal":
        k = "marshal_post"
    elif k == "stones":
        params = {"count": int(args[0])}
    elif k == "pond":
        key = args[2] if len(args) > 2 else "pond_ice"
        pd = {"p": p["p"], "rx": args[0], "rz": args[1], "surface": "water" if key == "water" else "ice"}
        if p.get("yaw"):
            pd["yaw"] = p["yaw"]
        ponds.append(pd)
        continue
    elif k == "bridge":
        n["p"] = [p["p"][0], -15.2, p["p"][1]]
        if len(args) > 0:
            params["length"] = args[0]
        if len(args) > 1:
            params["width"] = args[1]
        if len(args) > 2:
            params["spans"] = int(args[2])
    item = {"kind": k}
    item.update(n)
    if params:
        item["params"] = params
    props.append(item)
if props:
    L["props"] = props
if ponds:
    L["ponds"] = ponds

cams = {}
own = src.get("cams", {})
for name in ("hero", "site", "track", "crumble", "map", "avatar"):
    if name in own:
        cams[name] = own[name]
    elif name in cams_main and (src["name"] == "main" or name in ("avatar",)):
        cams[name] = cams_main[name]
L["cams"] = cams
L["_port_notes"] = sorted(set(notes)) + ["ported from spike/lab/b/data by tools/convert_laneb.py"]
json.dump(L, open(out_path, 'w', encoding='utf-8'), indent=1)
print("wrote", out_path, "props", len(props), "ponds", len(ponds))
