class_name TLKitLayoutBuild
extends RefCounted
## Builds a validated tl.layout/1 dictionary under a parent node (ported from spike/lab/b/src/world.gd, grown to lists).
## Tree: Layout_<name> / TerrainNear, TerrainCollision, TerrainFar, Static (every static part's visuals merged into
## one mesh so shadow cascades draw them once), Parts/<id> (the part nodes: collision bodies, lights, tags; fracturable
## and moving parts keep their own meshes), Nature (MultiMeshes), Actors/<id> (rigs).

var L: Dictionary = {}
var root: Node3D
var parts: Node3D
var terrain: TLKitTerrain
var circuits: Dictionary = {}     # id -> {"path": TLKitPath, "half_w": float}
var river_paths: Array = []
var water_y: float = -15.2
var nodes: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()
var _static: Array = []           # [mesh, transform relative to the layout root]
var _static_tris: int = 0
var _auto: int = 0


func run(layout: Dictionary, parent: Node3D) -> Dictionary:
	L = layout
	root = Node3D.new()
	root.name = "Layout_" + String(L["name"]).validate_node_name()
	root.set_meta("tl_layout", String(L["name"]))
	parts = Node3D.new()
	parts.name = "Parts"
	root.add_child(parts)
	var has_terrain: bool = L.has("terrain")
	var T: Dictionary = L.get("terrain", {})
	var base_y: float = float(T.get("base_y", -14.0))
	water_y = base_y - 1.2
	for c: Dictionary in L.get("circuits", []):
		var cps: Array = []
		for q: Array in c["points"]:
			cps.append(TLKitLayout.v2(q))
		var path: TLKitPath = TLKitPath.new(cps, bool(c.get("closed", true)), 2.0)
		var RL: float = path.length
		var ry: float = float(c.get("y", -12.0 if has_terrain else 0.0))
		var roll: float = float(c.get("roll", 1.0 if has_terrain else 0.0))
		path.set_heights(func(s: float, _q: Vector2) -> float: return ry + roll * (1.2 * sin(s / RL * TAU * 2.0 + 0.8) + 0.55 * sin(s / RL * TAU * 5.0)))
		circuits[String(c["id"])] = {"path": path, "half_w": float(c.get("half_width", 5.0)), "kerb_w": float(c.get("kerb_width", 1.2))}
	for rv: Dictionary in L.get("rivers", []):
		var rc: Array = []
		for q: Array in rv["points"]:
			rc.append(TLKitLayout.v2(q))
		var rp: TLKitPath = TLKitPath.new(rc, false, 4.0)
		var ry2: float = float(rv.get("y", base_y - 1.2))
		water_y = ry2
		rp.set_heights(func(_s: float, _q: Vector2) -> float: return ry2)
		river_paths.append({"path": rp, "half_w": float(rv.get("width", 11.0)) * 0.5, "id": String(rv.get("id", "river%d" % river_paths.size()))})
	if has_terrain:
		_build_terrain(T, base_y)
	for id: String in circuits:
		var c2: Dictionary = circuits[id]
		var rm: TLMesh = TLKitRoad.build(c2["path"], float(c2["half_w"]), float(c2["kerb_w"]), 0.14, 2, 0.07)
		var cn: Node3D = Node3D.new()
		cn.name = "Circuit_" + id
		cn.set_meta("tl_kind", "circuit")
		cn.set_meta("tl_length", (c2["path"] as TLKitPath).length)
		var centre: PackedVector3Array = PackedVector3Array()
		var pth: TLKitPath = c2["path"]
		for i: int in pth.count():
			centre.append(Vector3(pth.pts[i].x, pth.ys[i], pth.pts[i].y))
		cn.set_meta("tl_centre_line", centre)
		cn.set_meta("tl_half_width", float(c2["half_w"]))
		TLKitParts.trimesh(TLKitParts.body(cn, "asphalt"), rm.faces())
		parts.add_child(cn)
		_static.append([rm.build("road"), Transform3D.IDENTITY])
		_static_tris += rm.tri_count
		nodes[id] = cn
	for rv2: Dictionary in river_paths:
		var wm: TLMesh = TLKitRoad.river_ribbon(rv2["path"], float(rv2["half_w"]), 0.0)
		var wmi: MeshInstance3D = TLKitParts.mesh(root, wm, "River_" + String(rv2["id"]), false)
		wmi.set_meta("tl_material", "water")
		nodes[String(rv2["id"])] = wmi
	_build_arenas()
	for c3: Dictionary in L.get("cranes", []):
		var cr: Node3D = TLKit.build("crane", {"height": float(c3.get("h", 35.0)), "jib": float(c3.get("jib", 30.0)), "slew": float(c3.get("yaw", 0.0)), "trolley": float(c3.get("trolley", 0.55))})
		_place(cr, Transform3D(Basis.IDENTITY, ground(c3["p"][0], c3["p"][1])), _id(c3, "crane"), false)
	_build_walls()
	for h: Dictionary in L.get("houses", []):
		var hp: Vector3 = Vector3(h["p"][0], h["p"][1], h["p"][2])
		var HT: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(h.get("yaw", 0.0)))), hp)
		var hid: String = _id(h, "house")
		var hn: Node3D = TLKit.build("house", h.get("params", {}))
		_place(hn, HT, hid)
		if bool(h.get("frame", true)):
			var ext: float = (float(hn.get_meta("tl_params")["width"]) * 0.5 + 3.4) * float(h.get("ext_side", 1.0))
			_place(TLKit.build("timber_frame", {}), HT * Transform3D(Basis.IDENTITY, Vector3(ext, 0, 0)), hid + ".frame")
		if not TLStyle.headless():
			var sm: CPUParticles3D = TLStyleFx.smoke()
			sm.position = Vector3(2.08, 7.7, -0.78)
			hn.add_child(sm)
	for pd: Dictionary in L.get("ponds", []):
		var pn: Node3D = TLKit.build("pond", {"radius_x": float(pd["rx"]), "radius_z": float(pd["rz"]), "surface": String(pd.get("surface", "ice"))})
		_place(pn, Transform3D(Basis(Vector3.UP, deg_to_rad(float(pd.get("yaw", 0.0)))), _pos(pd["p"])), _id(pd, "pond"), String(pd.get("surface", "ice")) != "water")
	for pr: Dictionary in L.get("props", []):
		_build_prop(pr)
	for tr: Dictionary in L.get("trees", []):
		var tn: Node3D = TLKit.build("tree", {"species": String(tr.get("species", "pine")), "height": float(tr.get("height", 9.0)), "seed": int(tr.get("seed", 100))})
		_place(tn, Transform3D(Basis.IDENTITY, ground(tr["p"][0], tr["p"][1]) - Vector3(0, 0.3, 0)), _id(tr, "tree"))
	for rk: Dictionary in L.get("rocks", []):
		var rn: Node3D = TLKit.build("rock", {"size": float(rk.get("size", 1.0)), "squash": float(rk.get("squash", 0.7)), "seed": int(rk.get("seed", 200))})
		_place(rn, Transform3D(Basis(Vector3.UP, float(int(rk.get("seed", 200))) * 1.7), ground(rk["p"][0], rk["p"][1]) - Vector3(0, 0.2, 0)), _id(rk, "rock"))
	if has_terrain:
		_build_waterfalls()
		if bool((L.get("forest", {}) as Dictionary).get("scatter", true)):
			_build_nature()
	var sm2: MeshInstance3D = MeshInstance3D.new()
	sm2.name = "Static"
	sm2.mesh = TLMesh.merge(_static, "static")
	sm2.mesh.set_meta("tl_tris", _static_tris)
	# identity of the merged mesh = every source mesh's content hash with its transform, in build order
	var hc: HashingContext = HashingContext.new()
	hc.start(HashingContext.HASH_SHA1)
	for it: Array in _static:
		hc.update(str((it[0] as Mesh).get_meta("tl_hash", "")).to_utf8_buffer())
		hc.update(var_to_bytes(it[1]))
	sm2.mesh.set_meta("tl_hash", hc.finish().hex_encode())
	root.add_child(sm2)
	_build_actors()
	parent.add_child(root)
	var cams: Dictionary = {}
	var lc: Dictionary = L.get("cams", {})
	for cn2: String in lc:
		if not cn2.begins_with("_"):
			var cv: Dictionary = lc[cn2]
			cams[cn2] = {"pos": Vector3(cv["pos"][0], cv["pos"][1], cv["pos"][2]), "look": Vector3(cv["look"][0], cv["look"][1], cv["look"][2]), "fov": float(cv["fov"])}
	var sp: Dictionary = L.get("spawn", {"p": [0, 0]})
	var spawn: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(sp.get("yaw", 0.0)))), ground(sp["p"][0], sp["p"][1]))
	return {"ok": errors.is_empty(), "errors": errors, "nodes": nodes, "root": root, "cams": cams, "spawn": spawn, "terrain": terrain, "triangles": TLKit.triangles(root)}


func ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.h(x, z) if terrain != null else 0.0, z)


func _pos(p: Array) -> Vector3:
	return ground(p[0], p[1]) if p.size() == 2 else Vector3(p[0], p[1], p[2])


func _id(d: Dictionary, prefix: String) -> String:
	if d.has("id"):
		return String(d["id"])
	_auto += 1
	return "%s%d" % [prefix, _auto]


## Adds a part under `holder` (default Parts) at a transform relative to the layout root and registers it. With merge,
## its meshes move into the Static mesh (the node keeps bodies, lights and tags).
func _place(part: Node3D, xf: Transform3D, id: String, merge: bool = true, holder: Node3D = null, holder_xf: Transform3D = Transform3D.IDENTITY) -> void:
	if part == null:
		errors.append("part '%s' could not be built" % id)
		return
	part.name = id.validate_node_name()
	part.transform = holder_xf.affine_inverse() * xf
	(holder if holder != null else parts).add_child(part)
	nodes[id] = part
	if merge and not part.has_node("Intact"):
		_absorb(part, xf)


func _absorb(n: Node, xf: Transform3D) -> void:
	for c: Node in n.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			if mi.mesh != null and mi.visible:
				_static.append([mi.mesh, xf * mi.transform])
				_static_tris += int(mi.mesh.get_meta("tl_tris", 0))
				n.remove_child(mi)
				mi.free()
		elif c is Node3D and not (c is StaticBody3D):
			_absorb(c, xf * (c as Node3D).transform)


