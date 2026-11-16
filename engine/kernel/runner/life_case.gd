extends SceneTree
## Selftest case `life.case` (tools/selftest.sh): one probe pack (kernel/examples/bad_life) driven twice in one
## process by the one lifecycle core (runner/pack_life.gd): first as the lone worker drives it (TLContext.current set
## once, phase hooks as the watchdog's begin/end, the pack at the origin), then as a world's holder drives it (the
## pack entered and left around every kernel call, load laps, the holder 100 m along x). Both must record the same
## call sequence and the same state hash after every one of FRAMES frames. Headless; prints one line
## `LIFECASE ok|fail <detail>`.
##   <godot> --headless --path engine --script res://kernel/runner/life_case.gd

const PackLife: GDScript = preload("res://kernel/runner/pack_life.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")
const FRAMES: int = 5
const PROBE: String = "res://kernel/examples/bad_life"

var _runs: Array = []           # per driver: {"calls": [...], "hashes": [...]}
var _life: RefCounted = null
var _holder: Node3D = null
var _world_style: bool = false
var _f: int = 0
var _calls: Array = []
var _hashes: Array = []
var _done: bool = false


func _begin(world_style: bool) -> bool:
	_world_style = world_style
	_f = 0
	_calls = []
	_hashes = []
	var dir: String = Manifest.resolve_dir(PROBE)
	var mres: Dictionary = Manifest.read(dir)
	if dir.is_empty() or not bool(mres["ok"]):
		return false
	var m: Dictionary = mres["manifest"]
	_holder = Node3D.new()
	_holder.name = "Holder" if world_style else "Worker"
	root.add_child(_holder)
	_life = PackLife.new()
	_life.set("on_begin", func(phase: String) -> void: _calls.append(phase.trim_prefix("_") + ((" %d" % _f) if phase.ends_with("_tick") else "")))
	_life.set("on_end", func(_phase: String) -> bool: return true)
	if world_style:
		_life.set("on_mark", func(key: String) -> void: _calls.append("lap " + key))
	var ctx: TLContext = _life.call("make_context", _holder, m, dir, 1, 3600, "bot")
	if world_style:
		ctx.origin = Vector3(100, 0, 0)
		_holder.position = ctx.origin
	else:
		TLContext.current = ctx
	_life.call("make_scene")
	_life.call("make_io", false)
	var before: TLContext = TLContext.enter(ctx) if world_style else null
	var ok: bool = bool(_life.call("load_entry")) and bool(_life.call("load_bot", str((m["tests"] as Array)[0])))
	if world_style:
		TLContext.leave(before)
	return ok


## Each drive loads in a physics frame and has its first tick in that same frame, before the physics step, as both
## drivers do; the second drive starts in the frame after the first one ended.
func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if _life == null:
		var world_style: bool = _runs.size() == 1
		if not _begin(world_style):
			_finish("the probe pack did not load as the %s loads it" % ("holder" if world_style else "worker"))
			return true
	var ctx: TLContext = _life.get("ctx")
	var before: TLContext = TLContext.enter(ctx) if _world_style else null
	if _f == 0:
		_life.call("start")
	_life.call("tick", _f, true, func(_frame: int) -> bool:
		_calls.append("sample")
		return true)
	_hashes.append(str(_life.call("state_hash")))
	if _world_style:
		TLContext.leave(before)
	_f += 1
	if _f < FRAMES:
		return false
	_runs.append({"calls": _calls.filter(func(c: String) -> bool: return not c.begins_with("lap ")), "laps": _calls.filter(func(c: String) -> bool: return c.begins_with("lap ")), "hashes": _hashes})
	_holder.free()
	_holder = null
	_life = null
	TLContext.current = null
	if _runs.size() == 1:
		return false
	_judge()
	return true


func _judge() -> void:
	var a: Dictionary = _runs[0]
	var b: Dictionary = _runs[1]
	var want: Array = ["pack_setup", "bot_setup"]
	for f: int in FRAMES:
		if f == 0:
			want.append("pack_start")
		want.append_array(["bot_tick %d" % f, "sample", "pack_tick %d" % f])
	var why: PackedStringArray = PackedStringArray()
	if a["calls"] != want:
		why.append("the worker drive called %s, expected %s" % [str(a["calls"]), str(want)])
	if b["calls"] != a["calls"]:
		why.append("the holder drive called %s, the worker drive %s" % [str(b["calls"]), str(a["calls"])])
	if (b["laps"] as Array).is_empty():
		why.append("the holder drive had no load laps")
	var distinct: Dictionary = {}
	for i: int in FRAMES:
		distinct[a["hashes"][i]] = true
		if str(a["hashes"][i]) != str(b["hashes"][i]) or str(a["hashes"][i]).length() != 64:
			why.append("frame %d: worker %s, holder %s" % [i, str(a["hashes"][i]).left(16), str(b["hashes"][i]).left(16)])
	if distinct.size() != FRAMES:
		why.append("the hash did not move every frame (%d distinct of %d)" % [distinct.size(), FRAMES])
	_finish("" if why.is_empty() else "; ".join(why), "%d calls, %d frames, last hash %s in both drives" % [(a["calls"] as Array).size(), FRAMES, str(a["hashes"][FRAMES - 1]).left(16)])


func _finish(problem: String, detail: String = "") -> void:
	_done = true
	print("LIFECASE " + ("ok " + detail if problem.is_empty() else "fail " + problem))
	quit(0 if problem.is_empty() else 1)
