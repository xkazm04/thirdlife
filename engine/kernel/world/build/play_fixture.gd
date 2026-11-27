extends SceneTree
## Lane P (M6, 27 Nov 2026): writes a fixture Home holding a tower course, for playing the rules in the exe (a window):
##   <godot> --headless --path engine --script res://kernel/world/build/play_fixture.gd -- --out=<abs dir>
## then  TL_HOME_BUILD_DIR=<abs dir> TL_EXE_START=<printed> <godot> --path engine res://boot/boot.tscn
## In the landscape of boot/village.json (as selftest 752 builds it), at a clear patch east of (700, -60) where nothing
## refuses a cell, along -z from the start: three stairs up onto a stone slab; the Start pad (enter: start "Tower
## Run", say); coin 1; a plank wall 4 high with a 3 x 3 Door zone and a Switch pad before it (use: open the door, say);
## two cells on, a Jump pad (launch up 15 m/s and on 4 m/s, close the door) with coin 2 in its arc; a ledge 3 high with the Checkpoint pad; three stairs
## up to a tower top 6 blocks high with coin 3 and the finish Flag (enter: finish when all 3 coins are taken, else a
## say); Lava round the tower's foot (enter: respawn). Prints `FIXTURE ok dir=... start=x,z,x2,z2 site=...`.

