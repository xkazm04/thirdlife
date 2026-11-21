extends "res://kernel/world/terrain/harden_walks.gd"
## Day of 21 Nov 2026, lane L6 (crisp-harden): the selftest cases of tools/selftest.d/700-harden-day.sh. Headless,
## frames not wall clock; the villages are built as in a window (TLStyle.set_headless(false)), as harden_case.gd does.
## Prints one line per case: `HARDEN <case> ok|fail <detail>`; a case with no line is a FAIL there.
##   road_edge   every scatter object of the exe's village and of the wf_feel village (trees, rocks, bushes, pad rocks,
##               grass tufts), by its drawn mesh: its foot (the mesh lower than 1.2 m) stays off every road's surface
##               (the exact distance to the road's line, each road by its own half); a solid one (all but grass) also
##               stays off crisp's verge and its row of rails. Every trunk of the visitor's space tagged tree, rock or
##               bush: the same, by its cylinder. Under crisp, and the exe's village under classic.
##   rock_tops   every rock of the scatter with a body (WorldRocks*, WorldPadRocks) in the exe's and the wf_feel village:
##               its own body's top (the cylinder at its foot) is its drawn top over its middle within 0.25 m (a 1.4 m pillar
##               stood over every rock, a knee-high stone among them; a 1.6 m boulder stood over its pillar)
##   lot_props   every prop of a plain lot (village_parts.gd `lots`: the crane, the scaffold, the timber stacks, the
##               pallets of blocks, the barricades, the cones; the lots of 20 m and more of the wf_feel and the tour
##               village: a smaller one's props stand in each other as drawn), walked into from 8 sides
##               for 150 ticks (a way another prop stands in is left out; that one is walked into on its own): he stops
##               at what is drawn (his body's 0.35 m from it, never more than 0.45 m before it, never into it; a
##               barricade's splayed 7 cm feet are not solid on purpose, he slides off its end). What is drawn is found by rays along his way at his heights against the drawn meshes.

