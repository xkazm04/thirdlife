extends "rink_bot.gd"
## H1 hand (23 Nov): step responses of b0 through the pack's own input path (the keys' actions, ctx.input.set_axis/press, as
## bot_reverse_stop.gd and bot_sprint.gd do). Lives only in a COPY of the pack (.tl/h1/hockey/tests/), never in engine/.
## Scenes come from the JSON file in env H1_SCENES: [{"name", "drill", "frames", "segs": [[from, to, x, z, sprint], ...]}].
## Each scene taps its drill (a set start from data/drills.json), waits "wait" frames for the drill to settle, then holds the
## segments' keys (x: left/right axis, z: up/down axis, sprint: Shift) and logs one row per frame to H1_OUT/<name>.csv.
## The state read on frame f is the physics frame before it (rink_bot.gd); the row's age is the input's age, so age a's row
## shows what a keys held since age 0 did after a frames (age 1 = the first frame the keys acted).

var scenes: Array = []
var si := -1
var age := 0
var phase := "classic"
var rows := PackedStringArray()
var out_dir := ""
var summary: Array = []

func _bot_setup(c) -> void:
	super._bot_setup(c)
	var f := FileAccess.open(OS.get_environment("H1_SCENES"), FileAccess.READ)
	scenes = JSON.parse_string(f.get_as_text())
	out_dir = OS.get_environment("H1_OUT")

func _keys(x: float, z: float, sprint: bool) -> void:
	ctx.input.set_axis(&"left", &"right", x)
	ctx.input.set_axis(&"up", &"down", z)
	if sprint:
		ctx.input.press(&"sprint")
	else:
		ctx.input.release(&"sprint")

func _row() -> String:
	var me: Dictionary = _me()
	var pk: Dictionary = s.puck
	var b = ctx._entry.skaters["b0"]   # debug read of the body (probe only): its cap, thrust, height, floor
	return "%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%s,%.3f,%.3f,%.3f,%d" % [age, me.pos[0], me.pos[1], me.vel[0], me.vel[1], me.speed,
		me.facing[0], me.facing[1], pk.pos[0], pk.pos[1], pk.vel[0], pk.vel[1], str(pk.get("holder", "")), "1" if s.get("frozen", false) else "0", b.skate_speed, b.skate_accel, b.global_position.y, int(b.is_on_floor())]

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if phase == "classic":
		if classic():
			phase = "next"
		return
	if phase == "next":
		si += 1
		if si >= scenes.size():
			done = true
			return
		_keys(0, 0, false)
		ctx.input.tap(&"mode_base")      # a fresh match each scene: the 36 s period clock never runs out inside one
		phase = "drill"
		return
	if phase == "drill":
		ctx.input.tap(StringName("drill_" + str(scenes[si].drill)))
		age = -int(scenes[si].get("wait", 8))
		rows = PackedStringArray(["age,x,z,vx,vz,speed,fx,fz,px,pz,pvx,pvz,holder,frozen,cap,thrust,y,floor"])
		phase = "run"
		return
	var sc: Dictionary = scenes[si]
	if age >= 0:
		rows.append(_row())
	var x := 0.0
	var z := 0.0
	var sp := false
	for seg: Array in sc.segs:
		if age >= int(seg[0]) and age < int(seg[1]):
			x = float(seg[2]); z = float(seg[3]); sp = bool(seg[4])
	_keys(x, z, sp)
	age += 1
	if age > int(sc.frames):
		var f := FileAccess.open(out_dir.path_join(str(sc.name) + ".csv"), FileAccess.WRITE)
		f.store_string("\n".join(rows) + "\n")
		f.close()
		summary.append(str(sc.name))
		phase = "next"

func _bot_result() -> Dictionary:
	return {"ok": done, "summary": "%d scenes written" % summary.size(), "scenes": summary}
