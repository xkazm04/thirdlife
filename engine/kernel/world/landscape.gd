extends RefCounted
## N7 / P4. The world's own landscape: everything between the plots. Drawn once, owned by the world, never by a pack.
##
##   var stats: Dictionary = Landscape.build(parent, plots, radii, has_ground, cfg)
##
## P4: the ground has height (terrain/village_terrain.gd: rolling land, a ring of hills, a bluff, a valley with a river
## and two ponds). Every plot stands on a flat pad of its own height (`pad_h`, the walk's plot origin y) with a bank
## round it, a kerb at its lip and a spur road that climbs to the gate; the main road follows the land and crosses the
## river on a bridge; trees, rocks and bushes follow the land (tree lines on ridges, rocks on banks, none on a road,
## none inside a plot). The visitor's collider (terrain/world_space.gd) is built from the same things and stored on
## `parent` as the meta `tl_space`.
## `plots`: Transform3D per plot (world coordinates, lift included), `radii`: metres, `has_ground`: the pack has terrain
## of its own at its edge (the world's ground is cut open for it). `cfg` (the walk script's `landscape` block, all
## optional): road, road_half_m, spurs, fence, gates, lots ([{"at": [x, z], "radius": m, "h": pad height}]), pad_h (per
## plot: the height of its pad, default the plot's own y), river ({"path": [[x, z], ...], "half_m", "pond_m"}), trees,
## broadleaf, rocks, bushes, tufts, belt, mesas, seed, ground_key, spread_m, cell_m, rim_band.
## Cost is in the returned stats (`build_ms`, `terrain_ms`, instance counts); kernel/world/WORLD.md has the figures.

const VillageTerrain: GDScript = preload("res://kernel/world/terrain/village_terrain.gd")
const WorldSpace: GDScript = preload("res://kernel/world/terrain/world_space.gd")
const Parts: GDScript = preload("res://kernel/world/terrain/village_parts.gd")

const GROUND_Y: float = 0.0              # the terrain and the far plain: a pack's rim and the ground meet at the same height
const FLAT_GROUND_Y: float = -0.06      # the flat ground of single shots (`ground()`), as in N7
const PAD_EXTRA: float = 10.5            # the flat of a pad reaches this far beyond the plot's radius (ring and fence stand on it)


## The private material of the world's ground: the palette's shader and lookup, with the plots that carry a ground of
## their own cut open (toon.gdshader `tl_holes`).
static func _ground_material(plots: Array, radii: Array, has_ground: Array) -> ShaderMaterial:
	var pal: ShaderMaterial = TLStyle.material(&"white") as ShaderMaterial
	if pal == null or pal.shader == null:
		return null
	var gm: ShaderMaterial = ShaderMaterial.new()
	gm.shader = pal.shader
	gm.set_shader_parameter(&"pal_lut", pal.get_shader_parameter(&"pal_lut"))
	var holes: Array = []
	for i: int in plots.size():
		if float(radii[i]) > 0.0 and bool(has_ground[i]) and holes.size() < 32:
			holes.append(Vector4((plots[i] as Transform3D).origin.x, (plots[i] as Transform3D).origin.z, float(radii[i]) + 2.5, 0.0))
	var n: int = holes.size()
	while holes.size() < 32:
		holes.append(Vector4.ZERO)
	gm.set_shader_parameter(&"tl_holes", holes)
	gm.set_shader_parameter(&"tl_hole_n", n)
	return gm


## The flat ground of N7 (used when the landscape is off: `--landscape=off`, single shots).
static func ground(parent: Node3D, plots: Array, radii: Array, has_ground: Array, key: String = "") -> MeshInstance3D:
	var g: MeshInstance3D = TLStyle.ground(FLAT_GROUND_Y, key, 3000.0)
	parent.add_child(g)
	var gm: ShaderMaterial = _ground_material(plots, radii, has_ground)
	if gm != null:
		g.material_override = gm
	return g


static func _multi(parent: Node3D, mk: TLMesh, xs: Array, mname: String) -> void:
	if xs.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mk.build(mname.to_snake_case())
	mm.instance_count = xs.size()
	for i: int in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, Color.WHITE)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = mname
	mmi.multimesh = mm
	parent.add_child(mmi)


static func _v2(a: Variant) -> Vector2:
	return Vector2(float((a as Array)[0]), float((a as Array)[1]))


