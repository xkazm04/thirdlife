extends "rink_bot.gd"
## Exercise a real Pro carrier, both extended keeper catches, and the first free physics step after a speed change.

const DRILLS := ["own_corner", "open_outlet", "red_backpass", "slow_mouth", "pinch_raw", "pinch_declared", "slow_post"]
var row := 0
var start := -1
var scores := {}
var passes := {}
var rows := []
var live_frames := 0
var carrier_frames := 0
var red_passes := 0
var unsafe_passes := 0
var safe_outlet := false
var incoming := false
var catch_distance := 0.0
var previous_distance := 0.0
var resting := true
var injected := 0.0
var guarded := 0.0

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if s.get("level", "") != "pro":
		ctx.input.tap(&"level_pro")
		return
	if start < 0:
		if frame < 10 or s.state != "running" or s.frozen:
			return
		scores = s.scores.duplicate()
		passes = s.possession.passes.duplicate()
		live_frames = 0
		carrier_frames = 0
		red_passes = 0
		unsafe_passes = 0
		incoming = false
		catch_distance = 0.0
		resting = true
		injected = 0.0
		guarded = 0.0
		ctx.input.tap(StringName("drill_" + str(DRILLS[row])))
		start = frame
		return
	var age := frame - start
	var last: Dictionary = s.possession.get("last", {})
	var holder: String = s.puck.get("holder", "")
	if s.get("drill", "") == DRILLS[row] and s.state == "running" and not s.frozen:
		live_frames += 1
	if row < 2:
		if holder == "r0" and s.get("roles_now", {}).has("r0"):
			carrier_frames += 1
		for id: String in ["r0", "r1", "r2", "gr"]:
			var count: int = s.possession.passes[id]
			if count == passes[id]:
				continue
			red_passes += count - int(passes[id])
			passes[id] = count
			if last.get("kind") != "pass" or last.get("by") != id or last.get("frame") != frame - 1:
				unsafe_passes += 1
			elif _toward_own_end():
				unsafe_passes += 1
			elif row == 1 and id == "r0" and last.get("to") == "r1":
				safe_outlet = true
		var duration := 120 if row == 0 else 20
		if age == duration:
			var active := carrier_frames > 0 if row == 0 else safe_outlet
			_finish(live_frames == duration and active and unsafe_passes == 0 and s.scores == scores,
				"%d live, %d carrier, %d red passes, %d unsafe" % [live_frames, carrier_frames, red_passes, unsafe_passes])
	elif row in [2, 3, 6]:
		var keeper := "gb" if row == 3 else "gr"
		var velocity := _v(s.puck.vel)
		if holder == "":
			if row == 2 and last.get("kind") == "pass" and last.get("by") == "r0" and s.possession.passes.r0 == passes.r0 + 1:
				incoming = incoming or absf(velocity.x - 18.0) < 0.03
			elif row == 3 and last.is_empty():
				incoming = incoming or absf(velocity.x + 8.0) < 0.03
			elif row == 6 and last.is_empty() and _v(s.puck.pos).x > float(s.goals.red[0]):
				incoming = incoming or velocity.distance_to(Vector2(-1.2, 7.9)) < 0.03
			previous_distance = _pos(keeper).distance_to(_v(s.puck.pos))
		elif holder == keeper and incoming and catch_distance == 0.0:
			catch_distance = previous_distance
		if age == 40:
			_finish(incoming and holder == keeper and catch_distance > 2.4 and catch_distance < 3.4 and s.scores == scores,
				"%s held by %s, incoming %s, last free distance %.3f m" % [DRILLS[row], holder, incoming, catch_distance])
	else:
		var speed := _v(s.puck.vel).length()
		resting = resting and holder == "" and last.is_empty()
		if age <= 4:
			resting = resting and speed == 0.0
		elif age == 5:
			injected = speed
		elif age == 6:
			guarded = speed
			# One more free step loses the same ice speed as the first one.
			var step_loss := 27.0 - injected
			var expected := (14.0 if row == 4 else injected) - step_loss
			_finish(resting and absf(injected - 27.0) < 0.03 and absf(guarded - expected) < 0.03,
				"%s %.3f -> %.3f m/s" % [DRILLS[row], injected, guarded])

## Extend the observed release line to red's goal and side boards as a missed feed would travel.
func _toward_own_end() -> bool:
	var from := _v(s.puck.pos)
	var v := _v(s.puck.vel)
	if v.x <= 0.0:
		return false
	var goal := _v(s.goals.red)
	if absf(from.y + v.y * (goal.x - from.x) / v.x - goal.y) < 3.5:
		return true
	if absf(v.y) < 0.001:
		return false
	var board := signf(v.y) * float(s.rink.half_width)
	return from.x + v.x * (board - from.y) / v.y > goal.x - 12.0

func _finish(ok: bool, detail: String) -> void:
	rows.append({"drill": DRILLS[row], "ok": ok, "detail": detail})
	row += 1
	start = -1
	done = row == DRILLS.size()

func _bot_result() -> Dictionary:
	return {"ok": done and rows.all(func(r): return r.ok), "summary": str(rows)}
