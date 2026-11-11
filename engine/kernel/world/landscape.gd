extends RefCounted
## N7. The world's own landscape: everything between the plots. Drawn once, owned by the world, never by a pack:
## one ground with the plots cut out of it, a dirt road with a spur to every plot, a ring of worn ground and a fence
## around every plot (its edge reads as a place), trees, rocks and bushes scattered between the plots (never inside
## one, never on the road), and far mesas on the skyline. Visual only: no body, no script that ticks.
##
##   var stats: Dictionary = Landscape.build(parent, plots, radii, has_ground, cfg)
##
## `plots`: Transform3D per plot (world coordinates), `radii`: metres, `has_ground`: the pack has terrain of its own at
## its edge (a hole is cut in the world's ground for it). `cfg` (the walk script's `landscape` block, all optional):
## road ([[x, z], ...] control points of the main road), road_half_m, spurs, fence, gates (flags and a sign at every
## gate), lots ([{"at": [x, z], "radius": m}]: fenced building sites with a crane, no game on them yet), trees,
## broadleaf, rocks, bushes, patches, tufts, belt (trees of the forest belt around the village), mesas, seed,
## ground_key, spread_m.
## Cost is in the returned stats (`build_ms`, instance counts); kernel/world/WORLD.md has the measured figures.

const GROUND_Y: float = -0.06


static func ground(parent: Node3D, plots: Array, radii: Array, has_ground: Array, key: String = "") -> MeshInstance3D:
	var g: MeshInstance3D = TLStyle.ground(GROUND_Y, key, 3000.0)
	parent.add_child(g)
	# the plots are cut out of the world's ground (toon.gdshader `tl_holes`): its own material, same shader and palette
	var pal: ShaderMaterial = TLStyle.material(&"white") as ShaderMaterial
	if pal != null and pal.shader != null:
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
		g.material_override = gm
	return g


static func _strip(mk: TLMesh, path: PackedVector2Array, half: float, y: float, key: String, tone: float, rng: RandomNumberGenerator) -> void:
	var n: int = path.size()
	for i: int in n - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var ta: Vector2 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var tb: Vector2 = (path[mini(i + 2, n - 1)] - path[i]).normalized()
		var ra: Vector3 = Vector3(-ta.y, 0.0, ta.x) * half
		var rb: Vector3 = Vector3(-tb.y, 0.0, tb.x) * half
		var pa: Vector3 = Vector3(a.x, y, a.y)
		var pb: Vector3 = Vector3(b.x, y, b.y)
		var c: float = tone * (0.94 + 0.12 * rng.randf())
		mk.quad_up(pa - ra, pa + ra, pb + rb, pb - rb, key, Color(c, c, c))


static func _near(path: PackedVector2Array, p: Vector2, d: float) -> bool:
	var d2: float = d * d
	for q: Vector2 in path:
		if q.distance_squared_to(p) < d2:
			return true
	return false


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


