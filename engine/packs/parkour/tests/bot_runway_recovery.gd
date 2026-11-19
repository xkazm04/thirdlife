extends "bot_course.gd"
## Carry S through a fall. W still works, and a fresh S can deliberately walk off the back of the runway.
var first_drop := false
var held_before_retry := 0
var retry_frame := -1
var runway_z := 0.0
var drift := 0.0
var forward_travel := 0.0
var fresh_back := false
var left_rear_edge := false
var lower_retry := false
var failure := ""

func _skyline_inputs(frame: int, gate: int) -> void:
	if gate != 13 or lower_retry:
		super._skyline_inputs(frame, gate)
		return
	var z := float(state.return_z)
	if state.falls == 0:
		if state.get("grip", 0) == 1 and not first_drop:
			hand.tap(&"slide")
			first_drop = true
		if first_drop:
			hand.press(&"run")
			if state.height < state.rim_y - 0.7:
				hand.set_axis(&"forward", &"back", 1.0)
				held_before_retry += 1
			else:
				hand.set_axis(&"back", &"forward", 1.0)
		else:
			super._skyline_inputs(frame, gate)
		return
	if state.falls == 2:
		lower_retry = fresh_back and left_rear_edge and absf(z - runway_z) < 0.12 and state.grips_passed == 0
		if not lower_retry:
			failure = "second retry did not recover the deliberate backward fall"
		hand.release_all()
		return
	if retry_frame < 0:
		retry_frame = frame
		runway_z = z
		if not ctx.input.pressed(&"back") or held_before_retry < 3 or absf(z - state.headwall - 0.6) > 0.12:
			failure = "did not carry Back into the runway placement"
	var elapsed := frame - retry_frame
	hand.press(&"run")
	if elapsed <= 45:
		drift = maxf(drift, absf(z - runway_z))
		if drift > 0.05:
			failure = "held Back moved the runner on placement"
		hand.press(&"back")
	elif elapsed <= 64:
		hand.press(&"back")
		hand.press(&"forward")
	elif elapsed <= 70:
		forward_travel = maxf(forward_travel, z - runway_z)
		hand.release_all()
	else:
		hand.release(&"forward")
		hand.press(&"back")
		fresh_back = fresh_back or z < runway_z - 0.25
		left_rear_edge = left_rear_edge or (z < state.headwall and state.height < state.rim_y - 0.5)
		if elapsed > 170:
			failure = "fresh Back did not return from the lower approach"

func _bot_done() -> bool:
	return not failure.is_empty() or state.get("state") == "over" or state.get("falls", 0) > 2

func _bot_result() -> Dictionary:
	return {"ok": failure.is_empty() and first_drop and lower_retry and forward_travel > 1.3 and state.reason == "laps" and state.falls == 2,
		"summary": "held Back %d ticks before placement, drift %.3f m; W with S held travelled %.2f m; fresh Back crossed rear edge %s, retry %s, finish %s. %s" % [
		held_before_retry, drift, forward_travel, left_rear_edge, lower_retry, state.reason, failure]}
