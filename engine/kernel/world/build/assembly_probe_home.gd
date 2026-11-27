extends SceneTree
## M6 round 3, lane A6 (round 2): makes a Home for lane P's body probe (play_llm_probe.gd) over one assembly, in the
## landscape of res://boot/village.json: the assemble (expanded by home_build.gd `expand_input`, as an LLM answer is),
## a start pad on the ground at one end, a flag at the other, a run between them; saved to <dir>. A dev tool, not a case:
##   <godot> --headless --path engine --script res://kernel/world/build/assembly_probe_home.gd -- --out=<abs dir>
##     --op=<assemble JSON> --start=x,z|x,y,z --finish=x,y,z|x,z   (the start pad on the ground of column x,z or at x,y,z; the flag's feet cell or ground)
## Prints `PROBEHOME ok <dir> blocks=<n> refused=<n> start=<cell> finish=<cell>` or `PROBEHOME fail <why>`.

const Landscape := preload("res://kernel/world/landscape.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Valley := preload("res://kernel/world/home/valley.gd")
const Assembly := preload("res://kernel/world/build/assembly.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var a := {}
	for s: String in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
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
	TLStyle.set_headless(false)                     # as play_llm_probe.gd: the Home's ground is grown then
	Landscape.build(land, xf, radii, own, cfg)
	Landscape.arrive(land)
	var b: RefCounted = HomeBuild.attach(land, walk, Valley.new(int(cfg.seed), land.get_meta(&"tl_terrain")), {})
	var op: Variant = JSON.parse_string(str(a.get("op", "")))
	if not (op is Dictionary):
		print("PROBEHOME fail --op is not a JSON object")
		quit(1)
		return
	var home: Variant = land.get_meta(&"tl_home") if land.has_meta(&"tl_home") else null
	if home != null:                                 # the chunks round the shape loaded: their ground is read
		for k: String in ["start", "finish"]:
			var q := str(a.get(k, "0,0")).split(",")
			(home as RefCounted).call("ensure", Vector2(float(q[0]), float(q[q.size() - 1])))
		for i in 3:
			await physics_frame
	var st := str(a.get("start", "")).split(",")
	var fi := str(a.get("finish", "")).split(",")
	var g: Callable = Assembly.ground_of(b)
	var s := Vector3i(int(st[0]), int(st[1]), int(st[2])) if st.size() == 3 else Vector3i(int(st[0]), int(g.call(int(st[0]), int(st[1]))), int(st[1]))
	var f := Vector3i(int(fi[0]), int(fi[1]), int(fi[2])) if fi.size() == 3 else Vector3i(int(fi[0]), int(g.call(int(fi[0]), int(fi[1]))), int(fi[1]))
	var ops := [op,
		{"op": "zone", "id": 1, "box": [[s.x, s.y, s.z], [s.x + 1, s.y, s.z + 1]], "look": "pad", "name": "Start"},
		{"op": "zone", "id": 2, "box": [[f.x, f.y, f.z], [f.x, f.y, f.z]], "look": "flag", "name": "Finish"},
		{"op": "rule", "id": 1, "when": {"on": "enter", "zone": 1}, "do": [{"do": "start", "run": "Probe"}]},
		{"op": "rule", "id": 2, "when": {"on": "enter", "zone": 2}, "if": [{"running": true}], "do": [{"do": "finish"}]}]
	var ex: Dictionary = b.expand_input(ops)
	b.begin_batch("hand")
	var r: Dictionary = b.apply(ex.ops)
	b.end_batch()
	var dir := str(a.get("out", ""))
	DirAccess.make_dir_recursive_absolute(dir)
	var why: String = b.save(dir)
	print("PROBEHOME %s %s blocks=%d refused=%s start=%s finish=%s ground=%s" % ["ok" if why == "" and (ex.refused as Array).is_empty() else "fail " + why,
		dir, int(b.blocks.total), str(r.refused.slice(0, 4)) + str(ex.refused), s, f, home != null])
	quit(0)
