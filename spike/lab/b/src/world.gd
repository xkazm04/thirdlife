class_name World
extends Node3D
## Assembles a scene from kit parts using ONLY a layout file (data/layout.json, or data/layout_<name>.json with
## --layout=<name>): ridge, pads, mesas, circuit, river, arena (rink size, yaw, ribs), cranes, scaffolds, house, props,
## nature exclusions, cameras. No coordinates live in code. Static site meshes are merged so shadow cascades draw once.

var L: Dictionary = {}
var road: Path
var river: Path
var terrain: Terrain
var parts: Dictionary = {}
var stage: Dictionary = {}
var ribs: Array = []        # {built, holo, build, static}
var cranes: Array = []
var arena: Node3D
var arena_c: Vector3
var rib_span: float = 15.5
var blockers: Array = []    # {c: Vector2, r: float}: simple circles the avatar cannot enter
var _static: Array = []     # [mesh, global transform] merged at the end
const WATER_Y: float = -15.2


static func v2(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


func load_layout(lname: String) -> void:
	var path: String = "res://data/layout.json" if lname == "" else "res://data/layout_%s.json" % lname
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	L = JSON.parse_string(f.get_as_text())


func rib_x(i: int) -> float:
	var a: Dictionary = L["arena"]
	return (float(i) - (float(a["ribs"]) - 1.0) * 0.5 + float(a.get("rib_off", 0.0))) * float(a["rib_dx"])


func ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.h(x, z), z)


## Kit parts return a MeshInstance3D; when only the mesh is merged, the node must be freed (a Node is not
## reference counted: pass 2 leaked 8 of these plus their meshes and materials at exit).
static func _take(mi: MeshInstance3D) -> Mesh:
	var m: Mesh = mi.mesh
	mi.free()
	return m


func block(x: float, z: float, r: float) -> void:
	blockers.append({"c": Vector2(x, z), "r": r})


func build() -> void:
	var t0: int = Time.get_ticks_msec()
	var cps: Array = []
	for p: Array in L["circuit"]["cps"]:
		cps.append(v2(p))
	road = Path.new(cps, true, 2.0)
	var RL: float = road.length
	var ry: float = float(L["circuit"].get("y", -12.0))
	road.set_heights(func(s: float, _p: Vector2) -> float: return ry + 1.2 * sin(s / RL * TAU * 2.0 + 0.8) + 0.55 * sin(s / RL * TAU * 5.0))
	var rc: Array = []
	for p: Array in L.get("river", [[-2400, -2400], [-2500, -2400]]):   # layout C edit: the river is optional
		rc.append(v2(p))
	river = Path.new(rc, false, 4.0)
	river.set_heights(func(_s: float, _p: Vector2) -> float: return -15.2)
	terrain = Terrain.new(road, river, int(L.get("seed", 7)))
	terrain.ridge_a = v2(L["ridge"]["a"])
	terrain.ridge_b = v2(L["ridge"]["b"])
	terrain.ridge_fall = float(L["ridge"].get("fall", 17.0))
	for rp: Dictionary in L["ridge"].get("ramps", []):
		terrain.ridge_ramps.append({"c": v2(rp["c"]), "w": float(rp.get("w", 14.0)), "fall": float(rp.get("fall", 24.0))})
	for pd: Dictionary in L["pads"]:
		terrain.pads.append({"c": v2(pd["c"]), "r": float(pd["r"]), "blend": float(pd["blend"]), "h": float(pd["h"]), "dirt": bool(pd.get("dirt", false))})
	for ms: Dictionary in L.get("mesas", []):
		terrain.mesas.append({"c": v2(ms["c"]), "r": float(ms["r"]), "h": float(ms["h"]), "blend": float(ms.get("blend", 20.0)), "noise": float(ms.get("noise", 14.0))})
	terrain.build_grid()
	add_child(terrain.build_near())
	add_child(terrain.build_far())
	add_child(KitRoad.build(road))
	add_child(KitRoad.river_ribbon(river, 5.5, 0.0))
	_build_arena()
	_build_cranes()
	_build_props()
	_build_house()
	_build_waterfalls()
	if Style.user_args.has("nomerge"):   # measurement switch: one MeshInstance per part, as in pass 1
		for it: Array in _static:
			var one: MeshInstance3D = MeshInstance3D.new()
			one.mesh = it[0]
			one.transform = it[1]
			add_child(one)
	else:
		var sm: MeshInstance3D = MeshInstance3D.new()
		sm.mesh = MK.merge(_static, "site_static")
		sm.name = "SiteStatic"
		add_child(sm)
	_build_nature()
	print("[world] layout '%s': road %.0f m, built in %d ms" % [String(L.get("name", "?")), road.length, Time.get_ticks_msec() - t0])