static func build(parent: Node3D, plots: Array, radii: Array, has_ground: Array, cfg: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var stats: Dictionary = {"road_m": 0.0, "spurs": 0, "fence_m": 0.0, "trees": 0, "rocks": 0, "bushes": 0, "mesas": 0}
	if TLStyle.headless():
		ground(parent, plots, radii, has_ground, str(cfg.get("ground_key", "")))
		return stats
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 7))
	# ---- plots and lots: centre, radius, own ground, pad height
	var centres: Array = []
	var rad: Array = radii.duplicate()
	var own_ground: Array = has_ground.duplicate()
	var pad_h: Array = []
	var pad_cfg: Array = cfg.get("pad_h", []) if typeof(cfg.get("pad_h")) == TYPE_ARRAY else []
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for i: int in plots.size():
		var pt: Transform3D = plots[i]
		var c: Vector2 = Vector2(pt.origin.x, pt.origin.z)
		centres.append(c)
		pad_h.append(float(pad_cfg[i]) if i < pad_cfg.size() else pt.origin.y)
		lo = lo.min(c - Vector2.ONE * (float(radii[i]) + PAD_EXTRA))
		hi = hi.max(c + Vector2.ONE * (float(radii[i]) + PAD_EXTRA))
	var lots: Array = cfg.get("lots", []) if typeof(cfg.get("lots")) == TYPE_ARRAY else []
	var lot_auto: Array = []
	for k: int in lots.size():
		var lot: Dictionary = lots[k]
		var lc: Vector2 = _v2(lot["at"])
		var lr: float = float(lot.get("radius", 20.0))
		centres.append(lc)
		rad.append(lr)
		own_ground.append(false)
		pad_h.append(float(lot["h"]) if lot.has("h") else NAN)
		lot_auto.append(not lot.has("h"))
		lo = lo.min(lc - Vector2.ONE * (lr + PAD_EXTRA))
		hi = hi.max(lc + Vector2.ONE * (lr + PAD_EXTRA))
	var cps: Array = []
	for p: Variant in cfg.get("road", []):
		cps.append(_v2(p))
		lo = lo.min(cps[cps.size() - 1])
		hi = hi.max(cps[cps.size() - 1])
	var rv_cfg: Dictionary = cfg.get("river", {}) if typeof(cfg.get("river")) == TYPE_DICTIONARY else {}
	for p: Variant in rv_cfg.get("path", []):
		lo = lo.min(_v2(p) - Vector2.ONE * 40.0)
		hi = hi.max(_v2(p) + Vector2.ONE * 40.0)
	# ---- the terrain object (heights are built below, once pads, roads and the river are known)
	var cell: float = float(cfg.get("cell_m", 3.0))
	var margin: float = float(cfg.get("margin_m", 110.0))
	var bx0: float = floorf((lo.x - margin) / cell) * cell
	var bz0: float = floorf((lo.y - margin) / cell) * cell
	var bx1: float = ceilf((hi.x + margin) / cell) * cell
	var bz1: float = ceilf((hi.y + margin) / cell) * cell
	var terr: RefCounted = VillageTerrain.new(int(cfg.get("seed", 7)), Rect2(bx0, bz0, bx1 - bx0, bz1 - bz0), cell)
	terr.set("centre", (lo + hi) * 0.5)
	terr.set("relief", float(cfg.get("relief", 1.0)))
	for k: int in lots.size():
		if lot_auto[k]:
			var li: int = plots.size() + k
			pad_h[li] = float(terr.call("base_h", (centres[li] as Vector2).x, (centres[li] as Vector2).y))
	var pads: Array = []
	for i: int in centres.size():
		if float(rad[i]) > 0.0:
			pads.append({"c": centres[i], "r": float(rad[i]) + PAD_EXTRA, "h": float(pad_h[i]), "own": bool(own_ground[i])})
	terr.set("pads", pads)
	# ---- the roads: a main line that follows the land, a spur to every plot that climbs from the road to the gate
	var half: float = float(cfg.get("road_half_m", 2.6))
	var rd_list: Array = []
	var main_path: TLKitPath = null
	var main_ys: PackedFloat32Array = PackedFloat32Array()
	if cps.size() >= 2:
		main_path = TLKitPath.new(cps, false, 2.0)
		main_ys.resize(main_path.pts.size())
		for i: int in main_path.pts.size():
			main_ys[i] = float(terr.call("base_h", main_path.pts[i].x, main_path.pts[i].y))
		Parts.smooth(main_ys, 12)
		Parts.smooth(main_ys, 10)
		rd_list.append({"pts": main_path.pts, "ys": main_ys, "half": half})
		stats["road_m"] = snappedf(main_path.length, 0.1)
	var gates: Array = []                                    # per plot: the direction its gate faces (to the road)
	gates.resize(centres.size())
	var spur_paths: Array = []                               # [index, TLKitPath, ys]
	if main_path != null and bool(cfg.get("spurs", true)):
		for i: int in centres.size():
			var c: Vector2 = centres[i]
			var best: int = 0
			for q: int in main_path.pts.size():
				if main_path.pts[q].distance_squared_to(c) < main_path.pts[best].distance_squared_to(c):
					best = q
			var dir: Vector2 = (main_path.pts[best] - c).normalized()
			gates[i] = dir
			var from: Vector2 = c + dir * (float(rad[i]) + 0.5)
			var span: float = from.distance_to(main_path.pts[best])
			if span < 1.0:
				continue
			var sp: TLKitPath = TLKitPath.new([from, main_path.pts[best]], false, 2.0)
			var sys: PackedFloat32Array = PackedFloat32Array()
			sys.resize(sp.pts.size())
			var flat_len: float = PAD_EXTRA - 0.5
			for q: int in sp.pts.size():
				var l: float = from.distance_to(sp.pts[q])
				var f: float = smoothstep(0.0, 1.0, clampf((l - flat_len) / maxf(span - flat_len, 4.0), 0.0, 1.0))
				sys[q] = lerpf(float(pad_h[i]), main_ys[best], f)
			spur_paths.append([i, sp, sys])
			rd_list.append({"pts": sp.pts, "ys": sys, "half": half * 0.8})
			stats["spurs"] = int(stats["spurs"]) + 1
	terr.set("roads", rd_list)
	# ---- the river and its ponds
	var rv_path: TLKitPath = null
	var rv_half: float = float(rv_cfg.get("half_m", 6.0))
	if (rv_cfg.get("path", []) as Array).size() >= 2:
		var rcps: Array = []
		for p: Variant in rv_cfg["path"]:
			rcps.append(_v2(p))
		rv_path = TLKitPath.new(rcps, false, 4.0)
		var ry: PackedFloat32Array = PackedFloat32Array()
		ry.resize(rv_path.pts.size())
		for i: int in rv_path.pts.size():
			ry[i] = float(terr.call("base_h", rv_path.pts[i].x, rv_path.pts[i].y))
		Parts.smooth(ry, 8)
		Parts.smooth(ry, 8)
		for i: int in ry.size():
			ry[i] -= float(rv_cfg.get("depth_m", 5.6))
			if i > 0:
				ry[i] = minf(ry[i], ry[i - 1] - 0.004 * 4.0)
		for i: int in ry.size():
			rv_path.ys[i] = ry[i]
		terr.set("river", {"pts": rv_path.pts, "ys": ry, "half": rv_half})
		var pr: float = float(rv_cfg.get("pond_m", 18.0))
		terr.set("ponds", [{"c": rv_path.pts[0], "r": pr, "y": ry[0]}, {"c": rv_path.pts[rv_path.pts.size() - 1], "r": pr * 1.2, "y": ry[ry.size() - 1]}])
	terr.call("build_grid")
	var gmat: ShaderMaterial = _ground_material(plots, radii, has_ground)
	var tmat: Material = gmat
	if tmat == null:
		tmat = TLStyle.material(&"terrain")
	var tmi: MeshInstance3D = terr.call("build_mesh", tmat)
	parent.add_child(tmi)
	Parts.far_ground(parent, terr, str(cfg.get("ground_key", "")))
	var tms: int = int(terr.get("build_ms"))
	stats["terrain_ms"] = tms
	stats["terrain_verts"] = (int(terr.get("nx")) + 1) * (int(terr.get("nz")) + 1)
	stats["terrain_size_m"] = [snappedf(bx1 - bx0, 1.0), snappedf(bz1 - bz0, 1.0)]
	var hmin: float = INF
	var hmax: float = -INF
	for hv: float in (terr.get("heights") as PackedFloat32Array):
		hmin = minf(hmin, hv)
		hmax = maxf(hmax, hv)
	stats["height_range_m"] = [snappedf(hmin, 0.1), snappedf(hmax, 0.1)]
	stats["pads"] = pad_h.map(func(v: float) -> float: return snappedf(v, 0.1))
	var ws: RefCounted = WorldSpace.new()
	ws.set("tag", "wall")
	parent.set_meta(&"tl_space", ws)
	parent.tree_exiting.connect(func() -> void: ws.call("free_all"))
	# ---- roads: strips on the ground, a worn verge, a trodden middle; the bridge replaces the road over the river
	var road_pts: PackedVector2Array = PackedVector2Array()
	var mk_road: TLMesh = TLMesh.new(31)
	var bridge_a: int = -1
	var bridge_b: int = -1
	var bridge_probe: Array = []
	if main_path != null:
		road_pts.append_array(main_path.pts)
		if rv_path != null:
			for i: int in main_path.pts.size():
				if float(terr.call("river_dist", main_path.pts[i].x, main_path.pts[i].y)) < rv_half + 11.0:
					if bridge_a < 0:
						bridge_a = i
					bridge_b = i
		Parts.strip(mk_road, terr, main_path.pts, half + 0.7, 0.05, "grass_dry", 1.0, rng, bridge_a, bridge_b)
		Parts.strip(mk_road, terr, main_path.pts, half, 0.065, "dirt", 1.0, rng, bridge_a, bridge_b)
		Parts.strip(mk_road, terr, main_path.pts, half * 0.36, 0.08, "dirt", 0.9, rng, bridge_a, bridge_b)
		for sp: Array in spur_paths:
			var spp: TLKitPath = sp[1]
			Parts.strip(mk_road, terr, spp.pts, half * 0.8 + 0.5, 0.052, "grass_dry", 1.0, rng)
			Parts.strip(mk_road, terr, spp.pts, half * 0.8, 0.07, "dirt", 0.97, rng)
			road_pts.append_array(spp.pts)
		var rmi: MeshInstance3D = mk_road.instance("WorldRoad")
		rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(rmi)
	# ---- the river: water at its level, a pond at each end, a bridge where the road crosses
	if rv_path != null:
		var mk_w: TLMesh = TLKitRoad.river_ribbon(rv_path, rv_half + 9.0, 0.0)
		for pn: Dictionary in (terr.get("ponds") as Array):
			var pc: Vector2 = pn["c"]
			var pr2: float = float(pn["r"]) + 6.0
			var py: float = float(pn["y"])
			var seg: int = 20
			for k: int in seg:
				var a0: float = TAU * float(k) / float(seg)
				var a1: float = TAU * float(k + 1) / float(seg)
				mk_w.tri(Vector3(pc.x, py, pc.y), Vector3(pc.x + cos(a1) * pr2, py, pc.y + sin(a1) * pr2), Vector3(pc.x + cos(a0) * pr2, py, pc.y + sin(a0) * pr2), "water", Color.WHITE,
					Vector2(pc.x * 0.1, pc.y * 0.1), Vector2((pc.x + cos(a1) * pr2) * 0.1, (pc.y + sin(a1) * pr2) * 0.1), Vector2((pc.x + cos(a0) * pr2) * 0.1, (pc.y + sin(a0) * pr2) * 0.1))
		var wmi: MeshInstance3D = mk_w.instance("WorldWater")
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(wmi)
		stats["river_m"] = snappedf(rv_path.length, 0.1)
	if bridge_a >= 0 and main_path != null:
		ws.set("tag", "bridge")
		Parts.bridge(parent, ws, terr, main_path, main_ys, bridge_a, bridge_b, half)
		ws.set("tag", "wall")
		stats["bridge_m"] = snappedf(float(bridge_b - bridge_a) * 2.0, 0.1)
		var bm: Vector2 = main_path.pts[(bridge_a + bridge_b) / 2]
		var bt: Vector2 = (main_path.pts[(bridge_a + bridge_b) / 2 + 1] - main_path.pts[(bridge_a + bridge_b) / 2 - 1]).normalized()
		bridge_probe = [snappedf(bm.x, 0.01), snappedf(bm.y, 0.01), snappedf(-bt.y, 0.001), snappedf(bt.x, 0.001)]
	# ---- every plot's edge: a ring of worn ground, a kerb at the lip of the pad and a fence with a gate towards the road
	var mk_edge: TLMesh = TLMesh.new(33)
	var mk_ring: TLMesh = TLMesh.new(34)
	var mk_kerb: TLMesh = TLMesh.new(37)
	# P6: a pad is a place, not a disc: a worn ring 2 to 8 m wide (noise), rocks instead of fence on the side away
	# from the gate (the visitor's wall stays). A generator of its own: the scatter below keeps the places it had.
	var rng6: RandomNumberGenerator = RandomNumberGenerator.new()
	rng6.seed = int(cfg.get("seed", 7)) + 606
	var edge_n: FastNoiseLite = FastNoiseLite.new()
	edge_n.seed = int(cfg.get("seed", 7)) + 6
	edge_n.frequency = 0.03
	var edge_rocks: Array = []
	var ring_out: Callable = func(c: Vector2, r: float, a: float) -> float:
		return r + 2.0 + 6.2 * smoothstep(0.25, 0.8, edge_n.get_noise_2d(c.x + cos(a) * r, c.y + sin(a) * r) * 0.5 + 0.5)
	for i: int in centres.size():
		var r: float = float(rad[i])
		if r <= 0.0:
			continue
		var c: Vector2 = centres[i]
		var H: float = float(pad_h[i])
		var seg: int = maxi(24, int(TAU * r / 3.2))
		var r0: float = r + (2.4 if bool(own_ground[i]) else 0.0)        # a pack with its own ground is drawn to r + 3
		var r1: float = r + 5.0
		var gate: Variant = gates[i]
		var gate_a: float = atan2((gate as Vector2).y, (gate as Vector2).x) if gate != null else 0.0
		var rock_a: float = gate_a + PI + 0.6 * sin(float(i) * 2.1)
		var rock_w: float = 0.8 if (gate != null and bool(cfg.get("pad_rocks", true))) else -1.0
		var gate_w: float = (half * 0.8 + 1.6) / (r + 3.5)
		if gate != null and bool(cfg.get("gates", true)):
			# the gate: a flag on each side and a sign that faces the road
			var gd: Vector3 = Vector3((gate as Vector2).x, 0.0, (gate as Vector2).y)
			var side: Vector3 = Vector3(-gd.z, 0.0, gd.x)
			var gp: Vector3 = Vector3(c.x, H, c.y) + gd * (r + 3.6)
			TLKitSite.add_flag(mk_edge, gp + side * (half * 0.8 + 1.9), 5.5, "flag_a" if i % 2 == 0 else "flag_b")
			TLKitSite.add_flag(mk_edge, gp - side * (half * 0.8 + 1.9), 5.5, "flag_a" if i % 2 == 0 else "flag_b")
			TLKitSite.add_sign(mk_edge, gp + gd * 2.4 + side * (half * 0.8 + 3.6), rad_to_deg(atan2(gd.x, gd.z)))
		var run: PackedVector3Array = PackedVector3Array()
		var kerb_r: float = r + PAD_EXTRA - 0.4
		for k: int in seg:
			var a0: float = TAU * float(k) / float(seg)
			var a1: float = TAU * float(k + 1) / float(seg)
			var d0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
			var d1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
			var o: Vector3 = Vector3(c.x, H + 0.014, c.y)
			var tone: float = 0.92 + 0.14 * rng.randf()
			var ra: float = maxf(r0 + 0.4, float(ring_out.call(c, r, a0)))
			var rb: float = maxf(r0 + 0.4, float(ring_out.call(c, r, a1)))
			mk_ring.quad_up(o + d0 * r0, o + d0 * ra, o + d1 * rb, o + d1 * r0, "dirt", Color(tone, tone, tone))
			var og: Vector3 = Vector3(c.x, H + 0.008, c.y)
			mk_ring.quad_up(og + d0 * ra, og + d0 * (ra + 1.2), og + d1 * (rb + 1.2), og + d1 * rb, "grass_dry", Color.WHITE)
			# the kerb: a low stone edge at the lip where the pad meets its bank, wherever the bank falls or rises by more than a step
			var mid_pt: Vector2 = c + Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)) * (kerb_r + 4.0)
			var out_h: float = float(terr.call("h", mid_pt.x, mid_pt.y))
			if absf(out_h - H) > 0.9 and float(terr.call("road_dist", mid_pt.x, mid_pt.y)) > half + 3.0:
				var kc: Vector3 = Vector3(c.x, H, c.y) + (d0 + d1).normalized() * kerb_r
				var yaw_k: float = rad_to_deg(-((a0 + a1) * 0.5))
				mk_kerb.push_at(kc + Vector3(0.0, 0.2, 0.0), Vector3(0.0, yaw_k, 0.0))
				mk_kerb.box(Vector3(0.9, 0.46, (d0 - d1).length() * kerb_r + 0.12), "stone", Color(0.95, 0.95, 0.95), 0.05)
				mk_kerb.pop()
			if bool(cfg.get("fence", true)):
				var mid: float = (a0 + a1) * 0.5
				if gate != null and absf(angle_difference(mid, gate_a)) < gate_w:
					if run.size() > 1:
						ws.call("add_wall", run, 3.0)
					run = PackedVector3Array()
					continue
				var f: Vector3 = Vector3(c.x, H, c.y)
				if rock_w > 0.0 and absf(angle_difference(mid, rock_a)) < rock_w:
					Parts.edge_rocks(rng6, f, r, a0, a1, 1.0 - absf(angle_difference(mid, rock_a)) / rock_w, edge_rocks)
				else:
					TLKitSite.add_fence(mk_edge, f + d0 * (r + 3.6), f + d1 * (r + 3.6), 3.4)
					stats["fence_m"] = float(stats["fence_m"]) + (d0 - d1).length() * (r + 3.6)
				if run.is_empty():
					run.append(f + d0 * (r + 3.6))
				run.append(f + d1 * (r + 3.6))
		if run.size() > 1:
			ws.call("add_wall", run, 3.0)
	# ---- the lots: worn ground, a crane, a scaffold, stacked timber and pallets: the next game is being built here
	for k: int in lots.size():
		var li: int = plots.size() + k
		var lc: Vector2 = centres[li]
		var lr: float = float(rad[li])
		var base: Vector3 = Vector3(lc.x, float(pad_h[li]), lc.y)
		var segs: int = 28
		for q: int in segs:
			var a0: float = TAU * float(q) / float(segs)
			var a1: float = TAU * float(q + 1) / float(segs)
			var tone: float = 0.9 + 0.14 * rng.randf()
			var o: Vector3 = base + Vector3(0.0, 0.014, 0.0)
			var la: float = lr * (0.86 + 0.24 * (edge_n.get_noise_2d(lc.x + cos(a0) * lr * 3.0, lc.y + sin(a0) * lr * 3.0) * 0.5 + 0.5))
			var lb: float = lr * (0.86 + 0.24 * (edge_n.get_noise_2d(lc.x + cos(a1) * lr * 3.0, lc.y + sin(a1) * lr * 3.0) * 0.5 + 0.5))
			mk_ring.quad_up(o, o + Vector3(cos(a0), 0.0, sin(a0)) * la, o + Vector3(cos(a1), 0.0, sin(a1)) * lb, o, "dirt", Color(tone, tone, tone))
		var crane: Node3D = TLKitSite.crane(26.0, 2.0, 20.0, 8.0)
		crane.name = "WorldLotCrane%d" % k
		crane.position = base + Vector3(-lr * 0.38, 0.0, -lr * 0.22)
		crane.rotation.y = rng.randf() * TAU
		parent.add_child(crane)
		ws.call("add_box", Transform3D(Basis(), crane.position + Vector3(0.0, 3.0, 0.0)), Vector3(4.0, 6.0, 4.0))
		var sc: MeshInstance3D = TLKitSite.scaffold(3, 2).instance("WorldLotScaffold%d" % k)
		sc.position = base + Vector3(lr * 0.05, 0.0, -lr * 0.4)
		parent.add_child(sc)
		ws.call("add_box", Transform3D(Basis(), sc.position + Vector3(3.6, 2.0, 0.0)), Vector3(7.4, 4.0, 1.6))
		TLKitSite.add_lumber(mk_edge, base + Vector3(lr * 0.38, 0.0, lr * 0.2), 3.2, 1.0, 6, 20.0)
		TLKitSite.add_lumber(mk_edge, base + Vector3(lr * 0.12, 0.0, lr * 0.5), 3.2, 1.0, 4, -35.0)
		ws.call("add_box", Transform3D(Basis(), base + Vector3(lr * 0.38, 0.5, lr * 0.2)), Vector3(3.4, 1.2, 1.8))
		for j: int in 3:
			TLKitSite.add_pallet(mk_edge, base + Vector3(-lr * 0.15 + float(j) * 2.7, 0.0, lr * 0.08), 2 + j % 2, 12.0 * float(j))
		var lg: Variant = gates[li]
		if lg != null:
			var gd: Vector3 = Vector3((lg as Vector2).x, 0.0, (lg as Vector2).y)
			var side: Vector3 = Vector3(-gd.z, 0.0, gd.x)
			var yaw: float = rad_to_deg(atan2(gd.x, gd.z))
			TLKitSite.add_barricade(mk_edge, base + gd * (lr - 3.0) + side * 2.6, 1.8, yaw)
			TLKitSite.add_barricade(mk_edge, base + gd * (lr - 3.0) - side * 2.6, 1.8, yaw)
			for j: int in 4:
				TLKitSite.add_cone(mk_edge, base + gd * (lr - 5.0 - float(j) * 1.6) + side * (1.4 if j % 2 == 0 else -1.4))
		stats["lots"] = int(stats.get("lots", 0)) + 1
	var ring: MeshInstance3D = mk_ring.instance("WorldPlotRings")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	parent.add_child(mk_edge.instance("WorldPlotFences"))
	if mk_kerb.tri_count > 0:
		parent.add_child(mk_kerb.instance("WorldPadKerbs"))
	if not edge_rocks.is_empty():
		_multi(parent, TLKitNature.rock(210, 1.3, 0.78), edge_rocks, "WorldPadRocks")
		(parent.get_node("WorldPadRocks") as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # 337 rocks in four cascades cost more than they showed
		ws.set("tag", "rock")
		for x: Transform3D in edge_rocks:
			if x.basis.get_scale().x * 1.3 * 0.78 >= 0.9:
				ws.call("add_trunk", x.origin, x.basis.get_scale().x * 1.1, 1.4)
		ws.set("tag", "wall")
	stats["pad_rocks"] = edge_rocks.size()
	stats["fence_m"] = snappedf(float(stats["fence_m"]), 0.1)
	# ---- scatter: follows the land. Never inside a plot (plus its pad), never on a road, never in the river.
	var spread: float = float(cfg.get("spread_m", 70.0))
	var box: Rect2 = Rect2(Vector2(bx0, bz0) + Vector2.ONE * 30.0, Vector2(bx1 - bx0, bz1 - bz0) - Vector2.ONE * 60.0)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(cfg.get("seed", 7))
	noise.frequency = 0.022
	var is_free: Callable = func(p: Vector2, clear: float, road_clear: float, river_clear: float) -> bool:
		for i: int in centres.size():
			if p.distance_to(centres[i]) < float(rad[i]) + clear:
				return false
		if float(terr.call("road_dist", p.x, p.y)) < road_clear:
			return false
		return float(terr.call("river_dist", p.x, p.y)) > river_clear
	# mode: "ridge" (trees stand on convex ground), "bank" (rocks stand on steep ground and at the water), "any"
	var place: Callable = func(count: int, area: Rect2, clear: float, road_clear: float, s_min: float, s_max: float, clump: float, y_off: float, mode: String, max_slope: float) -> Array:
		var xs: Array = []
		var tries: int = 0
		while xs.size() < count and tries < count * 60:
			tries += 1
			var p: Vector2 = area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
			if clump > 0.0 and noise.get_noise_2d(p.x, p.y) < clump - 1.0 + rng.randf() * 0.5:
				continue
			var water: float = rv_half + (4.0 if mode != "bank" else 0.5)
			if not bool(is_free.call(p, clear, road_clear, water)):
				continue
			var sl: float = float(terr.call("slope", p.x, p.y))
			if sl > max_slope:
				continue
			if mode == "ridge":
				var conv: float = float(terr.call("h", p.x, p.y)) - 0.25 * (float(terr.call("h", p.x + 12.0, p.y)) + float(terr.call("h", p.x - 12.0, p.y)) + float(terr.call("h", p.x, p.y + 12.0)) + float(terr.call("h", p.x, p.y - 12.0)))
				if rng.randf() > 0.12 + 0.88 * smoothstep(-0.8, 1.6, conv):
					continue
			elif mode == "bank":
				var rdist: float = float(terr.call("river_dist", p.x, p.y))
				if sl < 0.06 and rdist > rv_half + 9.0 and rng.randf() > 0.06:
					continue
			var sc: float = rng.randf_range(s_min, s_max)
			var b: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc))
			xs.append(Transform3D(b, Vector3(p.x, float(terr.call("gy", p.x, p.y)) + y_off, p.y)))
		return xs
	ws.set("tag", "tree")
	var probe: Dictionary = {}
	var trees: int = int(cfg.get("trees", 120))
	for v: int in 3:
		var xs: Array = place.call(trees / 3, box, 9.0, 6.0, 0.8, 1.35, 0.9, -0.2, "ridge", 0.3)
		_multi(parent, TLKitNature.pine(100 + v, 8.5 + float(v) * 2.0, 5, 2.1 + float(v) * 0.3), xs, "WorldPines%d" % v)
		for x: Transform3D in xs:
			ws.call("add_trunk", x.origin, 0.42 * x.basis.get_scale().x)
			Parts.probe_candidate(probe, "tree", terr, x.origin, 0.42 * x.basis.get_scale().x)
		stats["trees"] = int(stats["trees"]) + xs.size()
	var leaf: Array = place.call(int(cfg.get("broadleaf", 40)), box, 10.0, 6.5, 0.8, 1.3, 0.7, 0.0, "any", 0.22)
	_multi(parent, TLKitNature.broadleaf(120, 7.5), leaf, "WorldBroadleaf")
	for x: Transform3D in leaf:
		ws.call("add_trunk", x.origin, 0.5 * x.basis.get_scale().x)
	stats["trees"] = int(stats["trees"]) + leaf.size()
	for v: int in 2:
		ws.set("tag", "rock")
		var xs: Array = place.call(int(cfg.get("rocks", 46)) / 2, box, 6.5, 3.6, 0.7, 2.0, 0.0, -0.25, "bank", 0.9)
		_multi(parent, TLKitNature.rock(200 + v, 1.2 + float(v) * 0.5, 0.65), xs, "WorldRocks%d" % v)
		for x: Transform3D in xs:
			var rvis: float = x.basis.get_scale().x * (1.2 + float(v) * 0.5)
			if rvis * 0.65 >= 0.5:           # a rock lower than a knee is a stone he walks over, not an obstacle
				ws.call("add_trunk", x.origin, rvis * 0.85, 1.4)
				Parts.probe_candidate(probe, "rock", terr, x.origin, rvis * 0.85)
		stats["rocks"] = int(stats["rocks"]) + xs.size()
	var bushes: Array = place.call(int(cfg.get("bushes", 90)), box, 6.5, 3.4, 0.7, 1.4, 0.4, 0.0, "any", 0.2)
	_multi(parent, TLKitNature.bush(300, 1.0), bushes, "WorldBushes")
	stats["bushes"] = bushes.size()
	var road_side: Array = Parts.road_side(rng6, terr, road_pts, half, rv_half, is_free, int(cfg.get("road_trees", 44)), int(cfg.get("road_bushes", 70)))
	var road_trees: Array = road_side[0]            # P6: density where the eye goes: trees and bushes along the roads
	var road_bushes: Array = road_side[1]
	_multi(parent, TLKitNature.broadleaf(121, 6.5), road_trees, "WorldRoadTrees")
	_multi(parent, TLKitNature.bush(301, 0.9), road_bushes, "WorldRoadBushes")
	if not road_bushes.is_empty():
		(parent.get_node("WorldRoadBushes") as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ws.set("tag", "tree")
	for x: Transform3D in road_trees:
		ws.call("add_trunk", x.origin, 0.5 * x.basis.get_scale().x)
	stats["trees"] = int(stats["trees"]) + road_trees.size()
	stats["bushes"] = int(stats["bushes"]) + road_bushes.size()
	var tufts: Array = []
	var want_tufts: int = int(cfg.get("tufts", 1400)) if road_pts.size() > 0 else 0
	var ttries: int = 0
	while tufts.size() < want_tufts and ttries < want_tufts * 6:
		ttries += 1
		var q: Vector2 = road_pts[rng.randi_range(0, road_pts.size() - 1)]
		var a: float = rng.randf() * TAU
		var p: Vector2 = q + Vector2(cos(a), sin(a)) * (half + 1.2 + rng.randf() * rng.randf() * 16.0)
		if not bool(is_free.call(p, 6.5, half + 1.0, rv_half + 2.0)) or float(terr.call("slope", p.x, p.y)) > 0.3:
			continue
		var sc: float = rng.randf_range(0.8, 1.6)
		tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p.x, float(terr.call("gy", p.x, p.y)) + 0.04, p.y)))
	if not tufts.is_empty():
		_multi(parent, TLKitNature.grass_tuft(400, 4, 0.5), tufts, "WorldTufts")
		var tm: MultiMeshInstance3D = parent.get_node("WorldTufts") as MultiMeshInstance3D
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tm.visibility_range_end = 120.0
		tm.visibility_range_end_margin = 12.0
	stats["tufts"] = tufts.size()
	# a forest belt on the hills round the village: the skyline between the venues and the mesas
	var belt: int = int(cfg.get("belt", 180))
	var centre: Vector2 = (lo + hi) * 0.5
	var reach: float = (hi - lo).length() * 0.5
	for v: int in 2:
		var xs: Array = []
		var tries: int = 0
		while xs.size() < belt / 2 and tries < belt * 25:
			tries += 1
			var a: float = rng.randf() * TAU
			var d: float = reach * 0.7 + spread * 0.6 + rng.randf() * rng.randf() * 260.0
			var p: Vector2 = centre + Vector2(cos(a), sin(a)) * d
			if bool(terr.call("inside", p.x, p.y, 8.0)):
				if not bool(is_free.call(p, 9.0, 6.0, rv_half + 4.0)) or float(terr.call("slope", p.x, p.y)) > 0.34:
					continue
				if float(terr.call("h", p.x, p.y)) < 3.0 and rng.randf() > 0.3:
					continue            # the belt stands on the hills; the plain is left open
			elif float(terr.call("road_dist", p.x, p.y)) < 7.0:
				continue
			var sc: float = rng.randf_range(0.9, 1.7)
			var py: float = float(terr.call("gy", p.x, p.y)) - 0.2 if bool(terr.call("inside", p.x, p.y)) else -0.26
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.95, 1.2), sc)), Vector3(p.x, py, p.y)))
		_multi(parent, TLKitNature.pine(110 + v, 10.0 + float(v) * 2.5, 5, 2.4 + float(v) * 0.3), xs, "WorldBelt%d" % v)
		for x: Transform3D in xs:
			if bool(terr.call("inside", x.origin.x, x.origin.z)):
				ws.call("add_trunk", x.origin, 0.5 * x.basis.get_scale().x)
		stats["trees"] = int(stats["trees"]) + xs.size()
	var mesa_trees: Array = []            # P6: the mesas stand ON the plain: a grass foot, pines at foot and cap, pine clumps before them
	stats["mesas"] = Parts.mesas(parent, rng, centre, reach, int(cfg.get("mesas", 18)), mesa_trees)
	Parts.plain_clumps(rng6, terr, centre, reach, int(cfg.get("plain_clumps", 16)), mesa_trees)
	if not mesa_trees.is_empty():
		_multi(parent, TLKitNature.pine(130, 10.0, 4, 2.6), mesa_trees, "WorldMesaPines")
		(parent.get_node("WorldMesaPines") as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stats["far_trees"] = mesa_trees.size()
	# ---- the visitor's collider: the terrain (left open where a plot's own ground carries him) and a copy of every
	# pack's static colliders
	var cs0: int = Time.get_ticks_msec()
	var skip: Callable = func(cx: float, cz: float) -> bool:
		for i: int in plots.size():
			if bool(has_ground[i]) and float(radii[i]) > 0.0 and Vector2(cx, cz).distance_to(centres[i]) < float(radii[i]) - 1.0:
				return true
		return false
	ws.set("tag", "terrain")
	ws.call("add_faces", terr.call("collision_faces", skip))
	var view: Node = parent.get_parent()
	var world: Variant = view.get("world") if view != null else null
	if world != null:
		var holders: Array = (world as Node).get("packs")
		var band: float = float(cfg.get("rim_band", 9.0))
		for i: int in mini(holders.size(), plots.size()):
			if float(radii[i]) > 0.0 and is_instance_valid(holders[i]):
				ws.set("tag", "pack %d" % i)
				ws.call("add_pack", holders[i], plots[i], float(radii[i]), float(pad_h[i]) - (plots[i] as Transform3D).origin.y, band)
	ws.call("finish")
	stats["space"] = ws.get("stats")
	stats["space_ms"] = Time.get_ticks_msec() - cs0
	parent.set_meta(&"tl_terrain", terr)
	parent.set_meta(&"tl_probe", probe)
	if not bridge_probe.is_empty():
		probe["rail"] = bridge_probe
	stats["probe"] = probe
	stats["build_ms"] = Time.get_ticks_msec() - t0
	return stats


## The haze of a world: a venue 200 m away must still read. Scales the style's fog on the environment the world
## host installed (the style file itself is not touched: a single pack looks as it did).
static func tone_haze(host: Node, k: float) -> bool:
	var we: WorldEnvironment = _find_env(host)
	if we == null or we.environment == null:
		return false
	we.environment.fog_density *= k
	we.environment.fog_height_density *= k
	return true


static func _find_env(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n as WorldEnvironment
	for c: Node in n.get_children():
		var w: WorldEnvironment = _find_env(c)
		if w != null:
			return w
	return null