func _build_terrain(T: Dictionary, base_y: float) -> void:
	terrain = TLKitTerrain.new(int(L.get("seed", 7)))
	terrain.base_y = base_y
	for rg: Dictionary in T.get("ridges", []):
		var ramps: Array = []
		for rp: Dictionary in rg.get("ramps", []):
			ramps.append({"c": TLKitLayout.v2(rp["c"]), "w": float(rp.get("w", 14.0)), "fall": float(rp.get("fall", 24.0))})
		terrain.ridges.append({"a": TLKitLayout.v2(rg["a"]), "b": TLKitLayout.v2(rg["b"]), "fall": float(rg.get("fall", 17.0)), "half_w": float(rg.get("half_w", 20.0)), "h": float(rg.get("h", 0.0)), "ramps": ramps})
	for pd: Dictionary in T.get("pads", []):
		terrain.pads.append({"c": TLKitLayout.v2(pd["c"]), "r": float(pd["r"]), "blend": float(pd["blend"]), "h": float(pd["h"]), "dirt": bool(pd.get("dirt", false))})
	for ms: Dictionary in T.get("mesas", []):
		terrain.mesas.append({"c": TLKitLayout.v2(ms["c"]), "r": float(ms["r"]), "h": float(ms["h"]), "blend": float(ms.get("blend", 20.0)), "noise": float(ms.get("noise", 14.0))})
	for id: String in circuits:
		terrain.roads.append(circuits[id])
	terrain.rivers = river_paths
	terrain.build_grid()
	root.add_child(terrain.build_near())
	var tb: StaticBody3D = terrain.collision_patch(-16.0, -80.0, 300.0)
	tb.set_meta("tl_material", "grass")
	root.add_child(tb)
	if bool(T.get("far", true)):
		root.add_child(terrain.build_far())


