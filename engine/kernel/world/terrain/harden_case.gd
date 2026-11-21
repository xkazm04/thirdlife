extends "res://kernel/world/terrain/harden_walks.gd"
## Night of 21 Nov 2026, lane L1 (crisp-harden): the selftest cases `harden.*` of tools/selftest.d/620-harden.sh.
## Headless, frames not wall clock. The exe's village (boot/village.json: its road, plots, lots and landscape block) is
## built under the crisp look as in a window (TLStyle.set_headless(false), as walks/bugfix_world_case.gd does), and the
## visitor's body (terrain/world_space.gd `drive`, the body with weight) is walked into things.
## Prints one line per case: `HARDEN <case> ok|fail <detail>`; a case with no line is a FAIL there.
##   rails_block   every place where the drawn rails (the WorldRoadRails meshes) run unbroken for a metre either side:
##                 walked into from the road for 70 ticks, he never ends beyond the row
##   rails_village the same in the compact village of wf_feel.json, and every start is on the land (a bush on the road's
##                 edge was a block he stood on and walked over the rails from)
##   rail_gaps     every open span between two drawn stretches of rail (one in nine, road_rails.gd PASS_EVERY): walked
##                 through from the road in 70 ticks, he ends beyond the row
##   site_fence    B2: a site being built is fenced along its footprint square (turned or not): stopped from behind,
##                 in through the gate along the path
##   site_sign     a construction site's sign (site/draw.gd `_sign`): its posts stop him, he walks under its board
##   gate_sign     every plot's and lot's gate marker (the sign and flag village_parts.gd `edge_geometry` draws; found
##                 in the WorldPlotFences mesh): walked into from the road side, he never passes it
##   bush_block    the village's bushes he cannot step over (and off the roads): walked into, he never reaches the middle
##                 third of one
##   kit_parts     TLKit parts in a pack, copied into the visitor's space as a game's colliders are: a rail fence, a
##                 site fence, a sign, a marshal post and a watch tower stop him, a bush stops him, he walks between a
##                 scoreboard's legs and over still pond water
##   spawn_clear   the world's spawn (the walk's first `player` entry) and the gate of every plot where Q puts him
##                 (runner/visit.gd `_to_gate`, 5 m outside the radius): the ground found there is the land's, and his
##                 capsule there touches nothing; a control box at the spawn must be found (the check bites)
## The shared helpers are in harden_walks.gd.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TLStyle.load_style("res://style/style_crisp.json")
	TLStyle.set_headless(false)
	var only: String = OS.get_environment("TL_HARDEN_ONLY")
	if only.is_empty() or only.contains("kit_parts"):
		_kit_parts()
	if only.is_empty() or only.contains("site_sign"):
		await _site_sign()
	if only.is_empty() or only.contains("site_fence"):
		await _site_fence()
	if only.is_empty() or only.contains("rail") or only.contains("gate_sign") or only.contains("bush") or only.contains("spawn"):
		_build_village()
		if only.is_empty() or only.contains("rail"):
			_rails()
		if only.is_empty() or only.contains("gate_sign"):
			_gate_sign()
		if only.is_empty() or only.contains("bush_block"):
			_bushes()
		if only.is_empty() or only.contains("spawn_clear"):
			_spawn_clear()
	if only.is_empty() or only.contains("rails_village"):
		_rails_village()
	quit()


