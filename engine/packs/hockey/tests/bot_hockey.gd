extends "rink_bot.gd"
## Bot: plays blue b0. It gets behind the puck (far side from the red goal), dribbles toward the goal around the red
## skaters, and shoots at the goal mouth when within reach and lined up.
## H5: its keys go through TLHand (hand_profile, "perfect" here: the same calls as before the port, so the same hash).
## A test that extends this file may set hand_profile (a person's hand), level (the opponents' level, chosen by the
## keyless action level_<id> before play) and use_pass (pass on Q when pressed and a mate is ahead and open).
## ok (require_win, the perfect hand; level rookie since H7): played to its result (the HUD reads WIN, LOSE or DRAW) and he
## took the puck at least once; who won is a number in the result (H9a: a must-win verdict held on 18 of 20 seeds).
## ok (the hand copies and the ladder): played to the end and the hand acted; who won is a number in the result.

var hand_profile: String = "perfect"
var level: String = "rookie"           # H7: this bot must win; it plays the default level (the perfect hand wins 95 % there)
var must_win: bool = false             # H10: the gate's verdict about the game: this cell must win (rookie, perfect hand)
var require_win: bool = true           # false in the hand copies and the ladder: who won is a number there
var use_pass: bool = false
var use_aim: bool = false              # H9: aim with the cursor through the hand (the ladder); bot_hockey stays key-only
var shoot_range: float = 16.0          # H9: a person's range: he shoots from inside it (the Director's ruling of 04:50)
var aim_tolerance_deg: float = 6.0     # H9: he presses when the game's stick points at his aim within this
var corner_z: float = 1.5              # L5: the side of the mouth he aims at, away from the goalie (was 1.2 before goalies)
var pass_target: Vector2 = Vector2.ZERO

var hand: TLHand

var trace: Array = []
var down_frames: int = 0               # frames b0 spent down after a hit
var max_period: int = 1
var passes_seen: int = 0
var passes_reached: int = 0
var pass_pending: bool = false
var metrics = preload("metrics.gd").new()   # N3 (22 Nov): the five bot metrics (HOCKEY-ARCADE 5.5), in the result

func ladder(division: String, profile: String) -> void:
	level = division
	hand_profile = profile
	use_aim = true
	use_pass = true
	require_win = false

func _bot_setup(c) -> void:
	super(c)
	hand = TLHand.create(ctx, "perfect" if hand_profile == "idle" else hand_profile)     # L5: idle presses nothing

func _bot_tick(frame: int) -> void:
	var _frame: int = frame
	s = ctx.pack_state()
	metrics.observe(s)
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")      # H3: this bot tests the base game; under another mode param it switches to it first
		return
	if frame == 0 or str(s.get("level", "none")) != level:
		ctx.input.tap(StringName("level_" + level))   # H5/H6: the test pins its level itself (the default is rookie since H6)
		return
	_measure()
	done = s["state"] == "over" and str(s.get("result", "")) != ""      # H9a: the result is written a tick after "over" at full time
	if hand_profile == "idle":
		return                               # L5: the idle hand: no key, no button, no cursor, the whole match
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
	if use_aim:
		_aim_play(pos, puck, others)
		hand.tick()
		return
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
		if _open_mate(pos, face) != Vector2.ZERO:
			hand.tap(&"pass")
	hand.tick()

## H9: the cursor's play. With the puck: the cursor on the goal mouth's open side (or on an open mate when pressed); he
## presses Space / Q (the left / right button's action) once the game's stick (state "stick", the aim's heading, turned
## at the stick's rate from where the hand's cursor really is) points at what he aims at, and only inside shoot_range.
## Without the puck: the cursor rests on the puck. The keys still skate him.
func _aim_play(pos: Vector2, puck: Vector2, others: Array) -> void:
	var has: bool = bool(s.get("pass_ready", false))
	if not has:
		hand.set_aim(&"aim", Vector3(puck.x, 0.0, puck.y))
		return
	var goal: Vector2 = Vector2(26.0, 0.0)
	var keeper_side: float = 0.0
	for o: Vector2 in others:
		if o.distance_to(goal) < 5.0:
			keeper_side += signf(o.y)
	var target: Vector2 = Vector2(26.0, -corner_z if keeper_side > 0.0 else corner_z)
	var want_pass: bool = false
	if use_pass:
		var face: Vector2 = _v(_me()["facing"]).normalized()
		var mate: Vector2 = _open_mate(pos, face)
		if mate != Vector2.ZERO:
			want_pass = true
			target = mate
	hand.set_aim(&"aim", Vector3(target.x, 0.0, target.y))
	if not s.has("stick"):
		return
	var stick: Vector2 = _v(s["stick"])
	var to: Vector2 = target - pos
	if to.length() < 0.5 or rad_to_deg(absf(stick.angle_to(to))) > aim_tolerance_deg:
		return
	if want_pass:
		hand.tap(&"pass")
	elif bool(s["shoot_ready"]) and puck.distance_to(goal) < shoot_range:
		hand.tap(&"shoot")

## An open blue mate ahead when a red skater presses him, or Vector2.ZERO.
func _open_mate(pos: Vector2, face: Vector2) -> Vector2:
	var pressed: bool = false
	var best: Vector2 = Vector2.ZERO
	for k: Dictionary in s["skaters"]:
		var p: Vector2 = _v(k["pos"])
		if str(k["team"]) == "red" and (p - pos).length() < 2.5 and (p - pos).dot(face) > 0.0:
			pressed = true
		if str(k["team"]) == "blue" and k["id"] != "b0" and (p - pos).length() > 4.0 and (p - pos).normalized().dot(face) > 0.64:
			var open: bool = true
			for o: Dictionary in s["skaters"]:
				if str(o["team"]) == "red" and (_v(o["pos"]) - p).length() < 3.0:
					open = false
			if open:
				best = p
	return best if pressed else Vector2.ZERO

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

func _bot_result() -> Dictionary:
	var tally: Dictionary = s.get("scores", {})
	var mine: int = int(tally.get("blue", 0))
	var theirs: int = int(tally.get("red", 0))
	var shots: int = int(s.get("shots", {}).get("b0", 0))
	var won: bool = done and str(s.get("winner", "")) == "blue"
	var took: int = int(s.get("possession", {}).get("takes", {}).get("b0", 0))
	var ok: bool = done and str(s.get("result", "")) in ["WIN", "LOSE", "DRAW"] and took >= 1
	if must_win:
		ok = done and str(s.get("winner", "")) == "blue" and str(s.get("result", "")) == "WIN"
	elif hand_profile == "idle":
		ok = done
	elif not require_win or not hand.is_perfect():
		ok = done and (hand.is_perfect() or int(hand.stats()["decisions"]) > 0)
	var dbg: String = ""
	if s.has("skaters"):
		dbg = " TRACE " + " | ".join(trace)
	return {"ok": ok, "summary": "blue %d : %d red in %d frames, %d shots, result %s%s" % [mine, theirs, ctx.frame, shots, str(s.get("result", "")), dbg],
		"frames": ctx.frame, "shots": shots, "goals": mine, "against": theirs, "won": won, "hand": hand.stats(), "taps_lost": int(hand.stats().get("taps_lost", 0)), "aim": use_aim, "level": level,
		"down_frames": down_frames, "period_reached": max_period, "passes": passes_seen, "passes_reached": passes_reached, "metrics": metrics.figures(hand_profile)}   # N3: named figures (HOCKEY-ARCADE 5.5, tofu names), raw counts under "raw"