func _build_arenas() -> void:
	for A: Dictionary in L.get("arenas", []):
		var id: String = String(A["id"])
		var an: Node3D = Node3D.new()
		an.name = "Arena_" + id.validate_node_name()
		an.set_meta("tl_kind", "arena")
		var AT: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(A.get("yaw", 0.0)))), Vector3(A["c"][0], A["c"][1], A["c"][2]))
		an.transform = AT
		parts.add_child(an)
		nodes[id] = an
		var rink: Node3D = TLKit.build("rink", A.get("rink", {}))
		var rp: Dictionary = rink.get_meta("tl_params")
		var RL: float = rp["length"]
		var RW: float = rp["width"]
		_place(rink, AT, id + ".rink", true, an, AT)
		for st: Dictionary in A.get("stands", []):
			var side: float = st["side"]
			var sp: Dictionary = {"length": RL - 8.0, "rows": int(st.get("rows", 10))}
			if st.has("row_depth"):
				sp["row_depth"] = st["row_depth"]
			if st.has("rise"):
				sp["rise"] = st["rise"]
			var sn: Node3D = TLKit.build("stands", sp)
			var sx: Transform3D = Transform3D(Basis(Vector3.UP, 0.0 if side < 0.0 else PI), Vector3(0, 0, side * (RW * 0.5 + 3.2)))
			_place(sn, AT * sx, "%s.stands%s" % [id, "_n" if side < 0.0 else "_s"], true, an, AT)
		var R: Dictionary = A.get("ribs", {"count": 0})
		var n: int = int(R["count"])
		var built: int = int(R.get("built", n))
		var dx: float = float(R.get("dx", 8.5))
		var span: float = RW * 0.5 + 2.5
		for i: int in n:
			var holo: bool = i >= built or (R.get("holograms", []) as Array).has(float(i + 1)) or (R.get("holograms", []) as Array).has(i + 1)
			var x: float = (float(i) - (float(n) - 1.0) * 0.5 + float(R.get("off", 0.0))) * dx
			var rib: Node3D = TLKit.build("arch_rib", {"span": span, "apex": float(R.get("apex", 14.0)), "exponent": float(R.get("exponent", 2.6)), "purlin_dx": dx if i > 0 else 0.0, "hologram": holo})
			_place(rib, AT * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)), "%s.rib%d" % [id, i + 1], not holo, an, AT)
			if holo:   # a hologram rib still shows where its footings will stand
				var fm: TLMesh = TLKitArena.footing(2.0, 1.1)
				for sz: float in [-span, span]:
					_static.append([fm.build("footing"), AT * Transform3D(Basis.IDENTITY, Vector3(x, 0, sz))])
					_static_tris += fm.tri_count
		var si: int = 0
		for s: Dictionary in A.get("scaffolds", []):
			var scp: Dictionary = {"bays": int(s["bays"]), "levels": int(s["levels"]), "decks": s["decks"]}
			for k: String in ["bay_w", "bay_d", "level_h"]:
				if s.has(k):
					scp[k] = s[k]
			si += 1
			_place(TLKit.build("scaffold", scp), AT * Transform3D(Basis(Vector3.UP, deg_to_rad(float(s.get("yaw", 0.0)))), Vector3(s["p"][0], 0, s["p"][1])), "%s.scaffold%d" % [id, si], true, an, AT)
		var bi: int = 0
		for b: Dictionary in A.get("bots", []):
			bi += 1
			var bp: Dictionary = (b.get("params", {}) as Dictionary).duplicate()
			if not bp.has("colors"):
				bp["colors"] = {"body": "bot_body" if bi % 3 != 0 else "bot_body2", "hat": ["hat_a", "hat_b", "hat_c"][bi % 3]}
			var rig: Node3D = TLRigs.build("bot", bp)
			rig.name = "bot%d" % bi
			rig.position = Vector3(b["p"][0], b["p"][1], b["p"][2])
			rig.rotation.y = deg_to_rad(float(b.get("yaw", 0.0)))
			rig.call("play", StringName(String(b.get("clip", "idle"))), 0.0)
			for f: int in 1 + (bi * 7) % 40:   # de-phase the crew
				rig.call("tick", f)
			an.add_child(rig)
			nodes["%s.bot%d" % [id, bi]] = rig
			if String(b.get("clip", "idle")) == "weld" and not TLStyle.headless():
				(rig.call("socket", &"tool") as Node3D).add_child(TLStyleFx.sparks())


