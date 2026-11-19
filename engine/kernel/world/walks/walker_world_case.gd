extends SceneTree
## Headless cases for tools/selftest.d/460-walker-world.sh. The shell gives
## each run a private copy of the arriving job, with its promotion held back.
const Space = preload("res://kernel/world/terrain/world_space.gd")
const Seam = preload("res://kernel/world/draw/view_seam.gd")
const Log = preload("res://kernel/world/site/log.gd")
const World = preload("res://kernel/world/world.gd")
const Pack = preload("res://kernel/world/pack.gd")
const Tiers = preload("res://kernel/world/tiers.gd")
const FIXTURES = "res://kernel/world/site/fixtures/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var job := OS.get_cmdline_user_args()[0]
	_concave_cover()
	_log_schema(job.get_base_dir())
	_late_files(job)
	quit()

func _line(label: String, ok: bool, detail: String) -> void:
	print("WALKERWORLD %s %s %s" % [label, "ok" if ok else "fail", detail])

func _concave_cover() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var body := StaticBody3D.new()
	holder.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	# Every corner and centroid is outside. The first face contains the disc,
	# the second crosses its edge and the third is a distant vertical wall.
	shape.set_faces(PackedVector3Array([
		Vector3(-60, 0, -60), Vector3(-60, 0, 60), Vector3(240, 0, 0),
		Vector3(60, 0, 18), Vector3(-60, 0, 18), Vector3(150, 0, 100),
		Vector3(100, 0, 0), Vector3(120, 0, 0), Vector3(110, 5, 0)]))
	collision.shape = shape
	body.add_child(collision)
	var ok := true
	var results := PackedStringArray()
	for sliced: bool in [false, true]:
		var ws := Space.new()
		ws.tag = "pad 0"
		ws.add_box(Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)), Vector3(40, 1, 40))
		ws.tag = "game"
		if sliced:
			var copies := [{"i": 0, "job": ws.begin_pack(holder, Transform3D.IDENTITY, 20, 0, 9)}]
			Seam.copy_colliders(copies, ws, [Transform3D.IDENTITY], [20], Vector3.ZERO)
			ok = ok and copies.is_empty()
		else:
			ws.add_pack(holder, Transform3D.IDENTITY, 20, 0, 9)
			ws.remove_tag("pad 0")
		ws.finish()
		var feet := Vector3(1, 0.1, 0)
		ws.place(feet)
		for tick in 90:
			feet = ws.drive(feet, Vector3.ZERO, false, false).pos
		ok = ok and ws.stats.pack_faces == 2 and absf(feet.y) < 0.1
		results.append("%s %d faces y=%.2f" % ["arriving" if sliced else "immediate", ws.stats.pack_faces, feet.y])
		ws.free_all()
	holder.free()
	_line("ground.concave_cover", ok, ", ".join(results) + " at tick 90")

func _world(job: String) -> Node:
	var w := World.new()
	w.jobs = RefCounted.new()
	w.sched = Tiers.new()
	w.walk = {"plots": [], "landscape": {"lots": [{"job": job, "at": [0, 0], "radius": 22}]}}
	w.site.setup(w, w.walk)
	w.plot_defs = w.walk.plots
	w.sched.plots = [{"id": "site_0", "tier": "ledger", "size": Vector2(44, 44)}]
	w.packs = [Pack.new()]
	w.add_child(w.packs[0])
	return w