func _holo_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/holo.gdshader")
	Style.push("holo", m)
	return m


func _build_arena() -> void:
	var A: Dictionary = L["arena"]
	arena_c = Vector3(A["c"][0], A["c"][1], A["c"][2])
	arena = Node3D.new()
	arena.name = "Arena"
	arena.position = arena_c
	arena.rotation.y = deg_to_rad(float(A.get("yaw", 0.0)))
	add_child(arena)
	var AT: Transform3D = arena.transform
	var rk: Array = A["rink"]
	rib_span = float(rk[1]) * 0.5 + 2.5
	var ice: ShaderMaterial = Style.material("ice")
	ice.set_shader_parameter("rink_c", Vector2(arena_c.x, arena_c.z))
	ice.set_shader_parameter("rink_s", Vector3(float(rk[0]) * 0.5, float(rk[1]) * 0.5, float(rk[2])))
	ice.set_shader_parameter("rink_rot", arena.rotation.y)
	_static.append([_take(KitArena.rink(float(rk[0]), float(rk[1]), float(rk[2]))), AT])
	if int(A.get("rows", 10)) > 0:   # layout C edit: rows 0 = no stands at all
		_static.append([_take(KitArena.stands(float(rk[0]), float(rk[1]), int(A.get("rows", 10)))), AT])
	var holo: ShaderMaterial = _holo_material()
	var n: int = int(A["ribs"])
	var built_n: int = int(A["built"])
	var dx: float = float(A["rib_dx"])
	var apex: float = float(A.get("apex", 14.0))
	var fm: MK = MK.new(35)
	for i: int in n:
		var x: float = rib_x(i)
		var m: ArrayMesh = KitArena.rib_mesh(rib_span, apex, 2.6, dx if i > 0 else 0.0, "rib_built", "rib_steel")
		var lt: Transform3D = Transform3D(Basis.IDENTITY, Vector3(x, 0, 0))
		if i < built_n:
			_static.append([m, AT * lt])
			ribs.append({"built": null, "holo": null, "build": 1.0, "static": true})
		else:
			var built: MeshInstance3D = MeshInstance3D.new()
			built.mesh = m
			built.transform = lt
			built.name = "RibBuilt%d" % (i + 1)
			built.visible = false
			arena.add_child(built)
			var h: MeshInstance3D = MeshInstance3D.new()
			h.mesh = KitArena.rib_mesh(rib_span, apex, 2.6, dx if i > 0 else 0.0, "holo_dummy", "holo_dummy")
			for k: int in h.mesh.get_surface_count():
				h.mesh.surface_set_material(k, holo)
			h.transform = lt
			h.name = "RibHolo%d" % (i + 1)
			h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arena.add_child(h)
			built.set_instance_shader_parameter("build", 0.0)
			h.set_instance_shader_parameter("build", 0.0)
			ribs.append({"built": built, "holo": h, "build": 0.0, "static": false})
		for sz: float in [-rib_span, rib_span]:
			fm.push_at(Vector3(x, 0, sz))
			fm.box(Vector3(2.0, 1.1, 2.0), "concrete", Color.WHITE, 0.08, Vector3(0, 0.45, 0))
			fm.box(Vector3(1.5, 0.3, 1.5), "concrete_dark", Color.WHITE, 0.04, Vector3(0, 1.1, 0))
			fm.pop()
			var wp: Vector3 = AT * Vector3(x, 0, sz)
			block(wp.x, wp.z, 1.3)
	_static.append([fm.build("footings"), AT])
	for s: Dictionary in A.get("scaffolds", []):
		var sc: MeshInstance3D = KitSite.scaffold(int(s["bays"]), int(s["levels"]), 2.4, 1.3, 2.0, s["decks"])
		var st: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(s.get("yaw", 0.0)))), Vector3(s["p"][0], 0, s["p"][1]))
		_static.append([_take(sc), AT * st])