func _on_circuit(on: Dictionary) -> Dictionary:
	var c: Dictionary = circuits[String(on["circuit"])]
	var path: TLKitPath = c["path"]
	var s: float
	if on.has("s"):
		s = float(on["s"])
	else:
		var q: Vector3 = path.query(float(on["near"][0]), float(on["near"][1]), 4)
		s = path.s[maxi(0, int(q.z))] + float(on.get("ds", 0.0))
	var at: Dictionary = path.at(s)
	var tan: Vector3 = at["tan"]
	var rgt: Vector3 = TLKitRoad.right_of(tan) * float(on.get("side", 1.0))
	return {"pos": (at["pos"] as Vector3) + rgt * float(on.get("off", 8.2)), "tan": tan, "s": s, "path": path, "road_y": (at["pos"] as Vector3).y}


func _build_walls() -> void:
	for w: Dictionary in L.get("walls", []):
		var id: String = String(w["id"])
		var nb: int = int(w.get("blocks", 12))
		var seed_: int = int(w.get("seed", 700))
		if w.has("p"):
			var wn: Node3D = TLKit.build("barrier_wall", {"blocks": mini(nb, 40), "seed": seed_})
			_place(wn, Transform3D(Basis(Vector3.UP, deg_to_rad(float(w.get("yaw", 0.0)))), _pos(w["p"])), id, false)
			continue
		var c: Dictionary = circuits[String(w["circuit"])]
		var path: TLKitPath = c["path"]
		var wa: Vector2 = TLKitLayout.v2(w["at"])
		var q: Vector3 = path.query(wa.x, wa.y, 3)
		var i0: int = maxi(0, int(q.z))
		var wall_s: float = path.s[i0]
		var tg: Vector2 = path.tang[i0]
		var side: float = 1.0 if (wa - path.pts[i0]).dot(Vector2(-tg.y, tg.x)) >= 0.0 else -1.0
		var holder: Node3D = Node3D.new()
		holder.name = id.validate_node_name()
		holder.set_meta("tl_kind", "wall")
		parts.add_child(holder)
		nodes[id] = holder
		for b: int in nb:
			var a: Dictionary = path.at(wall_s + (float(b) - (float(nb) - 1.0) * 0.5) * 2.46)
			var tan: Vector3 = a["tan"]
			var pos: Vector3 = (a["pos"] as Vector3) + TLKitRoad.right_of(tan) * side * (float(c["half_w"]) + 2.05)
			pos.y = ground(pos.x, pos.z).y + 0.06
			var blk: Node3D = TLKit.build("barrier_wall", {"blocks": 1, "seed": seed_ + b})
			blk.name = "block%d" % b
			blk.transform = Transform3D(Basis(tan, Vector3.UP, tan.cross(Vector3.UP).normalized()), pos)
			holder.add_child(blk)
			nodes["%s.block%d" % [id, b]] = blk


func _build_prop(pr: Dictionary) -> void:
	var kind: String = String(pr["kind"])
	var params: Dictionary = (pr.get("params", {}) as Dictionary).duplicate()
	var yaw: float = float(pr.get("yaw", 0.0))
	var o: Vector3
	if pr.has("on"):
		var oc: Dictionary = _on_circuit(pr["on"])
		o = ground((oc["pos"] as Vector3).x, (oc["pos"] as Vector3).z)
		yaw += rad_to_deg(atan2(-(oc["tan"] as Vector3).z, (oc["tan"] as Vector3).x))
	else:
		o = _pos(pr["p"])
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
	if kind == "fence" and pr.has("to"):
		var e: Vector3 = ground(pr["to"][0], pr["to"][1])
		var d: Vector3 = e - o
		params["length"] = clampf(d.length(), 1.0, 200.0)
		var fx: Vector3 = d.normalized()
		var fz: Vector3 = fx.cross(Vector3.UP).normalized()
		basis = Basis(fx, fz.cross(fx).normalized(), fz)
	var part: Node3D = TLKit.build(kind, params)
	_place(part, Transform3D(basis, o), _id(pr, kind), not bool(part.get_meta("tl_dynamic", false)) if part != null else true)


