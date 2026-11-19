extends Node
## The same race runs on stage, headless and on a village plot. TLRules owns time, ordered gates and personal bests.
const ACTIONS := {"left": &"left", "right": &"right", "forward": &"forward", "back": &"back",
	"run": &"run", "jump": &"jump", "slide": &"slide"}
const KILL_Y := -0.8
const SIDE := "runner"

const STAGES := ["High line", "Swing yard", "Summit", "Skyline"]
const CUES := ["Run + jump", "Jump the gap", "Slide under the beam", "Down the chute",
	"Follow the ramp around", "Leap to the first pad", "Jump to the opposite pad", "Land on the striped beam", "Time the swing",
	"Run up the wall and jump", "Jump to the next ledge", "Take the summit stripe", "Jump to the lip · Push forward to mantle",
	"Jump to blue · Swing to red · Space to release"]

var ctx: TLContext
var venue
var runner: TLBiped
var rules: TLRules
var cam: TLOrbitCam
var skyline_camera
var hud: TLHud
var spawn_at: Vector3
var lane
var splits: Array[int] = []
var stage_bests: Array[int] = []
var stage_started := 0
var falls := 0
var carried_strafe := 0.0
var carried_back := false
var swing_hits := 0
var swing_hit_pending := false
var hit_notice_until := 0
var grips_passed := 0
var missed_grip_until := 0
var missed_landing_until := 0
var chute_tilt := 0.0
var trail: Array[Vector3] = []         # the runner's last 8 places: blocked at the beam is under 10 cm of travel across them


func _pack_setup(c: TLContext) -> void:
	ctx = c
	venue = ctx.load_script("scripts/course.gd").new()
	TLKit.build_layout(ctx.read_json("yard.json"), ctx.root)
	venue.build(ctx.root, ctx.read_json("course.json"))
	lane = ctx.load_script("scripts/return_lane.gd").new()
	lane.build(ctx, venue.point(venue.finish, 0, 9))
	lane.build_skyline(ctx)
	spawn_at = venue.point(0, venue.DECK_Y + 0.04)
	runner = TLBiped.create({"feel": &"walker", "moves": [&"ledge", &"bar"], "position": spawn_at, "name": "Runner", "group": &"timber_runner",
		"rig_params": {"backpack": false, "expression": "focus", "colors": {"top": "flag_b", "trim": "white"}}})
	ctx.root.add_child(runner)
	lane.weight_contact.entered.connect(_weight_contact)
	rules = TLRules.create({"sides": [SIDE], "checkpoints": CUES.size(), "laps_to_win": 1, "time_limit_seconds": 60})
	ctx.root.add_child(rules)
	for key: Array in [[&"forward", [KEY_W, KEY_UP]], [&"back", [KEY_S, KEY_DOWN]], [&"left", [KEY_A, KEY_LEFT]],
			[&"right", [KEY_D, KEY_RIGHT]], [&"jump", [KEY_SPACE]], [&"run", [KEY_SHIFT]], [&"slide", [KEY_C]], [&"restart", [KEY_R]]]:
		ctx.input.declare(key[0], key[1])
	cam = ctx.cameras.orbit(runner, {"yaw": -90, "distance": 5.5, "pitch": 33, "look_height": 1.1, "fov": 55})
	skyline_camera = ctx.load_script("scripts/skyline_camera.gd").new()
	skyline_camera.cam = cam
	cam.add_child(skyline_camera)
	ctx.cameras.add_view(&"overview", Vector3(-9, 34, 50), Vector3(0, 5.1, 0.0), 43)
	_view(&"jump", venue.FIRST_LIP + 1.5, Vector3(1.8, 1.15, 6.4), 1.0)
	_view(&"under_bar", venue.bar + 0.3, Vector3(6.7, 1.6, 5.7), 0.85)
	_view(&"chute", (venue.lip + venue.foot) / 2, Vector3(4.2, 1.5, 9.6), -3.0)
	_return_view(&"pads", (lane.PAD_X + lane.second) / 2, 0.2, Vector3(4.6, 4.7, 7.5))
	_return_view(&"swing", lane.swing_x, 1.6, Vector3(8.5, 2.2, 3.7))
	_return_view(&"balance", lane.beam_start + 1.3, 0.3, Vector3(3.8, 2.8, 5.5))
	_return_view(&"wall", lane.wall_lip, 2.85, Vector3(4.4, 2.3, 8.8))
	_return_view(&"tower", lane.crest + lane.TIER_LENGTH * 1.6, 4.4, Vector3(-5.6, 4.0, 12.8))
	var wall_face: Vector3 = lane.root.transform * Vector3(lane.summit, lane.rim_y - 1.0, lane.HEADWALL)
	ctx.cameras.add_view(&"headwall", wall_face + Vector3(7.2, 2.2, 5.6), wall_face, 42)
	_upper_view(&"blue_grip", lane.FIRST_BAR, lane.first_bar_y - 0.7, Vector3(0.9, -0.55, -5.1))
	_upper_view(&"red_grip", lane.second_bar, lane.first_bar_y + 0.6, Vector3(-0.35, -0.7, -5.2))
	_upper_view(&"transfer", (lane.FIRST_BAR + lane.second_bar) / 2, lane.first_bar_y + 0.4, Vector3(5.5, 7.0, 1.8))
	_upper_view(&"catch_deck", lane.landing_z + 1.7, lane.landing_height(1.7) + 0.4, Vector3(6.0, 3.2, -5.2))
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_label(&"race", "", &"top_left")
	hud.set_plate(&"race")
	hud.add_label(&"controls", "WASD / arrows  Move     Shift  Run     Space  Jump     C  Slide     R  Restart", &"bottom")
	hud.set_plate(&"controls")