func _build_cranes() -> void:
	for c: Dictionary in L.get("cranes", []):
		var n: Node3D = KitSite.crane(float(c.get("h", 35.0)), 2.3, float(c.get("jib", 30.0)), 11.0)
		n.position = ground(c["p"][0], c["p"][1])
		(n.get_node("Slew") as Node3D).rotation_degrees.y = float(c.get("yaw", 0.0))
		(n.get_node("Slew/Hoist") as Node3D).position.x = float(c.get("jib", 30.0)) * float(c.get("trolley", 0.55))
		add_child(n)
		cranes.append(n)
		block(n.position.x, n.position.z, 3.0)


## Props are pure layout data: {"k": kind, "p": [x, z] or "s": metres along the circuit + "side", "yaw", "a": [args]}.
func _build_props() -> void:
	var mk: MK = MK.new(51)
	for pr: Dictionary in L.get("props", []):
		var yaw: float = float(pr.get("yaw", 0.0))
		var a: Array = pr.get("a", [])
		var o: Vector3
		if pr.has("s"):
			var at: Dictionary = road.at(float(pr["s"]))
			var rgt: Vector3 = KitRoad.right_of(at["tan"]) * float(pr.get("side", 1.0))
			var pp: Vector3 = (at["pos"] as Vector3) + rgt * float(pr.get("off", 8.2))
			o = ground(pp.x, pp.z)
			yaw += rad_to_deg(atan2(-(at["tan"] as Vector3).z, (at["tan"] as Vector3).x))
		else:
			o = ground(pr["p"][0], pr["p"][1])
		match String(pr["k"]):
			"lumber": KitSite.add_lumber(mk, o, a[0], a[1], int(a[2]), yaw)
			"pallet": KitSite.add_pallet(mk, o, int(a[0]) if a.size() > 0 else 3, yaw)
			"barricade": KitSite.add_barricade(mk, o, 1.9, yaw)
			"cone": KitSite.add_cone(mk, o)
			"fence":
				KitSite.add_fence(mk, o, ground(a[0], a[1]))
			"site_fence": KitSite.add_site_fence(mk, o, ground(a[0], a[1]))
			"sign": KitSite.add_sign(mk, o, yaw, String(a[0]) if a.size() > 0 else "sign")
			"flag": KitSite.add_flag(mk, o, float(a[0]) if a.size() > 0 else 7.0, String(a[1]) if a.size() > 1 else "flag_a")
			"light_mast":
				var mh: float = float(a[0]) if a.size() > 0 else 14.0
				KitSite.add_light_mast(mk, o, mh, yaw)
				block(o.x, o.z, 0.8)
				_site_light(o + Vector3(0, mh + 0.4, 0), yaw, mh)
			"cabin":
				KitSite.add_cabin(mk, o, yaw)
				block(o.x, o.z, 2.6)
			"scoreboard": KitSite.add_scoreboard(mk, o, yaw)
			"tyres": KitSite.add_tyres(mk, o, yaw, int(a[0]) if a.size() > 0 else 5)
			"marshal": KitSite.add_marshal_post(mk, o, yaw)
			"watch_tower":   # layout D edit 1 (after the freeze)
				KitSite.add_watch_tower(mk, o, yaw, float(a[0]) if a.size() > 0 else 9.0)
				block(o.x, o.z, 2.6)
			"entrance": KitSite.add_entrance(mk, o, yaw)
			"pond": KitSite.add_pond(mk, o, float(a[0]), float(a[1]), String(a[2]) if a.size() > 2 else "pond_ice")
			"bridge": KitSite.add_bridge(mk, Vector3(o.x, WATER_Y, o.z), yaw, float(a[0]) if a.size() > 0 else 26.0, float(a[1]) if a.size() > 1 else 4.6, int(a[2]) if a.size() > 2 else 3)
			"stones":
				for i: int in int(a[0]):
					mk.box(Vector3(0.5, 0.5, 0.5), "stone", Color(0.9 + 0.05 * (i % 2), 0.9, 0.9), 0.05, o + Vector3(i * 0.62, 0.25, -0.1 * (i % 2)))
	_static.append([mk.build("props"), Transform3D.IDENTITY])


