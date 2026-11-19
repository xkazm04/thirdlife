extends SceneTree
## Lane walker round 2 (night of 19 Nov 2026), hunt2 B4: a visit replayed from a Windows path (backslashes) must find
## the game's stage recording beside its record, as a forward-slash path does. Records a 75-frame visit with one stage
## (seed_drive, gas held from frame 4), then sets up two replays of it, forward-slash and backslash, and checks that both
## found the stage feed and that each replays the 71 gas ticks. Hashes are not compared here: the hunt2 repro found
## that a third in-process load of the pack can hash differently whatever the path (reported apart).
## Prints `REPLAYCASE input_path ok|fail ...`. Run: godot --headless --fixed-fps 60 --path engine --script res://kernel/runner/walker_replay_case.gd

const Visit = preload("res://kernel/runner/visit.gd")
const Pack = preload("res://kernel/world/pack.gd")
const World = preload("res://kernel/world/world.gd")


class WalkView extends Node:
	var world: Node
	var visitor: Node3D
	var stage: int = 0


class Walker extends Node3D:
	var feet: Vector3 = Vector3.ZERO
	var look_yaw: float = 0.0
	var look_pitch: float = 0.0
	var space: RefCounted
	var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


## One visit of 75 frames: [gas ticks, stage feeds found] (feeds -1 when recording).
func _trial(path: String, writing: bool) -> Array:
	var v: WalkView = WalkView.new()
	var w: Node = World.new()
	v.world = w
	v.visitor = Walker.new()
	v.add_child(v.visitor)
	w.set("plot_defs", [{"id": "road"}])
	w.set("walk", {"name": "village"})
	w.set("walk_ticks", 75)
	var pack: Node = Pack.new()
	root.add_child(pack)
	if not bool(pack.call("load_pack", "res://seeds/seed_drive", {"seed": 1, "frames": 75, "own_space": true, "scenery": "plot"})):
		return []
	w.set("packs", [pack])
	var visit: Node = Visit.new()
	if not str(visit.call("setup", v, {"record": path} if writing else {"input": path})).is_empty():
		return []
	var feeds: int = -1 if writing else (visit.get("_stage_feeds") as Dictionary).size()
	visit.call("stage", -1, 0, [pack], [], [])
	var gas: int = 0
	for t: int in 75:
		await physics_frame
		w.set("tick", t)
		var ctx: Object = pack.get("ctx")
		if writing and t == 4:
			(ctx.get("input") as Object).call("press", &"gas")
		visit.call("sample", t)
		pack.call("tick", t)
		gas += int(bool((ctx.get("input") as Object).call("pressed", &"gas")))
	await physics_frame
	visit.call("finish")
	visit.free()
	pack.call("unload")
	pack.free()
	v.free()
	w.free()
	return [gas, feeds]


func _run() -> void:
	var dir: String = OS.get_environment("TL_REPLAYCASE_DIR")
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	var path: String = dir.replace("\\", "/").path_join("walker_replay_case.json")
	var stage_file: String = path.trim_suffix(".json") + ".road.1.json"
	var rec: Array = await _trial(path, true)
	if rec.size() != 2 or not FileAccess.file_exists(stage_file):
		print("REPLAYCASE input_path fail could not record (%s, stage file %s)" % [str(rec), str(FileAccess.file_exists(stage_file))])
		quit(1)
		return
	var fwd: Array = await _trial(path, false)
	var native: Array = await _trial(path.replace("/", "\\"), false)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(stage_file)
	var ok: bool = fwd.size() == 2 and native.size() == 2 and int(fwd[1]) == 1 and int(native[1]) == 1 \
		and int(fwd[0]) == int(rec[0]) and int(native[0]) == int(rec[0])
	print("REPLAYCASE input_path %s recorded gas %d; forward-slash feeds %s gas %s; backslash feeds %s gas %s" % ["ok" if ok else "fail", int(rec[0]),
		str(fwd[1]) if fwd.size() == 2 else "?", str(fwd[0]) if fwd.size() == 2 else "?", str(native[1]) if native.size() == 2 else "?",
		str(native[0]) if native.size() == 2 else "?"])
	quit(0 if ok else 1)