func _view(id: StringName, station: float, offset: Vector3, above: float) -> void:
	var target: Vector3 = venue.point(station, venue.DECK_Y + above)
	ctx.cameras.add_view(id, target + offset, target, 45)


func _return_view(id: StringName, t: float, above: float, offset: Vector3) -> void:
	var target: Vector3 = lane.root.transform * Vector3(t, lane.HEIGHT + above, 0)
	ctx.cameras.add_view(id, target + offset, target, 46)


func _upper_view(id: StringName, station: float, height: float, offset: Vector3) -> void:
	var target: Vector3 = lane.root.transform * Vector3(lane.summit, height, station)
	ctx.cameras.add_view(id, target + offset, target, 46)


func _weight_contact(body: Node3D) -> void:
	if body == runner:
		swing_hit_pending = true


func _pack_start() -> void:
	_restart()


func _restart() -> void:
	spawn_at = venue.point(0, venue.DECK_Y + 0.04)
	runner.place(ctx.root.to_global(spawn_at))   # hunt2 C7: spawn_at is in course coordinates, place() takes the world's
	cam.yaw = -90
	_frame_course(0.0, false)
	cam.snap()
	trail.clear()
	splits.clear()
	stage_started = 0
	carried_strafe = 0.0
	carried_back = false
	swing_hits = 0
	swing_hit_pending = false
	hit_notice_until = 0
	grips_passed = 0
	missed_grip_until = 0
	missed_landing_until = 0
	falls = 0
	rules.start()
	_update_hud()


