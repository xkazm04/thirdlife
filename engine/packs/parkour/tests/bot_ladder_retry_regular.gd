extends Node
## Hold forward throughout. Omit the first slide and use the same C key a player sees at the beam.
var ctx: TLContext
var hand: TLHand
var state: Dictionary
var last_jump := -60
var last_slide := -60
var blocked := false
var respawned := false
var slid_under := false
var retry_distance := 0.0


func _bot_setup(c: TLContext) -> void:
	ctx = c
	hand = TLHand.create(ctx, "regular")


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	var at := float(state.station)
	hand.press(&"forward")
	hand.press(&"run")
	for edge: float in [state.first_lip, state.chain_lip]:
		if at >= edge - 2.2 and at < edge and state.motion == "ground" and frame - last_jump > 30:
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
	if respawned and at > state.bar - 3.6 and at < state.bar and frame - last_slide > 20:
		hand.tap(&"slide")
		last_slide = frame
	if respawned and state.motion == "slide" and at >= state.bar and at <= state.bar + state.bar_depth:
		slid_under = true
	hand.tick()


func _bot_done() -> bool:
	return state.get("state") == "over"


func _bot_result() -> Dictionary:
	var won: bool = state.get("reason") == "laps" and blocked and respawned and slid_under
	return {"ok": won, "won": won, "frames": state.total_frames, "taps_lost": hand.stats().taps_lost,
		"summary": "regular hand: blocked %s, checkpoint retry %s (%.2f m to beam), slid under %s, %s in %d ticks" % [
			blocked, respawned, retry_distance, slid_under, state.reason, state.total_frames]}
