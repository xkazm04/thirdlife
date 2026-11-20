extends Node
## Bot (H1/H2): bot-only play. It switches the autopilot on (a declared action with no key: the brain plays b0 too)
## and watches 6,000 frames. When a match ends (first to the goal target) it presses R, as a person would, and the
## next match starts: goals are counted over the 6,000 frames, matches too. ok: both sides scored in the 6,000 frames.
## The summary carries possession and hit figures (knockdowns, frames a side had a man down) for the reviewer.

var ctx
var s: Dictionary = {}
var done: bool = false
var goals: Dictionary = {"blue": 0, "red": 0}
var first_goal: Dictionary = {}
var prev: Dictionary = {"blue": 0, "red": 0}
var matches: Array = []               # "b:r@frame" of each finished match
var restarting: bool = false
var out_of_rink: int = 0              # skater-frames outside the boards (the rink of the mode): must stay 0
var closest_at: String = ""
var crowd_sum: int = 0                # L5b: skaters within 4 m of the puck, summed over live frames
var crowd_frames: int = 0
var crowd4: int = 0                    # L5b: live frames with 4 or more skaters within 4 m of the puck
var closest: float = 1e9               # H7: the closest two skaters came (centre to centre), against two body radii
var trace: Array = []                 # every 600 frames: who has the puck and where it is
const LIMIT: int = 18000   # L5: was 6000; with goalies the weaker side (Classic red) first scored at up to 12267 frames on seeds 1..20
const AT_LEAST: int = 6000 # L5: it stops at 6000 frames as before when both sides have scored by then, else when they have


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("level", "none")) != "none":
		ctx.input.tap(&"level_none")      # H6: this bot measures against the opponents of data/ai.json; the default level is rookie
		return
	if frame == 1:
		ctx.input.tap(&"autopilot")
	var sc: Dictionary = s.get("scores", {})
	for side: String in ["blue", "red"]:
		var now: int = int(sc.get(side, 0))
		if now > int(prev[side]):
			goals[side] = int(goals[side]) + now - int(prev[side])
			if not first_goal.has(side):
				first_goal[side] = frame
		prev[side] = now
	if s["state"] == "over" and not restarting:
		matches.append("%d:%d@%d" % [int(sc.get("blue", 0)), int(sc.get("red", 0)), frame])
		ctx.input.tap(&"restart")
		restarting = true
	elif s["state"] != "over" and restarting:
		restarting = false
		prev = {"blue": 0, "red": 0}
	for k: Dictionary in s["skaters"]:
		if absf(float(k["pos"][0])) > float(s["rink"]["half_length"]) + 0.5 or absf(float(k["pos"][1])) > float(s["rink"]["half_width"]) + 0.5:
			out_of_rink += 1
	var sks: Array = s["skaters"]
	if not bool(s["frozen"]) and str(s["state"]) == "running":
		# L5b: the scrum, measured: skaters (goalies not counted) within 4 m of the puck, per live frame (a number, no verdict)
		var pk2: Vector2 = Vector2(float(s["puck"]["pos"][0]), float(s["puck"]["pos"][1]))
		var near: int = 0
		for k2: Dictionary in sks:
			if str(k2["role"]) != "goalie" and Vector2(float(k2["pos"][0]), float(k2["pos"][1])).distance_to(pk2) < 4.0:
				near += 1
		crowd_sum += near
		crowd_frames += 1
		if near >= 4:
			crowd4 += 1
	for i: int in sks.size():
		for j: int in range(i + 1, sks.size()):
			var a: Array = sks[i]["pos"]
			var c: Array = sks[j]["pos"]
			var dd: float = Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(c[0]), float(c[1])))
			if dd < closest:
				closest = dd
				closest_at = "%s-%s frame %d, speeds %.1f/%.1f, down %s" % [str(sks[i]["id"]), str(sks[j]["id"]), frame, float(sks[i]["speed"]), float(sks[j]["speed"]), str(s["hits"].get("down", {}).keys())]
	if frame % 600 == 0:
		var pk: Array = s["puck"]["pos"]
		trace.append("%d:%s(%.0f,%.0f)" % [frame, str(s["puck"].get("holder", "-")), float(pk[0]), float(pk[1])])
	done = frame >= LIMIT or (frame >= AT_LEAST and first_goal.size() == 2)


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var pos: Dictionary = s.get("possession", {})
	var hs: Dictionary = s.get("hits", {})
	var ok: bool = first_goal.size() == 2 and bool(s.get("autopilot", false)) and out_of_rink == 0
	var crowd: String = "crowd near the puck %.2f skaters, 4+ in %.1f %% of live frames; " % [float(crowd_sum) / maxf(1.0, crowd_frames), 100.0 * crowd4 / maxf(1.0, crowd_frames)]
	return {"ok": ok, "crowd": snappedf(float(crowd_sum) / maxf(1.0, crowd_frames), 0.01), "crowd4_pct": snappedf(100.0 * crowd4 / maxf(1.0, crowd_frames), 0.1), "summary": crowd + "goals blue %d red %d in %d frames; skater-frames outside the rink %d; closest two skaters %.3f m (two body radii %.3f m; %s); first goals %s; matches ended %s; this match %s; takes %s passes %s pokes %s shots %s; hits given %s by %s; frames down %s side down %s; trace %s" % [
		int(goals["blue"]), int(goals["red"]), ctx.frame, out_of_rink, closest, 2.0 * float(s.get("body_radius", 0.0)), closest_at, str(first_goal), str(matches), str(s.get("scores", {})), str(pos.get("takes", {})), str(pos.get("passes", {})),
		str(pos.get("pokes", {})), str(s.get("shots", {})), str(hs.get("given", {})), str(hs.get("by", {})), str(hs.get("down_frames", {})), str(hs.get("side_down", {})), " ".join(trace)],
		"blue": int(goals["blue"]), "red": int(goals["red"]), "frames": ctx.frame, "closest": closest, "hits": hs.get("given", {}), "side_down": hs.get("side_down", {})}
