extends Node
## Bot: holds "forward" from frame 0 to the end, the way a person keeps a key down through a hit. Taps "knock" at 90
## (down for 90 frames, then get_up_frames to rise), "shove" at 240 (the walker: moved, not felled), "stumble" at 300.
## Proves: downed and got_up fired, frames down = 90 + get_up_frames, no thrust and no turn while down (move is
## ignored), he skates again after; the shove moved the walker more than a metre and did not fell him; the stumble
## did not fell the skater; the pair sized with its rig never came closer than its two bodies (2 x 0.66 m).

const KNOCK: int = 90
const DOWN: int = 90
var ctx
var state: Dictionary = {}
var speed_after_up: float = 0.0
var was_down_at_stumble: bool = true
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if frame == 0:
		ctx.input.press(&"forward")
	if frame == KNOCK:
		ctx.input.tap(&"knock")
	if frame == 240:
		ctx.input.tap(&"shove")
	if frame == 295:
		speed_after_up = float(state["skater_speed"])
	if frame == 300:
		ctx.input.tap(&"stumble")
	if frame == 310:
		was_down_at_stumble = bool(state["is_down"])
	done = frame >= 420


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var up_frames: int = int(state["got_up_at"]) - int(state["downed_at"])
	var ok: bool = done and int(state["downed_at"]) == KNOCK + 1 and int(state["got_up_at"]) > 0 \
		and int(state["down_frames"]) == up_frames and up_frames > DOWN \
		and float(state["speed_gain_while_down"]) <= 0.0001 and float(state["facing_turn_while_down"]) < 0.0001 \
		and speed_after_up > 3.0 and not bool(state["walker_down"]) and float(state["walker_z"]) < 5.0 \
		and not was_down_at_stumble and float(state["least_sized"]) >= 2.0 * float(state["body_sized"]) - 0.05
	return {"ok": ok, "summary": "down at tick %d, up at %d (%d frames: %d lying + rising); speed %.2f m/s when felled, never rose while down (largest rise %.4f), turned %.4f rad; skating again at %.2f m/s; shoved walker moved to z %.2f, felled: %s; stumble felled: %s; least centre distance: today's body %.2f m (radius %.2f), sized body %.2f m (radius %.2f)" % [
			int(state["downed_at"]), int(state["got_up_at"]), up_frames, DOWN, float(state["speed_at_down"]), float(state["speed_gain_while_down"]),
			float(state["facing_turn_while_down"]), speed_after_up, float(state["walker_z"]), str(state["walker_down"]), str(was_down_at_stumble),
			float(state["least_today"]), float(state["body_today"]), float(state["least_sized"]), float(state["body_sized"])],
		"down_frames": int(state["down_frames"]), "up_frames": up_frames, "least_today": snappedf(float(state["least_today"]), 0.001),
		"least_sized": snappedf(float(state["least_sized"]), 0.001), "body_sized": snappedf(float(state["body_sized"]), 0.001)}