func _rails() -> void:
	var tris: int = _index_rails()
	var off: float = TLStyle.num("detail", "road_rails", 0.0)
	var looks: Array = _rail_looks()
	if OS.get_environment("TL_HARDEN_DEBUG") == "1":
		var nd: int = 0
		for row: Array in looks:
			for l: Array in row:
				nd += int(bool(l[2]))
		var k0: Vector2i = _tris.keys()[0]
		print("DBG looks %d drawn %d cells %d first cell %s tri %s row0 %s" % [looks[0].size() + looks[1].size(), nd, _tris.size(), k0, (_tris[k0] as PackedVector3Array)[0], looks[0][0][0]])
	# rails_block: every place along the drawn rails
	var why: Array = []
	var got: Array = _walk_rails(_rail_places(looks))
	var tried: int = got[0]
	var crossed: Array = got[1]
	if not (got[2] as Array).is_empty():
		why.append("he would start on top of something, not on the road, at %s" % ", ".join((got[2] as Array).slice(0, 4)))
	if tried < 100:
		why.append("only %d places along drawn rails to walk into (%d rail triangles): the village has fewer rails than it should" % [tried, tris])
	if not crossed.is_empty():
		why.append("walked through the drawn rails at %d of %d places, e.g. %s" % [crossed.size(), tried, ", ".join(crossed.slice(0, 4))])
	_line("harden.rails_block", why, "%d places along the drawn rails (crisp, %.1f m from the road's edge) walked into from the road for %d ticks: stopped at all of them" % [tried, off, TICKS])
	# rail_gaps: an undrawn run of 1.5-4.6 m (posts stand at every second 2 m road sample) with drawn rail on both sides
	why = []
	var gaps: int = 0
	var stuck: Array = []
	for row: Array in looks:
		var k: int = 0
		while k < row.size():
			if bool(row[k][2]):
				k += 1
				continue
			var s: int = k
			while k < row.size() and not bool(row[k][2]):
				k += 1
			var e: int = k - 1
			var len_m: float = (row[s][0] as Vector2).distance_to(row[e][0]) + SUB
			if OS.get_environment("TL_HARDEN_DEBUG") == "1":
				print("DBG run %.1f at (%.1f, %.1f)" % [len_m, (row[s][0] as Vector2).x, (row[s][0] as Vector2).y])
			if s == 0 or k >= row.size() or len_m < 1.5 or len_m > 4.6:
				continue
			var mid: int = (s + e) / 2
			var p: Vector2 = ((row[s][0] as Vector2) + (row[e][0] as Vector2)) * 0.5
			var n: Vector2 = row[mid][1]
			var f: Vector3 = _walk_from(p - n * 2.0, n)
			gaps += 1
			var past: float = (Vector2(f.x, f.z) - p).dot(n)
			if past < 1.0:
				stuck.append("(%.1f, %.1f) %.1f m, stopped by %s" % [p.x, p.y, past, _what_stopped()])
	if gaps < 10:
		why.append("only %d open spans found between drawn rails" % gaps)
	if not stuck.is_empty():
		why.append("could not walk through %d of %d open spans: %s" % [stuck.size(), gaps, ", ".join(stuck.slice(0, 6))])
	_line("harden.rail_gaps", why, "%d open spans (one in nine) walked through from the road in %d ticks: all passed" % [gaps, TICKS])


## The same walk in the compact village of the walker-feel walks (walks/wf_feel.json: the exe's road and plots, another
## river and lots). There the first night's case started him on a roadside bush's cylinder, which leaned over the road's
## edge (1.45 m tall), and from its top he walked over the rails at (-215.2, -0.4) (the night's report read it as a road
## bank: there is none). Every place is walked into from the road; every start is on the land.
func _rails_village() -> void:
	var why: Array = []
	_build_village("res://kernel/world/walks/wf_feel.json")
	var got: Array = _walk_rails(_rail_places(_rail_looks()))
	if int(got[0]) < 100:
		why.append("only %d places along the drawn rails" % int(got[0]))
	if not (got[1] as Array).is_empty():
		why.append("walked over the rails at %d of %d places: %s" % [(got[1] as Array).size(), int(got[0]), ", ".join(got[1])])
	if not (got[2] as Array).is_empty():
		why.append("started on top of something, not on the road, at %s" % ", ".join(got[2]))
	_line("harden.rails_village", why, "%d places along the drawn rails of the wf_feel village walked into from the road (each start on the land) for %d ticks: stopped at all" % [int(got[0]), TICKS])


