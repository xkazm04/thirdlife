extends Node
## Bot: plays blue b0. It gets behind the puck (far side from the red goal), dribbles toward the goal around the red
## skaters, and shoots at the goal mouth when within reach and lined up.
## H5: its keys go through TLHand (hand_profile, "perfect" here: the same calls as before the port, so the same hash).
## A test that extends this file may set hand_profile (a person's hand), level (the opponents' level, chosen by the
## keyless action level_<id> before play) and use_pass (pass on Q when pressed and a mate is ahead and open).
## ok (require_win, the perfect hand; level rookie since H7): over, blue won (by score or at full time), at least 3 shots, the
## HUD reads WIN.
## ok (the hand copies and the ladder): played to the end and the hand acted; who won is a number in the result.

var hand_profile: String = "perfect"
var level: String = "rookie"           # H7: this bot must win; it plays the default level (the perfect hand wins 95 % there)
var require_win: bool = true           # false in the hand copies and the ladder: who won is a number there
var use_pass: bool = false
var ctx
var hand: TLHand
var s: Dictionary = {}
var done: bool = false
var trace: Array = []
var down_frames: int = 0               # frames b0 spent down after a hit
var max_period: int = 1
var passes_seen: int = 0
var passes_reached: int = 0
var pass_pending: bool = false


func _bot_setup(c) -> void:
	ctx = c
	hand = TLHand.create(ctx, hand_profile)


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _bot_tick(frame: int) -> void:
	var _frame: int = frame
	s = ctx.pack_state()
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")      # H3: this bot tests the base game; under another mode param it switches to it first
		return
	if frame == 0 or str(s.get("level", "none")) != level:
		ctx.input.tap(StringName("level_" + level))   # H5/H6: the test pins its level itself (the default is rookie since H6)
		return
	_measure()
	done = s["state"] == "over"
	if done or bool(s["frozen"]):
		hand.steer(&"left", &"right", &"up", &"down", Vector2.ZERO)
		hand.tick()
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
	hand.steer(&"left", &"right", &"up", &"down", dir)
	# shoot: puck close and in front, goal close enough, facing the goal mouth, clear lane
	if bool(s["shoot_ready"]) and dgoal < 40.0 and face.x > 0.3 and face.dot((goal - puck).normalized()) > 0.97:
		var zg: float = puck.y + face.y / face.x * (26.0 - puck.x)
		var clear: bool = true
		for o: Vector2 in others:
			var rel2: Vector2 = o - puck
			if rel2.dot(face) > 0.0 and absf(rel2.cross(face)) < 1.0 and o.x < 25.0:
				clear = false
		if absf(zg) < 2.5 and clear:
			hand.tap(&"shoot")
	elif use_pass and bool(s.get("pass_ready", false)):
		_maybe_pass(pos, face)
	hand.tick()


## A person's pass (ladder bots only): pressed by a red skater close in front, a blue mate ahead and open.
func _maybe_pass(pos: Vector2, face: Vector2) -> void:
	var pressed: bool = false
	var mate_ok: bool = false
	for k: Dictionary in s["skaters"]:
		var p: Vector2 = _v(k["pos"])
		if str(k["team"]) == "red" and (p - pos).length() < 2.5 and (p - pos).dot(face) > 0.0:
			pressed = true
		if str(k["team"]) == "blue" and k["id"] != "b0" and (p - pos).length() > 4.0 and (p - pos).normalized().dot(face) > 0.64:
			var open: bool = true
			for o: Dictionary in s["skaters"]:
				if str(o["team"]) == "red" and (_v(o["pos"]) - p).length() < 3.0:
					open = false
			mate_ok = mate_ok or open
	if pressed and mate_ok:
		hand.tap(&"pass")


func _measure() -> void:
	max_period = maxi(max_period, int(s.get("period", 1)))
	if (s["hits"].get("down", {}) as Dictionary).has("b0"):
		down_frames += 1
	var n: int = int(s["possession"]["passes"].get("b0", 0))
	if n > passes_seen:
		passes_seen = n
		pass_pending = true
	var h: String = str(s["puck"].get("holder", ""))
	if pass_pending and h != "" and h != "b0":
		pass_pending = false
		if str(s["skaters"].filter(func(k): return k["id"] == h)[0]["team"]) == "blue":
			passes_reached += 1


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var tally: Dictionary = s.get("scores", {})
	var mine: int = int(tally.get("blue", 0))
	var theirs: int = int(tally.get("red", 0))
	var shots: int = int(s.get("shots", {}).get("b0", 0))
	var won: bool = done and str(s.get("winner", "")) == "blue"
	# H8: a win, not "3 goals": since H3 a match can be won at the end of its periods with fewer (seed 18: 2:1 at full time)
	var ok: bool = done and str(s.get("winner", "")) == "blue" and mine > theirs and shots >= 3 and str(s.get("result", "")) == "WIN"
	if not require_win or not hand.is_perfect():
		ok = done and (hand.is_perfect() or int(hand.stats()["decisions"]) > 0)
	var dbg: String = ""
	if s.has("skaters"):
		dbg = " TRACE " + " | ".join(trace)
	return {"ok": ok, "summary": "blue %d : %d red in %d frames, %d shots, result %s%s" % [mine, theirs, ctx.frame, shots, str(s.get("result", "")), dbg],
		"frames": ctx.frame, "shots": shots, "goals": mine, "against": theirs, "won": won, "hand": hand.stats(), "level": level,
		"down_frames": down_frames, "period_reached": max_period, "passes": passes_seen, "passes_reached": passes_reached}
