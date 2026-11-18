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


func _pack_setup(c: TLContext) -> void:
	ctx = c
	venue = ctx.load_script("scripts/course.gd").new()
	venue.build(ctx.root, ctx.read_json("course.json"))
	spawn_at = venue.point(0, venue.DECK_Y + 0.04)
	runner = TLBiped.create({"feel": &"walker", "position": spawn_at, "name": "Runner",
		"rig_params": {"backpack": false, "expression": "focus", "colors": {"top": "flag_a", "trim": "white"}}})
	ctx.root.add_child(runner)
	rules = TLRules.create({"sides": [SIDE], "checkpoints": venue.checkpoints.size(), "laps_to_win": 1, "time_limit_seconds": 60})
	ctx.root.add_child(rules)
	for key: Array in [[&"forward", [KEY_W, KEY_UP]], [&"back", [KEY_S, KEY_DOWN]], [&"left", [KEY_A, KEY_LEFT]],
			[&"right", [KEY_D, KEY_RIGHT]], [&"jump", [KEY_SPACE]], [&"run", [KEY_SHIFT]], [&"slide", [KEY_C]], [&"restart", [KEY_R]]]:
		ctx.input.declare(key[0], key[1])
	cam = ctx.cameras.orbit(runner, {"distance": 5.5, "pitch": 33, "look_height": 1.1, "fov": 55})
	ctx.cameras.add_view(&"overview", Vector3(3, 48, 0.5), Vector3(0, 2, 0.5), 39)
	_view(&"jump", venue.FIRST_LIP + 1.1, Vector3(7.2, 2.0, 0.8), 1.15)
	_view(&"under_bar", venue.bar + 0.6, Vector3(1.7, 0.90, -5.0), 0.65)
	_view(&"chute", (venue.lip + venue.foot) / 2, Vector3(7.5, 2.0, -4.0), -2.3)
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
	runner.place(spawn_at)
	cam.snap()
	falls = 0
	rules.start()
	_update_hud()


func _pack_tick(_frame: int) -> void:
	if ctx.input.just_pressed(&"restart"):
		_restart()
	if rules.is_running():
		var at: float = venue.Z_START - runner.position.z
		# Catch a miss before a trestle underneath a high deck can catch the runner.
		var below_decks: bool = at < venue.lip and runner.position.y < venue.DECK_Y - 1.35
		if runner.position.y < KILL_Y or below_decks:
			falls += 1
			runner.place(spawn_at)
			cam.snap()
		runner.drive_from_input(ctx.input, ACTIONS, cam.yaw_basis())
		var index := int(rules.next_checkpoint[SIDE])
		var station: float = venue.checkpoints[index]
		var height: float = 0.0 if index == venue.checkpoints.size() - 1 else venue.DECK_Y
		var feet := runner.position
		if runner.grounded and absf(feet.y - height) < 0.2 and absf(feet.x) < venue.WIDTH / 2 \
				and at >= station and at < station + 0.6:
			if rules.pass_checkpoint(SIDE, index):
				spawn_at = venue.point(station, height + 0.04)
	else:
		runner.move(Vector3.ZERO)
	_update_hud()


func _update_hud() -> void:
	var best := "—"
	if rules.best_lap_frames.has(SIDE):
		best = "%.2f s" % (float(rules.best_lap_frames[SIDE]) / 60)
	var caption := "TIMBER RUN    |    %d / %d" % [int(rules.next_checkpoint[SIDE]), venue.checkpoints.size()]
	var cue: String = ["Run + jump", "Jump, land, then slide", "Down the chute"][int(rules.next_checkpoint[SIDE])]
	caption += "    " + cue
	if rules.is_over():
		caption = "FINISH" if rules.reason == "laps" else "TIME UP"
	hud.set_text(&"race", "%s\n%.2f s     Best  %s" % [caption, rules.seconds_played(), best])


func _pack_state() -> Dictionary:
	var s := rules.snapshot()
	s.merge({"station": venue.Z_START - runner.position.z, "height": runner.position.y, "motion": runner.walker_motion(),
		"speed": runner.speed(), "falls": falls, "checkpoint": int(rules.next_checkpoint[SIDE]),
		"first_lip": venue.FIRST_LIP,
		"first_land": venue.first_land, "chain_lip": venue.chain_lip, "chain_land": venue.chain_land,
		"bar": venue.bar, "bar_depth": venue.BAR_DEPTH, "lip": venue.lip, "foot": venue.foot, "deck_y": venue.DECK_Y,
		"clearance": venue.clearance, "chute_degrees": rad_to_deg(venue.angle), "run_mps": runner.run_speed})
	if rules.best_lap_frames.has(SIDE):
		s["best_frames"] = int(rules.best_lap_frames[SIDE])
	return s
