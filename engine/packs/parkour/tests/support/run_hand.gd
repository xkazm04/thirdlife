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
var jump_response := -1.0
var observed_request := -100
var grip_request := -100
var target_grip := 0
var skyline_sample := -100
var last_station := 0.0
var last_height := 0.0


func _bot_setup(c: TLContext) -> void:
	ctx = c
	hand = TLHand.create(ctx, hand_profile)


func _return_inputs(frame: int) -> void:
	# Read the delivered key edge against our last request, as a player anticipating their own timing can.
	var request := maxi(last_leap, grip_request)
	if ctx.input.just_pressed(&"jump") and request >= 0 and request != observed_request:
		var ticks := clampi(frame - request - 1, 0, 25)
		jump_response = ticks if jump_response < 0.0 else lerpf(jump_response, ticks, 0.4)
		observed_request = request
	var gate := int(state.checkpoint)
	var t := float(state.return_x)
	if state.falls != last_falls:
		through = false
		last_falls = state.falls
		target_grip = 0
		last_z = state.return_z
	if not marks.has(gate):
		marks[gate] = frame
	if gate >= 12:
		_skyline_inputs(frame, gate)
		return
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


func _skyline_inputs(frame: int, gate: int) -> void:
	var advance: float = state.return_z - last_station
	var rise: float = state.height - last_height
	var consecutive := frame == skyline_sample + 1
	last_station = state.return_z
	last_height = state.height
	skyline_sample = frame
	hand.press(&"run")
	if state.motion != "bar":
		hand.set_axis(&"back", &"forward", 1.0)
	if gate == 12:
		if state.height < state.rim_y - 1.0 and state.return_z >= state.headwall - 1.6 and state.motion == "ground" and frame - last_leap > 30:
			hand.tap(&"jump")
			last_leap = frame
		return
	var lead := maxf(jump_response, 0.0)
	if state.motion == "ground" and state.return_z < state.runway_end:
		var takeoff: float = state.runway_end - 1.05 - lead * float(state.run_mps) / 60.0
		if state.return_z >= takeoff and frame - last_leap > 27:
			target_grip = 0
			hand.tap(&"jump")
			last_leap = frame
		return
	if state.motion == "bar":
		var rod := int(state.grip)
		var omega := float(state.bar_omega)
		# Pump back while returning. Aim for the forward, rising part of the next swing.
		var frequency := sqrt(24.0 / 1.1)
		var ahead := frequency * lead / 60.0
		var next_omega := omega * cos(ahead) - frequency * float(state.bar_theta) * sin(ahead)
		hand.set_axis(&"back", &"forward", 1.0 if next_omega >= 0.0 else -1.0)
		var next_theta := float(state.bar_theta) * cos(ahead) + omega / frequency * sin(ahead)
		if next_omega > 2.7 and next_theta >= 0.63 and next_theta < 1.35:
			_request_release(frame, rod)
	elif state.motion == "air" and consecutive and advance > 0.03 and state.grips_passed < 2:
		var rod := int(state.grips_passed) + 1
		var axis_z: float = state.first_bar if rod == 1 else state.second_bar
		var axis_y: float = state.first_bar_y if rod == 1 else state.first_bar_y + state.red_rise
		var eta: float = (axis_z - float(state.return_z) - 0.24) / advance
		if eta < 0.0 or eta > lead:
			return
		# Anticipate only a reachable catch. A slow transfer takes longer to build the release angle.
		var hands: float = state.height + 2.2 + rise * eta - 12.0 * pow(eta / 60.0, 2)
		var swing_ticks := 0.63 * 1.1 / advance
		if absf(hands - axis_y) < 0.55 and eta + swing_ticks + 1.0 <= lead:
			_request_release(frame, rod)


func _request_release(frame: int, rod: int) -> void:
	if target_grip == rod and frame - grip_request < 40:
		return
	target_grip = rod
	grip_request = frame
	hand.tap(&"jump")