## layout C edit: "houses": [ {p, yaw, ext_side, frame} ... ] builds a village; the single "house" key still works.
func _build_house() -> void:
	var hs: Array = L.get("houses", [])
	if L.has("house"):
		hs = hs + [L["house"]]
	for H: Dictionary in hs:
		_build_one_house(H)


func _build_one_house(H: Dictionary) -> void:
	var p: Vector3 = Vector3(H["p"][0], H["p"][1], H["p"][2])
	var T: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(H.get("yaw", 0.0)))), p)
	_static.append([_take(KitHouse.house(8.0, 5.6, 3.0, 2.7)), T])
	var ext: float = 7.4 * float(H.get("ext_side", 1.0))   # which end of the house the timber-frame extension stands on
	var blocks: Array = [Vector3(-2, 0, 0), Vector3(2, 0, 0)]
	if bool(H.get("frame", true)):
		_static.append([_take(KitHouse.frame(6.0, 5.6, 3.0, 2.4)), T * Transform3D(Basis.IDENTITY, Vector3(ext, 0, 0))])
		blocks.append(Vector3(ext, 0, 0))
	for c: Vector3 in blocks:
		var w: Vector3 = T * c
		block(w.x, w.z, 3.4)
	var sm: CPUParticles3D = Fx.smoke()
	sm.position = T * Vector3(2.08, 7.7, -0.78)
	add_child(sm)
	# warm window and porch light spilling onto the ground
	for lp: Vector3 in [Vector3(-2.4, 2.0, 4.2), Vector3(2.4, 2.0, 4.2), Vector3(0.8, 2.6, 3.6)]:
		var ol: OmniLight3D = OmniLight3D.new()
		ol.light_color = Color(Style.data["palette"]["window"])
		ol.light_energy = float(Style.data.get("lights", {}).get("window", 5.0))
		ol.omni_range = float(Style.data.get("lights", {}).get("window_range", 7.5))
		ol.omni_attenuation = 1.4
		ol.position = T * lp
		add_child(ol)
	parts["house_t"] = T


## Warm spill from a light mast: a shadowless spot aimed at the ground in front of the lamp head (energy = style lights.mast).
func _site_light(p: Vector3, yaw_deg: float, h: float) -> void:
	var e: float = float(Style.data.get("lights", {}).get("mast", 0.0))
	if e <= 0.0:
		return
	var sl: SpotLight3D = SpotLight3D.new()
	sl.light_color = Color(String(Style.data["palette"]["window"]))
	sl.light_energy = e
	sl.spot_range = h * 2.6
	sl.spot_angle = 36.0
	sl.spot_angle_attenuation = 0.5
	sl.spot_attenuation = 0.35
	sl.shadow_enabled = false
	add_child(sl)
	sl.position = p
	var fwd: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(0, 0, 1)
	sl.look_at(p + fwd * h * 0.75 - Vector3(0, h, 0), Vector3.UP)


