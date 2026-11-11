extends SceneTree
## P12 item 1. The main-thread milliseconds of one arrival of each pack, split by what is in it, as the build queue
## does it: PREPARE on a worker (jobs.gd `prepare`, waited for), then the holder is made and the pack loaded on the
## main thread (pack.gd `load_pack`, scenery "plot"), as `jobs.attach` -> `world._rebuild` -> `_spawn_plot` does.
##   <godot> --headless --path engine -s res://kernel/world/arrival_probe.gd -- <abs pack dir> [<abs pack dir> ...]
## One line per pack: `ARRIVAL {json}` with
##   prepare_ms   worker time (scripts, layouts built ahead)
##   main_ms      the whole main-thread half (holder, load_pack, laws)
##   setup_ms     in it: the pack's `_pack_setup`
##   laws_ms      in it: TLLaws.apply_tree
## (The split of `setup_ms` into rigs, parts and layout in TIERS.md, section P12, was taken with timers inside
## TLRigs.build, TLKit.build and TLKitLayout.build that were removed again: kit, rigs and style may not read a clock.)
##   nodes        nodes under the pack after the arrival
## Each pack is measured twice in one process (first arrival, then a second one: scripts compiled, style tables warm);
## both are printed (`n` 1 and 2).

const Jobs: GDScript = preload("res://kernel/world/jobs.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")
const PackScript: GDScript = preload("res://kernel/world/pack.gd")

var _dirs: Array = []
var _k: int = 0
var _n: int = 1
var _th: Thread = null
var _keys: Array = []
var _prep_ms: float = 0.0
var _done: bool = false
var _holders: Array = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		_dirs.append(Manifest.resolve_dir(a))


func _count(n: Node) -> int:
	var c: int = 1
	for ch: Node in n.get_children():
		c += _count(ch)
	return c


func _process(_d: float) -> bool:
	if _k >= _dirs.size():
		for h: Node in _holders:
			h.call("release_space")
		return true
	var dir: String = _dirs[_k]
	var m: Dictionary = Manifest.read(dir)["manifest"]
	if _th == null:
		_done = false
		_th = Thread.new()
		_th.start(func() -> void:
			var t: int = Time.get_ticks_usec()
			_keys = Jobs.prepare(dir, m, "plot")
			_prep_ms = float(Time.get_ticks_usec() - t) / 1000.0
			_done = true)
		return false
	if not _done:
		return false
	_th.wait_to_finish()
	_th = null
	var t0: int = Time.get_ticks_usec()
	var p: Node3D = PackScript.new()
	p.name = "P%d_%d" % [_k, _n]
	root.add_child(p)
	p.position = Vector3(400.0 * float(_k + 1), 0, 300.0 * float(_n))
	TLRigs._record_rigs(true)
	TLKit._record_parts(true)
	var ok: bool = p.call("load_pack", dir, {"mode": "smoke", "seed": 1, "frames": 60, "at": p.position, "scenery": "plot", "on_stage": false})
	var main_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	Jobs.remember_rigs(dir, TLRigs._record_rigs(false), TLKit._record_parts(false))
	for key: String in _keys:
		Jobs.drop_ahead(key)
	var lm: Dictionary = p.get("load_ms")
	var laws_ms: float = float(lm.get("laws", 0.0))
	var out: Dictionary = {"pack": dir.get_file(), "n": _n, "ok": ok, "prepare_ms": snappedf(_prep_ms, 0.1), "main_ms": snappedf(main_ms, 0.1),
		"laws_ms": snappedf(laws_ms, 0.1), "setup_ms": snappedf(float(lm.get("setup", 0.0)), 0.1),
		"script_ms": snappedf(float(lm.get("script", 0.0)) + float(lm.get("assets", 0.0)), 0.1), "nodes": _count(p)}
	print("ARRIVAL " + JSON.stringify(out))
	_holders.append(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	if _n == 1:
		_n = 2
	else:
		_n = 1
		_k += 1
	return false
