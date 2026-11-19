extends Node
## The same race runs on stage, headless and on a village plot. TLRules owns time, ordered gates and personal bests.
const ACTIONS := {"left": &"left", "right": &"right", "forward": &"forward", "back": &"back",
	"run": &"run", "jump": &"jump", "slide": &"slide"}
const KILL_Y := -0.8
const SIDE := "runner"

var ctx: TLContext
var venue
var runner: TLBiped
var rules: TLRules
var cam: TLOrbitCam
var hud: TLHud
var spawn_at: Vector3
var falls := 0
var chute_tilt := 0.0
var trail: Array[Vector3] = []         # the runner's last 8 places: blocked at the beam is under 10 cm of travel across them


func _pack_setup(c: TLContext) -> void:
	ctx = c
	venue = ctx.load_script("scripts/course.gd").new()
	TLKit.build_layout(ctx.read_json("yard.json"), ctx.root)
	venue.build(ctx.root, ctx.read_json("course.json"))
	spawn_at = venue.point(0, venue.DECK_Y + 0.04)
	runner = TLBiped.create({"feel": &"walker", "position": spawn_at, "name": "Runner",
		"rig_params": {"backpack": false, "expression": "focus", "colors": {"top": "flag_b", "trim": "white"}}})
	ctx.root.add_child(runner)
	rules = TLRules.create({"sides": [SIDE], "checkpoints": venue.checkpoints.size(), "laps_to_win": 1, "time_limit_seconds": 60})
	ctx.root.add_child(rules)
	for key: Array in [[&"forward", [KEY_W, KEY_UP]], [&"back", [KEY_S, KEY_DOWN]], [&"left", [KEY_A, KEY_LEFT]],
			[&"right", [KEY_D, KEY_RIGHT]], [&"jump", [KEY_SPACE]], [&"run", [KEY_SHIFT]], [&"slide", [KEY_C]], [&"restart", [KEY_R]]]:
		ctx.input.declare(key[0], key[1])
	cam = ctx.cameras.orbit(runner, {"yaw": -90, "distance": 5.5, "pitch": 33, "look_height": 1.1, "fov": 55})
	ctx.cameras.add_view(&"overview", Vector3(-3.5, 30, 41), Vector3(0, 5.7, 0), 43)
	_view(&"jump", venue.FIRST_LIP + 1.5, Vector3(1.8, 1.15, 6.4), 1.0)
	_view(&"under_bar", venue.bar + 0.3, Vector3(6.7, 1.6, 5.7), 0.85)
	_view(&"chute", (venue.lip + venue.foot) / 2, Vector3(4.2, 1.5, 9.6), -3.0)
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_label(&"race", "", &"top_left")
	hud.set_plate(&"race")
	hud.add_label(&"controls", "WASD / arrows  Move     Shift  Run     Space  Jump     C  Slide     R  Restart", &"bottom")
	hud.set_plate(&"controls")


func _view(id: StringName, station: float, offset: Vector3, above: float) -> void:
	var target: Vector3 = venue.point(station, venue.DECK_Y + above)
	ctx.cameras.add_view(id, target + offset, target, 45)


func _pack_start() -> void:
	_restart()


func _restart() -> void:
	spawn_at = venue.point(0, venue.DECK_Y + 0.04)
	runner.place(ctx.root.to_global(spawn_at))   # hunt2 C7: spawn_at is in course coordinates, place() takes the world's
	_frame_chute(0.0)
	cam.snap()
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
		var below_decks: bool = at < venue.lip and runner.position.y < venue.DECK_Y - 1.35
		var retry := _at_blocked_bar(at) and ctx.input.just_pressed(&"slide")
		if runner.position.y < KILL_Y or below_decks or retry:
			if not retry:
				falls += 1
			runner.place(ctx.root.to_global(spawn_at))
			at = spawn_at.x - venue.START_X
			cam.snap()
		runner.drive_from_input(ctx.input, ACTIONS, cam.yaw_basis())
		var index := int(rules.next_checkpoint[SIDE])
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
				var safe_station: float = venue.bar + venue.BAR_DEPTH + 1.0 if index == 2 else station
				spawn_at = venue.point(safe_station, height + 0.04)
	else:
		runner.move(Vector3.ZERO)
	_frame_chute(runner.position.x - venue.START_X)
	_update_hud()


func _frame_chute(at: float) -> void:
	# Lift the orbit over the lip, then give the player their original pitch on the finish deck.
	var weight := smoothstep(venue.lip - 3.0, venue.lip, at) * (1.0 - smoothstep(venue.foot + 1.0, venue.finish, at))
	var free_pitch := clampf(cam.pitch - chute_tilt, TLOrbitCam.PITCH_MIN, TLOrbitCam.PITCH_MAX)
	chute_tilt = (TLOrbitCam.PITCH_MAX - free_pitch) * weight
	cam.pitch = free_pitch + chute_tilt
	cam.look_height = 1.1 + weight * 0.65


func _at_blocked_bar(at: float) -> bool:
	return int(rules.next_checkpoint[SIDE]) == 2 and runner.grounded and trail.size() == 8 \
		and Vector2(trail[0].x - trail[7].x, trail[0].z - trail[7].z).length() < 0.1 \
		and at > venue.bar - 0.6 and at < venue.bar


func _update_hud() -> void:
	var best := "—"
	if rules.best_lap_frames.has(SIDE):
		best = "%.2f s" % (float(rules.best_lap_frames[SIDE]) / 60)
	var caption := "TIMBER RUN    |    %d / %d" % [int(rules.next_checkpoint[SIDE]), venue.checkpoints.size()]
	var cue: String = ["Run + jump", "Jump the gap", "Slide under the beam", "Down the chute"][int(rules.next_checkpoint[SIDE])]
	if _at_blocked_bar(runner.position.x - venue.START_X):
		cue = "C  Retry from checkpoint"
	caption += "    " + cue
	if rules.is_over():
		caption = "FINISH" if rules.reason == "laps" else "TIME UP"
	hud.set_text(&"race", "%s\n%.2f s     Best  %s" % [caption, rules.seconds_played(), best])


func _pack_state() -> Dictionary:
	var s := rules.snapshot()
	s.merge({"station": runner.position.x - venue.START_X, "height": runner.position.y, "motion": runner.walker_motion(),
		"speed": runner.speed(), "falls": falls, "checkpoint": int(rules.next_checkpoint[SIDE]),
		"first_lip": venue.FIRST_LIP,
		"first_land": venue.first_land, "chain_lip": venue.chain_lip, "chain_land": venue.chain_land,
		"bar": venue.bar, "bar_depth": venue.BAR_DEPTH, "lip": venue.lip, "foot": venue.foot, "deck_y": venue.DECK_Y,
		"clearance": venue.clearance, "chute_degrees": rad_to_deg(venue.angle), "run_mps": runner.run_speed})
	if rules.best_lap_frames.has(SIDE):
		s["best_frames"] = int(rules.best_lap_frames[SIDE])
	return s
