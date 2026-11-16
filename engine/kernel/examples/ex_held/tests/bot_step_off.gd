extends Node
## Bot: lets the skater ride the shaken, held ball for 60 frames, then holds "go" so he skates off it, and watches
## him for 4 more seconds. Passes when he did stand on the ball, did leave it, and never went faster than his own
## top skating speed plus 1 m/s after leaving (a ball that acted as a platform throws him at its own speed).

var ctx
var state: Dictionary = {}
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if frame == 60:
		ctx.input.press(&"go")
	done = frame >= 60 and int(state["left_at"]) >= 0 and int(state["ticks"]) >= int(state["left_at"]) + 240 or frame >= 900


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var limit: float = float(state["skate_speed"]) + 1.0
	var ok: bool = int(state["on_ball_frames"]) >= 30 and int(state["left_at"]) >= 0 and float(state["top_speed_after"]) <= limit
	return {"ok": ok, "summary": "rode the held ball %d frames, left it at frame %d; top speed after leaving %.2f m/s (limit %.2f), on the ball %.2f m/s; the held ball moved at up to %.2f m/s" % [
			int(state["on_ball_frames"]), int(state["left_at"]), float(state["top_speed_after"]), limit, float(state["top_speed_on"]), float(state["ball_peak"])],
		"on_ball_frames": int(state["on_ball_frames"]), "left_at": int(state["left_at"]),
		"top_speed_after": snappedf(float(state["top_speed_after"]), 0.01), "top_speed_on": snappedf(float(state["top_speed_on"]), 0.01), "ball_peak": snappedf(float(state["ball_peak"]), 0.01)}