func _log_schema(scratch: String) -> void:
	var fixtures := PackedStringArray()
	var ok := true
	for name: String in DirAccess.get_directories_at(FIXTURES):
		var content := FileAccess.get_file_as_string(FIXTURES + name + "/job.jsonl")
		var reader := Log.new()
		var count := reader.feed(content)
		ok = ok and count > 0 and count == content.strip_edges().split("\n").size() and reader.error.is_empty()
		fixtures.append("%s=%d" % [name, count])

	var lines := FileAccess.get_file_as_string(FIXTURES + "arrive/job.jsonl").split("\n")
	var plan: Dictionary = JSON.parse_string(lines[2])
	var invalid := []
	# Make each invalid plan line 2, so sequence checks cannot mask missing schema checks.
	plan.seq = 2
	for key: String in ["v", "seq", "ts", "job", "type", "packages"]:
		var row := plan.duplicate(true)
		row.erase(key)
		invalid.append(row)
	for field: String in ["unknown", "missing", "acceptance", "args", "registers", "deps"]:
		var row := plan.duplicate(true)
		var package: Dictionary = row.packages[0]
		match field:
			"unknown": package["titlle"] = "typo"
			"missing": package.erase("title")
			"acceptance": package.acceptance[0]["extra"] = true
			"args": package.acceptance[0].args = [2]
			"registers": package.registers = {"asset": []}
			"deps": package.deps = null
		invalid.append(row)
	for fields: Dictionary in [{"seq": 3}, {"v": 2}, {"packages": "wrong"}, {"card": null}]:
		var row := plan.duplicate(true)
		row.merge(fields, true)
		invalid.append(row)
	var envelope := plan.duplicate()
	envelope.erase("packages")
	for fields: Dictionary in [
		{"type": "job_created", "title": "missing packId", "sentence": "build"},
		{"type": "package_state", "package": "court", "state": "failed", "round": 1},
		{"type": "package_state", "package": "court", "state": "queued", "round": 1.5},
		{"type": "verify", "round": 1, "level": "V2", "verb": "smoke", "report": "r.json", "ok": "false"},
		{"type": "builder_run", "round": 1, "adapter": "fake", "mode": "edit", "model": "m", "outcome": "ok", "durationMs": 0},
		{"type": "budget", "state": "running", "reason": "", "policy": {"kind": "overnight", "limit": 100}},
		{"type": "budget", "state": "running", "reason": "", "policy": {"kind": "only_while_playing", "limt": 2}},
		{"type": "brief_set", "brief": {"arena": "a"}, "estimate": {"packages": 1, "wallMinutes": 2, "tokens": 0}},
		{"type": "brief_set", "brief": {"rules": "r", "arena": "a", "ai": "a", "controls": "c", "mood": "m"},
			"estimate": {"packages": 1, "wallMinutes": 2, "tokens": "0"}},
	]:
		invalid.append(envelope.merged(fields, true))
	var refused := 0
	for row: Dictionary in invalid:
		var reader := Log.new()
		var prefix := lines[0] + "\n"
		reader.feed(prefix)
		var rest := prefix + JSON.stringify(row) + "\n" + lines[2] + "\n"
		if reader.feed(rest) == 0 and reader.events.size() == 1 and not reader.error.is_empty() and Log.fold(reader.events).stage == "pad":
			refused += 1

	var bad_dir := scratch.path_join("invalid")
	DirAccess.make_dir_recursive_absolute(bad_dir)
	var file := FileAccess.open(bad_dir.path_join("job.jsonl"), FileAccess.WRITE)
	file.store_string(lines[0] + "\n" + JSON.stringify(invalid[0]) + "\n" + lines[2] + "\n")
	file.close()
	var w := _world(bad_dir)
	w.site.tick(0)
	w.site.tick(60)
	var warnings: Array = w.site.warnings
	ok = ok and refused == invalid.size() and warnings.size() == 1 and str(warnings[0]).contains("line 2") and w.site.sites[0].n == 1
	w.free()
	_line("site.log_schema", ok, "%d/%d invalid rows refused, %d warnings, %s" % [refused, invalid.size(), warnings.size(), ", ".join(fixtures)])

func _late_files(job: String) -> void:
	var w := _world(job)
	for t in 61:
		w.site.tick(t)
	var held: bool = w.site.holds(0)
	var moved := DirAccess.rename_absolute(job.get_base_dir().path_join("pending"), job.path_join("promoted"))
	for t in range(61, 120):
		w.site.tick(t)
	var before_poll: bool = w.site.holds(0)
	for t in range(120, 241):
		w.site.tick(t)
	var s: Dictionary = w.site.sites[0]
	var tick := int(s.get("arrived_at", -1))
	var ok: bool = moved == OK and held and before_poll and tick == 120 and s.reads == 5 and s.n == 21 and w.site.warnings.size() == 1 and w.sched.plots[0].pack == "example.bounce"
	_line("site.late_files", ok, "arrival tick %d, %d events, %d polls, %d warnings" % [tick, s.n, s.reads, w.site.warnings.size()])
	w.free()
