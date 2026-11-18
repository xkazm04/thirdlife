extends SceneTree
## Bugfix-37 D2 and D10 (selftest 340-bugfix-runner.sh, cases runner.stage_record_rebuilt and runner.stage_handover).
## The holders are shaped as pack_life.gd makes them (the game's TLInput a child of the holder, in the tree) and the
## rebuild as world.gd `_rebuild` does it (the holder's children freed, then the holder), so this is the real path.
##   record    20 ticks on stage, one press at tick 12, then the game is rebuilt on stage: the first visit's record is
##             written with `length` 20 (the ticks sampled), not 1 (the sparse rows) nor 13 (the last row + 1).
##   handover  a bot holds `gas` (TLInput.press holds until release); the person takes the game on stage: from the
##             first tick on stage `gas` is not down while no key is. Control: the same press without a hand-over holds.
## Prints `BUGFIXRUNNER record ok|fail ...` and `BUGFIXRUNNER handover ok|fail ...`.

const Visit: GDScript = preload("res://kernel/runner/visit.gd")
const Session: GDScript = preload("res://kernel/runner/session.gd")


class World extends Node:
	var plot_defs: Array = [{"id": "court"}]


class Holder extends Node:
	var ctx: TLContext = TLContext.new()
	var manifest: Dictionary = {"id": "example.court"}
	var seed_value: int = 1
	var frames_target: int = 100
	var bot_off: bool = false


func _holder() -> Holder:
	var h: Holder = Holder.new()
	root.add_child(h)
	h.ctx.input = TLInput.new()
	h.ctx.input.name = "TLInput"
	h.add_child(h.ctx.input)
	h.ctx.input.declare(&"move", [KEY_M])
	h.ctx.input.declare(&"gas", [KEY_G])
	return h


func _initialize() -> void:
	_run()


## After the first frame: in `_initialize` the root is not in the tree yet, and the rebuild must leave a tree.
func _run() -> void:
	await process_frame
	var a: bool = _record()
	var b: bool = _handover()
	var ok: bool = a and b
	quit(0 if ok else 1)


func _record() -> bool:
	var world: World = World.new()
	root.add_child(world)
	var visit: Node = Visit.new()
	visit.set("world", world)
	visit.set("devices", true)
	var base: String = OS.get_user_data_dir().path_join("bugfix_runner_%d" % OS.get_process_id())
	visit.set("record_path", base + ".json")
	var h: Holder = _holder()
	visit.call("stage", -1, 0, [h], [], [])
	for t: int in 20:
		if t == 12:
			h.ctx.input.tap(&"move")
		h.ctx.input._sample()
	# the next round: world.gd `_rebuild` frees the holder's children in the tree, then the holder
	for c: Node in h.get_children():
		c.free()
	h.free()
	var next: Holder = _holder()
	visit.call("stage", 0, 0, [next], [], [])
	var path: String = base + ".court.1.json"
	var got: Dictionary = Session.call("read", path)
	var exists: bool = FileAccess.file_exists(path)
	var length: int = int((got.get("record", {}) as Dictionary).get("length", -1)) if bool(got.get("ok", false)) else -1
	var frames: Array = (got.get("record", {}) as Dictionary).get("frames", []) if bool(got.get("ok", false)) else []
	var why: String = ""
	if not exists:
		why = "no record written for the rebuilt visit (%s)" % str(got.get("error", ""))
	elif length != 20:
		why = "length %d, want 20 (the ticks sampled)" % length
	elif frames.size() != 1 or int(frames[0][0]) != 12:
		why = "frames %s, want [[12, move, 1]]" % str(frames)
	print("BUGFIXRUNNER record %s %s written=%s length=%d rows=%d" % ["ok" if why.is_empty() else "fail", why if not why.is_empty() else "-", exists, length, frames.size()])
	for f: String in [path, base + ".court.2.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	visit.set("record_path", "")            # the second visit (the rebuilt game) is not written
	visit.call("_close_stage_record", [next])
	next.queue_free()
	visit.free()
	world.queue_free()
	return why.is_empty()


func _handover() -> bool:
	var world: World = World.new()
	root.add_child(world)
	# control: a bot's press holds with nobody taking over
	var ch: Holder = _holder()
	ch.ctx.input.press(&"gas", 1.0)
	var held: int = 0
	for t: int in 30:
		ch.ctx.input._sample()
		if ch.ctx.input.pressed(&"gas"):
			held += 1
	# the hand-over: the bot held gas, then the person takes the game on stage
	var visit: Node = Visit.new()
	visit.set("world", world)
	visit.set("devices", true)
	var h: Holder = _holder()
	h.ctx.input.press(&"gas", 1.0)
	h.ctx.input._sample()
	var before: bool = h.ctx.input.pressed(&"gas")
	visit.call("stage", -1, 0, [h], [], [])
	var down: int = 0
	for t: int in 30:
		h.ctx.input._sample()
		if h.ctx.input.pressed(&"gas") and not Input.is_physical_key_pressed(KEY_G):
			down += 1
	var why: String = ""
	if held != 30:
		why = "control: the bot's press held on %d/30 ticks, want 30" % held
	elif not before:
		why = "the bot's press was not down before the hand-over"
	elif down > 0:
		why = "gas down on %d/30 ticks on stage with no key down" % down
	print("BUGFIXRUNNER handover %s %s control_held=%d/30 on_stage_down=%d/30 bot_off=%s" % ["ok" if why.is_empty() else "fail", why if not why.is_empty() else "-", held, down, h.get("bot_off")])
	visit.free()
	ch.queue_free()
	h.queue_free()
	world.queue_free()
	return why.is_empty()
