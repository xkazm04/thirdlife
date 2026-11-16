extends Node
## Bot (H4): the stick follows the aim. A person's mouse is the aim (ctx.input.set_aim stands in for the cursor).
##   shoot x10: drill carry_alone; he skates east (D held) while the aim sits north of him; after 20 frames Space:
##     the puck must leave along the aim (angle error per try, from his position to the aim point)
##   pass x10: drill pass_two (mates north-east and south-east of him, both inside his facing's cone); the aim points
##     at one of them (alternating), Q: the pass must reach the one aimed at
##   dead zone: the aim on the figure itself: the stick keeps his facing, the shot leaves east
##   cleared: aim north 20 frames, then clear_aim and Space on the same frame: the shot leaves along his facing
## ok: every shot within 3 degrees of its aim, 9 of 10 passes to the aimed mate, dead zone and cleared within 1 degree.

var ctx
var s: Dictionary = {}
var tests: Array = []                  # [kind, index]
var t: int = 0
var phase: String = "start"
var t0: int = 0
var shot_at: int = -1
var want: Vector3 = Vector3.ZERO
var target_mate: String = ""
var shot_err: Array = []
var pass_hits: int = 0
var pass_log: Array = []
var dead_err: float = -1.0
var clear_err: float = -1.0
var notes: Array = []
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c
	for i: int in 10:
		tests.append(["shoot", i])
	for i: int in 10:
		tests.append(["pass", i])
	tests.append(["dead", 0])
	tests.append(["clear", 0])


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _sk(id: String) -> Dictionary:
	for k: Dictionary in s["skaters"]:
		if k["id"] == id:
			return k
	return {}


func _p3(id: String) -> Vector3:
	var p: Vector2 = _v(_sk(id)["pos"])
	return Vector3(p.x, 0.0, p.y)


func _deg(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z))) if a.length() > 0.01 and b.length() > 0.01 else 999.0


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")
		return
	if str(s.get("level", "none")) != "none":
		ctx.input.tap(&"level_none")      # H6: this bot measures against the opponents of data/ai.json; the default level is rookie
		return
	if done:
		return
	if t >= tests.size():
		ctx.input.clear_aim(&"aim")
		ctx.input.set_axis(&"left", &"right", 0.0)
		done = true
		return
	var kind: String = str(tests[t][0])
	var idx: int = int(tests[t][1])
	if phase == "start":
		ctx.input.clear_aim(&"aim")
		ctx.input.set_axis(&"left", &"right", 0.0)
		ctx.input.tap(StringName("drill_" + ("pass_two" if kind == "pass" else "carry_alone")))
		t0 = frame
		shot_at = -1
		phase = "run"
		return
	var age: int = frame - t0
	if age < 2:
		return
	var me: Vector3 = _p3("b0")
	var face: Vector2 = _v(_sk("b0")["facing"])
	match kind:
		"shoot":
			ctx.input.set_axis(&"left", &"right", 1.0)                      # skating east
			want = me + Vector3((idx - 5) * 0.6, 0.0, -8.0)                # the aim sits north, a little either side
			if shot_at < 0:
				ctx.input.set_aim(&"aim", want)
			if age == 22:
				ctx.input.tap(&"shoot")
				shot_at = frame
				if idx == 0:
					notes.append("shot 0: he skates at %.2f m/s, facing (%.2f,%.2f)" % [float(_sk("b0")["speed"]), face.x, face.y])
			if shot_at >= 0 and frame - shot_at == 3:
				var pv: Vector2 = _v(s["puck"]["vel"])
				var e: float = absf(_deg(want - me, Vector3(pv.x, 0, pv.y)))
				shot_err.append(snappedf(e, 0.01))
				_next()
		"pass":
			target_mate = "b1" if idx % 2 == 0 else "b2"
			if shot_at < 0:
				ctx.input.set_aim(&"aim", _p3(target_mate))
			if age == 20:
				ctx.input.tap(&"pass")
				shot_at = frame
			if shot_at >= 0:
				var h: String = str(s["puck"].get("holder", ""))
				if (h != "" and h != "b0") or frame - shot_at > 150:
					if h == target_mate:
						pass_hits += 1
					pass_log.append("%s->%s" % [target_mate, h if h != "" else "none"])
					_next()
		"dead":
			if age < 14:
				ctx.input.set_aim(&"aim", me)                                 # the cursor on the figure
			if age == 12:
				var st: Array = s.get("stick", [])
				notes.append("dead zone: stick %s facing (%.3f,%.3f)" % [str(st), face.x, face.y])
			if age == 14:
				ctx.input.tap(&"shoot")
				shot_at = frame
			if shot_at >= 0 and frame - shot_at == 3:
				var pv2: Vector2 = _v(s["puck"]["vel"])
				dead_err = absf(_deg(Vector3(face.x, 0, face.y), Vector3(pv2.x, 0, pv2.y)))
				_next()
		"clear":
			if age < 22:
				ctx.input.set_aim(&"aim", me + Vector3(0, 0, -8))
			if age == 21:
				notes.append("before clear: stick %s" % str(s.get("stick", [])))
			if age == 22:
				ctx.input.clear_aim(&"aim")
				ctx.input.tap(&"shoot")
				shot_at = frame
			if shot_at >= 0 and frame - shot_at == 3:
				var pv3: Vector2 = _v(s["puck"]["vel"])
				clear_err = absf(_deg(Vector3(face.x, 0, face.y), Vector3(pv3.x, 0, pv3.y)))
				notes.append("after clear: stick in state %s" % str(s.has("stick")))
				_next()
	if age > 400:
		notes.append("%s %d timed out" % [kind, idx])
		_next()


func _next() -> void:
	t += 1
	phase = "start"


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var worst: float = 0.0
	var sum: float = 0.0
	for e in shot_err:
		worst = maxf(worst, float(e))
		sum += float(e)
	var ok: bool = done and shot_err.size() == 10 and worst <= 3.0 and pass_hits >= 9 and dead_err >= 0.0 and dead_err <= 1.0 \
		and clear_err >= 0.0 and clear_err <= 1.0
	return {"ok": ok, "summary": "shots along the aim: errors %s deg (mean %.2f, worst %.2f); passes to the aimed mate %d of %d (%s); dead zone error %.2f deg; cleared error %.2f deg; %s" % [
		str(shot_err), sum / maxf(1.0, shot_err.size()), worst, pass_hits, pass_log.size(), " ".join(pass_log), dead_err, clear_err, " | ".join(notes)],
		"shot_err": shot_err, "passes": pass_hits}