static func build(parent: Node3D, plots: Array, radii: Array, has_ground: Array, cfg: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var stats: Dictionary = {"road_m": 0.0, "spurs": 0, "fence_m": 0.0, "trees": 0, "rocks": 0, "bushes": 0, "mesas": 0}
	ground(parent, plots, radii, has_ground, str(cfg.get("ground_key", "")))
	if TLStyle.headless():
		return stats
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 7))
	var centres: Array = []
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for i: int in plots.size():
		var c: Vector2 = Vector2((plots[i] as Transform3D).origin.x, (plots[i] as Transform3D).origin.z)
		centres.append(c)
		lo = lo.min(c - Vector2.ONE * float(radii[i]))
		hi = hi.max(c + Vector2.ONE * float(radii[i]))
	# lots: building sites with no game on them yet. They get a spur, a ring and a fence like a plot, and the scatter
	# keeps out of them. `rad` and `own_ground` are the plots' figures followed by the lots'.
	var rad: Array = radii.duplicate()
	var own_ground: Array = has_ground.duplicate()
	var lots: Array = cfg.get("lots", []) if typeof(cfg.get("lots")) == TYPE_ARRAY else []
	for lot: Variant in lots:
		var lc: Vector2 = Vector2(float(((lot as Dictionary)["at"] as Array)[0]), float(((lot as Dictionary)["at"] as Array)[1]))
		var lr: float = float((lot as Dictionary).get("radius", 20.0))
		centres.append(lc)
		rad.append(lr)
		own_ground.append(false)
		lo = lo.min(lc - Vector2.ONE * lr)
		hi = hi.max(lc + Vector2.ONE * lr)
	# ---- the road: a main line through the village, a spur to every plot
	var road: PackedVector2Array = PackedVector2Array()      # samples of every stretch, for "is this on the road"
	var half: float = float(cfg.get("road_half_m", 2.6))
	var mk_road: TLMesh = TLMesh.new(31)
	var cps: Array = []
	for p: Variant in cfg.get("road", []):
		cps.append(Vector2(float((p as Array)[0]), float((p as Array)[1])))
	var gates: Array = []                                    # per plot: the direction its gate faces (to the road)
	gates.resize(centres.size())
	if cps.size() >= 2:
		var path: TLKitPath = TLKitPath.new(cps, false, 2.0)
		_strip(mk_road, path.pts, half + 0.7, 0.012, "grass_dry", 1.0, rng)       # a worn verge
		_strip(mk_road, path.pts, half, 0.03, "dirt", 1.0, rng)
		_strip(mk_road, path.pts, half * 0.36, 0.042, "dirt", 0.9, rng)           # the trodden middle
		stats["road_m"] = snappedf(path.length, 0.1)
		road.append_array(path.pts)
		if bool(cfg.get("spurs", true)):
			for i: int in centres.size():
				var c: Vector2 = centres[i]
				var best: Vector2 = path.pts[0]
				for q: Vector2 in path.pts:
					if q.distance_squared_to(c) < best.distance_squared_to(c):
						best = q
				var dir: Vector2 = (best - c).normalized()
				gates[i] = dir
				var from: Vector2 = c + dir * (float(rad[i]) + 0.5)
				var span: float = from.distance_to(best)
				if span < 1.0:
					continue
				var sp: PackedVector2Array = PackedVector2Array()
				var steps: int = maxi(2, int(ceil(span / 2.0)))
				for k: int in steps + 1:
					sp.append(from.lerp(best, float(k) / float(steps)))
				_strip(mk_road, sp, half * 0.8 + 0.5, 0.014, "grass_dry", 1.0, rng)
				_strip(mk_road, sp, half * 0.8, 0.034, "dirt", 0.97, rng)
				road.append_array(sp)
				stats["spurs"] = int(stats["spurs"]) + 1
		var rmi: MeshInstance3D = mk_road.instance("WorldRoad")
		rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(rmi)
	# ---- every plot's edge: a ring of worn ground and a fence with a gate towards the road
	var mk_edge: TLMesh = TLMesh.new(33)
	var mk_ring: TLMesh = TLMesh.new(34)
	for i: int in centres.size():
		var r: float = float(rad[i])
		if r <= 0.0:
			continue
		var c: Vector2 = centres[i]
		var seg: int = maxi(24, int(TAU * r / 3.2))
		var r0: float = r + (2.4 if bool(own_ground[i]) else 0.0)        # a pack with its own ground is drawn to r + 3
		var r1: float = r + 5.0
		var gate: Variant = gates[i]
		var gate_a: float = atan2((gate as Vector2).y, (gate as Vector2).x) if gate != null else 0.0
		var gate_w: float = (half * 0.8 + 1.6) / (r + 3.5)
		if gate != null and bool(cfg.get("gates", true)):
			# the gate: a flag on each side and a sign that faces the road
			var gd: Vector3 = Vector3((gate as Vector2).x, 0.0, (gate as Vector2).y)
			var side: Vector3 = Vector3(-gd.z, 0.0, gd.x)
			var gp: Vector3 = Vector3(c.x, 0.0, c.y) + gd * (r + 3.6)
			TLKitSite.add_flag(mk_edge, gp + side * (half * 0.8 + 1.9), 5.5, "flag_a" if i % 2 == 0 else "flag_b")
			TLKitSite.add_flag(mk_edge, gp - side * (half * 0.8 + 1.9), 5.5, "flag_a" if i % 2 == 0 else "flag_b")
			TLKitSite.add_sign(mk_edge, gp + gd * 2.4 + side * (half * 0.8 + 3.6), rad_to_deg(atan2(gd.x, gd.z)))
		for k: int in seg:
			var a0: float = TAU * float(k) / float(seg)
			var a1: float = TAU * float(k + 1) / float(seg)
			var d0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
			var d1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
			var o: Vector3 = Vector3(c.x, 0.036, c.y)
			var tone: float = 0.92 + 0.14 * rng.randf()
			mk_ring.quad_up(o + d0 * r0, o + d0 * r1, o + d1 * r1, o + d1 * r0, "dirt", Color(tone, tone, tone))
			var og: Vector3 = Vector3(c.x, 0.016, c.y)
			mk_ring.quad_up(og + d0 * r1, og + d0 * (r1 + 1.2), og + d1 * (r1 + 1.2), og + d1 * r1, "grass_dry", Color.WHITE)
			if bool(cfg.get("fence", true)):
				var mid: float = (a0 + a1) * 0.5
				if gate != null and absf(angle_difference(mid, gate_a)) < gate_w:
					continue
				var f: Vector3 = Vector3(c.x, 0.0, c.y)
				TLKitSite.add_fence(mk_edge, f + d0 * (r + 3.6), f + d1 * (r + 3.6), 3.4)
				stats["fence_m"] = float(stats["fence_m"]) + (d0 - d1).length() * (r + 3.6)
	# ---- the lots: worn ground, a crane, a scaffold, stacked timber and pallets: the next game is being built here
	for k: int in lots.size():
		var li: int = plots.size() + k
		var lc: Vector2 = centres[li]
		var lr: float = float(rad[li])
		var base: Vector3 = Vector3(lc.x, 0.0, lc.y)
		var segs: int = 28
		for q: int in segs:
			var a0: float = TAU * float(q) / float(segs)
			var a1: float = TAU * float(q + 1) / float(segs)
			var tone: float = 0.9 + 0.14 * rng.randf()
			var o: Vector3 = base + Vector3(0.0, 0.03, 0.0)
			mk_ring.quad_up(o, o + Vector3(cos(a0), 0.0, sin(a0)) * lr, o + Vector3(cos(a1), 0.0, sin(a1)) * lr, o, "dirt", Color(tone, tone, tone))
		var crane: Node3D = TLKitSite.crane(26.0, 2.0, 20.0, 8.0)
		crane.name = "WorldLotCrane%d" % k
		crane.position = base + Vector3(-lr * 0.38, 0.0, -lr * 0.22)
		crane.rotation.y = rng.randf() * TAU
		parent.add_child(crane)
		var sc: MeshInstance3D = TLKitSite.scaffold(3, 2).instance("WorldLotScaffold%d" % k)
		sc.position = base + Vector3(lr * 0.05, 0.0, -lr * 0.4)
		parent.add_child(sc)
		TLKitSite.add_lumber(mk_edge, base + Vector3(lr * 0.38, 0.0, lr * 0.2), 3.2, 1.0, 6, 20.0)
		TLKitSite.add_lumber(mk_edge, base + Vector3(lr * 0.12, 0.0, lr * 0.5), 3.2, 1.0, 4, -35.0)
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
	stats["fence_m"] = snappedf(float(stats["fence_m"]), 0.1)
	# ---- scatter between the plots: never inside one (plus its ring), never on the road
	var spread: float = float(cfg.get("spread_m", 70.0))
	var box: Rect2 = Rect2(lo - Vector2.ONE * spread, (hi - lo) + Vector2.ONE * spread * 2.0)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(cfg.get("seed", 7))
	noise.frequency = 0.022
	var is_free: Callable = func(p: Vector2, clear: float, road_clear: float) -> bool:
		for i: int in centres.size():
			if p.distance_to(centres[i]) < float(rad[i]) + clear:
				return false
		return not _near(road, p, road_clear)
	var place: Callable = func(count: int, area: Rect2, clear: float, road_clear: float, s_min: float, s_max: float, clump: float, y_off: float) -> Array:
		var xs: Array = []
		var tries: int = 0
		while xs.size() < count and tries < count * 30:
			tries += 1
			var p: Vector2 = area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
			if clump > 0.0 and noise.get_noise_2d(p.x, p.y) < clump - 1.0 + rng.randf() * 0.5:
				continue
			if not bool(is_free.call(p, clear, road_clear)):
				continue
			var sc: float = rng.randf_range(s_min, s_max)
			var b: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc))
			xs.append(Transform3D(b, Vector3(p.x, y_off, p.y)))
		return xs
	var trees: int = int(cfg.get("trees", 150))
	for v: int in 3:
		var xs: Array = place.call(trees / 3, box, 9.0, 6.0, 0.8, 1.35, 0.9, -0.2)
		_multi(parent, TLKitNature.pine(100 + v, 8.5 + float(v) * 2.0, 5, 2.1 + float(v) * 0.3), xs, "WorldPines%d" % v)
		stats["trees"] = int(stats["trees"]) + xs.size()
	var leaf: Array = place.call(int(cfg.get("broadleaf", 46)), box, 10.0, 6.5, 0.8, 1.3, 0.7, 0.0)
	_multi(parent, TLKitNature.broadleaf(120, 7.5), leaf, "WorldBroadleaf")
	stats["trees"] = int(stats["trees"]) + leaf.size()
	for v: int in 2:
		var xs: Array = place.call(int(cfg.get("rocks", 60)) / 2, box, 6.5, 3.6, 0.7, 2.0, 0.0, -0.25)
		_multi(parent, TLKitNature.rock(200 + v, 1.2 + float(v) * 0.5, 0.65), xs, "WorldRocks%d" % v)
		stats["rocks"] = int(stats["rocks"]) + xs.size()
	var bushes: Array = place.call(int(cfg.get("bushes", 110)), box, 6.5, 3.4, 0.7, 1.4, 0.4, 0.0)
	_multi(parent, TLKitNature.bush(300, 1.0), bushes, "WorldBushes")
	stats["bushes"] = bushes.size()
	# the plain itself: patches of darker and drier grass (flat, one mesh), and tufts along the road and the plot edges
	var mk_patch: TLMesh = TLMesh.new(36)
	var patches: int = int(cfg.get("patches", 90))
	var made: int = 0
	var ptries: int = 0
	while made < patches and ptries < patches * 20:
		ptries += 1
		var c: Vector2 = box.position + Vector2(rng.randf() * box.size.x, rng.randf() * box.size.y)
		var pr: float = 5.0 + rng.randf() * 13.0
		if not bool(is_free.call(c, 7.5 + pr, 4.0 + pr)):
			continue
		var key: String = "grass_dark" if rng.randf() > 0.4 else "grass_dry"
		var o: Vector3 = Vector3(c.x, 0.004 + 0.004 * rng.randf(), c.y)
		var n: int = 9
		var rim: Array = []
		for k: int in n:
			var a: float = TAU * float(k) / float(n)
			rim.append(o + Vector3(cos(a), 0.0, sin(a) * (0.6 + 0.4 * rng.randf())) * pr * (0.65 + 0.5 * rng.randf()))
		for k: int in n:
			mk_patch.quad_up(o, rim[k], rim[(k + 1) % n], o, key, Color.WHITE)
		made += 1
	if made > 0:
		var pmi: MeshInstance3D = mk_patch.instance("WorldPatches")
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(pmi)
	stats["patches"] = made
	var tufts: Array = []
	var want_tufts: int = int(cfg.get("tufts", 1600)) if road.size() > 0 else 0
	var ttries: int = 0
	while tufts.size() < want_tufts and ttries < want_tufts * 6:
		ttries += 1
		var q: Vector2 = road[rng.randi_range(0, road.size() - 1)]
		var a: float = rng.randf() * TAU
		var p: Vector2 = q + Vector2(cos(a), sin(a)) * (half + 1.2 + rng.randf() * rng.randf() * 16.0)
		if not bool(is_free.call(p, 6.5, half + 1.0)):
			continue
		var sc: float = rng.randf_range(0.8, 1.6)
		tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p.x, -0.02, p.y)))
	if not tufts.is_empty():
		_multi(parent, TLKitNature.grass_tuft(400, 4, 0.5), tufts, "WorldTufts")
		var tm: MultiMeshInstance3D = parent.get_node("WorldTufts") as MultiMeshInstance3D
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tm.visibility_range_end = 120.0
		tm.visibility_range_end_margin = 12.0
	stats["tufts"] = tufts.size()
	# a forest belt around the village: the skyline between the venues and the mesas
	var belt: int = int(cfg.get("belt", 260))
	var centre: Vector2 = (lo + hi) * 0.5
	var reach: float = (hi - lo).length() * 0.5
	for v: int in 2:
		var xs: Array = []
		var tries: int = 0
		while xs.size() < belt / 2 and tries < belt * 20:
			tries += 1
			var a: float = rng.randf() * TAU
			var d: float = reach + spread * 0.6 + rng.randf() * rng.randf() * 240.0
			var p: Vector2 = centre + Vector2(cos(a), sin(a)) * d
			if box.has_point(p) and not bool(is_free.call(p, 9.0, 6.0)):
				continue
			if _near(road, p, 7.0):
				continue
			var sc: float = rng.randf_range(0.9, 1.7)
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.95, 1.2), sc)), Vector3(p.x, -0.2, p.y)))
		_multi(parent, TLKitNature.pine(110 + v, 10.0 + float(v) * 2.5, 5, 2.4 + float(v) * 0.3), xs, "WorldBelt%d" % v)
		stats["trees"] = int(stats["trees"]) + xs.size()
	# ---- far mesas: flat-topped cliffs on the skyline, one mesh
	var mk_far: TLMesh = TLMesh.new(35)
	var count: int = int(cfg.get("mesas", 18))
	for i: int in count:
		var a: float = TAU * (float(i) + rng.randf() * 0.7) / float(maxi(1, count))
		var d: float = reach + 330.0 + rng.randf() * 420.0
		var r: float = 45.0 + rng.randf() * 85.0
		var h: float = 34.0 + rng.randf() * 70.0
		var at: Vector3 = Vector3(centre.x + cos(a) * d, -3.0, centre.y + sin(a) * d)
		var tone: float = 0.9 + 0.2 * rng.randf()
		mk_far.push_at(at, Vector3(0.0, rng.randf() * 360.0, 0.0), Vector3(1.0, 1.0, 0.6 + rng.randf() * 0.5))
		# an uneven outline (still star-shaped), a scree foot, three strata of other tones, a grass cap
		var sides: int = 9 + rng.randi_range(0, 3)
		var unit: PackedVector2Array = PackedVector2Array()
		for v: int in sides:
			var pa: float = TAU * float(v) / float(sides)
			unit.append(Vector2(cos(pa), sin(pa)) * (0.84 + 0.3 * rng.randf()))
		var outline: Callable = func(scale: float) -> PackedVector2Array:
			var out: PackedVector2Array = PackedVector2Array()
			for u: Vector2 in unit:
				out.append(u * scale)
			return out
		mk_far.prism(outline.call(r * 1.28), 0.0, h * 0.34, "cliff", Color(tone * 0.88, tone * 0.88, tone * 0.88), 0.82)
		for k: int in 3:
			var kt: float = tone * (0.9 + 0.1 * float((k + i) % 2)) * (0.94 + 0.06 * float(k))
			var y0: float = h * 0.3 + h * float(k) / 3.0
			mk_far.prism(outline.call(r * (1.0 - 0.07 * float(k))), y0, y0 + h / 3.0, "cliff", Color(kt, kt * 0.98, kt * 0.96), 0.95)
		mk_far.prism(outline.call(r * 0.81), h * 1.3, h * 1.3 + 2.5, "grass_dry", Color.WHITE, 0.96)
		if rng.randf() > 0.5:
			mk_far.push_at(Vector3(r * 0.18, 0.0, 0.0))
			mk_far.prism(outline.call(r * 0.46), h * 1.3, h * 1.75, "cliff", Color(tone, tone, tone), 0.84)
			mk_far.prism(outline.call(r * 0.38), h * 1.75, h * 1.75 + 2.0, "grass_dry", Color.WHITE, 0.96)
			mk_far.pop()
		mk_far.pop()
	if count > 0:
		var far: MeshInstance3D = mk_far.instance("WorldMesas")
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(far)
	stats["mesas"] = count
	stats["build_ms"] = Time.get_ticks_msec() - t0
	return stats


## The haze of a world: a venue 200 m away must still read. Scales the style's fog on the environment the world host
## installed (the style file itself is not touched: a single pack looks as it did).
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