## A waterfall is layout data {"p": [x, z] on a cliff top, "to": [x, z] towards its pool, "w": width}. The lip and the
## foot are found by marching the terrain from p towards the pool, so the fall always hugs the cliff it belongs to.
## Drawn in the ink style: separate strands of two flat tones with rock showing between them, foam at lip and foot.
func _build_waterfalls() -> void:
	for wf: Dictionary in L.get("waterfalls", []):
		var p: Vector2 = v2(wf["p"])
		var dir: Vector2 = (v2(wf["to"]) - p).normalized()
		var w: float = float(wf.get("w", 9.0))
		var top: float = terrain.h(p.x, p.y)
		var d: float = 0.0
		while d < 160.0 and terrain.h(p.x + dir.x * d, p.y + dir.y * d) > top - 2.0:
			d += 1.0
		var lip_d: float = d - 2.0
		while d < 260.0 and terrain.h(p.x + dir.x * d, p.y + dir.y * d) > WATER_Y + 1.5:
			d += 1.0
		var run: float = d + 1.0 - lip_d
		var mk: MK = MK.new(66)
		mk.push(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(p.x + dir.x * lip_d, 0, p.y + dir.y * lip_d)))
		var segs: int = 14
		var prof: Array = []   # (z outward, y) following the cliff, pushed 1.4 m off the rock
		for i: int in segs + 1:
			var dd: float = lip_d + run * float(i) / float(segs)
			prof.append(Vector2(run * float(i) / float(segs) + 1.4, maxf(terrain.h(p.x + dir.x * dd, p.y + dir.y * dd), WATER_Y) + (0.9 if i < segs else 0.1)))
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
			mk.blob(Vector3(0.20, 0.13, 0.16) * w, 1, 0.22, "fall_b", Color.WHITE, 0.03, Vector3((float(k) - 3.0) * 0.17 * w, WATER_Y + 0.5 + float(k % 2) * 0.08 * w, foot.x + 1.0 + float(k % 3)))
		for k: int in 3:
			mk.blob(Vector3(0.14, 0.07, 0.10) * w, 1, 0.2, "fall_b", Color.WHITE, 0.03, Vector3((float(k) - 1.0) * 0.3 * w, (prof[0] as Vector2).y + 0.2, 1.2))
		mk.pop()
		var mi: MeshInstance3D = mk.instance("waterfall")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## Scatter `count` instances of `mesh` where accept(x, z, y, normal) returns a keep-probability.
func _scatter(mesh: Mesh, count: int, box: Rect2, accept: Callable, s_min: float, s_max: float, seed_: int, y_off: float = 0.0,
		vis_end: float = 0.0, cast: bool = true, tint: Callable = Callable(), lean: float = 0.0) -> MultiMeshInstance3D:
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
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i: int in xs.size():
		mm.set_instance_transform(i, xs[i][0])
		mm.set_instance_color(i, xs[i][1])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = vis_end * 0.1
	add_child(mmi)
	return mmi


func _free_ground(x: float, z: float, road_clear: float = 11.0, pad_clear: float = 4.0) -> bool:
	if road.query(x, z).x < road_clear:
		return false
	if river.query(x, z, 3).x < 11.0:
		return false
	for pd: Dictionary in terrain.pads:
		if Vector2(x, z).distance_to(pd["c"]) < float(pd["r"]) + pad_clear:
			return false
	return true


## Sight lines that tall trees must not block (layout "clear": [x0, x1, z0, z1] boxes).
func _view_clear(x: float, z: float) -> bool:
	for b: Array in L.get("clear", []):
		if x > float(b[0]) and x < float(b[1]) and z > float(b[2]) and z < float(b[3]):
			return false
	return true