func _build_actors() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Actors"
	root.add_child(holder)
	for a: Dictionary in L.get("actors", []):
		var rig: Node3D = TLRigs.build(String(a["rig"]), a.get("params", {}))
		if rig == null:
			errors.append("actor '%s' could not be built" % String(a["id"]))
			continue
		var yaw: float = float(a.get("yaw", 0.0))
		var o: Vector3
		if a.has("on"):
			var oc: Dictionary = _on_circuit(a["on"])
			o = oc["pos"]
			o.y = float(oc["road_y"]) + 0.07
			yaw += rad_to_deg(atan2(-(oc["tan"] as Vector3).x, -(oc["tan"] as Vector3).z))   # rigs face -Z: turn -Z onto the tangent
		else:
			o = _pos(a["p"])
		rig.name = String(a["id"]).validate_node_name()
		rig.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), o)
		if a.has("clip"):
			if (rig.call("clips") as PackedStringArray).has(String(a["clip"])):
				rig.call("play", StringName(String(a["clip"])), 0.0)
				rig.call("tick", 1)
			else:
				errors.append("actor '%s': rig %s has no clip '%s'" % [String(a["id"]), String(a["rig"]), String(a["clip"])])
		holder.add_child(rig)
		nodes[String(a["id"])] = rig


## A waterfall hugs the cliff it belongs to: the lip and the foot are found by marching the terrain from p towards `to`.
func _build_waterfalls() -> void:
	for wf: Dictionary in L.get("waterfalls", []):
		var p: Vector2 = TLKitLayout.v2(wf["p"])
		var dir: Vector2 = (TLKitLayout.v2(wf["to"]) - p).normalized()
		var w: float = float(wf.get("w", 9.0))
		var top: float = terrain.h(p.x, p.y)
		var d: float = 0.0
		while d < 160.0 and terrain.h(p.x + dir.x * d, p.y + dir.y * d) > top - 2.0:
			d += 1.0
		var lip_d: float = d - 2.0
		while d < 260.0 and terrain.h(p.x + dir.x * d, p.y + dir.y * d) > water_y + 1.5:
			d += 1.0
		var run: float = d + 1.0 - lip_d
		var mk: TLMesh = TLMesh.new(66)
		mk.push(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(p.x + dir.x * lip_d, 0, p.y + dir.y * lip_d)))
		var segs: int = 14
		var prof: Array = []
		for i: int in segs + 1:
			var dd: float = lip_d + run * float(i) / float(segs)
			prof.append(Vector2(run * float(i) / float(segs) + 1.4, maxf(terrain.h(p.x + dir.x * dd, p.y + dir.y * dd), water_y) + (0.9 if i < segs else 0.1)))
		var strands: Array = [[-0.42, 0.20, "fall_a", 0.0], [-0.20, 0.13, "fall_b", 0.5], [-0.02, 0.22, "fall_a", 0.2], [0.21, 0.10, "fall_b", 0.6], [0.38, 0.17, "fall_a", 0.1]]
		for st: Array in strands:
			for i: int in segs:
				var k0: float = float(i) / float(segs)
				var k1: float = float(i + 1) / float(segs)
				var x0: float = (float(st[0]) + 0.03 * sin(float(i) * 1.7 + float(st[3]) * 9.0)) * w
				var x1: float = (float(st[0]) + 0.03 * sin(float(i + 1) * 1.7 + float(st[3]) * 9.0)) * w
				var h0: float = float(st[1]) * w * 0.5 * (0.8 + 0.5 * k0)
				var h1: float = float(st[1]) * w * 0.5 * (0.8 + 0.5 * k1)
				var a0: Vector2 = prof[i]
				var a1: Vector2 = prof[i + 1]
				var zo: float = float(st[3])
				mk.quad_up_any(Vector3(x0 - h0, a0.y, a0.x + zo), Vector3(x0 + h0, a0.y, a0.x + zo), Vector3(x1 + h1, a1.y, a1.x + zo), Vector3(x1 - h1, a1.y, a1.x + zo), String(st[2]))
		var foot: Vector2 = prof[segs]
		for k: int in 7:
			mk.blob(Vector3(0.20, 0.13, 0.16) * w, 1, 0.22, "fall_b", Color.WHITE, 0.03, Vector3((float(k) - 3.0) * 0.17 * w, water_y + 0.5 + float(k % 2) * 0.08 * w, foot.x + 1.0 + float(k % 3)))
		for k: int in 3:
			mk.blob(Vector3(0.14, 0.07, 0.10) * w, 1, 0.2, "fall_b", Color.WHITE, 0.03, Vector3((float(k) - 1.0) * 0.3 * w, (prof[0] as Vector2).y + 0.2, 1.2))
		mk.pop()
		TLKitParts.mesh(root, mk, "Waterfall%d" % root.get_child_count(), false)