# ------------------------------------------------------------------------------------------------ the gate marker
func _gate_sign() -> void:
	var why: Array = []
	var fences: MeshInstance3D = _land.get_node_or_null("WorldPlotFences") as MeshInstance3D
	var verts: PackedVector3Array = (fences.mesh as ArrayMesh).get_faces() if fences != null else PackedVector3Array()
	var centres: Array = []
	var rad: Array = []
	for p: Dictionary in _walk["plots"]:
		centres.append(Vector2(float(p["origin"][0]), float(p["origin"][2])))
		rad.append(float(p["radius"]))
	for l: Dictionary in (_walk["landscape"] as Dictionary).get("lots", []):
		centres.append(Vector2(float(l["at"][0]), float(l["at"][1])))
		rad.append(float(l.get("radius", 20.0)))
	var out_m: float = TLStyle.num("detail", "sign_out", 0.0)
	var tried: int = 0
	var passed: Array = []
	var drawn: int = 0
	for i: int in centres.size():
		var c: Vector2 = centres[i]
		var best: int = 0
		for q: int in _road.pts.size():
			if _road.pts[q].distance_squared_to(c) < _road.pts[best].distance_squared_to(c):
				best = q
		var dir: Vector2 = (_road.pts[best] - c).normalized()
		var entrance: Vector2 = c + dir * (float(rad[i]) + 3.6)
		var post: Vector2 = entrance + dir.orthogonal() * (_half * 0.8 + 1.9 + 1.2) - dir * 0.15 + dir * out_m
		var gy: float = float(_terr.call("gy", post.x, post.y))
		var seen: bool = false
		for v: Vector3 in verts:
			if Vector2(v.x, v.z).distance_to(post) < 0.8 and v.y > gy + 1.3 and v.y < gy + 2.0:
				seen = true
				break
		if not seen:
			continue          # no marker drawn here (a site, or the fence is off)
		drawn += 1
		if OS.get_environment("TL_HARDEN_DEBUG") == "1":
			print("DBG marker %d at (%.1f, %.1f) faces (%.2f, %.2f)" % [i, post.x, post.y, dir.x, dir.y])
		var f: Vector3 = _walk_from(post + dir * 3.0, -dir, 60)
		tried += 1
		var past: float = (Vector2(f.x, f.z) - post).dot(-dir)
		if past > 0.3:
			passed.append("marker %d at (%.1f, %.1f): %.1f m beyond its board" % [i, post.x, post.y, past])
	if tried < 5:
		why.append("only %d gate markers found in the drawn mesh" % tried)
	if not passed.is_empty():
		why.append("walked through %d of %d gate markers: %s" % [passed.size(), tried, ", ".join(passed)])
	_line("harden.gate_sign", why, "%d gate markers (sign and flag, %.1f m before the fence) walked into from the road for 60 ticks: stopped at all" % [tried, out_m])


# ------------------------------------------------------------------------------------------------ bushes
func _bushes() -> void:
	var why: Array = []
	var tried: int = 0
	var into: Array = []
	for nm: String in ["WorldBushes", "WorldRoadBushes"]:
		var mm: MultiMeshInstance3D = _land.get_node_or_null(nm) as MultiMeshInstance3D
		if mm == null:
			why.append("no %s" % nm)
			continue
		var r: float = 1.0 if nm == "WorldBushes" else 0.9
		var count: int = 0
		var xs: Array = mm.get_meta(&"tl_xs", [])
		for k: int in xs.size():
			var x: Transform3D = xs[k]
			var s: Vector3 = x.basis.get_scale()
			if 1.1 * r * s.y < 0.6 or float(_terr.call("slope", x.origin.x, x.origin.z)) > 0.15 or _on_road(Vector2(x.origin.x, x.origin.z), snappedf(0.75 * r * s.x, 0.05)):
				continue
			if count >= 25:
				break
			count += 1
			var c: Vector2 = Vector2(x.origin.x, x.origin.z)
			var best: float = INF
			var g: float = float(_ws.call("ground_at", c.x - 3.5, c.y, 200.0))
			var feet: Vector3 = Vector3(c.x - 3.5, g, c.y)
			_ws.call("place", feet)
			_ws.call("rest")
			for t: int in 60:
				feet = (_ws.call("drive", feet, Vector3(WALK, 0, 0), false, false) as Dictionary)["pos"]
				best = minf(best, Vector2(feet.x, feet.z).distance_to(c))
			tried += 1
			if best < r * s.x * 0.33:
				into.append("%s %d at (%.1f, %.1f): %.2f m from its middle" % [nm, k, c.x, c.y, best])
	if tried < 30:
		why.append("only %d bushes walked into" % tried)
	if not into.is_empty():
		why.append("walked into the middle of %d of %d bushes: %s" % [into.size(), tried, ", ".join(into.slice(0, 4))])
	_line("harden.bush_block", why, "%d bushes taller than %.1f m walked into for 60 ticks: never in the middle third of one" % [tried, 0.6])


