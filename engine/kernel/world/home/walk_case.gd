extends SceneTree
## D1 (22 Nov 2026): the visitor walks out of the village onto the Home (arm A) and over the mill bridge, on his own
## body (world_space.gd `drive`, the one a person's keys move), in the visitor's space that landscape.gd builds for
## res://boot/village.json (landscape.home "wren": home/hook.gd). Time is physics frames: one `drive` per frame.
## Prints `HOME <case> ok|fail <detail>` lines and `HOME DONE`; engine/tools/selftest.d/751-home-walk.sh reads them.
##   home.walk     from the village road (-200, 3) west through the gate, the ford lane, over the bridge to Mill Green:
##                 he arrives, he is on the ground every frame out of the village (no fall-through: never below the
##                 drawn ground; no floating: never above what is drawn under him), the distance out of the village
##                 is stated
##   home.bridge   the frames over Wren Water: on the deck (above the water, on the plank quads)
##   home.trees    he runs at the trunks of five lone valley trees of different sizes: each stops him at its bark (made with the
##                 ground chunk it stands in)
##   home.drops    he is dropped from 25 m at five far places of the valley (streamed chunks): he lands on the drawn
##                 ground there, and he does not fall through it in 120 frames of standing
const Landscape := preload("res://kernel/world/landscape.gd")
const ROUTE := [[-200, 3], [-270, 6], [-391, 14], [-477, 49], [-575, 116], [-653, 106], [-747, 92], [-805, 81],
	[-847, 77], [-881, 95]]
const DROPS := [[-1300, -420], [957, 198], [-2500, 0], [1900, -2100], [-1140, 390]]
const SPEED := 9.0            # m/s, the run (world_body.gd RUN_MPS)
const SINK := -0.08           # metres below the drawn surface that is still "on it" (the capsule's contact margin)
const FLOAT := 0.12           # metres above it that is still "on it"
const LIMIT := 9000           # frames for the walk (150 s; the route is about 700 m)

var node: Node3D
var ws: Object
var home: RefCounted
var terr: RefCounted
var valley: RefCounted


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	print("HOME %s %s %s" % [case_name, "ok" if ok else "fail", detail])


func run() -> void:
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))
	var cfg: Dictionary = walk.landscape.duplicate(true)
	cfg.road = walk.road
	cfg.footprints = []
	var xf := []
	var radii := []
	var own := []
	for p: Dictionary in walk.plots:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(p.origin[0], p.origin[1], p.origin[2])))
		radii.append(p.radius)
		own.append(false)
		cfg.footprints.append(Vector2(p.footprint.size_m[0], p.footprint.size_m[1]))
	node = Node3D.new()
	root.add_child(node)
	TLStyle.set_headless(false)
	var stats: Dictionary = Landscape.build(node, xf, radii, own, cfg)
	Landscape.arrive(node)
	if not node.has_meta(&"tl_home"):
		say("walk", false, "no Home: landscape.gd did not grow it (landscape.home of boot/village.json, TL_HOME=%s)" % OS.get_environment("TL_HOME"))
		print("HOME DONE")
		quit(1)
		return
	ws = node.get_meta(&"tl_space")
	home = node.get_meta(&"tl_home")
	terr = node.get_meta(&"tl_terrain")
	valley = preload("res://kernel/world/home/valley.gd").new(int(cfg.seed), terr)
	print("[home] landscape build %d ms, home %s" % [int(stats.get("build_ms", -1)), JSON.stringify(stats.get("home", {}))])
	walk_route()
	trees()
	drops()
	print("[home] chunks made %d dropped %d faces %d trunks %d build %.1f ms" % [home.stats.made, home.stats.dropped, home.stats.faces, home.stats.trunks, home.stats.build_usec / 1000.0])
	print("HOME DONE")
	quit(0)


