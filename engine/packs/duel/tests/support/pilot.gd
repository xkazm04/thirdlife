extends Node
## A player for the ladder: it watches the rival as a person does (its animation, its distance) and answers through a
## TLHand (perfect, sharp, regular, newcomer: the hand adds the person's reaction, tap length, lapses). It knows the
## rules a player learns in the first rounds: block or parry what is coming (a heavy is parried more often than a light;
## a bash and a red heavy are rolled), punish a blocked heavy with a light, a parried light with a heavy, bash a raised
## guard, hit a rival who missed, taunted or tapped his blade, back off when out of stamina.
## Its decisions use ctx.rng-free draws from its own seeded generator (the game's choices stay the hand's same).
var ctx
var hand: TLHand
var hand_profile: String = "regular"
var rung: int = 0                      ## the rival: 0 Wall, 1 Duelist, 2 Dancer, 3..5 champions
var matches: int = 1                   ## matches to play
var skill: Dictionary = {"parry": 0.35, "punish": 0.9, "bash_guard": 0.7, "roll_unblockable": 0.85}
var rng := RandomNumberGenerator.new()
var decided: int = -1
var block_until: int = -1
var parry_at: int = -1
var roll_at: int = -1
var started: bool = false
var done: bool = false
var frame_now: int = 0
var plan: Array = []                   ## [frame, action, hold frames]
var punished_serial: int = -1
var last_attack: int = -100
var strafe: float = 1.0
var results: Array = []
var acted: int = 0
var moments: Dictionary = {}           ## N4's looks: contact kind -> the frames it happened (read from pack_state, no hash input)
var kinds_seen: Dictionary = {}
var checklist: bool = false            ## also hold the plays-twice items this bot can measure (9, 11, contacts both-change)


func _bot_setup(c) -> void:
	ctx = c
	if hand_profile != "idle":
		hand = TLHand.create(ctx, hand_profile)
	rng.seed = int(ctx.seed) * 7919 + rung * 31 + 5


func _bot_tick(frame: int) -> void:
	frame_now = frame
	var s: Dictionary = ctx.pack_state()
	_moments(s, frame)
	if not started:
		if frame == 2:
			ctx.input.tap(StringName("rung_%d" % rung))
			started = true
		return
	if s["phase"] == "match_end":
		if results.size() < int(s["matches"]):
			results.append(str(s["winner"]))
		if results.size() >= matches:
			done = true
		elif hand != null and int(s["phase_t"]) == 30:
			ctx.input.tap(&"restart")
		_idle()
		return
	if hand == null:
		return
	if s["phase"] != "fight":
		_idle()
		hand.tick()
		return
	_play(s)
	hand.tick()


func _idle() -> void:
	if hand != null:
		hand.steer(&"left", &"right", &"up", &"down", Vector2.ZERO)
		hand.release(&"block")


