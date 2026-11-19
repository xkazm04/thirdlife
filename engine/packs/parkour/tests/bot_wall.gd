extends "bot_course.gd"
## Walk to the very edge and jump the wall. After the miss, use the same run-up at running speed.
var walk_jump := false
var walked_over_lip := false
var recovered := false
var walk_mps := 0.0


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if state.checkpoint == 9 and not recovered:
		if state.falls > 0:
			recovered = state.falls == 1 and absf(state.return_x - (state.beam_end - 0.6)) < 0.25
		else:
			hand.release(&"run")
			hand.press(&"forward")
			if state.return_x >= state.wall_lip - 0.10 and state.motion == "ground" and not walk_jump:
				walk_mps = state.speed
				hand.tap(&"jump")
				walk_jump = true
			if walk_jump and state.motion == "air" and state.return_x > state.wall_lip + 0.5:
				walked_over_lip = true
			hand.tick()
			return
	super._bot_tick(frame)


func _bot_done() -> bool:
	return state.get("state") == "over" or int(state.get("falls", 0)) > 1


func _bot_result() -> Dictionary:
	var ok: bool = walk_jump and walked_over_lip and walk_mps <= 4.6 and recovered and jumped_wall \
		and state.reason == "laps" and state.falls == 1
	return {"ok": ok, "summary": "wall walk-jump %.2f m/s, airborne beyond lip %s, checkpoint recovery %s, running jump %s, %d falls, finish %s" % [
		walk_mps, walked_over_lip, recovered, jumped_wall, state.falls, state.reason]}