func _pack_tick(_frame: int) -> void:
	if ctx.input.just_pressed(&"restart"):
		_restart()
	if rules.is_running():
		# hunt2 A15: pushed into the beam he bounces 3 cm in a three-tick cycle and his speed flickers: read his travel
		trail.push_back(runner.position)
		if trail.size() > 8:
			trail.pop_front()
		var at: float = runner.position.x - venue.START_X
		# Catch a miss before a trestle underneath a high deck can catch the runner.
		var index := int(rules.next_checkpoint[SIDE])
		lane.advance(rules.total_frames)
		var below_decks: bool = index < 4 and at < venue.lip and runner.position.y < venue.DECK_Y - 1.35
		below_decks = below_decks or (index >= 5 and runner.position.y < lane.HEIGHT - 0.7)
		# A capsule can skim a deck with its centre outside the marked landing, then run past it.
		if index >= 5 and index <= 8 and runner.grounded and _past_landing(index):
			missed_landing_until = rules.total_frames + 75
			below_decks = true
		if index >= 9:
			var p: Vector3 = lane.local_feet(runner.position)
			if p.x > lane.wall_lip and p.y < lane.HEIGHT + lane.WALL_RISE - 0.8:
				below_decks = true
		if index >= 12:
			var upper: Vector3 = lane.local_feet(runner.position)
			below_decks = below_decks or upper.y < lane.summit_y - 0.7 or absf(upper.x - lane.summit) > lane.UPPER_WIDTH / 2 + 0.6
			# The lower headwall approach is no longer the active deck after the mantle.
			if index == 13 and runner.grounded and upper.z < lane.HEADWALL and upper.y < lane.rim_y - 0.7:
				below_decks = true
		if index == 13:
			var grip := _current_grip()
			if grip > 0 and grip == grips_passed + 1:
				grips_passed = grip
			var upper_station: float = lane.local_feet(runner.position).z
			if runner.grounded and upper_station >= lane.landing_z and grips_passed < 2:
				missed_grip_until = rules.total_frames + 90
				below_decks = true
		var retry := _at_blocked_bar(at) and ctx.input.just_pressed(&"slide")
		var struck := swing_hit_pending and index >= 4
		swing_hit_pending = false
		if struck:
			swing_hits += 1
			hit_notice_until = rules.total_frames + 60
		if runner.position.y < KILL_Y or below_decks or retry or struck:
			grips_passed = 0
			if not retry:
				falls += 1
			carried_back = index == 13 and ctx.input.pressed(&"back")
			var facing := 0.0
			if index == 8:
				carried_strafe = signf(ctx.input.axis(&"left", &"right"))
				facing = Vector3.FORWARD.signed_angle_to(lane.root.basis.x, Vector3.UP)
			runner.place(ctx.root.to_global(spawn_at), facing)
			trail.clear()
			at = spawn_at.x - venue.START_X
			cam.snap()
		_drive_walker(index)
		if index < 4:
			_high_checkpoint(index, at)
		else:
			_return_checkpoint(index)
	else:
		runner.move(Vector3.ZERO)
	_frame_course(runner.position.x - venue.START_X if splits.is_empty() else 0.0, int(rules.next_checkpoint[SIDE]) == 13)
	_update_hud()


func _drive_walker(index: int) -> void:
	var view := cam.yaw_basis()
	runner.drive_from_input(ctx.input, ACTIONS, view)
	if carried_back:
		carried_back = index == 13 and ctx.input.pressed(&"back")
		if carried_back:
			# A held pump key belongs to the previous swing. Keep lateral and forward input live.
			var side := ctx.input.axis(&"left", &"right")
			runner.move(view * Vector3(side, 0.0, -ctx.input.strength(&"forward")), ctx.input.pressed(&"run"))
			return
	if carried_strafe == 0.0:
		return
	if index != 8 or signf(ctx.input.axis(&"left", &"right")) != carried_strafe:
		carried_strafe = 0.0
		return
	# A held side key belonged to the fall. Keep the forward/back controls until the player steers afresh.
	var along := ctx.input.axis(&"forward", &"back")
	runner.move(view * Vector3(0.0, 0.0, along), ctx.input.pressed(&"run"))