# ------------------------------------------------------------------------------------------------ kit parts in a pack
func _kit_parts() -> void:
	var why: Array = []
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var fcs: CollisionShape3D = CollisionShape3D.new()
	var fb: BoxShape3D = BoxShape3D.new()
	fb.size = Vector3(400, 1, 400)
	fcs.shape = fb
	fcs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fcs)
	holder.add_child(floor_body)
	# [kind, params, x, expect "stop" | "pass", walk from z, to +z]: each stands at (x, 0, 0), the board or line along X
	var cases: Array = [["fence", {"length": 8.0}, 0.0, "stop"], ["fence", {"length": 8.0, "style": "mesh"}, 20.0, "stop"],
		["bush", {}, 40.0, "stop"], ["sign", {}, 60.0, "stop"], ["marshal_post", {}, 80.0, "stop"], ["watch_tower", {}, 100.0, "stop"],
		["scoreboard", {}, 120.0, "pass"], ["pond", {"surface": "water", "radius_x": 4.0, "radius_z": 4.0}, 140.0, "pass"]]
	for c: Array in cases:
		var part: Node3D = TLKit.build(str(c[0]), c[1])
		part.position = Vector3(float(c[2]) - (4.0 if str(c[0]) == "fence" else 0.0), 0.0, 0.0)
		holder.add_child(part)
	var ws: RefCounted = Space.new()
	ws.call("add_pack", holder, Transform3D.IDENTITY, 0.0, 0.0, 0.0)
	ws.call("finish")
	var got: Array = []
	for c: Array in cases:
		var x: float = float(c[2])
		var f: Vector3 = _walk_from(Vector2(x, -4.0), Vector2(0, 1), 90, ws)
		var stopped: bool = f.z < 0.5
		got.append("%s%s %s" % [c[0], "(mesh)" if (c[1] as Dictionary).get("style", "") == "mesh" else "", "stopped" if stopped else "passed"])
		if stopped != (str(c[3]) == "stop"):
			why.append("%s: he %s (feet z %.2f, stopped by %s), want %s" % [c[0], "stopped" if stopped else "passed", f.z, _what_stopped(ws), "stopped" if str(c[3]) == "stop" else "through"])
	ws.call("free_all")
	holder.free()
	_line("harden.kit_parts", why, ", ".join(got))


## The sign by a site's gate (site/draw.gd `_sign`: a board on two posts at (10 +- 4.6, r + 6.2) in the gate's frame,
## its foot 2.3 m up): he walks into each post and is stopped; he walks under the board between them and passes.
func _site_sign() -> void:
	var why: Array = []
	var land: Node3D = Node3D.new()
	root.add_child(land)
	var ws: RefCounted = Space.new()
	ws.call("add_box", Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(400, 1, 400))
	land.set_meta(&"tl_space", ws)
	land.set_meta(&"tl_terrain", FlatGround.new())
	var model: SiteView = SiteView.new()
	var site: Node3D = (preload("res://kernel/world/site/draw.gd") as GDScript).call("make", model, 0, Vector3.ZERO, 32.0, Vector2(0, 1))
	land.add_child(site)
	var waited: int = 0
	while (not site.has_node("Parts/site_rails") or not (site.get("_tasks") as Dictionary).is_empty()) and waited < 600:
		await physics_frame
		waited += 1
	var z: float = 32.0 + 6.2
	var got: Array = []
	for c: Array in [[5.4, "stop"], [14.6, "stop"], [10.0, "pass"]]:
		var f: Vector3 = _walk_from(Vector2(float(c[0]), z - 1.7), Vector2(0, 1), 90, ws)     # inside the entrance rails (r + 3.6)
		var stopped: bool = f.z < z
		got.append("x %.1f %s" % [float(c[0]), "stopped" if stopped else "passed"])
		if stopped != (str(c[1]) == "stop"):
			why.append("x %.1f: he %s (feet z %.2f, stopped by %s), want %s" % [float(c[0]), "stopped" if stopped else "passed", f.z, _what_stopped(ws), "stopped" if str(c[1]) == "stop" else "through"])
	land.free()
	ws.call("free_all")
	_line("harden.site_sign", why, "a site's sign after %d frames: its posts %s; under the board between them %s" % [waited, ", ".join(got.slice(0, 2)), got[2]])


