extends "bot_course.gd"
## On one clock, omit the takeoff, release at the bottom, then release red on the return stroke.
var trial := 0
var left_runway := false
var blue_ticks := 0
var red_ticks := 0
var bad_angle := 0.0
var red_omega := 0.0
var released := false
var airborne := false
var grips_seen := 0
var observations: Array[String] = []
var lowest := INF
var nearest := -INF
var failure := ""


func _skyline_inputs(frame: int, gate: int) -> void:
	if gate != 13 or trial >= 3:
		super._skyline_inputs(frame, gate)
		return
	if state.falls > trial:
		var recovered: bool = state.falls == trial + 1 and state.grips_passed == 0 and state.stage_splits.size() == 3 and absf(state.return_z - (state.headwall + 0.6)) < 0.3
		var in_pit: bool = lowest < state.rim_y - 1.0
		var passed := [left_runway and grips_seen == 0, released and airborne and grips_seen == 1,
			released and airborne and grips_seen == 2 and red_omega < 0.0]
		if not recovered or not in_pit or not passed[trial]:
			failure = "trial %d returned without its physical witness" % trial
			return
		var label: String = ["running off missed blue", "bottom release missed red", "return-stroke release missed ramp"][trial]
		observations.append("%s (furthest %.2f m, descended %.2f m below runway)" % [label, nearest, state.rim_y - lowest])
		lowest = INF
		nearest = -INF
		trial += 1
		released = false
		airborne = false
		grips_seen = 0
		super._skyline_inputs(frame, gate)
		return
	nearest = maxf(nearest, state.return_z)
	lowest = minf(lowest, state.height)
	var grip := int(state.get("grip", 0))
	grips_seen = maxi(grips_seen, grip)
	if trial == 0:
		hand.press(&"forward")
		hand.press(&"run")
		left_runway = left_runway or (state.motion == "air" and state.return_z > state.runway_end + 0.6)
		return
	if (trial == 1 and grip == 1) or (trial == 2 and grip == 2):
		hand.press(&"forward")
		hand.press(&"run")
		if trial == 1:
			blue_ticks += 1
		else:
			red_ticks += 1
		if not released and (trial == 1 or (state.bar_omega < -1.0 and state.bar_theta < 0.85)):
			bad_angle = state.bar_theta
			if trial == 2:
				red_omega = state.bar_omega
			hand.tap(&"jump")
			released = true
		return
	if released:
		airborne = airborne or state.motion == "air"
		hand.press(&"forward")
		hand.press(&"run")
		return
	super._skyline_inputs(frame, gate)


func _bot_done() -> bool:
	return not failure.is_empty() or state.get("state") == "over"


func _bot_result() -> Dictionary:
	var ok: bool = failure.is_empty() and trial == 3 and state.reason == "laps" and state.grips_passed == 2 and state.falls == 3
	return {"ok": ok, "summary": "%s; blue held %d ticks; red held %d ticks, wrong release %.2f rad / %.2f rad per second; clean transfer finished %s in %d ticks. %s" % [
		", ".join(observations), blue_ticks, red_ticks, bad_angle, red_omega, state.reason, state.total_frames, failure]}
