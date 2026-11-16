extends Node
## Bot (H3): every mode plays to an end with bots on both sides. For each mode it presses mode_<id> (a declared
## action with no key: the match is rebuilt in that mode), switches the autopilot on and waits for the rules to say
## over, at most CAP frames a mode. ok: every mode ended, none inside 300 frames, none over the cap.

var ctx
var s: Dictionary = {}
const MODES: Array = ["base", "outnumbered", "sudden_death", "pond", "big_ice"]
const CAP: int = 7000
var i: int = 0
var phase: String = "start"
var t0: int = 0
var results: Array = []
var done: bool = false
var pilot_on: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("level", "none")) != "none":
		ctx.input.tap(&"level_none")      # H6: this bot measures against the opponents of data/ai.json; the default level is rookie
		return
	if done:
		return
	if not pilot_on:
		ctx.input.tap(&"autopilot")
		pilot_on = true
		return
	if i >= MODES.size():
		done = true
		return
	var mid: String = str(MODES[i])
	if phase == "start":
		ctx.input.tap(StringName("mode_" + mid))
		t0 = frame
		phase = "run"
		return
	var age: int = frame - t0
	if age < 2:
		return
	if str(s["mode"]) != mid:
		results.append({"mode": mid, "ok": false, "why": "the mode did not switch (state says %s)" % str(s["mode"])})
		_next()
		return
	if s["state"] == "over" or age >= CAP:
		var sc: Dictionary = s.get("scores", {})
		var ended: bool = s["state"] == "over"
		var n: int = (s["skaters"] as Array).size()
		results.append({"mode": mid, "ok": ended and age > 300, "frames": age, "ended": ended, "winner": str(s.get("winner", "")),
			"reason": str(s.get("reason", "")), "score": "%d:%d" % [int(sc.get("blue", 0)), int(sc.get("red", 0))], "period": int(s.get("period", 0)), "skaters": n,
			"hits": int((s["hits"]["given"]["blue"] as Dictionary).values().reduce(func(a, b): return a + b, 0)) + int((s["hits"]["given"]["red"] as Dictionary).values().reduce(func(a, b): return a + b, 0))})
		_next()


func _next() -> void:
	i += 1
	phase = "start"


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and results.size() == MODES.size()
	var parts: Array = []
	for r: Dictionary in results:
		ok = ok and bool(r["ok"])
		if r.has("why"):
			parts.append("%s: FAILED %s" % [r["mode"], r["why"]])
		else:
			parts.append("%s: %s %s in %d frames (winner %s, reason %s, period %d, %d skaters, %d hits)%s" % [r["mode"], "ended" if r["ended"] else "NOT ENDED", r["score"], int(r["frames"]),
				r["winner"] if r["winner"] != "" else "-", r["reason"], int(r["period"]), int(r["skaters"]), int(r["hits"]), "" if r["ok"] else " MISS"])
	return {"ok": ok, "summary": " | ".join(parts), "modes": results}