func _build_nature() -> void:
	var T: Terrain = terrain
	var box: Rect2 = Rect2(-200, -270, 400, 380)
	var pine_acc: Callable = func(x: float, z: float, y: float, n: Vector3) -> float:
		if n.y < 0.8 or y > -2.0 or not _free_ground(x, z, 12.0, 6.0) or not _view_clear(x, z):
			return 0.0
		return smoothstep(0.5, 0.7, T.n_forest.get_noise_2d(x + 300.0, z) * 0.5 + 0.5)
	var FO: Dictionary = L.get("forest", {})   # layout C edit: {"density": pine count multiplier, "edges": [[x0, x1, z0, z1, pines]]}
	for v: int in 3:
		_scatter(KitNature.pine(100 + v, 8.5 + v * 2.0, 5, 2.1 + v * 0.3), int(330.0 * float(FO.get("density", 1.0))), box, pine_acc, 0.8, 1.35, 500 + v, -0.2, 0.0, true, Callable(), 0.05)
	var edge_acc: Callable = func(x: float, z: float, _y: float, n: Vector3) -> float:
		return 1.0 if n.y > 0.8 and _free_ground(x, z, 12.0, 4.0) else 0.0
	for e: Array in FO.get("edges", []):
		for v: int in 3:
			_scatter(KitNature.pine(100 + v, 8.5 + v * 2.0, 5, 2.1 + v * 0.3), int(e[4]) / 3, Rect2(float(e[0]), float(e[2]), float(e[1]) - float(e[0]), float(e[3]) - float(e[2])), edge_acc, 0.8, 1.4, 700 + v + int(e[0]), -0.2, 0.0, true, Callable(), 0.05)
	var leaf_acc: Callable = func(x: float, z: float, y: float, n: Vector3) -> float:
		if n.y < 0.85 or y > -2.0 or not _free_ground(x, z, 12.0, 6.0) or not _view_clear(x, z):
			return 0.0
		return 0.05 + 0.2 * smoothstep(0.35, 0.5, T.n_forest.get_noise_2d(x + 80.0, z + 40.0) * 0.5 + 0.5)
	_scatter(KitNature.broadleaf(120, 7.5), 60, box, leaf_acc, 0.8, 1.3, 530)
	var rock_acc: Callable = func(x: float, z: float, _y: float, n: Vector3) -> float:
		if not _free_ground(x, z, 8.0, 2.0):
			return 0.0
		return 0.9 if n.y < 0.78 else 0.04
	for v: int in 3:
		_scatter(KitNature.rock(200 + v, 1.2 + v * 0.5, 0.65), 55, box, rock_acc, 0.8, 2.2, 540 + v, -0.25)
	var bush_acc: Callable = func(x: float, z: float, _y: float, n: Vector3) -> float:
		if n.y < 0.85 or not _free_ground(x, z, 8.0, 2.0):
			return 0.0
		return 0.08
	_scatter(KitNature.bush(300, 1.0), 90, box, bush_acc, 0.7, 1.4, 550)
	var grass_acc: Callable = func(x: float, z: float, y: float, n: Vector3) -> float:
		if n.y < 0.72:
			return 0.0
		if y > -3.0:
			return 0.95
		return 0.0 if not _free_ground(x, z, 8.0, 1.0) else 0.12
	var gt: Callable = func(rng: RandomNumberGenerator, _x: float, _z: float, _y: float) -> Color:
		var k: float = rng.randf()
		return Color(0.85 + 0.35 * k, 0.9 + 0.2 * rng.randf(), 0.7 + 0.2 * (1.0 - k), 1.0)
	_scatter(KitNature.grass_tuft(400, 4, 0.5), 3000, Rect2(-50, -28, 100, 60), grass_acc, 0.7, 1.35, 560, -0.02, 130.0, false, gt)
	_scatter(KitNature.grass_tuft(401, 4, 0.55), 1500, Rect2(-120, -90, 240, 130), grass_acc, 0.8, 1.5, 561, -0.02, 90.0, false, gt)
	# hero tree + foreground boulders (layout data), merged into one mesh
	var items: Array = []
	if L.has("hero_tree"):
		var tp: Vector3 = ground(L["hero_tree"][0], L["hero_tree"][1])
		items.append([KitNature.hero_tree(), Transform3D(Basis.IDENTITY, tp - Vector3(0, 0.3, 0))])
		block(tp.x, tp.z, 1.1)
	for r: Array in L.get("hero_rocks", []):
		var rp: Vector3 = ground(r[0], r[1])
		items.append([KitNature.rock(int(r[4]), float(r[2]), float(r[3])), Transform3D(Basis(Vector3.UP, float(r[4]) * 1.7), rp - Vector3(0, 0.2, 0))])
		block(rp.x, rp.z, float(r[2]) * 0.85)
	var hm: MeshInstance3D = MeshInstance3D.new()
	hm.mesh = MK.merge(items, "ridge_dressing")
	hm.name = "RidgeDressing"
	add_child(hm)
