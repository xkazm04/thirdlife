extends SceneTree
## Lane P (M6 round 2, 27 Nov 2026): can a body finish a Home's course? A probe, not a selftest:
##   <godot> --headless --path engine --script res://kernel/world/build/play_llm_probe.gd -- --home=<abs dir> [--run]
## The Home of <dir> (copied first: its records are not touched) in the landscape of boot/village.json, build mode with
## the rules in play over the real facade (play_facade.gd), a real visitor (visitor.gd, the person's body: walking,
## jumping 1.0 m, mantling, as keys move it). The path is lane C's estimate (command_replay.gd `replay`: start -> the
## coins -> the finish over standable cells); an autopilot steers him cell to cell at a walk (--run: a run), and
## presses jump when the next cell is higher or more than a cell away. Prints one `PROBE` line per waypoint it could
## not reach in 240 frames (where it fails), then `PROBE done finished=<bool> coins=<n> frames=<n> stuck=[...]`.

const Landscape := preload("res://kernel/world/landscape.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const Valley := preload("res://kernel/world/home/valley.gd")
const Visitor := preload("res://kernel/world/visitor.gd")
const Replay := preload("res://kernel/world/build/command_replay.gd")
const RR := preload("res://kernel/world/build/rules_run.gd")

var v: Node3D
var t := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var src := ""
	var speed := 4.5
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--home="):
			src = a.substr(7)
		elif a == "--run":
			speed = 9.0
	var dir := OS.get_user_data_dir().path_join("tl_llm_probe")
	DirAccess.make_dir_recursive_absolute(dir)
	for f: String in ["build.json", "edits.jsonl"]:
		DirAccess.copy_absolute(src.path_join(f), dir.path_join(f))
	DirAccess.remove_absolute(dir.path_join("records.json"))
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
	var land := Node3D.new()
	root.add_child(land)
	TLStyle.set_headless(false)
	Landscape.build(land, xf, radii, own, cfg)
	Landscape.arrive(land)
	var b: RefCounted = HomeBuild.attach(land, walk, Valley.new(int(cfg.seed), land.get_meta(&"tl_terrain")), {})
	var lr: Dictionary = b.load(dir)
	b.flush()
	var rp: Dictionary = Replay.replay(b, land)
	if (rp.runs as Array).is_empty() or (rp.runs[0].walk as Array).is_empty():
		print("PROBE done finished=false no run or no walk: %s" % str(rp.get("space", {}).get("runs", [])))
		quit(1)
		return
	var cells: Array = rp.runs[0].walk
	print("PROBE home %s blocks=%d, run '%s', estimate walk %d cells, estimate finished=%s" % [dir, int(lr.get("blocks", -1)),
		str(rp.runs[0].run), cells.size(), str(rp.runs[0].finished)])
	print("PROBE walk %s" % str(cells))
	var c0: Vector3i = cells[0]
	v = Visitor.new()
	land.add_child(v)
	v.setup(Vector3(c0.x + 0.5, c0.y + 0.5, c0.z + 0.5 + 2.0), Vector3.FORWARD)
	v.call("put", Vector3(c0.x + 0.5, c0.y, c0.z + 0.5 + 1.5), 0.0, false)
	v.steer_on()
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	bm.set("feet_at", func() -> Vector3: return v.feet)
	bm.set("dir", dir)
	root.add_child(bm)
	var p: RefCounted = bm.get("play")
	p.set("visitor", v)
	var rr: RefCounted = p.get("run")
	var stuck := []
	var jumps := 0
	var i := 0
	var stall := 0
	var best_d := INF
	while i < cells.size() and t < 9000:
		var c: Vector3i = cells[i]
		var target := Vector3(c.x + 0.5, c.y, c.z + 0.5)
		var here := RR.feet_cell(v.feet)
		var flat := Vector2(target.x - v.feet.x, target.z - v.feet.z)
		if here == c or (flat.length() < 0.3 and absf(v.feet.y - target.y) < 0.3):
			print("PROBE reached %d %s at frame %d feet %s" % [i, str(c), t, str(v.feet)])
			i += 1
			stall = 0
			best_d = INF
			continue
		var up: float = float(c.y) - float(v.feet.y)
		var wish := Vector3(flat.x, 0, flat.y).normalized() * speed if flat.length() > 0.05 else Vector3.ZERO
		var jump: bool = str(v.get("mode")) == "ground" and ((up > 0.45 and flat.length() < 1.3) or (flat.length() > 1.2 and _gap_ahead(c, here)))
		if jump:
			jumps += 1
		await _frame(wish, jump)
		stall += 1
		var d := flat.length() + absf(up)
		if d < best_d - 0.05:
			best_d = d
			stall = mini(stall, 60)
		if stall > 240:
			stuck.append([i, c, here, v.feet])
			print("PROBE stuck at waypoint %d %s: feet %s (cell %s), mode %s" % [i, str(c), str(v.feet), str(here), str(v.get("mode"))])
			if stuck.size() >= 3:
				break
			v.call("put", target, 0.0, false)              # put him there and go on, to find every place it fails
			i += 1
			stall = 0
			best_d = INF
	for k in 30:
		await _frame(Vector3.ZERO, false)
	var st: Dictionary = rr.call("state")
	var lf: Dictionary = rr.get("last_finish")
	print("PROBE done finished=%s coins=%s frames=%d jumps=%d waypoints=%d/%d stuck=%s speed=%.1f" % [str(not lf.is_empty()),
		str((st.counters as Dictionary).get("coins", "-") if not lf.is_empty() else (st.counters as Dictionary).get("coins", 0)),
		int(lf.get("frames", -1)), jumps, i, cells.size(), str(stuck), speed])
	quit(0)


## True when the cell under the walk between here and `c` is not a floor (a gap to jump).
func _gap_ahead(c: Vector3i, here: Vector3i) -> bool:
	return absi(c.x - here.x) + absi(c.z - here.z) > 1


func _frame(wish: Vector3, jump: bool) -> void:
	await physics_frame
	t += 1
	v.call("wish", wish, jump, false)
	v.call("step", v.feet, t)