# ------------------------------------------------------------------ nature (seeded scatter, MultiMesh)
func _scatter(holder: Node3D, mk: TLMesh, count: int, box: Rect2, accept: Callable, s_min: float, s_max: float, seed_: int, y_off: float = 0.0,
		vis_end: float = 0.0, cast: bool = true, tint: Callable = Callable(), lean: float = 0.0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_
	var xs: Array = []
	var tries: int = 0
	while xs.size() < count and tries < count * 40:
		tries += 1
		var x: float = box.position.x + rng.randf() * box.size.x
		var z: float = box.position.y + rng.randf() * box.size.y
		var y: float = terrain.h(x, z)
		var n: Vector3 = terrain.normal_at(x, z)
		if rng.randf() > float(accept.call(x, z, y, n)):
			continue
		var sc: float = rng.randf_range(s_min, s_max)
		var b: Basis = Basis(Vector3.UP, rng.randf() * TAU)
		if lean > 0.0:
			b = Basis(Vector3.RIGHT, (rng.randf() - 0.5) * lean) * Basis(Vector3.FORWARD, (rng.randf() - 0.5) * lean) * b
		b = b.scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc))
		xs.append([Transform3D(b, Vector3(x, y + y_off, z)), tint.call(rng, x, z, y) if tint.is_valid() else Color.WHITE])
	if xs.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mk.build("scatter")
	mm.instance_count = xs.size()
	for i: int in xs.size():
		mm.set_instance_transform(i, xs[i][0])
		mm.set_instance_color(i, xs[i][1])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Scatter%d" % holder.get_child_count()
	mmi.set_meta("tl_hash", "%s x%d seed %d" % [mk.content_hash(), xs.size(), seed_])
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = vis_end * 0.1
	holder.add_child(mmi)


func _free_ground(x: float, z: float, road_clear: float = 11.0, pad_clear: float = 4.0) -> bool:
	for id: String in circuits:
		if ((circuits[id]["path"] as TLKitPath).query(x, z).x) < road_clear + float(circuits[id]["half_w"]) - 5.0:
			return false
	for rv: Dictionary in river_paths:
		if (rv["path"] as TLKitPath).query(x, z, 3).x < float(rv["half_w"]) + 5.5:
			return false
	for pd: Dictionary in terrain.pads:
		if Vector2(x, z).distance_to(pd["c"]) < float(pd["r"]) + pad_clear:
			return false
	return true


func _view_clear(x: float, z: float) -> bool:
	for b: Array in (L.get("forest", {}) as Dictionary).get("clear", []):
		if x > float(b[0]) and x < float(b[1]) and z > float(b[2]) and z < float(b[3]):
			return false
	return true