const Landscape := preload("res://kernel/world/landscape.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const Valley := preload("res://kernel/world/home/valley.gd")
const WALK_AT := Vector2i(700, -60)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	if out == "" or not out.is_absolute_path():
		print("FIXTURE fail: give -- --out=<abs dir>")
		quit(2)
		return
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
	var node := Node3D.new()
	root.add_child(node)
	TLStyle.set_headless(false)
	Landscape.build(node, xf, radii, own, cfg)
	Landscape.arrive(node)
	if not node.has_meta(&"tl_home"):
		print("FIXTURE fail: no Home in the landscape")
		quit(1)
		return
	var home: RefCounted = node.get_meta(&"tl_home")
	var valley: RefCounted = Valley.new(int(cfg.seed), node.get_meta(&"tl_terrain"))
	for k in 30:
		var sx := WALK_AT.x + 10 * k
		var sz := WALK_AT.y
		var b: RefCounted = HomeBuild.attach(node, walk, valley, {})
		var hi := -INF
		var lo := INF
		for z in range(sz - 21, sz + 19):
			for x in range(sx - 9, sx + 10):
				home.call("ensure", Vector2(x, z))
				var g: float = home.call("ground_y", x + 0.5, z + 0.5)
				hi = maxf(hi, g)
				lo = minf(lo, g)
		var gy := int(floorf(hi))
		if hi - lo > 2.5:
			b.free_all()
			continue
		var why := course(b, Vector3i(sx, gy, sz))
		if why == "":
			DirAccess.make_dir_recursive_absolute(out)
			var se: String = b.save(out)
			print("FIXTURE %s dir=%s start=%.1f,%.1f,%.1f,%.1f site=%d,%d,%d blocks=%d ground=%.2f..%.2f tries=%d %s" % [
				"ok" if se == "" else "fail", out, sx + 0.5, sz + 18.5, sx + 0.5, sz - 20.0, sx, gy, sz, int(b.blocks.total), lo, hi, k + 1, se])
			b.free_all()
			quit(0 if se == "" else 1)
			return
		print("FIXTURE try %d at %d,%d refused: %s" % [k + 1, sx, sz, why])
		b.free_all()
	print("FIXTURE fail: no clear patch")
	quit(1)


static func zone(n: int, lo: Vector3i, hi: Vector3i, look: String, name: String) -> Dictionary:
	return {"op": "zone", "id": n, "box": [[lo.x, lo.y, lo.z], [hi.x, hi.y, hi.z]], "look": look, "name": name}


static func rule(n: int, when: Dictionary, effects: Array, conds: Array = []) -> Dictionary:
	var r := {"op": "rule", "id": n, "when": when, "do": effects}
	if not conds.is_empty():
		r["if"] = conds
	return r


## The course at `o` (the base slab's cells are at o.y; feet stand at o.y + 1). "" or why refused.
static func course(b: RefCounted, o: Vector3i) -> String:
	var F := o.y + 1
	var cells := {}
	var put := func(x: int, y: int, z: int, code: int) -> void:
		cells[Vector3i(o.x + x, y, o.z + z)] = code
	var stone := Blocks.code(Blocks.CUBE, 1)
	var dark := Blocks.code(Blocks.CUBE, 2)
	var plank := Blocks.code(Blocks.CUBE, 3)
	var wood := Blocks.code(Blocks.CUBE, 4)
	var white := Blocks.code(Blocks.CUBE, 9)
	for z in range(-20, 13):
		for x in range(-7, 8):
			for y in range(o.y - 2, o.y + 1):                     # the slab, down into the ground so no gap shows
				put.call(x, y, z, stone if z >= -2 else dark)
	for s in 3:                                                  # three stairs down from the slab to the ground at +z
		for x in range(-2, 3):
			for y in range(o.y - 2, o.y - s):
				put.call(x, y, 13 + s, stone)
			put.call(x, o.y - s, 13 + s, Blocks.code(Blocks.STAIR, 1, 0))
	for x in range(-4, 5):                                       # the wall with the door
		for y in range(F, F + 4):
			put.call(x, y, 3, plank)
	for z in range(-8, -2):                                      # the ledge, 3 high
		for x in range(-2, 3):
			for y in range(F, F + 3):
				put.call(x, y, z, white if y == F + 2 else wood)
	for s in 3:                                                  # three stairs up to the top
		var z := -9 - s
		for x in range(-1, 2):
			for y in range(F, F + 3 + s):
				put.call(x, y, z, wood)
			put.call(x, F + 3 + s, z, Blocks.code(Blocks.STAIR, 1, 0))
	for z in range(-15, -11):                                    # the top, 6 high
		for x in range(-2, 3):
			for y in range(F, F + 6):
				put.call(x, y, z, white if y == F + 5 else wood)
	b.begin_batch("hand")
	var keys: Array = cells.keys()
	keys.sort()
	for c: Vector3i in keys:
		var r: Dictionary = b.place(c, int(cells[c]), "hand")
		if not bool(r.ok):
			b.end_batch()
			return "block %s: %s" % [str(c), str(r.reason)]
	b.end_batch()
	var X := o.x
	var Z := o.z
	var ops := [
		zone(1, Vector3i(X - 1, F, Z + 8), Vector3i(X + 1, F + 1, Z + 10), "pad", "Start"),
		zone(2, Vector3i(X, F, Z + 6), Vector3i(X, F + 1, Z + 6), "coin", "Coin 1"),
		zone(3, Vector3i(X - 1, F, Z + 3), Vector3i(X + 1, F + 2, Z + 3), "none", "Door"),
		zone(4, Vector3i(X - 1, F, Z + 4), Vector3i(X + 1, F + 1, Z + 4), "pad", "Switch"),
		zone(5, Vector3i(X - 1, F, Z), Vector3i(X + 1, F, Z), "pad", "Jump"),
		zone(6, Vector3i(X - 1, F + 3, Z - 3), Vector3i(X + 1, F + 4, Z - 2), "coin", "Coin 2"),
		zone(7, Vector3i(X - 2, F + 3, Z - 6), Vector3i(X + 2, F + 4, Z - 5), "pad", "Checkpoint"),
		zone(8, Vector3i(X, F + 6, Z - 12), Vector3i(X, F + 7, Z - 12), "coin", "Coin 3"),
		zone(9, Vector3i(X - 1, F + 6, Z - 14), Vector3i(X + 1, F + 7, Z - 14), "flag", "Flag"),
		zone(10, Vector3i(X - 7, F - 1, Z - 20), Vector3i(X + 7, F, Z - 2), "none", "Lava"),
		rule(1, {"on": "enter", "zone": 1}, [{"do": "start", "run": "Tower Run"}, {"do": "say", "text": "Go! Three coins, then the flag up top", "frames": 150}]),
		rule(2, {"on": "enter", "zone": 2}, [{"do": "take", "zone": 2}, {"do": "add", "counter": "coins", "by": 1}]),
		rule(3, {"on": "use", "zone": 4}, [{"do": "open", "zone": 3}, {"do": "say", "text": "The door slides open", "frames": 90}]),
		rule(4, {"on": "enter", "zone": 5}, [{"do": "launch", "up_cm": 1500, "fwd_cm": 400}, {"do": "close", "zone": 3}]),
		rule(5, {"on": "enter", "zone": 6}, [{"do": "take", "zone": 6}, {"do": "add", "counter": "coins", "by": 1}]),
		rule(6, {"on": "enter", "zone": 7}, [{"do": "checkpoint", "zone": 7}, {"do": "say", "text": "Checkpoint", "frames": 70}]),
		rule(7, {"on": "enter", "zone": 8}, [{"do": "take", "zone": 8}, {"do": "add", "counter": "coins", "by": 1}]),
		rule(8, {"on": "enter", "zone": 9}, [{"do": "finish"}], [{"counter": "coins", "min": 3}]),
		rule(9, {"on": "enter", "zone": 9}, [{"do": "say", "text": "Find all three coins first", "frames": 90}], [{"counter": "coins", "max": 2}]),
		rule(10, {"on": "enter", "zone": 10}, [{"do": "respawn"}, {"do": "say", "text": "Lava! Back you go", "frames": 70}]),
		rule(11, {"on": "count", "counter": "coins", "at": 3}, [{"do": "say", "text": "All three coins! Now the flag", "frames": 100}]),
	]
	var r2: Dictionary = b.apply(ops)
	if not bool(r2.ok):
		return "rules: %s" % str(r2.refused.slice(0, 3))
	return ""