## The drawn surface under (x, z) outside the village: the valley's rendered ground (ground.gd triangles) or a lane or
## the deck drawn over it (places.gd quads), whichever is highest below `top`.
func drawn(x: float, z: float, top: float) -> float:
	var y: float = home.ground_y(x, z)
	var lanes: Dictionary = home.lanes
	var c: Vector2i = home.chunk_of(Vector2(x, z))
	var from := Vector3(x, top, z)
	for id: Vector2i in [c, c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
		if not lanes.has(id):
			continue
		var f: PackedVector3Array = lanes[id]
		for i: int in range(0, f.size() - 2, 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, f[i], f[i + 1], f[i + 2])
			if hit != null and (hit as Vector3).y > y:
				y = (hit as Vector3).y
	return y


## What his sole stands on: the highest drawn surface under his capsule's bottom (radius 0.35 m, world_space.gd).
func under(p: Vector3) -> float:
	var y := -INF
	for o: Vector2 in [Vector2.ZERO, Vector2(0.3, 0), Vector2(-0.3, 0), Vector2(0, 0.3), Vector2(0, -0.3)]:
		y = maxf(y, drawn(p.x + o.x, p.z + o.y, p.y + 0.6))
	return y


func outside(p: Vector3) -> bool:
	return not terr.inside(p.x, p.z)


func walk_route() -> void:
	var start: Array = ROUTE[0]
	var pos := Vector3(start[0], 0.0, start[1])
	pos.y = float(ws.call("ground_at", pos.x, pos.z, 200.0))
	ws.call("place", pos)
	var target := 1
	var frames := 0
	var out_m := 0.0
	var out_frames := 0
	var off := 0
	var worst_sink := 0.0
	var worst_float := 0.0
	var worst_at := ""
	var bridge_frames := 0
	var bridge_bad := 0
	var deck_low := INF
	var deck_span := {}
	var stuck := 0
	var last := pos
	while target < ROUTE.size() and frames < LIMIT:
		var aim := Vector3(ROUTE[target][0], 0.0, ROUTE[target][1])
		var to := Vector3(aim.x - pos.x, 0.0, aim.z - pos.z)
		if to.length() < 3.0:
			target += 1
			continue
		var r: Dictionary = ws.call("drive", pos, to.normalized() * SPEED, false, false)
		pos = r.pos
		frames += 1
		var step := Vector2(pos.x - last.x, pos.z - last.z).length()
		stuck = stuck + 1 if step < 0.02 else 0
		if stuck > 120:
			break
		if outside(pos):
			out_m += step
			out_frames += 1
			var sink := pos.y - drawn(pos.x, pos.z, pos.y + 0.6)
			var lift := pos.y - under(pos)
			if not bool(r.grounded) or sink < SINK or lift > FLOAT:
				off += 1
				if off <= 5:
					print("[off] f%d (%.2f, %.2f, %.2f) sink %.3f lift %.3f %s" % [frames, pos.x, pos.y, pos.z, sink, lift, r.get("mode", "")])
			if sink < worst_sink or lift > worst_float:
				worst_at = "(%.1f, %.2f, %.1f) sink %.3f lift %.3f %s" % [pos.x, pos.y, pos.z, sink, lift, r.get("mode", "")]
			worst_sink = minf(worst_sink, sink)
			worst_float = maxf(worst_float, lift)
			if absf(pos.x - valley.river_x(pos.z)) < valley.river_width(pos.z):
				bridge_frames += 1
				if not deck_span.has("from"):
					deck_span["from"] = [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1), frames]
				deck_span["to"] = [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1), frames]
				deck_low = minf(deck_low, pos.y)
				if pos.y < valley.level(pos.z) + 1.0 or sink < SINK or lift > FLOAT:
					bridge_bad += 1
		if OS.get_environment("TL_HOME_TRACE") == "1" and frames % 20 == 0:
			print("[trace] f%d (%.2f, %.2f, %.2f) %s g=%s blocked=%s hit=%s" % [frames, pos.x, pos.y, pos.z, r.get("mode", ""), r.get("grounded", ""), r.get("blocked", ""), str(ws.get("last_hit"))])
		last = pos
	var arrived := target >= ROUTE.size()
	say("walk", arrived and off == 0 and out_m > 500.0,
		"%s in %d frames; %.1f m out of the village over %d frames, %d frames off the drawn ground (lowest %.3f m under it at his centre, highest %.3f m over it under his sole; worst %s)" % [
		"arrived at Mill Green" if arrived else "stopped at (%.1f, %.1f) before waypoint %d (stuck %d frames)" % [pos.x, pos.z, target, stuck],
		frames, out_m, out_frames, off, worst_sink, worst_float, worst_at])
	say("bridge", bridge_frames > 30 and bridge_bad == 0,
		"%d frames over Wren Water, %d not on the deck; lowest feet %.2f m (water %.2f m); over the water from %s to %s" % [bridge_frames, bridge_bad, deck_low, valley.level(95.0), str(deck_span.get("from")), str(deck_span.get("to"))])


