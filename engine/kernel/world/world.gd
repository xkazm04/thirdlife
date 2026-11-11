extends Node
## N2. The world host: several packs alive in one process, each in its own holder (kernel/world/pack.gd) with its
## own context, input record, seeded generator, tick counter and physics space.
##
##   <godot> --headless --fixed-fps 60 --path <engine> res://kernel/host/host.tscn -- world --packs=<dir>,<dir>,...
##           [--frames=N] [--seeds=..] [--at=x:y:z,..] [--spacing=M] [--every=N,..] [--pause=i:from:len;..]
##           [--mode=smoke|bot] [--space=own|shared] [--trace=N] [--hold=N] [--state=1] [--out=<file>]
##   (tools/world.sh run does this.)
##
## List options take one value per pack, or one value for all. Output: one JSON line per pack (`"kind":"pack"`, with
## its state hash) and one for the world (`"kind":"world"`), schema tl.world/1. Exit code 0 when every pack loaded
## and no pack logged an error, else 1.
##
## One world tick, in this node's `_physics_process` (it runs before every other node):
##   1. a pack whose last tick has been stepped is finished (state hash, teardown) and switched off;
##   2. every other pack is asked whether it gets this world tick (`--every`, `--pause`); the ones that do not are
##      switched off (scripts and space), the ones that do are switched on and ticked: `ctx.frame` = the pack's own
##      tick count -> bot -> input latch -> `_pack_tick`;
##   3. the scene tree then ticks the nodes of the packs that are on, pack by pack, and the physics server steps the
##      spaces that are active. A pack that is off costs nothing in either.
## A pack's hash depends on its own tick count and its own input only, never on the world tick.

const PackScript: GDScript = preload("res://kernel/world/pack.gd")
const LoggerScript: GDScript = preload("res://kernel/runner/logger.gd")

var opts: Dictionary = {}
var logger: Object
var packs: Array = []
var tick: int = 0
var hold_left: int = 0
var show_state: bool = false
var errors: Array = []
var pauses: Array = []                  # [pack index or -1 for all, from world tick, length]
var _last_usec: int = 0
var _last_due: int = 0
var _iter_all: PackedInt64Array = PackedInt64Array()      # iterations in which every pack was ticked
var _iter_any: PackedInt64Array = PackedInt64Array()      # every iteration with at least one pack still open
var _iter_hold: PackedInt64Array = PackedInt64Array()     # iterations of the hold phase (every pack switched off)
var _kernel_usec: PackedInt64Array = PackedInt64Array()   # this node's own work per world tick (calls into packs)
var _ended: bool = false
var _t_start: int = 0
var _load_ms: int = 0
var _mem_before: int = 0
var _mem_loaded: int = 0


func _list(key: String, fallback: String) -> PackedStringArray:
	return str(opts.get(key, fallback)).split(",", false)


func _item(list: PackedStringArray, i: int, fallback: String) -> String:
	if list.is_empty():
		return fallback
	return list[i] if i < list.size() else list[list.size() - 1]


func start(options: Dictionary) -> void:
	opts = options
	print("[tl] world start")
	_t_start = Time.get_ticks_msec()
	process_physics_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	logger = LoggerScript.new()
	OS.add_logger(logger)
	for e: String in TLLaws.load_tables():
		errors.append("kernel data: " + e)
	var headless: bool = DisplayServer.get_name() == "headless"
	TLStandin.prepare_style(headless)
	if not headless:
		TLStandin.install_look(self)
	get_tree().node_added.connect(_on_node_added)
	show_state = opts.has("state")
	hold_left = int(opts.get("hold", "0"))
	for part: String in str(opts.get("pause", "")).split(";", false):
		var f: PackedStringArray = part.split(":")
		if f.size() == 3:
			pauses.append([-1 if f[0] == "all" else int(f[0]), int(f[1]), int(f[2])])
		else:
			errors.append("--pause wants <pack index or all>:<from world tick>:<ticks>, got '%s'" % part)
	var dirs: PackedStringArray = _list("packs", "")
	var frames: PackedStringArray = _list("frames", "3600")
	var seeds: PackedStringArray = _list("seeds", "1")
	var ats: PackedStringArray = _list("at", "")
	var everys: PackedStringArray = _list("every", "1")
	var spacing: float = float(opts.get("spacing", "0"))
	_mem_before = OS.get_static_memory_usage()
	for i: int in dirs.size():
		var at: Vector3 = Vector3(spacing * float(i), 0.0, 0.0)
		if not ats.is_empty():
			var xyz: PackedStringArray = _item(ats, i, "0:0:0").split(":")
			if xyz.size() == 3:
				at = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
			else:
				errors.append("--at wants x:y:z per pack, got '%s'" % _item(ats, i, ""))
		var p: Node3D = PackScript.new()
		p.name = "P%d_%s" % [i, dirs[i].replace("\\", "/").trim_suffix("/").get_file()]
		p.set("world", self)
		add_child(p)
		var ok: bool = p.call("load_pack", dirs[i], {"mode": str(opts.get("mode", "smoke")), "seed": int(_item(seeds, i, "1")),
			"frames": int(_item(frames, i, "3600")), "every": int(_item(everys, i, "1")), "at": at,
			"trace": int(opts.get("trace", "0")), "own_space": str(opts.get("space", "own")) != "shared"})
		if not ok:
			errors.append("pack %d (%s) did not load" % [i, dirs[i]])
		packs.append(p)
	_mem_loaded = OS.get_static_memory_usage()
	_load_ms = Time.get_ticks_msec() - _t_start
	_last_usec = Time.get_ticks_usec()
	set_physics_process(true)