## B2: a site being built is fenced along its footprint (site/draw.gd `_hoarding`): the square of the lot's pad, turned
## by the player's yaw, open where the path from the gate meets it. Unturned and turned 30 degrees: from behind the
## yard he is stopped before the square (never within its inscribed circle); from the gate along the path he walks in.
func _site_fence() -> void:
	var why: Array = []
	var got: Array = []
	for yaw: float in [0.0, 30.0]:
		var land: Node3D = Node3D.new()
		root.add_child(land)
		var ws: RefCounted = Space.new()
		ws.call("add_box", Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(400, 1, 400))
		land.set_meta(&"tl_space", ws)
		land.set_meta(&"tl_terrain", FlatGround.new())
		var model: SiteView = SiteView.new()
		if yaw != 0.0:
			model.view["yaw_deg"] = yaw
		var r: float = float(model.view["radius"])
		var site: Node3D = (preload("res://kernel/world/site/draw.gd") as GDScript).call("make", model, 0, Vector3.ZERO, r, Vector2(0, 1))
		land.add_child(site)
		var waited: int = 0
		while (not site.has_node("Parts/site_rails") or not (site.get("_tasks") as Dictionary).is_empty()) and waited < 600:
			await physics_frame
			waited += 1
		var h: float = r - 1.0
		var stretches: int = int(site.get("hoarding")) if site.get("hoarding") != null else 0     # a draw.gd without a site fence: none
		var drawn: bool = site.has_node("Parts/site_hoarding")
		# from behind, beyond the square's corners, straight at the centre
		var back: Vector3 = _walk_from(Vector2(0.0, -(h * 1.42 + 3.0)), Vector2(0, 1), 360, ws)
		var back_in: float = Vector2(back.x, back.z).length()
		# from the gate (between the entrance rails) along the path
		var gate: Vector3 = _walk_from(Vector2(0.0, r + 4.5), Vector2(0, -1), 150, ws)
		var gate_in: float = Vector2(gate.x, gate.z).length()
		got.append("yaw %d: %d stretches%s, from behind stopped %.1f m from the centre, from the gate %.1f m" % [int(yaw), stretches, "" if drawn else " (NOT DRAWN)", back_in, gate_in])
		if stretches < 4 or not drawn:
			why.append("yaw %d: %d stretches of site fence, mesh drawn %s" % [int(yaw), stretches, str(drawn)])
		if back_in < h - 0.05:
			why.append("yaw %d: from behind he got %.1f m from the centre, inside the fenced square (half side %.1f; stopped by %s)" % [int(yaw), back_in, h, _what_stopped(ws)])
		if gate_in > h - 1.0:
			why.append("yaw %d: from the gate he stopped %.1f m from the centre, outside the yard (stopped by %s)" % [int(yaw), gate_in, _what_stopped(ws)])
		land.free()
		ws.call("free_all")
	_line("harden.site_fence", why, "; ".join(got))


func _spawn_clear() -> void:
	var why: Array = []
	var where: Array = []
	var first: Array = (_walk["player"] as Array)[0][1]
	var spawn: Vector2 = Vector2(float(first[0]), float(first[2]))
	var bad: String = _clear_at(spawn, float(first[1]) + 80.0)
	where.append("spawn")
	if not bad.is_empty():
		why.append("the spawn (%.1f, %.1f): %s" % [spawn.x, spawn.y, bad])
	var road: Array = _walk["road"]
	for p: Dictionary in _walk["plots"]:
		var c: Vector2 = Vector2(float(p["origin"][0]), float(p["origin"][2]))
		var best: Vector2 = Vector2.ZERO
		var bd: float = INF
		for k: int in range(road.size() - 1):
			var a: Vector2 = Vector2(float(road[k][0]), float(road[k][1]))
			var b: Vector2 = Vector2(float(road[k + 1][0]), float(road[k + 1][1]))
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(c, a, b)
			if q.distance_to(c) < bd:
				bd = q.distance_to(c)
				best = q
		var g: Vector2 = (best - c).normalized()
		var at: Vector2 = c + g * (float(p["radius"]) + 5.0)
		where.append(str(p["id"]))
		bad = _clear_at(at, 200.0)
		if not bad.is_empty():
			why.append("the gate of %s (%.1f, %.1f): %s" % [p["id"], at.x, at.y, bad])
	# the control: a box where he spawns must be found
	var was: String = str(_ws.get("tag"))
	_ws.set("tag", "control")
	var gy: float = float(_terr.call("gy", spawn.x, spawn.y))
	_ws.call("add_box", Transform3D(Basis(), Vector3(spawn.x + 0.5, gy + 0.5, spawn.y)), Vector3(0.6, 1.0, 0.6))
	var control: String = _clear_at(spawn, float(first[1]) + 80.0)
	_ws.call("remove_tag", "control")
	_ws.set("tag", was)
	if control.is_empty():
		why.append("the control box at the spawn was not found: the check cannot bite")
	_line("harden.spawn_clear", why, "%d places (%s): on the land, his capsule touches nothing; the control box is found (%s)" % [where.size(), ", ".join(where), control])