func _high_checkpoint(index: int, at: float) -> void:
	var station: float = venue.checkpoints[index]
	var height: float = 0.0 if index == venue.checkpoints.size() - 1 else venue.DECK_Y
	var feet := runner.position
	# A late jump can land beyond the stripe. The entire approach earns its respawn.
	var end: float = venue.bar if index == 1 else station + 0.6
	# The beam checkpoint is inside the opening. Jumping around a jamb cannot earn it.
	var on_route: bool = index != 2 or (at < venue.bar + venue.BAR_DEPTH and absf(feet.z) < venue.WIDTH / 2 - 0.35)
	if on_route and runner.grounded and absf(feet.y - height) < 0.2 and absf(feet.z) < venue.WIDTH / 2 \
			and at >= station and at < end:
		if rules.pass_checkpoint(SIDE, index):
			if index == 3:
				_close_stage()
				cam.orbit_by(-90, 0)
			var safe_station: float = venue.bar + venue.BAR_DEPTH + 1.0 if index == 2 else station
			spawn_at = venue.point(safe_station, height + 0.04)


func _return_checkpoint(index: int) -> void:
	if not runner.grounded:
		return
	var p: Vector3 = lane.local_feet(runner.position)
	var safe := p
	match index:
		4:
			if p.z > 1.55 or p.z < -1.7 or absf(p.x + 0.7) > 2.8 or absf(p.y - lane.HEIGHT) > 0.2:
				return
			safe = Vector3(-1.3, lane.HEIGHT, 0)
			cam.orbit_by(-90, 0)
		5, 6:
			if not lane.pad_landing(index - 5, p):
				return
			var pad: Node3D = lane.pads[index - 5]
			safe = pad.transform * Vector3(-1.05, 0, 0)
		7, 8:
			var mark: float = lane.beam_start + 0.6 if index == 7 else lane.beam_end - 0.6
			var end: float = lane.swing_x - 0.9 if index == 7 else lane.beam_end + 0.1
			if p.x < mark or p.x > end or absf(p.z) > lane.beam_width / 2 or absf(p.y - lane.HEIGHT) > 0.2:
				return
			safe = Vector3(mark, lane.HEIGHT, 0)
		9, 10, 11:
			var tier := index - 9
			var near: float = lane.crest + tier * lane.TIER_LENGTH
			var top: float = lane.crest_y + tier * lane.tier_rise
			var mark: float = lane.summit if index == 11 else near
			if p.x < mark or p.x >= near + lane.TIER_LENGTH or absf(p.z) > 1.8 or absf(p.y - top) > 0.18:
				return
			safe = Vector3(near + 0.7, top, 0)
		12:
			if p.z < lane.HEADWALL + 0.25 or p.z > lane.RUNWAY_END or absf(p.y - lane.rim_y) > 0.1:
				return
			safe = Vector3(lane.summit, lane.rim_y, lane.HEADWALL + 0.6)
		13:
			var distance: float = p.z - lane.landing_z
			if distance < 0.45 or distance > lane.LANDING_RUN or absf(p.y - lane.landing_height(distance)) > 0.24:
				return
	rules.pass_checkpoint(SIDE, index)
	spawn_at = lane.root.transform * (safe + Vector3.UP * 0.04)
	if index == 11:
		spawn_at = lane.root.transform * Vector3(lane.summit, lane.summit_y + 0.04, 0)
		cam.orbit_by(-90, 0)
	if index == 8 or index == 11 or index == 13:
		_close_stage()


func _past_landing(index: int) -> bool:
	var t: float = lane.local_feet(runner.position).x
	if index == 7:
		return t > lane.swing_x - 0.9
	if index == 8:
		return t > lane.beam_end + 0.1
	# Past this radius the complete pad, including its yaw and the capsule radius, is behind us.
	var centre: float = lane.PAD_X if index == 5 else lane.second
	return t > centre + Vector2(lane.PAD_LENGTH, lane.PAD_WIDTH).length() / 2 + 0.35


func _current_grip() -> int:
	if runner.walker_motion() != &"bar":
		return 0
	var z: float = lane.root.to_local(runner.bar_point).z
	if absf(z - lane.FIRST_BAR) < 0.1:
		return 1
	return 2 if absf(z - lane.second_bar) < 0.1 else 0


