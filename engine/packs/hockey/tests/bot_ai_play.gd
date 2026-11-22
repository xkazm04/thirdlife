extends "rink_bot.gd"
## A full six-AI Pro match. In a second match switch to keys after 600 frames and skate b0 to the puck.
var phase := "match"
var started := false
var second_start := 0
var roles_seen := {}
var metrics = preload("metrics.gd").new()
var passes := {"blue": 0, "red": 0}
var complete := {"blue": 0, "red": 0}
var release_frame := -1
var receiver := ""
var previous_takes := {}
var side := ""
var called := ""

func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if s.mode != "base":
		ctx.input.tap(&"mode_base")
		return
	if s.get("level", "") != "pro":
		ctx.input.tap(&"level_pro")
		return
	if not started and s.state == "running":
		ctx.input.tap(&"autopilot")
		started = true
		return
	if phase == "match":
		if not s.autopilot:
			return
		metrics.observe(s)
		for role: String in s.get("roles_now", {}).values():
			roles_seen[role] = true
		_passes()
		if s.state == "over":
			phase = "restart"
			ctx.input.tap(&"restart")
		return
	if phase == "restart":
		if s.state == "running":
			second_start = frame
			if not s.autopilot:
				ctx.input.tap(&"autopilot")
			phase = "warmup"
		return
	if phase == "warmup":
		if frame - second_start >= 600 and s.autopilot and not s.frozen:
			ctx.input.tap(&"autopilot")
			phase = "human"
		return
	if s.autopilot:
		if not s.frozen:
			ctx.input.tap(&"autopilot")
		return
	var dir := (_v(s.puck.pos) - _pos("b0")).normalized()
	if s.puck.get("holder", "") == "b0":
		dir = (Vector2(21, 0) - _pos("b0")).normalized()
		var id: String = s.get("call", "")
		if id != "" and s.roles_now.get(id, "") == "F2" and not s.roles_now.has("b0"):
			called = id
	ctx.input.set_axis(&"left", &"right", dir.x)
	ctx.input.set_axis(&"up", &"down", dir.y)
	done = called != "" or s.state == "over"

func _passes() -> void:
	if s.frozen:
		receiver = ""
		return
	var pos: Dictionary = s.possession
	var last: Dictionary = pos.get("last", {})
	var holder: String = pos.get("carrier", "")
	# A one-touch pass or one-timer may have released before the next observed state.
	if receiver != "" and int(pos.takes[receiver]) > int(previous_takes.get(receiver, 0)):
		complete[side] += 1
		receiver = ""
	elif holder != "" or pos.puck_state != "pass":
		receiver = ""
	previous_takes = pos.takes.duplicate()
	if last.get("frame", -1) != release_frame:
		release_frame = last.get("frame", -1)
		receiver = ""
		if last.get("kind", "") == "pass" and _sk(last.by).role != "goalie":
			side = last.team
			receiver = last.get("to", "") if pos.puck_state == "pass" else ""
			passes[side] += 1


func _bot_result() -> Dictionary:
	var ok := called != ""
	for role: String in ["F1", "F2", "F3", "D1", "D2", "D3"]:
		ok = ok and roles_seen.has(role)
	for team: String in passes:
		ok = ok and passes[team] >= 4 and complete[team] >= 2 and metrics.shots[team] > 0
	ok = ok and metrics.slot_shots.blue + metrics.slot_shots.red > 0
	return {"ok": ok, "summary": "skater passes %s, intended completions %s, shots %s, slot %s, roles %s, human call %s" %
		[passes, complete, metrics.shots, metrics.slot_shots, roles_seen.keys(), called]}
