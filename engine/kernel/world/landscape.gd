extends RefCounted
## N7 / P4. The world's own landscape: everything between the plots. Drawn once, owned by the world, never by a pack.
##
##   var stats: Dictionary = Landscape.build(parent, plots, radii, has_ground, cfg)
##
## P4: the ground has height (terrain/village_terrain.gd: rolling land, a ring of hills, a bluff, a valley with a river
## and two ponds). Every plot stands on a flat pad of its own height (`pad_h`, the walk's plot origin y) with a graded
## shoulder and a spur road that climbs to the entrance; the main road follows the land and crosses the
## river on a bridge; trees, rocks and bushes follow the land (tree lines on ridges, rocks on banks, none on a road,
## none inside a plot). The visitor's collider (terrain/world_space.gd) is built from the same things and stored on
## `parent` as the meta `tl_space`.
## `plots`: Transform3D per plot (world coordinates, lift included), `radii`: metres, `has_ground`: the pack has terrain
## of its own at its edge (the world's ground is cut open for it). `cfg` (the walk script's `landscape` block, all
## optional): road, road_half_m, spurs, fence, gates, lots ([{"at": [x, z], "radius": m, "h": pad height}]; S: a lot with
## `job` and `replay` is a construction site, kernel/world/site.gd: when its log is found it is a plot, drawn by site/draw.gd), pad_h (per
## plot: the height of its pad, default the plot's own y before the lift), river ({"path": [[x, z], ...], "half_m", "pond_m"}), trees,
## broadleaf, rocks, bushes, tufts, belt, mesas, seed, ground_key, spread_m, cell_m, rim_band.
## Cost is in the returned stats (`build_ms`, `terrain_ms`, instance counts); kernel/world/WORLD.md has the figures.

const DrawBase := preload("res://kernel/world/draw/draw_base.gd")
const VillageTerrain: GDScript = preload("res://kernel/world/terrain/village_terrain.gd")
const WorldSpace: GDScript = preload("res://kernel/world/terrain/world_space.gd")
const Parts: GDScript = preload("res://kernel/world/terrain/village_parts.gd")
const SiteDraw: GDScript = preload("res://kernel/world/site/draw.gd")    # S: a construction site's look

const GROUND_Y: float = 0.0              # the terrain and the far plain: a pack's rim and the ground meet at the same height
const FLAT_GROUND_Y: float = -0.06      # the flat ground of single shots (`ground()`), as in N7
const SCATTER_MARGIN: float = 10.5            # clearance for scenery around a reserved plot


## The private material of the world's ground: the palette's shader and lookup, with the plots that carry a ground of
## their own cut open (toon.gdshader `tl_holes`).
static func _ground_material(plots: Array, radii: Array, has_ground: Array, village := false) -> ShaderMaterial:
	var pal: ShaderMaterial = TLStyle.material(&"white") as ShaderMaterial
	if pal == null or pal.shader == null:
		return null
	var gm := VillageTerrain._village_material() if village else pal.duplicate() as ShaderMaterial
	var holes: Array = []
	for i: int in plots.size():
		if float(radii[i]) > 0.0 and bool(has_ground[i]) and holes.size() < 32:
			holes.append(Vector4((plots[i] as Transform3D).origin.x, (plots[i] as Transform3D).origin.z, float(radii[i]) + 2.5, 0.0))
	var n: int = holes.size()
	while holes.size() < 32:
		holes.append(Vector4.ZERO)
	gm.set_shader_parameter(&"tl_holes", holes)
	gm.set_shader_parameter(&"tl_hole_n", n)
	gm.set_meta(&"tl_holes_all", holes.duplicate())      # walker-feel T: every hole as cut, for draw/view_seam.gd `close_holes`
	return gm


## The flat ground of N7 (`--landscape=off`, single shots); its material is the meta `tl_ground_mat` of `parent` as in `build` (bugfix-37 D16).
static func ground(parent: Node3D, plots: Array, radii: Array, has_ground: Array, key: String = "") -> MeshInstance3D:
	var g: MeshInstance3D = TLStyle.ground(FLAT_GROUND_Y, key, 3000.0)
	parent.add_child(g)
	var gm: ShaderMaterial = _ground_material(plots, radii, has_ground)
	if gm != null:
		g.material_override = gm
		parent.set_meta(&"tl_ground_mat", gm)
	return g


