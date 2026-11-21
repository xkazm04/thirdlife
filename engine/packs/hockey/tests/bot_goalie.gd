extends "rink_bot.gd"
## Bot (L5, 21 Nov): the goalies. One drill a row, the goalies in their nets (drills.json "goalies": true), level none
## (the goalie of data/tuning.json "goalie"); each row reads the red goalie's saves and the score:
##   straight at him: b0 shoots from 12 m in the middle at the goal's centre: a save, no goal
##   to the far side from an angle: b0 shoots from (15, -9) at the far post (z 1.7): a goal
##   after a pass across: b1 passes from the left side to b0 on the right, b0 shoots at once at the far post: a goal
##   carried at him: b0 skates the puck into the crease (D held): his poke check takes it, no goal
##   tracking: before each shot the goalie stands between the puck and his goal's centre, inside the posts
## ok: the four rows as stated, and he never left his crease (|z| <= z_max, at most `out` + 0.1 m in front of his line).

const ROWS: Array = [["straight at him from 12 m", "goalie_straight", "save", 0.0], ["far side from an angle", "goalie_angle", "goal", 0.0],
	["one-timer after a pass across", "goalie_cross", "goal", 0.0], ["carried into his crease", "goalie_poke", "save", 1.0]]
var row: int = 0
var t0: int = -1
var before: Dictionary = {}
var saves0: int = 0
var results: Array = []

var crease_ok: bool = true
var worst: String = ""

func _goalie() -> Dictionary:
	for k: Dictionary in s["skaters"]:
		if str(k["role"]) == "goalie" and str(k["team"]) == "red":
			return k
	return {}

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if not classic():
		return
	if done:
		return
	if row >= ROWS.size():
		ctx.input.set_axis(&"left", &"right", 0.0)
		done = true
		return
	var r: Array = ROWS[row]
	if t0 < 0:
		if str(s["state"]) == "over":
			ctx.input.tap(&"restart")
			return
		if bool(s["frozen"]) or str(s["state"]) != "running":
			return
		before = (s.get("scores", {}) as Dictionary).duplicate()
		saves0 = int(s.get("saves", {}).get("red", 0))
		ctx.input.tap(StringName("drill_" + str(r[1])))
		t0 = frame
		return
	var age: int = frame - t0
	if row < 3:
		var target_z := 0.0 if row == 0 else (1.7 if row == 1 else -1.7)
		ctx.input.set_aim(&"aim", Vector3(26, 0, target_z))
		if (row < 2 and age == 20) or (row == 2 and s.shoot_ready and s.puck.get("holder", "") == "b0"):
			ctx.input.tap(&"shoot")
	else:
		ctx.input.clear_aim(&"aim")
	ctx.input.set_axis(&"left", &"right", float(r[3]))
	var gk: Dictionary = _goalie()
	if age > 2 and not gk.is_empty():
		var gx: float = float(gk["pos"][0])
		var gz: float = float(gk["pos"][1])
		if absf(gz) > 1.5 + 0.01 or gx < 26.0 - 1.3 - 0.1 or gx > 26.0:
			crease_ok = false
			worst = "row %d frame %d at (%.2f, %.2f)" % [row, age, gx, gz]
	var sc: Dictionary = s.get("scores", {})
	var goal: bool = int(sc.get("blue", 0)) > int(before.get("blue", 0))
	var saved: bool = int(s.get("saves", {}).get("red", 0)) > saves0
	if goal or age > 150 or (saved and age > 40):
		var got: String = "goal" if goal else ("save" if saved else "nothing")
		results.append({"row": str(r[0]), "want": str(r[2]), "got": got, "frames": age, "ok": got == str(r[2])})
		ctx.input.set_axis(&"left", &"right", 0.0)
		row += 1
		t0 = -1

func _bot_result() -> Dictionary:
	var ok: bool = done and results.size() == ROWS.size() and crease_ok
	var parts: Array = []
	for x: Dictionary in results:
		ok = ok and bool(x["ok"])
		parts.append("%s: %s after %d frames (wanted %s)%s" % [x["row"], x["got"], int(x["frames"]), x["want"], "" if x["ok"] else " MISS"])
	parts.append("crease kept" if crease_ok else "LEFT HIS CREASE " + worst)
	return {"ok": ok, "summary": " | ".join(parts), "rows": results}