func _play(s: Dictionary) -> void:
	var me: Dictionary = s["you"]
	var rv: Dictionary = s["rival"]
	var dx: float = float(rv["x"]) - float(me["x"])
	var dz: float = float(rv["z"]) - float(me["z"])
	var d: float = Vector2(dx, dz).length()
	var f: int = frame_now
	# scheduled presses
	for i in range(plan.size() - 1, -1, -1):
		var p: Array = plan[i]
		if int(p[0]) == f:
			hand.tap(StringName(p[1]), int(p[2]))
			acted += 1
			plan.remove_at(i)
	if f == parry_at:
		hand.tap(&"block", 6)
		acted += 1
	if f == roll_at:
		hand.tap(&"roll", 4)
		acted += 1
	var rst: String = str(rv["state"])
	var rmv: String = str(rv["mv"])
	# DEFEND: one decision per rival attack, on its wind-up
	if rst == "WINDUP" and int(rv["serial"]) != decided and rmv != "":
		decided = int(rv["serial"])
		var left: int = int(rv["windup"]) - int(rv["mf"])
		if rmv == "bash" or rmv == "charged":
			if rng.randf() < float(skill["roll_unblockable"]):
				roll_at = f + maxi(1, left - 10)
				plan = []
		elif rng.randf() < float(skill["parry"]) * (1.6 if rmv == "heavy" else 1.0):
			parry_at = f + maxi(1, left - 7)
			plan = []
		else:
			block_until = f + left + 12
			plan = []
	var blocking: bool = f < block_until
	if blocking:
		hand.press(&"block")
	elif f > parry_at + 6:
		hand.release(&"block")
	# move: hold the range, circle a little; back off when tired; roll needs a direction: away
	var want: float = 1.9
	if float(me["stamina"]) < 22.0 and not blocking:
		want = 4.0
	var fwd: float = clampf((d - want) * 1.2, -1.0, 1.0)
	if f % 140 == 0:
		strafe = -strafe
	var steer := Vector2(strafe * 0.5, -fwd)
	if f == roll_at or f == roll_at - 1:
		steer = Vector2(strafe, 0.6)                    # roll back and to the side
	hand.steer(&"left", &"right", &"up", &"down", steer if steer.length() > 0.25 else Vector2.ZERO)
	if blocking or f < parry_at + 8 or not plan.is_empty():
		return
	var mst: String = str(me["state"])
	if not (mst in ["IDLE", "BLOCK", "RECOVERY", "PARRY_OK", "BLOCKSTUN"]):
		return
	# PUNISH what it sees open
	if rst in ["REBOUND", "PARRIED", "GUARDBROKEN", "WALLSPLAT", "STAGGER", "BROKEN", "TAUNT", "TELL", "PARRY_WHIFF"] and d < 2.6:
		if punished_serial != int(rv["serial"]) and rng.randf() < float(skill["punish"]):
			punished_serial = int(rv["serial"])
			var left2: int = int(rv["len"]) - int(rv["t"])
			plan.append([f + 1, "heavy" if (rst == "BROKEN" or left2 > 40) else "light", 5])
			if rst in ["REBOUND", "GUARDBROKEN"] and left2 > 34:
				plan.append([f + 26, "light", 5])
		return
	if rst == "RECOVERY" and d < 2.4 and punished_serial != int(rv["serial"]) and int(rv["len"]) - int(rv["t"]) > 14:
		punished_serial = int(rv["serial"])
		plan.append([f + 1, "light", 5])
		return
	# PRESS when the rival is open (idle, walking) and it is in range; every 40 frames at most
	if rst in ["IDLE", "BLOCK"] and d < 2.3 and f - last_attack > 40 and float(me["stamina"]) > 25.0:
		last_attack = f
		var r: float = rng.randf()
		if rst == "BLOCK" and r < float(skill["bash_guard"]):
			plan.append([f + 1, "bash", 4])
			plan.append([f + 24, "light", 5])
		elif r < 0.55:
			plan.append([f + 1, "light", 5])
			if rng.randf() < 0.55:                       # a chain: the next light pressed in the cancel window
				plan.append([f + 31, "light", 5])
				if rng.randf() < 0.5:
					plan.append([f + 59, "light", 5])
		elif r < 0.85:
			plan.append([f + 1, "heavy", 6])
		else:
			plan.append([f + 1, "bash", 4])


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var s: Dictionary = ctx.pack_state()
	var won: bool = results.size() > 0 and results[0] == "you"
	var st: Dictionary = hand.stats() if hand != null else {"decisions": 0}
	var ok: bool = done and (hand == null or int(st.get("intents", 0)) > 0)
	var why: String = ""
	if checklist:
		if int(s["rival_passive_max"]) > 120:
			why += " item 9: the rival stood idle %d frames;" % int(s["rival_passive_max"])
		if int(s["rival_tells_min"]) < 12:
			why += " item 11: a rival wind-up of %d frames;" % int(s["rival_tells_min"])
		if int(s["failures"]) > 0:
			why += " %d contacts left a fighter unchanged;" % int(s["failures"])
		ok = ok and why == ""
	var mt: Dictionary = _metrics(s, st)
	var gf: int = 0
	var ga: int = 0
	for r: Array in s["rounds"]:
		gf += 1 if str(r[0]) == "you" else 0
		ga += 1 if str(r[0]) == "rival" else 0
	return {"ok": ok, "won": won, "checklist": why, "goals": gf, "against": ga, "frames": ctx.frame,
		"summary": ("CHECKLIST FAIL:" + why + " | " if why != "" else "") + "%s hand vs %s: %s, rounds %s; lead changes %d, rival never idle > %d f, shortest tell %d f, contacts %s, failures %d" % [
			hand_profile, s["rival_key"], "WON" if won else "lost", str(s["rounds"]), int(s["lead_changes"]), int(s["rival_passive_max"]),
			int(s["rival_tells_min"]), str(s["kinds"]), int(s["failures"])],
		"rounds": s["rounds"], "lead_changes": s["lead_changes"], "rival_passive_max": s["rival_passive_max"], "rival_passive_note": s["rival_passive_note"],
		"rival_tells_min": s["rival_tells_min"], "kinds": s["kinds"], "failures": s["failures"], "hand": st, "you_counts": s["you_counts"],
		"rival_counts": s["rival_counts"], "rival_mind": s["rival_mind"], "first_minute": s["first_minute"], "lessons": s["lessons"], "spacing": s["spacing"], "metrics": mt, "loss_causes": s["loss_causes"], "moments": moments.duplicate(true)}


