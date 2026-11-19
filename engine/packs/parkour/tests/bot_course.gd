extends "support/run_hand.gd"
## A perfect hand proves the route. Sample actual airborne crossings, clearance and downhill travel.
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
var on_beam := false
var passed_weight := false
var jumped_wall := false
var tower_air := [false, false]


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if state.checkpoint >= 4 or state.state == "over":
		if state.state != "over":
			_watch_return()
			_return_inputs(frame)
		hand.tick()
		return
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


func _restart_run() -> void:
	hand.release_all()
	hand.tap(&"restart")
	hand.tick()
	jumped = [false, false]
	airborne_over = [false, false]
	crossed = [false, false]
	previous = &"ground"
	landing = -1
	slide_start = -1
	under = -1
	slope_frames = 0
	slope_drop = 0.0
	jump_frame = -1
	chute_frame = -1
	on_beam = false
	passed_weight = false
	jumped_wall = false
	tower_air = [false, false]
	through = false
	last_falls = 0
	wait_ticks = 0
	last_leap = -100
	last_side_tap = -100
	side_action = &""
	side_press_seen = false
	last_z = 0.0
	marks.clear()


func _watch_return() -> void:
	var t := float(state.return_x)
	if state.motion == "ground" and absf(state.return_z) < float(state.beam_width) / 2:
		if state.checkpoint == 8 and t < state.swing_x:
			on_beam = true
		if on_beam and state.checkpoint == 8 and t > state.swing_x + 0.9:
			passed_weight = true
	if state.checkpoint == 9 and state.motion == "air" and t > state.wall_lip and t < state.crest:
		jumped_wall = jumped_wall or (state.speed > 6 and state.height > state.wall_top + 0.4)
	for i: int in 2:
		var face := float(state.crest) + (i + 1) * float(state.tier_length)
		if state.checkpoint == 10 + i and state.motion == "air" and absf(t - face) < 0.9:
			tower_air[i] = true


func _bot_done() -> bool:
	return state.get("state") == "over" or int(state.get("falls", 0)) > 0


func _bot_result() -> Dictionary:
	var ok: bool = state.get("reason") == "laps" and crossed == [true, true] and under >= 0 and landing >= 0 \
		and slide_start > landing and slide_start <= landing + 2 and slope_frames > 4 and slope_drop > 2.0 and state.falls == 0 \
		and on_beam and state.swing_hits == 0 and passed_weight and jumped_wall and tower_air == [true, true] \
		and marks.has(11) and state.stage_splits.size() == 3 and state.stage_splits == state.stage_bests
	var result := {"ok": ok, "summary": "perfect hand, %d frames (%.3f s), gaps %s, chain landed %d / slid %d, under bar %d, chute %d ticks / %.2f m, falls %d" % [
		state.total_frames, float(state.total_frames) / 60, crossed, landing, slide_start, under, slope_frames, slope_drop, state.falls]}
	result.summary += "; splits %s, waited %d ticks; " % [state.stage_splits, wait_ticks] + _where()
	if jump_frame >= 0:
		result["jump_frame"] = jump_frame
	if under >= 0:
		result["under_bar_frame"] = under
	if chute_frame >= 0:
		result["chute_frame"] = chute_frame
	if state.has("best_frames"):
		result["finish_frames"] = state.best_frames
	return result