const KINDS: PackedStringArray = ["WorldPines", "WorldBroadleaf", "WorldRocks", "WorldBushes", "WorldRoadTrees", "WorldRoadBushes", "WorldPadRocks", "WorldTufts"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var only: String = OS.get_environment("TL_HARDEN_ONLY")
	if only.is_empty() or only.contains("road_edge"):
		_road_edge()
	if only.is_empty() or only.contains("lot_props"):
		_lot_props()
	if only.is_empty() or only.contains("rock_tops"):
		_rock_tops()
	quit()


# ------------------------------------------------------------------------------------------------ road_edge
func _road_edge() -> void:
	var why: Array = []
	var got: Array = []
	for run: Array in [["crisp", "res://boot/village.json"], ["crisp", "res://kernel/world/walks/wf_feel.json"], ["classic", "res://boot/village.json"]]:
		TLStyle.load_style("res://style/style_crisp.json" if run[0] == "crisp" else "res://style/style.json")
		TLStyle.set_headless(false)
		_build_village(str(run[1]))
		var off: float = TLStyle.num("detail", "road_rails", 0.0)
		var roads: Array = _terr.get("roads")
		var seen: int = 0
		var bad: Array = []
		for c: Node in _land.get_children():
			if not (c is MultiMeshInstance3D) or not Array(KINDS).any(func(k: String) -> bool: return str(c.name).begins_with(k)):
				continue
			var foot: float = 0.0
			for v: Vector3 in (c as MultiMeshInstance3D).multimesh.mesh.get_faces():
				if v.y < 1.2:
					foot = maxf(foot, Vector2(v.x, v.z).length())
			var solid: bool = not str(c.name).begins_with("WorldTufts")
			for x: Transform3D in c.get_meta(&"tl_xs", []):
				seen += 1
				var g: Array = _gap(roads, Vector2(x.origin.x, x.origin.z), foot * x.basis.get_scale().x, off if solid else 0.0)
				if float(g[0]) < 0.0:
					bad.append("%s at (%.1f, %.1f) %.2f m onto the %s" % [c.name, x.origin.x, x.origin.z, -float(g[0]), g[1]])
		var trunks: int = 0
		var bodies: Array = _ws.get("_bodies")
		var tags: Dictionary = _ws.get("_tags")
		for b: Variant in bodies:
			var t: String = str(tags.get(b, ""))
			if not (t in ["tree", "rock", "bush"]) or PhysicsServer3D.body_get_shape_count(b as RID) < 1:
				continue
			var sh: RID = PhysicsServer3D.body_get_shape(b as RID, 0)
			if PhysicsServer3D.shape_get_type(sh) != PhysicsServer3D.SHAPE_CYLINDER:
				continue
			var data: Variant = PhysicsServer3D.shape_get_data(sh)
			var r: float = float((data as Dictionary).get("radius", 0.0)) if data is Dictionary else float((data as Vector2).y)
			var o: Vector3 = PhysicsServer3D.body_get_shape_transform(b as RID, 0).origin
			trunks += 1
			var g: Array = _gap(roads, Vector2(o.x, o.z), r, off)
			if float(g[0]) < 0.0:
				bad.append("%s collider at (%.1f, %.1f) r %.2f %.2f m onto the %s" % [t, o.x, o.z, r, -float(g[0]), g[1]])
		got.append("%s %s: %d objects, %d trunks clear" % [run[0], str(run[1]).get_file().get_basename(), seen, trunks])
		if seen < 1000 or trunks < 100:
			why.append("%s %s: only %d objects and %d trunks found" % [run[0], str(run[1]).get_file(), seen, trunks])
		if not bad.is_empty():
			why.append("%s %s: %d stand on a road or its rails: %s" % [run[0], str(run[1]).get_file(), bad.size(), ", ".join(bad.slice(0, 5))])
	_line("harden.road_edge", why, "; ".join(got))


## [the smallest gap between a foot of radius `r` at `p` and a road's surface (and, when `rails` > 0, the main road's
## verge and its row of rails), what it meets]. Every segment of every road, the exact distance.
func _gap(roads: Array, p: Vector2, r: float, rails: float) -> Array:
	var best: float = INF
	var what: String = "-"
	for k: int in roads.size():
		var pts: PackedVector2Array = (roads[k] as Dictionary)["pts"]
		var lim: float = float((roads[k] as Dictionary)["half"]) + r + (rails + 0.15 if k == 0 and rails > 0.0 else 0.0)
		for i: int in pts.size() - 1:
			if absf(pts[i].x - p.x) > lim + 3.0 or absf(pts[i].y - p.y) > lim + 3.0:
				continue
			var d: float = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) - lim
			if d < best:
				best = d
				var verge: float = rails + 0.15 if k == 0 and rails > 0.0 else 0.0
				what = ("main road's verge and rails" if d + verge >= 0.0 else "main road (%.2f m onto it)" % -(d + verge)) if k == 0 else "spur"
	return [best, what]


# ------------------------------------------------------------------------------------------------ lot_props
const PROP_FROM: Dictionary = {"crane": 6.5, "scaffold": 6.0, "timber": 4.5, "pallet": 4.0, "barricade": 3.0, "cone": 2.5}
const RADIUS: float = 0.35       # his capsule (terrain/world_space.gd)
const HELD: float = 0.45         # the most he may be held before what he sees