static func _v2(a: Variant) -> Vector2:
	return Vector2(float((a as Array)[0]), float((a as Array)[1]))


static func build(parent: Node3D, plots: Array, radii: Array, has_ground: Array, cfg: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var stats: Dictionary = {"_lap": Time.get_ticks_usec(), "road_m": 0.0, "spurs": 0, "fence_m": 0.0, "trees": 0, "rocks": 0, "bushes": 0, "mesas": 0}
	if TLStyle.headless():
		ground(parent, plots, radii, has_ground, str(cfg.get("ground_key", "")))
		return stats
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 7))
	# ---- plots and lots: centre, radius, own ground, pad height
	var centres: Array = []
	var footprints: Array = cfg.get("footprints", [])
	var extents: Array[Vector2] = []
	var axes: Array[Vector2] = []
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
		pad_h.append(float(pad_cfg[i]) if i < pad_cfg.size() else pt.origin.y + float(WorldSpace.call("pad_rim", parent.get_parent(), i, float(radii[i]))))
		var extent: Vector2 = footprints[i] * 0.5 if i < footprints.size() else Vector2.ONE * float(radii[i])
		var axis := Vector2(pt.basis.x.x, pt.basis.x.z).normalized()
		extents.append(extent)
		axes.append(axis)
		var bounds := (axis.abs() * extent.x + axis.orthogonal().abs() * extent.y).max(Vector2.ONE * float(radii[i]))
		lo = lo.min(c - bounds - Vector2.ONE * SCATTER_MARGIN)
		hi = hi.max(c + bounds + Vector2.ONE * SCATTER_MARGIN)
	var lots: Array = (cfg["lots"] as Array).duplicate() if typeof(cfg.get("lots")) == TYPE_ARRAY else []     # S: a copy (site lots are taken out of it)
	var site_plots: Array = SiteDraw.split_lots(parent, lots)   # S: a construction site is a plot (kernel/world/site.gd); the rest stay plain lots
	var lot_auto: Array = []
	for k: int in lots.size():
		var lot: Dictionary = lots[k]
		var lc: Vector2 = _v2(lot["at"])
		var lr: float = float(lot.get("radius", 20.0))
		centres.append(lc)
		extents.append(Vector2(0.72, 0.62) * lr)   # working floor under the crane, scaffold and stores
		axes.append(Vector2.RIGHT)
		rad.append(lr)
		own_ground.append(false)
		pad_h.append(float(lot["h"]) if lot.has("h") else NAN)
		lot_auto.append(not lot.has("h"))
		lo = lo.min(lc - Vector2.ONE * (lr + SCATTER_MARGIN))
		hi = hi.max(lc + Vector2.ONE * (lr + SCATTER_MARGIN))
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
			var flat_len := 2.5 + cell * sqrt(2.0) if i < plots.size() else 0.0
			for q: int in sp.pts.size():
				var l: float = from.distance_to(sp.pts[q])
				var f: float = smoothstep(0.0, 1.0, clampf((l - flat_len) / maxf(span - flat_len, 4.0), 0.0, 1.0))
				sys[q] = lerpf(float(pad_h[i]), main_ys[best], f)
			spur_paths.append([i, sp, sys])
			rd_list.append({"pts": sp.pts, "ys": sys, "half": half * 0.8})
			stats["spurs"] = int(stats["spurs"]) + 1
	terr.set("roads", rd_list)
	var pads: Array = []
	for i: int in centres.size():
		if float(rad[i]) <= 0.0:
			continue
		var approach: Vector2 = gates[i] if gates[i] != null else Vector2.DOWN
		pads.append({"c": centres[i], "extent": extents[i], "axis": axes[i], "h": float(pad_h[i]),
			"rp": float(rad[i]), "own": bool(own_ground[i]), "yard": i >= plots.size(), "approach": approach, "path_half": half * 0.8 if gates[i] != null else 0.0})
	terr.set("pads", pads)
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
	_lap(stats, "grid_prep")
	terr.call("build_grid")
	_lap(stats, "grid")
	var ws: RefCounted = WorldSpace.new()
	var crown_batches := []
	ws.set("crown_batches", crown_batches)
	ws.set("tag", "wall")
	parent.set_meta(&"tl_space", ws)
	parent.tree_exiting.connect(func() -> void: ws.call("free_all"))
	# ---- Road samples also guide the roadside scatter and locate the bridge.
	var road_pts: PackedVector2Array = PackedVector2Array()
	var bridge_a: int = -1
	var bridge_b: int = -1
	var bridge_probe: Array = []
	if main_path != null:
		road_pts.append_array(main_path.pts)
		if rv_path != null:
			var span: Vector2i = terr.call("bridge_span", main_path.pts, rv_half + 11.0)     # bugfix-37 Q15: (-1, -1) for a road that only ends there
			bridge_a = span.x
			bridge_b = span.y
		# The road and verge share the terrain. Advance the three former strips' segment tones.
		var skipped := mini(bridge_b + 1, main_path.pts.size() - 1) - bridge_a if bridge_a >= 0 else 0
		for q: int in 3 * (main_path.pts.size() - 1 - skipped):
			rng.randf()
		for sp: Array in spur_paths:
			var spp: TLKitPath = sp[1]
			# The spur is worn into the heightfield. Keep the scatter stream after its former two strips.
			for q: int in 2 * (spp.pts.size() - 1):
				rng.randf()
			road_pts.append_array(spp.pts)
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
	if main_path != null and TLStyle.num("detail", "road_rails", 0.0) > 0.0:     # a style-keyed row of rails along the road, no colliders (terrain/road_rails.gd); absent key = none
		stats["rail_m"] = preload("res://kernel/world/terrain/road_rails.gd").build(parent, terr, main_path, half, spur_paths, bridge_a, bridge_b, centres, rad, TLStyle.num("detail", "road_rails", 0.0))
	_lap(stats, "roads")
	# A pair of short rails marks the spur mouth. Both ends sit on the visitor's heightfield.
	var mk_edge := TLMesh.new(33)
	var rng6 := RandomNumberGenerator.new()
	rng6.seed = int(cfg.get("seed", 7)) + 606
	var edge_jobs: Array = []
	var edge_rocks: Array = []
	for i: int in centres.size():
		var r: float = float(rad[i])
		if r <= 0.0:
			continue
		var seg: int = maxi(24, int(TAU * r / 3.2))
		for k: int in seg:
			rng.randf()    # preserve the old apron tones' draws before lots and scatter
		if gates[i] == null:
			continue
		var c: Vector2 = centres[i]
		var dir: Vector2 = gates[i]
		var side := dir.orthogonal()
		var is_site := site_plots.any(func(sp: Array) -> bool: return int(sp[1]) == i)
		var rails := PackedVector3Array()
		var entrance := c + dir * (r + 3.6)
		if bool(cfg.get("fence", true)) and not is_site:
			for hand: float in [-1.0, 1.0]:
				var a := entrance + side * hand * (half * 0.8 + 2.0)
				var b := a + side * hand * clampf(r * 0.15, 3.4, 6.5)
				var span := PackedVector3Array([Vector3(a.x, terr.gy(a.x, a.y), a.y), Vector3(b.x, terr.gy(b.x, b.y), b.y)])
				rails.append_array(span)
				ws.call("add_wall", span, 1.2)
				stats["fence_m"] += span[0].distance_to(span[1])
			if bool(cfg.get("pad_rocks", true)):
				Parts.bank_rocks(rng6, terr, c, r, seg, dir.angle() + PI + 0.6 * sin(float(i) * 2.1), edge_rocks)
		edge_jobs.append({"i": i, "rails": rails, "entrance": entrance, "dir": dir, "flags": not is_site and bool(cfg.get("gates", true))})
	_lap(stats, "edges_loop")
	# ---- the lots: worn ground, a crane, a scaffold, stacked timber and pallets: the next game is being built here
	Parts.lots(parent, lots.size(), plots.size(), centres, rad, pad_h, gates, rng, ws, mk_edge, stats)
	SiteDraw.place(parent, site_plots, centres, pad_h, rad, gates, stats)     # S: the construction sites, on their plots' pads
	_lap(stats, "lots")
	var edge_task: Dictionary = {"jobs": edge_jobs, "terr": terr, "half": half, "edge": mk_edge}
	if bool(cfg.get("edges_now", false)) or OS.get_environment("TL_LAND_NOW") == "1":
		Parts.edge_geometry(edge_task)            # P13: in the frame, as before (to measure the difference)
		Parts.edge_nodes(parent, edge_task)
	else:
		edge_task["task"] = WorkerThreadPool.add_task(Parts.edge_geometry.bind(edge_task))
		parent.set_meta(&"tl_land_rest", edge_task)     # landscape.gd `arrive` adds the nodes when the worker is done
	if not edge_rocks.is_empty():
		Parts.multi(parent, TLKitNature.rock(210, 1.3, 0.78), edge_rocks, "WorldPadRocks")
		(parent.get_node("WorldPadRocks") as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # 337 rocks in four cascades cost more than they showed
		ws.set("tag", "rock")
		for x: Transform3D in edge_rocks:
			if x.basis.get_scale().x * 1.3 * 0.78 >= 0.9:
				ws.call("add_trunk", x.origin, x.basis.get_scale().x * 1.1, 1.4)
		ws.set("tag", "wall")
	stats["pad_rocks"] = edge_rocks.size()
	stats["fence_m"] = snappedf(float(stats["fence_m"]), 0.1)
	_lap(stats, "edges")
	# ---- scatter: follows the land. Never inside a plot (plus its pad), never on a road, never in the river.
	var spread: float = float(cfg.get("spread_m", 70.0))
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(cfg.get("seed", 7))
	noise.frequency = 0.022
	preload("res://kernel/world/terrain/landmarks.gd").place(parent, ws, terr, cfg, stats, centres, rad)     # D2: imported models in the village; scatter keeps clear of them
	var box: Rect2 = Rect2(Vector2(bx0, bz0) + Vector2.ONE * 30.0, Vector2(bx1 - bx0, bz1 - bz0) - Vector2.ONE * 60.0)
	var is_free: Callable = func(p: Vector2, clear: float, road_clear: float, river_clear: float) -> bool:
		for i: int in centres.size():
			if p.distance_to(centres[i]) < float(rad[i]) + clear:
				return false
		if float(terr.call("road_dist", p.x, p.y)) < road_clear:
			return false
		return float(terr.call("river_dist", p.x, p.y)) > river_clear
	stats["soft_patches"] = Parts.soft_ground(parent, terr, int(cfg.get("seed", 7)), box, is_free, int(cfg.get("soft_patches", 150)), SCATTER_MARGIN, half + 0.7)     # P13, P14b
	var gmat: ShaderMaterial = _ground_material(plots, radii, has_ground, true)
	var tmat: Material = gmat
	if tmat == null:
		tmat = TLStyle.material(&"terrain")
	var tmi: MeshInstance3D = terr.call("build_mesh", tmat)
	parent.add_child(tmi)
	if gmat != null:
		parent.set_meta(&"tl_ground_mat", gmat)            # walker-feel T: draw/view_seam.gd `close_holes`
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
	_lap(stats, "terrain")
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
	_lap(stats, "scatter_setup")
	var cams: Array = Parts.cameras(cfg.get("events", []))
	ws.set("tag", "tree")
	var probe: Dictionary = {}
	var trees: int = int(cfg.get("trees", 120))
	for v: int in 3:
		var xs: Array = Parts.clear_views(place.call(trees / 3, box, 9.0, 6.0, 0.8, 1.35, 0.9, -0.2, "ridge", 0.3), cams)
		Parts.multi(parent, TLKitNature.pine(100 + v, 8.5 + float(v) * 2.0, 5, 2.1 + float(v) * 0.3), xs, "WorldPines%d" % v, crown_batches)
		for x: Transform3D in xs:
			ws.call("add_trunk", x.origin, 0.42 * x.basis.get_scale().x)
			Parts.probe_candidate(probe, "tree", terr, x.origin, 0.42 * x.basis.get_scale().x)
		stats["trees"] = int(stats["trees"]) + xs.size()
	var leaf: Array = Parts.clear_views(place.call(int(cfg.get("broadleaf", 40)), box, 10.0, 6.5, 0.8, 1.3, 0.7, 0.0, "any", 0.22), cams)
	Parts.multi(parent, TLKitNature.broadleaf(120, 7.5), leaf, "WorldBroadleaf", crown_batches)
	for x: Transform3D in leaf:
		ws.call("add_trunk", x.origin, 0.5 * x.basis.get_scale().x)
	stats["trees"] = int(stats["trees"]) + leaf.size()
	for v: int in 2:
		ws.set("tag", "rock")
		var xs: Array = place.call(int(cfg.get("rocks", 46)) / 2, box, 6.5, 3.6, 0.7, 2.0, 0.0, -0.25, "bank", 0.9)
		Parts.multi(parent, TLKitNature.rock(200 + v, 1.2 + float(v) * 0.5, 0.65), xs, "WorldRocks%d" % v)
		for x: Transform3D in xs:
			var rvis: float = x.basis.get_scale().x * (1.2 + float(v) * 0.5)
			if rvis * 0.65 >= 0.5:           # a rock lower than a knee is a stone he walks over, not an obstacle
				ws.call("add_trunk", x.origin, rvis * 0.85, 1.4)
				Parts.probe_candidate(probe, "rock", terr, x.origin, rvis * 0.85)
		stats["rocks"] = int(stats["rocks"]) + xs.size()
	var bushes: Array = place.call(int(cfg.get("bushes", 90)), box, 6.5, 3.4, 0.7, 1.4, 0.4, 0.0, "any", 0.2)
	Parts.multi(parent, TLKitNature.bush(300, 1.0), bushes, "WorldBushes")
	stats["bushes"] = bushes.size()
	_lap(stats, "scatter")
	var road_side: Array = Parts.road_side(rng6, terr, road_pts, half, rv_half, is_free, int(cfg.get("road_trees", 44)), int(cfg.get("road_bushes", 70)))
	var road_trees: Array = Parts.clear_views(road_side[0], cams)     # P13: trees give way to fixed cameras            # P6: density where the eye goes: trees and bushes along the roads
	var road_bushes: Array = road_side[1]
	Parts.multi(parent, TLKitNature.broadleaf(121, 6.5), road_trees, "WorldRoadTrees", crown_batches)
	Parts.multi(parent, TLKitNature.bush(301, 0.9), road_bushes, "WorldRoadBushes")
	if not road_bushes.is_empty():
		(parent.get_node("WorldRoadBushes") as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ws.set("tag", "tree")
	for x: Transform3D in road_trees:
		ws.call("add_trunk", x.origin, 0.5 * x.basis.get_scale().x)
	stats["trees"] = int(stats["trees"]) + road_trees.size()
	stats["bushes"] = int(stats["bushes"]) + road_bushes.size()
	_lap(stats, "road_side")
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
		Parts.multi(parent, TLKitNature.grass_tuft(400, 4, 0.5), tufts, "WorldTufts")
		var tm: MultiMeshInstance3D = parent.get_node("WorldTufts") as MultiMeshInstance3D
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tm.visibility_range_end = 120.0
		tm.visibility_range_end_margin = 12.0
	stats["tufts"] = tufts.size()
	_lap(stats, "tufts")
	# a forest belt on the hills round the village: the skyline between the venues and the mesas
	var view: Node = parent.get_parent()
	var world: Variant = view.get("world") if view != null else null
	var walk_v: Variant = (world as Object).get("walk") if world is Object else null     # a world without a walk (a test) has none
	var walk: Dictionary = walk_v if walk_v is Dictionary else {}
	var cam: Dictionary = walk.get("visitor_cam", {}) if walk.get("visitor_cam") is Dictionary else {}
	var crown_region: Rect2 = Parts.camera_region(Rect2(bx0, bz0, bx1 - bx0, bz1 - bz0), hmax, cam)
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
		Parts.multi(parent, TLKitNature.pine(110 + v, 10.0 + float(v) * 2.5, 5, 2.4 + float(v) * 0.3), xs, "WorldBelt%d" % v, crown_batches, crown_region)
		for x: Transform3D in xs:
			if bool(terr.call("inside", x.origin.x, x.origin.z)):
				ws.call("add_trunk", x.origin, 0.5 * x.basis.get_scale().x)
		stats["trees"] = int(stats["trees"]) + xs.size()
	_lap(stats, "belt")
	var mesa_trees: Array = []            # P6: the mesas stand ON the plain: a grass foot, pines at foot and cap, pine clumps before them
	stats["mesas"] = Parts.mesas(parent, rng, centre, reach, int(cfg.get("mesas", 18)), mesa_trees)
	Parts.plain_clumps(rng6, terr, centre, reach, int(cfg.get("plain_clumps", 16)), mesa_trees)
	if not mesa_trees.is_empty():
		Parts.multi(parent, TLKitNature.pine(130, 10.0, 4, 2.6), mesa_trees, "WorldMesaPines", crown_batches, crown_region)
		(parent.get_node("WorldMesaPines") as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stats["far_trees"] = mesa_trees.size()
	_lap(stats, "mesas")
	# ---- the visitor's collider: the terrain (left open where a plot's own ground carries him) and a copy of every
	# pack's static colliders
	var cs0: int = Time.get_ticks_msec()
	var skip: Callable = func(cx: float, cz: float) -> bool:
		for i: int in plots.size():
			if bool(has_ground[i]) and float(radii[i]) > 0.0 and Vector2(cx, cz).distance_to(centres[i]) < float(radii[i]) - 1.0:
				return true
		return false
	ws.set("tag", "terrain")
	var near: PackedVector3Array = PackedVector3Array()
	for i: int in plots.size():
		if bool(has_ground[i]) and float(radii[i]) > 0.0:
			near.append(Vector3((centres[i] as Vector2).x, (centres[i] as Vector2).y, float(radii[i])))
	terr.set("skip_near", near)
	var cfaces: PackedVector3Array = terr.call("collision_faces", skip)
	_lap(stats, "coll_faces")
	ws.call("add_faces", cfaces)
	_lap(stats, "add_faces")
	ws.call("add_pads", terr, centres, has_ground, radii, (world as Node).get("packs") if world != null else [])     # bugfix-37 D3: world_space.gd
	if world != null:
		var holders: Array = (world as Node).get("packs")
		var configured_band: float = float(cfg.get("rim_band", NAN))
		for i: int in mini(holders.size(), plots.size()):
			if float(radii[i]) > 0.0 and is_instance_valid(holders[i]):
				ws.set("tag", "pack %d" % i)
				ws.call("add_pack", holders[i], plots[i], float(radii[i]), float(pad_h[i]) - (plots[i] as Transform3D).origin.y, DrawBase.rim_width(float(radii[i]), configured_band) if bool(has_ground[i]) else 0.0)
	_lap(stats, "space")
	ws.call("finish")
	_lap(stats, "crowns")
	stats["space"] = ws.get("stats")
	stats["space_ms"] = Time.get_ticks_msec() - cs0
	parent.set_meta(&"tl_terrain", terr)
	parent.set_meta(&"tl_probe", probe)
	if not bridge_probe.is_empty():
		probe["rail"] = bridge_probe
	stats["probe"] = probe
	if TLStyle.num("detail", "tree_shade", 0.0) > 0.0:     # a style-keyed map of where trees stand, for the land shader (terrain/tree_shade.gd); absent key = none
		stats["tree_shade"] = preload("res://kernel/world/terrain/tree_shade.gd").build(parent, TLStyle.num("detail", "tree_shade", 0.0))
	stats["build_ms"] = Time.get_ticks_msec() - t0
	stats.erase("_lap")
	return stats


## P13: called by the viewer once per frame after `build` (PATCHES-P13 entry 1; draw.gd calls it until then): the parts
## of the landscape made on a worker are added when it is done. True when nothing is left to arrive.
static func arrive(parent: Node3D) -> bool:
	if not parent.has_meta(&"tl_land_rest"):
		return true
	var t: Dictionary = parent.get_meta(&"tl_land_rest")
	if not WorkerThreadPool.is_task_completed(int(t["task"])):
		return false
	WorkerThreadPool.wait_for_task_completion(int(t["task"]))
	parent.remove_meta(&"tl_land_rest")
	Parts.edge_nodes(parent, t)
	return true


## P13: where the landscape's time goes, section by section (stats "laps_ms").
static func _lap(stats: Dictionary, name: String) -> void:
	var now: int = Time.get_ticks_usec()
	if not stats.has("laps_ms"):
		stats["laps_ms"] = {}
	(stats["laps_ms"] as Dictionary)[name] = snappedf(float(now - int(stats.get("_lap", now))) / 1000.0, 0.1)
	stats["_lap"] = now


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
