extends Node
## Bot (H11): a puck inside a goal volume counts however it got there. One drill a row; each row reads the change of
## the score (R when three goals ended the match):
##   carried in on the blade: b0 skates into the red net with the puck on his blade (D held): blue scores
##   own goal: b0 skates into his own (blue) net carrying: red scores
##   released there: the puck let go just inside the red goal line, rolling slowly: blue scores
##   lying there: the puck at rest inside the red net: blue scores
##   behind the net: b0 skates along the red end boards behind the net, the puck on his blade outside the volume: no goal
## ok: the five rows as stated.

var ctx
var s: Dictionary = {}
const ROWS: Array = [["carried in on the blade", "goal_carried", "blue", 1.0, 0.0], ["own goal, carried into his own net", "goal_own", "red", -1.0, 0.0],
	["released inside the goal line", "goal_released", "blue", 0.0, 0.0], ["lying at rest inside the net", "goal_lying", "blue", 0.0, 0.0],
	["on the blade behind the net", "behind_net", "", 0.0, 1.0]]
var row: int = 0
var t0: int = -1
var before: Dictionary = {}
var results: Array = []
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")
		return
	if str(s.get("level", "none")) != "none":
		ctx.input.tap(&"level_none")
		return
	if done:
		return
	if row >= ROWS.size():
		ctx.input.set_axis(&"left", &"right", 0.0)
		ctx.input.set_axis(&"up", &"down", 0.0)
		done = true
		return
	var r: Array = ROWS[row]
	if t0 < 0:
		if str(s["state"]) == "over":
			ctx.input.tap(&"restart")              # three goals end a match: R, as a person would, and the next row
			return
		if bool(s["frozen"]) or str(s["state"]) != "running":
			return                                   # wait out the pause after the last row's goal
		before = (s.get("scores", {}) as Dictionary).duplicate()
		ctx.input.tap(StringName("drill_" + str(r[1])))
		t0 = frame
		return
	var age: int = frame - t0
	ctx.input.set_axis(&"left", &"right", float(r[3]))
	ctx.input.set_axis(&"up", &"down", float(r[4]))
	var sc: Dictionary = s.get("scores", {})
	var goal_side: String = ""
	for side: String in ["blue", "red"]:
		if int(sc.get(side, 0)) > int(before.get(side, 0)):
			goal_side = side
	if goal_side != "" or age > 150:
		var holder: String = str(s["puck"].get("holder", ""))
		results.append({"row": str(r[0]), "want": str(r[2]), "got": goal_side, "frames": age, "ok": goal_side == str(r[2]), "puck": s["puck"]["pos"], "holder": holder})
		ctx.input.set_axis(&"left", &"right", 0.0)
		ctx.input.set_axis(&"up", &"down", 0.0)
		row += 1
		t0 = -1


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and results.size() == ROWS.size()
	var parts: Array = []
	for x: Dictionary in results:
		ok = ok and bool(x["ok"])
		parts.append("%s: %s after %d frames (wanted %s)%s" % [x["row"], ("goal " + str(x["got"])) if str(x["got"]) != "" else "no goal", int(x["frames"]),
			("goal " + str(x["want"])) if str(x["want"]) != "" else "no goal", "" if x["ok"] else " MISS"])
	return {"ok": ok, "summary": " | ".join(parts), "rows": results}
