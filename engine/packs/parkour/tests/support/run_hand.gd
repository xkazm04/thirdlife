extends Node
## All hands read the same stripes, swing phase and foot positions. TLHand delivers their inputs.
var ctx: TLContext
var hand: TLHand
var hand_profile := "perfect"
var state: Dictionary
var last_leap := -100
var marks := {}
var wait_ticks := 0
var through := false
var last_falls := 0
var last_side_tap := -100
var side_action: StringName = &""
var side_press_seen := false
var last_z := 0.0


func _bot_setup(c: TLContext) -> void:
	ctx = c
	hand = TLHand.create(ctx, hand_profile)


func _return_inputs(frame: int) -> void:
	var gate := int(state.checkpoint)
	var t := float(state.return_x)
	if state.falls != last_falls:
		through = false
		last_falls = state.falls
		last_z = state.return_z
	if not marks.has(gate):
		marks[gate] = frame
	hand.press(&"run", 1.0 if gate < 10 else 0.0)
	var holding := false
	if gate == 8 and not through and t > state.swing_x - 3.5:
		# Read the passing weight at the approach stripe. A clear window at running speed needs no stop.
		if _crossing_open(t):
			through = true
		else:
			holding = true
			wait_ticks += 1
	hand.press(&"forward", 0.0 if holding else 1.0)
	if gate < 5:
		last_z = state.return_z
		return
	# Common take-off cues on the three return jumps.
	var lead := 1.2
	if gate <= 8:
		_aim_return(frame)
	if gate <= 7:
		var target := 1.55
		if t > state.pad_two - 2.6:
			target = state.pad_two + 0.8
		elif t > state.pad_one - 2.6:
			target = state.pad_one + 0.8
		if t >= target - lead and t < target + 1.5 and frame - last_leap > 27:
			hand.tap(&"jump")
			last_leap = frame
	elif gate >= 9:
		var lip: float = state.wall_lip if gate == 9 else state.crest + (gate - 9) * state.tier_length
		# Gain height before the face; a late arrival can take another ordinary jump from its foot.
		var distance := 1.45 if gate == 9 else 1.55
		if t >= lip - distance and t < lip + 0.3 and state.motion == "ground" and frame - last_leap > 24:
			hand.tap(&"jump")
			last_leap = frame


func _crossing_open(t: float) -> bool:
	var speed := float(state.speed)
	if speed > 1.0 and speed < 7.0:
		return false
	var half_cycle := float(state.swing_period) / 2.0
	var stride := 60.0 / float(state.run_mps)
	var start_cost := 8.0 if speed <= 1.0 else 0.0
	var entry := fposmod(state.swing_phase + start_cost + (state.swing_x - 1.1 - t) * stride, half_cycle)
	var exit_phase := entry + 2.2 * stride
	return entry >= half_cycle * 0.18 and exit_phase <= half_cycle * 0.82


func _aim_return(frame: int) -> void:
	var t := float(state.return_x)
	var z := float(state.return_z)
	var target := float(state.pad_z[0]) - 0.55 if t < state.pad_one - 1.0 else 0.0
	var dz := z - last_z
	last_z = z
	# Finish one key stroke before requesting another. A missed tap may never reach the input.
	if side_action != &"":
		if ctx.input.pressed(side_action):
			side_press_seen = true
			return
		if not side_press_seen and frame - last_side_tap < 45:
			return
		side_action = &""
	var error := target - (z + 12.0 * dz)
	if absf(error) > 0.28 and frame - last_side_tap >= 16:
		side_action = &"right" if error > 0 else &"left"
		side_press_seen = false
		hand.tap(side_action, 9)
		last_side_tap = frame


func _where() -> String:
	return "checkpoint %d, return (%.2f, %.2f), height %.2f, marks %s" % [
		state.checkpoint, state.return_x, state.return_z, state.height, marks]