func _frame_course(at: float, on_runway: bool) -> void:
	# Lift the orbit over the lip, then give the player their original pitch on the finish deck.
	var weight := smoothstep(venue.lip - 3.0, venue.lip, at) * (1.0 - smoothstep(venue.foot + 1.0, venue.finish, at))
	var free_pitch := clampf(cam.pitch - chute_tilt, TLOrbitCam.PITCH_MIN, TLOrbitCam.PITCH_MAX)
	chute_tilt = (TLOrbitCam.PITCH_MAX - free_pitch) * weight
	cam.pitch = free_pitch + chute_tilt
	cam.look_height = 1.1 + weight * 0.65
	cam.fov = 55.0
	skyline_camera.amount = 0.0
	if on_runway:
		var feet: Vector3 = lane.local_feet(runner.position)
		var skyline := smoothstep(lane.HEADWALL + 0.6, lane.RUNWAY_END - 1.0, feet.z) \
			* (1.0 - smoothstep(lane.second_bar + 1.75, lane.landing_z + 0.45, feet.z))
		# Keep W aligned with the runway until blue is caught, and with the ramp after red is released.
		skyline_camera.swing_view = grips_passed == 1 or (grips_passed == 2 and runner.walker_motion() == &"bar")
		skyline_camera.amount = skyline
		cam.fov += 4.0 * skyline


func _at_blocked_bar(at: float) -> bool:
	return int(rules.next_checkpoint[SIDE]) == 2 and runner.grounded and trail.size() == 8 \
		and Vector2(trail[0].x - trail[7].x, trail[0].z - trail[7].z).length() < 0.1 \
		and at > venue.bar - 0.6 and at < venue.bar


func _close_stage() -> void:
	var index := splits.size()
	var elapsed := rules.total_frames - stage_started
	splits.append(elapsed)
	if index == stage_bests.size():
		stage_bests.append(elapsed)
	else:
		stage_bests[index] = mini(stage_bests[index], elapsed)
	stage_started = rules.total_frames


func _update_hud() -> void:
	var best := "—"
	if rules.best_lap_frames.has(SIDE):
		best = "%.2f s" % (float(rules.best_lap_frames[SIDE]) / 60)
	var index := mini(splits.size(), STAGES.size() - 1)
	var caption := "%d   %s" % [index + 1, STAGES[index]]
	var cue: String = CUES[int(rules.next_checkpoint[SIDE])]
	if _at_blocked_bar(runner.position.x - venue.START_X):
		cue = "C  Retry from checkpoint"
	if rules.total_frames < missed_landing_until:
		cue = "Missed landing · Back to checkpoint"
	if rules.total_frames < hit_notice_until:
		cue = "Weight hit   ·   Back on beam"
	if carried_strafe != 0.0:
		cue = "Back on beam   ·   Release side key to steer"
	if int(rules.next_checkpoint[SIDE]) == 13:
		cue = ["Jump to the blue bar", "Swing forward · Space to reach red", "Space to land on the striped ramp"][grips_passed]
		if carried_back:
			cue = "Back on runway · Release Back to step back"
		elif rules.total_frames < missed_grip_until:
			cue = "Catch blue, then red · Try again"
	caption += "    " + cue
	if rules.is_over():
		caption = "FINISH" if rules.reason == "laps" else "TIME UP"
	var stage_time := rules.total_frames - stage_started if splits.size() <= index else splits[index]
	if rules.reason == "laps":
		var lines := PackedStringArray(["FINISH     %.2f s     Best  %s" % [rules.seconds_played(), best]])
		for i: int in splits.size():
			lines.append("%s    %.2f     Best  %.2f" % [STAGES[i], splits[i] / 60.0, stage_bests[i] / 60.0])
		hud.set_text(&"race", "\n".join(lines))
		return
	var pb := "%.2f" % (stage_bests[index] / 60.0) if index < stage_bests.size() else "—"
	hud.set_text(&"race", "%s\nSplit  %.2f     Best  %s\nRun  %.2f     Best  %s" % [
		caption, stage_time / 60.0, pb, rules.seconds_played(), best])