func _lot_props() -> void:
	TLStyle.load_style("res://style/style_crisp.json")
	TLStyle.set_headless(false)
	var why: Array = []
	var got: Array = []
	for path: String in ["res://kernel/world/walks/wf_feel.json", "res://kernel/world/walks/tour.json"]:
		_build_village(path)
		var props: Array = _land.get_meta(&"tl_lot_props", [])
		var faces: PackedVector3Array = PackedVector3Array()
		for n: Node in _land.get_children():
			if str(n.name) == "WorldPlotFences" or str(n.name).begins_with("WorldLotCrane") or str(n.name).begins_with("WorldLotScaffold"):
				for mi: Node in [n] + n.find_children("*", "MeshInstance3D", true, false):
					if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
						var x: Transform3D = (mi as MeshInstance3D).global_transform
						for v: Vector3 in (mi as MeshInstance3D).mesh.get_faces():
							faces.append(x * v)
		var sp: RID = PhysicsServer3D.space_create()
		PhysicsServer3D.space_set_active(sp, true)
		var body: RID = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_space(body, sp)
		var cp: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		cp.backface_collision = true
		cp.set_faces(faces)
		PhysicsServer3D.body_add_shape(body, cp.get_rid(), Transform3D.IDENTITY)
		var walks: int = 0
		var walked: int = 0
		var blocked: int = 0
		var bad: Array = []
		var kinds: Dictionary = {}
		for pr: Array in props:
			if float(pr[3]) < 20.0:
				continue          # a lot smaller than its props (tour's 8 m lot): they stand in each other as drawn
			var kind: String = pr[0]
			var c: Vector3 = pr[1]
			kinds[kind] = int(kinds.get(kind, 0)) + 1
			walked += 1
			for d: int in 8:
				var a: float = float(pr[2]) + TAU * float(d) / 8.0 + 0.2
				var dir: Vector2 = Vector2(cos(a), sin(a))
				var from: Vector2 = Vector2(c.x, c.z) + dir * float(PROP_FROM[kind])
				var gy: float = float(_terr.call("gy", from.x, from.y))
				# what he sees along his way: the nearest drawn face at his heights
				var seen: float = INF
				for h: float in [0.15, 0.4, 0.7, 1.0, 1.3, 1.7]:
					var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(from.x, gy + h, from.y), Vector3(c.x, gy + h, c.z) - Vector3(dir.x, 0, dir.y) * 2.0)
					q.hit_back_faces = true
					var hit: Dictionary = PhysicsServer3D.space_get_direct_state(sp).intersect_ray(q)
					if not hit.is_empty():
						seen = minf(seen, Vector2((hit["position"] as Vector3).x, (hit["position"] as Vector3).z).distance_to(from))
				if seen == INF:
					continue       # nothing drawn on this line at his heights (between a barricade's legs, under its boards)
				var other: bool = false
				for o: Array in props:
					var oc: Vector3 = o[1]
					if not is_same(o, pr) and Geometry2D.get_closest_point_to_segment(Vector2(oc.x, oc.z), from, Vector2(c.x, c.z)).distance_to(Vector2(oc.x, oc.z)) < 1.2:
						other = true
				if other:
					continue       # another prop stands in the way: he meets that one first (walked into on its own)
				walks += 1
				var r: Array = _walk_watch(from, -dir, 150, sp, 0.6 if kind == "barricade" else 0.2, float(PROP_FROM[kind]))
				if int(r[1]) == -2:
					walks -= 1
					blocked += 1
					continue
				var f: Vector3 = r[0]
				var along: float = (Vector2(f.x, f.z) - from).dot(-dir)
				var off: float = absf((Vector2(f.x, f.z) - from).dot(dir.orthogonal()))
				if int(r[1]) >= 0:
					bad.append("%s at (%.1f, %.1f) from %d deg: into it at tick %d (%.2f m along; it meets his body at %.2f m)" % [kind, c.x, c.z, int(rad_to_deg(a)) % 360, int(r[1]), float(r[2]), seen - RADIUS])
				elif off < 0.3 and along < seen - RADIUS - HELD:
					bad.append("%s at (%.1f, %.1f) from %d deg: held %.2f m before it (by %s)" % [kind, c.x, c.z, int(rad_to_deg(a)) % 360, seen - RADIUS - along, _what_stopped()])
		PhysicsServer3D.free_rid(body)
		PhysicsServer3D.free_rid(sp)
		got.append("%s: %d props (%s), %d walks (%d starts inside another prop left out)" % [path.get_file().get_basename(), walked, ", ".join(kinds.keys().map(func(k: String) -> String: return "%d %s" % [kinds[k], k])), walks, blocked])
		if walked < 10 or walks < 60:
			why.append("%s: only %d props and %d walks" % [path.get_file(), walked, walks])
		if not bad.is_empty():
			why.append("%s: %d of %d walks: %s" % [path.get_file(), bad.size(), walks, ", ".join(bad.slice(0, 6))])
	_line("harden.lot_props", why, "; ".join(got) + ": he stops at what is drawn, from every side")


