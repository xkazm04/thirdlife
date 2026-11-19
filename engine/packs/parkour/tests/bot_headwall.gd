extends "bot_course.gd"
## Run into the wall, catch it, drop once, then mantle the same lip.
var blocked_ticks := 0
var held_ticks := 0
var dropped := false
var back_on_deck := false


func _skyline_inputs(frame: int, gate: int) -> void:
	if gate != 12 or back_on_deck:
		super._skyline_inputs(frame, gate)
		return
	if blocked_ticks < 75:
		hand.press(&"forward")
		hand.press(&"run")
		if state.motion == "ground" and absf(state.return_z - state.headwall) < 0.55:
			blocked_ticks += 1
		return
	if state.motion == "hang":
		hand.release(&"forward")
		held_ticks += 1
		if held_ticks == 18:
			hand.tap(&"slide")
			dropped = true
	elif dropped:
		hand.release(&"forward")
		back_on_deck = state.motion == "ground" and state.height < state.rim_y - 2.0
	else:
		hand.press(&"forward")
		if state.motion == "ground" and frame - last_leap > 30:
			hand.tap(&"jump")
			last_leap = frame


func _bot_result() -> Dictionary:
	var r := super._bot_result()
	r.ok = r.ok and blocked_ticks == 75 and held_ticks >= 18 and back_on_deck
	r.summary = "blocked %d grounded ticks, held %d ticks, dropped to approach %s, then: " % [blocked_ticks, held_ticks, back_on_deck] + r.summary
	return r
