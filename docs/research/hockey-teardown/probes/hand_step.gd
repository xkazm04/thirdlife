extends "rink_bot.gd"
## H1 hand (23 Nov): step responses of b0 through the pack's own input path (the keys' actions, ctx.input.set_axis/press, as
## bot_reverse_stop.gd and bot_sprint.gd do). Lives only in a COPY of the pack (.tl/h1/hockey/tests/), never in engine/.
## Scenes come from the JSON file in env H1_SCENES: [{"name", "drill", "frames", "segs": [[from, to, x, z, sprint], ...]}].
## Each scene taps its drill (a set start from data/drills.json), waits "wait" frames for the drill to settle, then holds the
## segments' keys (x: left/right axis, z: up/down axis, sprint: Shift) and logs one row per frame to H1_OUT/<name>.csv.
## The state read on frame f is the physics frame before it (rink_bot.gd); the row's age is the input's age, so age a's row
## shows what a keys held since age 0 did after a frames (age 1 = the first frame the keys acted).
## Round 2 (hits): optional "taps": [[age, action]] and "holds": [[from, to, action]] (check, cross, poke...), and the row's
## tail: r0, both men's state (d down, s stumbling), the last hit, b0's wind-up / swing / ready flags, the hit-stop left.

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
		me.facing[0], me.facing[1], pk.pos[0], pk.pos[1], pk.vel[0], pk.vel[1], str(pk.get("holder", "")), "1" if s.get("frozen", false) else "0", b.skate_speed, b.skate_accel, b.global_position.y, int(b.is_on_floor())] + _hit_tail()

func _flag(h: Dictionary, id: String) -> String:
	return "d%d" % int(h.down[id]) if h.get("down", {}).has(id) else ("s" if h.get("stumbling", {}).has(id) else "")

func _hit_tail() -> String:
	var r: Dictionary = _sk("r0")
	var h: Dictionary = s.get("hits", {})
	var lh: Dictionary = h.get("last", {})
	var fs: Dictionary = s.get("fun", {})
	return ",%d,%.4f,%.4f,%.4f,%s,%s,%d,%s,%s,%.3f,%.3f,%d,%d,%d,%d,%d,%d" % [ctx.frame, r.pos[0], r.pos[1], r.speed, _flag(h, "b0"), _flag(h, "r0"),
		int(lh.get("frame", -1)), str(lh.get("class", "")), str(lh.get("kind", "")), float(lh.get("ratio", 0)), float(lh.get("closing", 0)),
		int(h.get("windups", {}).has("b0")), int(h.get("swings", {}).has("b0")), int(s.get("check_ready", false)), int(s.get("poke_ready", false)),
		int(fs.get("stop_left", 0)), int(h.get("braced", false))]

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
		if not scenes[si].get("keep", false):
			ctx.input.tap(&"mode_base")      # a fresh match each scene ("keep": the scene follows the last one, as a test's rows do)
		phase = "drill"
		return
	if phase == "drill":
		ctx.input.tap(StringName("drill_" + str(scenes[si].drill)))
		age = -int(scenes[si].get("wait", 8))
		rows = PackedStringArray(["age,x,z,vx,vz,speed,fx,fz,px,pz,pvx,pvz,holder,frozen,cap,thrust,y,floor,f,rx,rz,rspeed,b0st,r0st,hit_f,hit_class,hit_kind,hit_ratio,hit_closing,windup,swing,check_ready,poke_ready,stop_left,braced"])
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
	for t: Array in sc.get("taps", []):
		if int(t[0]) == age:
			ctx.input.tap(StringName(str(t[1])))
	for hd: Array in sc.get("holds", []):
		if age == int(hd[0]):
			ctx.input.press(StringName(str(hd[2])))
		elif age == int(hd[1]):
			ctx.input.release(StringName(str(hd[2])))
	age += 1
	if age > int(sc.frames):
		var f := FileAccess.open(out_dir.path_join(str(sc.name) + ".csv"), FileAccess.WRITE)
		f.store_string("\n".join(rows) + "\n")
		f.close()
		summary.append(str(sc.name))
		phase = "next"

func _bot_result() -> Dictionary:
	return {"ok": done, "summary": "%d scenes written" % summary.size(), "scenes": summary}
