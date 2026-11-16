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
var trace: Array = []                 # every 600 frames: who has the puck and where it is
const LIMIT: int = 6000


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
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
	if frame % 600 == 0:
		var pk: Array = s["puck"]["pos"]
		trace.append("%d:%s(%.0f,%.0f)" % [frame, str(s["puck"].get("holder", "-")), float(pk[0]), float(pk[1])])
	done = frame >= LIMIT


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var pos: Dictionary = s.get("possession", {})
	var hs: Dictionary = s.get("hits", {})
	var ok: bool = first_goal.size() == 2 and bool(s.get("autopilot", false)) and out_of_rink == 0
	return {"ok": ok, "summary": "goals blue %d red %d in %d frames; skater-frames outside the rink %d; first goals %s; matches ended %s; this match %s; takes %s passes %s pokes %s shots %s; hits given %s by %s; frames down %s side down %s; trace %s" % [
		int(goals["blue"]), int(goals["red"]), ctx.frame, out_of_rink, str(first_goal), str(matches), str(s.get("scores", {})), str(pos.get("takes", {})), str(pos.get("passes", {})),
		str(pos.get("pokes", {})), str(s.get("shots", {})), str(hs.get("given", {})), str(hs.get("by", {})), str(hs.get("down_frames", {})), str(hs.get("side_down", {})), " ".join(trace)],
		"blue": int(goals["blue"]), "red": int(goals["red"]), "frames": ctx.frame, "hits": hs.get("given", {}), "side_down": hs.get("side_down", {})}