func _pack_state() -> Dictionary:
	var s := rules.snapshot()
	var p: Vector3 = lane.local_feet(runner.position)
	s.merge({"return_x": p.x, "return_z": p.z, "pad_z": lane.pad_offsets.duplicate(), "pad_one": lane.PAD_X, "pad_two": lane.second,
		"beam_start": lane.beam_start, "beam_end": lane.beam_end, "beam_width": lane.beam_width,
		"wall_base": lane.wall_base, "wall_lip": lane.wall_lip, "wall_top": lane.HEIGHT + lane.WALL_RISE,
		"crest": lane.crest, "crest_y": lane.crest_y, "tier_rise": lane.tier_rise,
		"headwall": lane.HEADWALL, "ledge_rise": lane.ledge_rise, "rim_y": lane.rim_y, "runway_end": lane.RUNWAY_END,
		"first_bar": lane.FIRST_BAR, "first_bar_y": lane.first_bar_y, "red_rise": lane.RED_RISE, "second_bar": lane.second_bar,
		"landing_z": lane.landing_z, "landing_y": lane.landing_y, "grips_passed": grips_passed,
		"tier_length": lane.TIER_LENGTH, "summit": lane.summit,
		"corner_end": lane.CORNER_CENTER.x + lane.CORNER_SIZE.x / 2,
		"corner_near_z": lane.CORNER_CENTER.z - lane.CORNER_SIZE.z / 2,
		"corner_far_z": lane.CORNER_CENTER.z + lane.CORNER_SIZE.z / 2,
		"weight_depth": lane.WEIGHT_SIZE.x, "contact_skin": lane.CONTACT_SKIN,
		"pad_length": lane.PAD_LENGTH, "pad_width": lane.PAD_WIDTH, "pad_yaw": lane.PAD_YAW,
		"swing_arm": lane.ARM, "weight_width": lane.WEIGHT_SIZE.z, "weight_height": lane.WEIGHT_SIZE.y,
		"swing_x": lane.swing_x, "swing_phase": lane.phase(rules.total_frames), "swing_period": lane.swing_period_frames,
		"swing_degrees": rad_to_deg(lane.swing_angle), "station": runner.position.x - venue.START_X,
		"height": runner.position.y, "motion": runner.walker_motion(),
		"speed": runner.speed(), "falls": falls, "swing_hits": swing_hits, "carried_strafe": carried_strafe, "swing_hit_pending": swing_hit_pending, "checkpoint": int(rules.next_checkpoint[SIDE]),
		"stage_splits": splits.duplicate(), "stage_bests": stage_bests.duplicate(), "stage_started": stage_started,
		"first_lip": venue.FIRST_LIP,
		"first_land": venue.first_land, "chain_lip": venue.chain_lip, "chain_land": venue.chain_land,
		"bar": venue.bar, "bar_depth": venue.BAR_DEPTH, "lip": venue.lip, "foot": venue.foot, "deck_y": venue.DECK_Y,
		"clearance": venue.clearance, "chute_degrees": rad_to_deg(venue.angle), "run_mps": runner.run_speed})
	if carried_back:
		s["carried_back"] = true
	if rules.total_frames < missed_landing_until:
		s["missed_landing_until"] = missed_landing_until
	if rules.total_frames < missed_grip_until:
		s["missed_grip_until"] = missed_grip_until
	if runner.walker_motion() == &"bar":
		s["grip"] = _current_grip()
		s["bar_theta"] = runner.bar_theta
		s["bar_omega"] = runner.bar_omega
	if rules.best_lap_frames.has(SIDE):
		s["best_frames"] = int(rules.best_lap_frames[SIDE])
	return s
