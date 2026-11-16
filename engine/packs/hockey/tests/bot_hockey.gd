extends Node
## Bot: plays blue b0 through ctx.input only. It gets behind the puck (far side from the red goal), dribbles
## toward the goal around the red skaters, and shoots at the goal mouth when within ~12 m and lined up.
## ok: the rules say over, blue won 3, the bot took at least 3 shots and the HUD result reads WIN.

var ctx
var s: Dictionary = {}
var done: bool = false
var trace: Array = []


func _bot_setup(c) -> void:
	ctx = c


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _bot_tick(frame: int) -> void:
	var _frame: int = frame
	s = ctx.pack_state()
	done = s["state"] == "over"
	if done or bool(s["frozen"]):
		ctx.input.set_axis(&"left", &"right", 0.0)
		ctx.input.set_axis(&"up", &"down", 0.0)
		return
	var me: Dictionary = {}
	var others: Array = []
	for k: Dictionary in s["skaters"]:
		if k["id"] == "b0":
			me = k
		else:
			others.append(_v(k["pos"]))
	var pos: Vector2 = _v(me["pos"])
	var face: Vector2 = _v(me["facing"]).normalized()
	var puck: Vector2 = _v(s["puck"]["pos"])
	var goal: Vector2 = Vector2(26.0, 0.0)
	# aim at the goal side that is farther from the nearest red skater
	var aim: Vector2 = goal
	var dgoal: float = (goal - puck).length()
	var dirg: Vector2 = (aim - puck).normalized()
	# detour around a red skater standing in the lane puck -> goal
	for o: Vector2 in others:
		if o.x < 20.0 and o.x > puck.x - 0.5 and o.x < puck.x + 8.0:
			var rel: Vector2 = o - puck
			var along: float = rel.dot(dirg)
			var side: float = rel.cross(dirg)
			if along > 0.0 and absf(side) < 2.2:
				var sgn: float = 1.0 if puck.y - o.y >= 0.0 else -1.0
				aim = Vector2(o.x + 3.0, o.y + sgn * 3.5)
				dirg = (aim - puck).normalized()
	if absf(puck.y) > 13.4:
		dirg = Vector2(1.0, -signf(puck.y) * 0.7).normalized()   # pinned on a board: peel it off the wall
	if puck.x < -24.0:
		dirg = Vector2(1.0, -puck.y * 0.15).normalized()         # behind own goal line: bring it out to the middle
	var to_puck: Vector2 = puck - pos
	if _frame % 240 == 0 and trace.size() < 40:
		trace.append("%d me(%.0f,%.0f) f(%.1f,%.1f) pk(%.0f,%.0f) aim(%.0f,%.0f)" % [_frame, pos.x, pos.y, face.x, face.y, puck.x, puck.y, aim.x, aim.y])
	var behind: Vector2 = puck - dirg * 1.2
	var want: Vector2
	var lateral: float = to_puck.cross(dirg)
	if to_puck.dot(dirg) > 0.0 and absf(lateral) < 1.3:
		want = puck + dirg * 3.0 - pos          # lined up behind it: push through
	else:
		want = behind - pos
		# if in front of the puck, swing wide first
		if to_puck.dot(dirg) < 0.0 and to_puck.length() < 4.0:
			var perp: Vector2 = Vector2(-dirg.y, dirg.x) * (1.0 if lateral <= 0.0 else -1.0)
			want = behind + perp * 2.5 - pos
	# keep clear of red skaters
	for o: Vector2 in others:
		var d: Vector2 = pos - o
		if d.length() < 1.2 and d.length() > 0.01:
			want += d.normalized() * (1.2 - d.length()) * 3.0
	var dir: Vector2 = want.normalized() if want.length() > 0.05 else Vector2.ZERO
	ctx.input.set_axis(&"left", &"right", dir.x)
	ctx.input.set_axis(&"up", &"down", dir.y)
	# shoot: puck close and in front, goal close enough, facing the goal mouth, clear lane
	if bool(s["shoot_ready"]) and dgoal < 40.0 and face.x > 0.3 and face.dot((goal - puck).normalized()) > 0.97:
		var zg: float = puck.y + face.y / face.x * (26.0 - puck.x)
		var clear: bool = true
		for o: Vector2 in others:
			var rel2: Vector2 = o - puck
			if rel2.dot(face) > 0.0 and absf(rel2.cross(face)) < 1.0 and o.x < 25.0:
				clear = false
		if absf(zg) < 2.5 and clear:
			ctx.input.tap(&"shoot")


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var tally: Dictionary = s.get("scores", {})
	var mine: int = int(tally.get("blue", 0))
	var theirs: int = int(tally.get("red", 0))
	var shots: int = int(s.get("shots", {}).get("b0", 0))
	var ok: bool = done and str(s.get("winner", "")) == "blue" and mine == 3 and shots >= 3 and str(s.get("result", "")) == "WIN"
	var dbg: String = ""
	if s.has("skaters"):
		dbg = " TRACE " + " | ".join(trace)
	return {"ok": ok, "summary": "blue %d : %d red in %d frames, %d shots, result %s%s" % [mine, theirs, ctx.frame, shots, str(s.get("result", "")), dbg],
		"frames": ctx.frame, "shots": shots, "goals": mine}