func trees() -> void:
	var picked := []
	var seen := {}
	var ids: Array = home.trees.keys()
	ids.sort()
	for id: Vector2i in ids:
		for t: Array in home.trees[id]:
			var near := false
			for q: Array in home.trees[id]:
				near = near or (q != t and Vector2(q[0].x - t[0].x, q[0].z - t[0].z).length() < 9.0)
			var band := int(t[1] * 100.0)
			if not near and not seen.has(band) and picked.size() < 5:
				seen[band] = true
				picked.append(t)
	var bad := []
	var report := []
	for t: Array in picked:
		var foot: Vector3 = t[0]
		var pos := Vector3(foot.x + 6.0, 0.0, foot.z)
		pos.y = drawn(pos.x, pos.z, 1000.0)
		ws.call("place", pos)
		ws.call("drive", pos, Vector3.ZERO, false, false)     # the chunk round him is made before he moves
		pos.y = drawn(pos.x, pos.z, 1000.0)
		var closest := INF
		for f: int in 150:
			var r: Dictionary = ws.call("drive", pos, Vector3(foot.x - pos.x, 0.0, foot.z - pos.z).normalized() * 4.5, false, false)
			pos = r.pos
			closest = minf(closest, Vector2(pos.x - foot.x, pos.z - foot.z).length())
		report.append("(%.0f, %.0f) r %.2f closest %.2f" % [foot.x, foot.z, t[1], closest])
		if closest < t[1] + 0.25:
			bad.append("(%.0f, %.0f)" % [foot.x, foot.z])
	say("trees", picked.size() == 5 and bad.is_empty(), "%d trunks: %s%s" % [picked.size(), "; ".join(report),
		"" if bad.is_empty() else "; walked into " + ", ".join(bad)])


func drops() -> void:
	var bad := []
	var report := []
	for d: Array in DROPS:
		var top := drawn(d[0], d[1], 1000.0)
		var pos := Vector3(d[0], top + 25.0, d[1])
		ws.call("place", pos)
		var landed := -1
		var lowest := INF
		for f: int in 300:
			var r: Dictionary = ws.call("drive", pos, Vector3.ZERO, false, false)
			pos = r.pos
			if landed < 0 and bool(r.grounded):
				landed = f
			if landed >= 0:
				lowest = minf(lowest, pos.y - drawn(pos.x, pos.z, pos.y + 0.6))
			if landed >= 0 and f > landed + 120:
				break
		var lift := pos.y - under(pos)
		report.append("(%d, %d) landed at frame %d, sink %.3f lift %.3f" % [d[0], d[1], landed, lowest, lift])
		if landed < 0 or lift > FLOAT or lowest < SINK:
			bad.append("(%d, %d)" % [d[0], d[1]])
	say("drops", bad.is_empty(), "%d of %d places: %s%s" % [DROPS.size() - bad.size(), DROPS.size(), "; ".join(report),
		"" if bad.is_empty() else "; FAILED " + ", ".join(bad)])
