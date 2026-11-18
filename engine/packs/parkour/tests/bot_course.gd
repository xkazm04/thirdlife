extends Node
## A perfect hand proves the route. Sample actual airborne crossings, clearance and downhill travel.
var ctx: TLContext
var hand: TLHand
var state: Dictionary
var jumped := [false, false]
var airborne_over := [false, false]
var crossed := [false, false]
var previous: StringName = &"ground"
var landing := -1
var slide_start := -1
var under := -1
var slope_frames := 0
var slope_drop := 0.0
var slope_y := 0.0
var jump_frame := -1
var chute_frame := -1


func _bot_setup(c: TLContext) -> void:
	ctx = c
	hand = TLHand.create(ctx, "perfect")


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	var at := float(state.station)
	var motion := StringName(state.motion)
	hand.press(&"forward")
	hand.press(&"run")
	for i: int in 2:
		var edge := float(state.first_lip if i == 0 else state.chain_lip)
		var far_edge := float(state.first_land if i == 0 else state.chain_land)
		if at >= edge - 0.85 and at < edge and motion == &"ground" and not jumped[i]:
			hand.tap(&"jump")
			jumped[i] = true
		if at > edge and at < far_edge and motion == &"air" and state.height > state.deck_y + 0.3:
			airborne_over[i] = true
			if i == 0 and state.height > state.deck_y + 0.9:
				jump_frame = frame
		if airborne_over[i] and previous == &"air" and motion == &"ground" and at >= far_edge:
			crossed[i] = true
	if crossed[1] and previous == &"air" and motion == &"ground" and at >= state.chain_land and landing < 0:
		landing = frame
		hand.tap(&"slide")
	if motion == &"slide" and slide_start < 0:
		slide_start = frame
	if motion == &"slide" and at > state.bar + 0.2 and at < state.bar + state.bar_depth - 0.2:
		under = frame
	if motion == &"slope":
		if slope_frames == 0:
			slope_y = float(state.height)
		slope_frames += 1
		slope_drop = maxf(slope_drop, slope_y - float(state.height))
		if slope_drop < 3.2:
			chute_frame = frame
	previous = motion
	hand.tick()


func _bot_done() -> bool:
	return state.get("state") == "over" or int(state.get("falls", 0)) > 0


func _bot_result() -> Dictionary:
	var ok: bool = state.get("reason") == "laps" and crossed == [true, true] and under >= 0 and landing >= 0 \
		and slide_start > landing and slide_start <= landing + 2 and slope_frames > 4 and slope_drop > 2.0 and state.falls == 0
	var result := {"ok": ok, "summary": "perfect hand, %d frames (%.3f s), gaps %s, chain landed %d / slid %d, under bar %d, chute %d ticks / %.2f m, falls %d" % [
		state.total_frames, float(state.total_frames) / 60, crossed, landing, slide_start, under, slope_frames, slope_drop, state.falls]}
	if jump_frame >= 0:
		result["jump_frame"] = jump_frame
	if under >= 0:
		result["under_bar_frame"] = under
	if chute_frame >= 0:
		result["chute_frame"] = chute_frame
	if state.has("best_frames"):
		result["finish_frames"] = state.best_frames
	return result
