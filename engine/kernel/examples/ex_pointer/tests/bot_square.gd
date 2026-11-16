extends Node
## Bot: drives the aim (ctx.input.set_aim) the way a hand moves a cursor, and proves the stick follows.
##   0..29     no aim: the stick holds its heading (0)
##   30..229   the aim jumps to each corner of a 4 m square round the figure and stays 50 frames: the stick reaches
##             the corner's bearing within FOLLOW_FRAMES frames (within 1 degree)
##   230..549  the aim is dragged along the square's edges at 0.1 m a frame: the stick never lags the bearing by
##             more than SWEEP_DEGREES once it has caught up (from frame 240)
##   550..579  the cursor sits on the figure (2 cm away): no direction, the heading does not move
##   580..609  the aim is taken away (clear_aim): the heading does not move

const FOLLOW_FRAMES: int = 20
const SWEEP_DEGREES: float = 3.0
const CORNERS: Array = [Vector3(4, 0, -4), Vector3(-4, 0, -4), Vector3(-4, 0, 4), Vector3(4, 0, 4)]

var ctx
var state: Dictionary = {}
var follow: Array = [-1, -1, -1, -1]     # frames each corner took to be reached
var sweep_max: float = 0.0
var held_idle: bool = false
var held_on_figure: float = -1.0         # largest heading change while the cursor sat on the figure
var held_cleared: float = -1.0           # largest heading change after clear_aim
var heading_before: float = 0.0
var dead_seen: int = 0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bearing(p: Vector3) -> float:
	var d: Vector3 = p - Vector3(float(state["skater_x"]), 0.0, float(state["skater_z"]))
	return rad_to_deg(atan2(-d.x, -d.z))


func _err(a: float, b: float) -> float:
	return absf(wrapf(a - b, -180.0, 180.0))


func _square(s: float) -> Vector3:
	# a point on the square's edges, s metres along from corner 0 (each edge 8 m)
	var edge: int = int(s / 8.0) % 4
	var t: float = fmod(s, 8.0) / 8.0
	return (CORNERS[edge] as Vector3).lerp(CORNERS[(edge + 1) % 4], t)


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()       # what the game showed after the last frame
	var heading: float = float(state["heading_deg"])
	if frame == 29:
		held_idle = absf(heading) < 0.001 and not bool(state["aim_valid"])
	if frame >= 30 and frame < 230:
		var k: int = (frame - 30) / 50
		var since: int = (frame - 30) % 50
		if since == 0:
			ctx.input.set_aim(&"aim", CORNERS[k])
		elif follow[k] < 0 and _err(heading, _bearing(CORNERS[k])) < 1.0:
			follow[k] = since
	if frame >= 230 and frame < 550:
		var s: float = float(frame - 230) * 0.1
		if frame > 240:
			# the game's heading after frame - 1 against the bearing of the point it was given in frame - 1
			sweep_max = maxf(sweep_max, _err(heading, _bearing(_square(s - 0.1))))
		ctx.input.set_aim(&"aim", _square(s))
	if frame == 550:
		heading_before = heading
		held_on_figure = 0.0
		ctx.input.set_aim(&"aim", Vector3(float(state["skater_x"]) + 0.02, 0.0, float(state["skater_z"]) + 0.01))
	if frame > 551 and frame < 580:
		held_on_figure = maxf(held_on_figure, _err(heading, heading_before))
	if frame == 580:
		dead_seen = int(state["dead_frames"])
		heading_before = heading
		held_cleared = 0.0
		ctx.input.clear_aim(&"aim")
	if frame > 581 and frame < 610:
		held_cleared = maxf(held_cleared, _err(heading, heading_before))
	done = frame >= 610


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var followed: bool = true
	for f: Variant in follow:
		followed = followed and int(f) >= 0 and int(f) <= FOLLOW_FRAMES
	var ok: bool = done and held_idle and followed and sweep_max <= SWEEP_DEGREES \
		and held_on_figure >= 0.0 and held_on_figure < 0.001 and dead_seen >= 28 \
		and held_cleared >= 0.0 and held_cleared < 0.001 and not bool(state["aim_valid"])
	return {"ok": ok, "summary": "corners reached in %s frames (limit %d); dragged round the square the stick lagged at most %.2f degrees (limit %.1f); cursor on the figure for %d frames: heading moved %.4f degrees; aim cleared: heading moved %.4f degrees; idle start held: %s" % [
			str(follow), FOLLOW_FRAMES, sweep_max, SWEEP_DEGREES, dead_seen, held_on_figure, held_cleared, str(held_idle)],
		"follow_frames": follow, "sweep_max_degrees": snappedf(sweep_max, 0.001), "dead_frames": dead_seen,
		"on_figure_moved_degrees": snappedf(held_on_figure, 0.0001), "cleared_moved_degrees": snappedf(held_cleared, 0.0001),
		"idle_held": held_idle, "valid_frames": int(state["valid_frames"])}