func _build_nature() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Nature"
	root.add_child(holder)
	var T: TLKitTerrain = terrain
	var hi: float = terrain.base_y + 12.0   # nothing tall grows on the ridge tops (sight lines)
	var box: Rect2 = Rect2(-200, -270, 400, 380)
	var FO: Dictionary = L.get("forest", {})
	var pine_acc: Callable = func(x: float, z: float, y: float, n: Vector3) -> float:
		if n.y < 0.8 or y > hi or not _free_ground(x, z, 12.0, 6.0) or not _view_clear(x, z):
			return 0.0
		return smoothstep(0.5, 0.7, T.n_forest.get_noise_2d(x + 300.0, z) * 0.5 + 0.5)
	for v: int in 3:
		_scatter(holder, TLKitNature.pine(100 + v, 8.5 + v * 2.0, 5, 2.1 + v * 0.3), int(330.0 * float(FO.get("density", 1.0))), box, pine_acc, 0.8, 1.35, 500 + v, -0.2, 0.0, true, Callable(), 0.05)
	var edge_acc: Callable = func(x: float, z: float, _y: float, n: Vector3) -> float:
		return 1.0 if n.y > 0.8 and _free_ground(x, z, 12.0, 4.0) else 0.0
	for e: Array in FO.get("edges", []):
		for v: int in 3:
			_scatter(holder, TLKitNature.pine(100 + v, 8.5 + v * 2.0, 5, 2.1 + v * 0.3), int(e[4]) / 3, Rect2(float(e[0]), float(e[2]), float(e[1]) - float(e[0]), float(e[3]) - float(e[2])), edge_acc, 0.8, 1.4, 700 + v + int(e[0]), -0.2, 0.0, true, Callable(), 0.05)
	var leaf_acc: Callable = func(x: float, z: float, y: float, n: Vector3) -> float:
		if n.y < 0.85 or y > hi or not _free_ground(x, z, 12.0, 6.0) or not _view_clear(x, z):
			return 0.0
		return 0.05 + 0.2 * smoothstep(0.35, 0.5, T.n_forest.get_noise_2d(x + 80.0, z + 40.0) * 0.5 + 0.5)
	_scatter(holder, TLKitNature.broadleaf(120, 7.5), 60, box, leaf_acc, 0.8, 1.3, 530)
	var rock_acc: Callable = func(x: float, z: float, _y: float, n: Vector3) -> float:
		if not _free_ground(x, z, 8.0, 2.0):
			return 0.0
		return 0.9 if n.y < 0.78 else 0.04
	for v: int in 3:
		_scatter(holder, TLKitNature.rock(200 + v, 1.2 + v * 0.5, 0.65), 55, box, rock_acc, 0.8, 2.2, 540 + v, -0.25)
	var bush_acc: Callable = func(x: float, z: float, _y: float, n: Vector3) -> float:
		if n.y < 0.85 or not _free_ground(x, z, 8.0, 2.0):
			return 0.0
		return 0.08
	_scatter(holder, TLKitNature.bush(300, 1.0), 90, box, bush_acc, 0.7, 1.4, 550)
	var grass_acc: Callable = func(x: float, z: float, y: float, n: Vector3) -> float:
		if n.y < 0.72:
			return 0.0
		if y > hi - 1.0:
			return 0.95
		return 0.0 if not _free_ground(x, z, 8.0, 1.0) else 0.12
	var gt: Callable = func(rng: RandomNumberGenerator, _x: float, _z: float, _y: float) -> Color:
		var k: float = rng.randf()
		return Color(0.85 + 0.35 * k, 0.9 + 0.2 * rng.randf(), 0.7 + 0.2 * (1.0 - k), 1.0)
	_scatter(holder, TLKitNature.grass_tuft(400, 4, 0.5), 3000, Rect2(-50, -28, 100, 60), grass_acc, 0.7, 1.35, 560, -0.02, 130.0, false, gt)
	_scatter(holder, TLKitNature.grass_tuft(401, 4, 0.55), 1500, Rect2(-120, -90, 240, 130), grass_acc, 0.8, 1.5, 561, -0.02, 90.0, false, gt)