## `_walk_from` that watches him: [feet at the end, the first tick his body (a capsule 0.1 m inside his own, from `low`
## to 1.7 m up) overlaps a drawn face of `mesh_space` (-1: never; -2: at the start, before a step), how far along he was
## then; watched until he is `until` m along: past the prop's middle]. A barricade is watched from 0.6 m: its splayed 7 cm feet are not solid on purpose (a foot and the boards made
## a corner he stuck in when he walked along it; now he slides off its end).
func _walk_watch(from: Vector2, dir: Vector2, ticks: int, mesh_space: RID, low: float = 0.2, until: float = INF) -> Array:
	var g: float = float(_ws.call("ground_at", from.x, from.y, 200.0))
	var feet: Vector3 = Vector3(from.x, 0.0 if is_nan(g) else g, from.y)
	_ws.call("place", feet)
	_ws.call("rest")
	var wish: Vector3 = Vector3(dir.x, 0.0, dir.y).normalized() * WALK
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = RADIUS - 0.1
	cap.height = maxf(1.7 - low, 2.0 * cap.radius)
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	var state: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(mesh_space)
	var lift: Vector3 = Vector3(0, low + cap.height * 0.5, 0)
	q.transform = Transform3D(Basis(), feet + lift)
	if not state.intersect_shape(q, 1).is_empty():
		return [feet, -2, 0.0]          # he would start in something drawn (props of a small lot stand in each other)
	for t: int in ticks:
		feet = (_ws.call("drive", feet, wish, false, false) as Dictionary)["pos"]
		if (Vector2(feet.x, feet.z) - from).dot(dir) > until:
			break          # past the prop's middle (he went round it): what he meets after is another walk's
		q.transform = Transform3D(Basis(), feet + lift)
		if not state.intersect_shape(q, 1).is_empty():
			return [feet, t, (Vector2(feet.x, feet.z) - from).dot(dir)]
	return [feet, -1, 0.0]


# ------------------------------------------------------------------------------------------------ rock_tops
func _rock_tops() -> void:
	TLStyle.load_style("res://style/style_crisp.json")
	TLStyle.set_headless(false)
	var why: Array = []
	var got: Array = []
	for path: String in ["res://boot/village.json", "res://kernel/world/walks/wf_feel.json"]:
		_build_village(path)
		var solid: int = 0
		var bad: Array = []
		var tops: Dictionary = {}          # Vector2i(x * 100, z * 100) of a rock body's foot -> its top (y)
		var tags: Dictionary = _ws.get("_tags")
		for bd: Variant in _ws.get("_bodies"):
			if str(tags.get(bd, "")) != "rock":
				continue
			var sh: RID = PhysicsServer3D.body_get_shape(bd as RID, 0)
			if PhysicsServer3D.shape_get_type(sh) != PhysicsServer3D.SHAPE_CYLINDER:
				continue
			var data: Variant = PhysicsServer3D.shape_get_data(sh)
			var h: float = float((data as Dictionary).get("height", 0.0)) if data is Dictionary else float((data as Vector2).x)
			var o: Vector3 = PhysicsServer3D.body_get_shape_transform(bd as RID, 0).origin
			tops[Vector2i(roundi(o.x * 100.0), roundi(o.z * 100.0))] = o.y + h * 0.5
		for nm: String in ["WorldRocks0", "WorldRocks1", "WorldPadRocks"]:
			var mmi: MultiMeshInstance3D = _land.get_node_or_null(nm) as MultiMeshInstance3D
			if mmi == null:
				continue
			var faces: PackedVector3Array = mmi.multimesh.mesh.get_faces()
			for x: Transform3D in mmi.get_meta(&"tl_xs", []):
				var key: Vector2i = Vector2i(roundi(x.origin.x * 100.0), roundi(x.origin.z * 100.0))
				if not tops.has(key):
					continue          # no body: a stone he walks over
				var inv: Transform3D = x.affine_inverse()
				var a: Vector3 = inv * (x.origin + Vector3(0, 20, 0))
				var b: Vector3 = inv * (x.origin - Vector3(0, 20, 0))
				var top: float = -INF
				for i: int in range(0, faces.size(), 3):
					var r: Variant = Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i + 1], faces[i + 2])
					if r != null:
						top = maxf(top, (x * (r as Vector3)).y)
				solid += 1
				var ct: float = float(tops[key])
				var gy: float = float(_terr.call("gy", x.origin.x, x.origin.z))
				if absf(ct - top) > 0.25:
					bad.append("%s at (%.0f, %.0f): its body's top %.2f m, the rock's %.2f m over the ground" % [nm, x.origin.x, x.origin.z, ct - gy, top - gy])
		got.append("%s: %d rocks with a body" % [path.get_file().get_basename(), solid])
		if solid < 15:
			why.append("%s: only %d rocks with a body" % [path.get_file(), solid])
		if not bad.is_empty():
			why.append("%s: %d of %d: %s" % [path.get_file(), bad.size(), solid, ", ".join(bad.slice(0, 5))])
	_line("harden.rock_tops", why, ", ".join(got) + ": each body's top within 0.25 m of its rock's")
