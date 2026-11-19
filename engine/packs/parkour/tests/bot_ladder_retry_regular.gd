extends "support/run_hand.gd"
## The retry drill deliberately runs into the bar. The open course tries a landing slide first.
var force_retry := true
var last_jump := -60
var last_slide := -60
var blocked := false
var respawned := false
var slid_under := false
var retry_distance := 0.0


func _init() -> void:
	hand_profile = "regular"


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if state.checkpoint >= 4 or state.state == "over":
		if state.state != "over":
			_return_inputs(frame)
		hand.tick()
		return
	var at := float(state.station)
	hand.press(&"forward")
	hand.press(&"run")
	var lead := 1.95
	for edge: float in [state.first_lip, state.chain_lip]:
		if at >= edge - lead and at < edge and state.motion == "ground" and frame - last_jump > 30:
			hand.tap(&"jump")
			last_jump = frame
	if at > state.bar - 0.6 and at < state.bar and state.motion == "ground" and state.speed < 0.5:
		blocked = true
		if frame - last_slide > 30:
			hand.tap(&"slide")
			last_slide = frame
	if blocked and not respawned and state.checkpoint == 2 and at >= state.chain_land and at < state.bar - 2.5:
		respawned = true
		retry_distance = state.bar - at
	if not force_retry and not blocked and state.checkpoint == 2 and state.motion == "ground" and frame - last_slide > 30:
		hand.tap(&"slide")
		last_slide = frame
	# Build speed after the C retry so the slide is still active inside the beam.
	if respawned and at > state.bar - 3.0 and at < state.bar and frame - last_slide > 20:
		hand.tap(&"slide")
		last_slide = frame
	if (respawned or not force_retry) and state.motion == "slide" and at >= state.bar and at <= state.bar + state.bar_depth:
		slid_under = true
	hand.tick()


func _bot_done() -> bool:
	return state.get("state") == "over"


func _bot_result() -> Dictionary:
	var won: bool = state.get("reason") == "laps" and slid_under and (not force_retry or (blocked and respawned))
	return {"ok": won, "won": won, "frames": state.total_frames, "taps_lost": hand.stats().taps_lost,
		"falls": state.falls, "swing_hits": state.swing_hits, "slid_under": slid_under,
		"summary": "%s hand: blocked %s, checkpoint retry %s (%.2f m to beam), slid under %s, %s in %d ticks" % [
			hand_profile, blocked, respawned, retry_distance, slid_under, state.reason, state.total_frames] + "; " + _where()}