func _on_node_added(n: Node) -> void:
	if not (n is CollisionObject3D):
		return
	var up: Node = n.get_parent()
	while up != null and up != self:
		if up.get_parent() == self:
			if up.has_method("adopt"):
				up.call("adopt", n)
			return
		up = up.get_parent()


## Whether pack `i` gets world tick `tick`.
func _is_due(i: int, p: Node) -> bool:
	for w: Array in pauses:
		if (int(w[0]) == -1 or int(w[0]) == i) and tick >= int(w[1]) and tick < int(w[1]) + int(w[2]):
			return false
	return tick % int(p.get("every")) == 0


func _physics_process(_delta: float) -> void:
	if _ended:
		return
	var now: int = Time.get_ticks_usec()
	if tick > 0:
		var span: int = now - _last_usec          # the whole previous iteration: scripts, tree, every active space
		if _last_due < 0:
			_iter_hold.append(span)
		else:
			_iter_any.append(span)
			if _last_due == packs.size() and not packs.is_empty():
				_iter_all.append(span)
	_last_usec = now
	TLContext.current = null
	var open: int = 0
	for p: Node in packs:
		if bool(p.get("loaded")) and not bool(p.get("finished")):
			if int(p.get("frames_done")) >= int(p.get("frames_target")):
				p.call("finish", tick)            # its last tick has been stepped: hash it now
			else:
				open += 1
	if open == 0:
		for p: Node in packs:
			p.set("due", false)
			p.call("set_running", false)
		if hold_left > 0:
			hold_left -= 1
			_last_due = -1
			tick += 1
			return
		_end()
		return
	var due_count: int = 0
	for i: int in packs.size():
		var p: Node = packs[i]
		if not bool(p.get("loaded")) or bool(p.get("finished")):
			continue
		var d: bool = _is_due(i, p)
		p.set("due", d)
		p.call("set_running", d)
		if d:
			p.call("tick", tick)
			due_count += 1
	TLContext.current = null
	_last_due = due_count
	_kernel_usec.append(Time.get_ticks_usec() - now)
	tick += 1
	if tick > 10000000:
		errors.append("the world ran ten million ticks without finishing")
		_end()


func _pct(values: PackedInt64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedInt64Array = values.duplicate()
	sorted.sort()
	var idx: int = clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return snappedf(float(sorted[idx]) / 1000.0, 0.0001)


func _mean(values: PackedInt64Array) -> float:
	if values.is_empty():
		return 0.0
	var sum: int = 0
	for v: int in values:
		sum += v
	return snappedf(float(sum) / float(values.size()) / 1000.0, 0.0001)


func _end() -> void:
	_ended = true
	set_physics_process(false)
	TLContext.current = null
	var lines: PackedStringArray = PackedStringArray()
	var bad: bool = not errors.is_empty()
	var leaks: int = 0
	var wrong: int = 0
	for i: int in packs.size():
		var r: Dictionary = (packs[i] as Node).call("result", i)
		bad = bad or not bool(r["loaded"]) or int(r["script_errors"]) > 0 or int(r["engine_errors"]) > 0
		leaks += int(r["gate_leaks"])
		wrong += int(r["wrong_pack_calls"])
		lines.append(JSON.stringify(r, "", false))
	var snap: Dictionary = logger.call("snapshot")
	var warns: Array = logger.call("warning_texts")
	var dropped: int = 0
	for w: Variant in warns:
		var low: String = str(w).to_lower()
		if low.contains("contact") or low.contains("body pair") or low.contains("max_bodies") or low.contains("maximum number of bodies"):
			dropped += 1
	var world_line: Dictionary = {"schema": "tl.world/1", "kind": "world", "packs": packs.size(), "world_ticks": tick,
		"load_ms": _load_ms, "wall_ms": Time.get_ticks_msec() - _t_start,
		"iter_ms_p50_all_ticked": _pct(_iter_all, 0.5), "iter_ms_p99_all_ticked": _pct(_iter_all, 0.99),
		"iter_ms_mean_all_ticked": _mean(_iter_all), "iters_all_ticked": _iter_all.size(),
		"iter_ms_p50_last_third": _pct(_iter_all.slice(_iter_all.size() * 2 / 3), 0.5),
		"iter_ms_p50": _pct(_iter_any, 0.5), "iter_ms_mean": _mean(_iter_any), "iters": _iter_any.size(),
		"hold_iter_ms_p50": _pct(_iter_hold, 0.5), "hold_iter_ms_mean": _mean(_iter_hold), "hold_iters": _iter_hold.size(),
		"kernel_ms_p50": _pct(_kernel_usec, 0.5), "kernel_ms_mean": _mean(_kernel_usec),
		"static_mem_per_pack_kb": int(float(_mem_loaded - _mem_before) / 1024.0 / float(maxi(1, packs.size()))),
		"gate_leaks": leaks, "wrong_pack_calls": wrong,
		"script_errors": int(snap["script_errors"]), "engine_errors": int(snap["engine_errors"]),
		"engine_warnings": int(snap["warnings"]), "warning_texts": warns, "contact_or_body_limit_warnings": dropped,
		"errors": errors, "logged": snap["errors"]}
	bad = bad or dropped > 0 or leaks > 0
	lines.append(JSON.stringify(world_line, "", false))
	for line: String in lines:
		print(line)
	if opts.has("out"):
		var f: FileAccess = FileAccess.open(str(opts["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
			f.close()
	print("[tl] world done: packs=%d ticks=%d" % [packs.size(), tick])
	# leave nothing behind: nodes first, then the spaces they lived in
	for p: Node in packs:
		for c: Node in p.get_children():
			c.free()
		p.call("release_space")
	get_tree().quit(1 if bad else 0)
