extends "bot_course.gd"
## Keep the capsule supported on the beam but the feet outside its stripe. Recover at pad two and centre the next jump.
var supported := false
var recovered := false
var previous_z := 0.0


func _aim_return(frame: int) -> void:
	if state.checkpoint not in [6, 7] or recovered:
		previous_z = state.return_z
		super._aim_return(frame)
		return
	var z := float(state.return_z)
	var ahead := z + 6.0 * (z - previous_z)
	previous_z = z
	hand.set_axis(&"left", &"right", 1.0 if ahead < 0.60 else -1.0 if ahead > 0.68 else 0.0)


func _return_inputs(frame: int) -> void:
	# From rest on pad two, use the far stripe for a full run-up on the recovery jump.
	if recovered and state.checkpoint == 7:
		hand.press(&"run")
		hand.press(&"forward")
		super._aim_return(frame)
		if state.return_x > state.pad_two + 0.45 and state.motion == "ground" and frame - last_leap > 27:
			hand.tap(&"jump")
			last_leap = frame
		return
	super._return_inputs(frame)


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	# Approach after the weight has swung clear, to isolate the missed landing.
	if frame < 36:
		hand.tick()
		return
	if state.checkpoint == 7:
		if state.motion == "ground" and state.return_x > state.beam_start + 0.6 and state.return_z > state.beam_width / 2:
			supported = true
		if state.falls == 1 and state.get("missed_landing_until", 0) > state.total_frames and state.return_x < state.pad_two:
			recovered = true
			hand.set_axis(&"left", &"right", 0)
	super._bot_tick(frame)


func _bot_done() -> bool:
	return state.get("state") == "over" or state.get("falls", 0) > 1


func _bot_result() -> Dictionary:
	return {"ok": supported and recovered and state.reason == "laps" and state.falls == 1,
		"summary": "skimming beam supported %s, missed landing returned to pad two %s, falls %s, finish %s" % [
		supported, recovered, state.falls, state.reason]}