## The tofu-stage figures (contracts/JOB.md, added 2026-11-22), named as the editor reads them; absent = not measured.
func _metrics(s: Dictionary, st: Dictionary) -> Dictionary:
	var feed: Dictionary = s["metrics_feed"]
	var rounds: Array = s["rounds"]
	var m: Dictionary = {"hand": hand_profile}
	if feed.has("feedback_f"):
		m["feedback_f"] = int(feed["feedback_f"])                       # press -> wind-up on screen (item 1)
	if feed.has("hit_max") and float(feed["hit_max"]) > 0.0:
		m["skill_spread"] = snappedf((float(feed["hit_max"]) - float(feed["hit_min"])) / float(feed["hit_max"]), 0.001)   # item 3
	var mine: Dictionary = {}
	for k: String in (s["you_counts"] as Dictionary):
		if k in ["light", "heavy", "bash", "parries", "blocks", "rolls", "dodges", "feints", "bashes_landed", "clashes"]:
			mine[k] = true
	m["skill_variants"] = mine.size()                                    # distinct verbs the player used to an end (item 3)
	m["idle_max_f"] = int(s["rival_passive_max"])                        # item 9
	m["tell_min_f"] = int(s["rival_tells_min"])                          # item 11
	m["tells"] = int(s["rival_attacks"])
	var frames: Array = s["rival_attack_frames"]
	var waves: int = 0
	var hot: bool = false
	if not frames.is_empty():
		var last: int = int(frames[-1])
		var w: int = int(frames[0])
		while w <= last:                                                  # 3 s windows: a wave is a run of busy windows after a quiet one
			var n: int = 0
			for f: Variant in frames:
				if int(f) >= w and int(f) < w + 180:
					n += 1
			if n >= 3 and not hot:
				waves += 1
				hot = true
			elif n <= 1:
				hot = false
			w += 180
	m["pressure_waves"] = waves                                          # item 12
	var changed: int = 0
	var close: int = 0
	for r: Array in rounds:
		if r.size() > 6:
			changed += 1 if int(r[5]) > 0 else 0
			close += 1 if float(r[6]) <= 0.35 else 0
	m["lead_change_share"] = snappedf(float(changed) / maxf(1.0, float(rounds.size())), 0.001)   # item 15
	m["close_rounds"] = close
	m["contact_types"] = (s["kinds"] as Dictionary).size()
	m["one_sided_contacts"] = int(s["failures"])
	var _u = st
	return m


## The moments a look can film (N4, 2026-11-22): the frame each named contact happened, from the pack's contact counts.
## Names: parried, blocked_heavy, clash, guard_break, wall_splat, hit_heavy, ko; at most 12 frames each.
func _moments(s: Dictionary, frame: int) -> void:
	var kinds: Dictionary = s["kinds"]
	for k: String in kinds:
		var n: int = int(kinds[k])
		if n > int(kinds_seen.get(k, 0)):
			var name: String = _moment_name(k)
			if name != "":
				var at: Array = moments.get(name, [])
				if at.size() < 12:
					at.append(frame)
				moments[name] = at
		kinds_seen[k] = n


static func _moment_name(k: String) -> String:
	if k.ends_with("_parried"):
		return "parried"
	if k.begins_with("heavy_block"):
		return "blocked_heavy"
	if k == "clash":
		return "clash"
	if k == "bash" or k.contains("guardbreak") or k.contains("posture_break"):
		return "guard_break"
	if k == "bash_wallsplat" or k == "wall_knock":
		return "wall_splat"
	if k.begins_with("hit_heavy") or k.begins_with("hit_charged"):
		return "hit_heavy"
	if k == "ko":
		return "ko"
	return ""
