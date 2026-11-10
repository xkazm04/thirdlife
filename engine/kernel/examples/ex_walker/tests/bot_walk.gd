extends Node
## Bot: walks, then runs the walker across the room through both checkpoints, using only input actions. Meanwhile it
## skates the skater for two seconds and lets go, to measure the glide on ice. It also lets go of the walker keys
## once to measure how fast a walker stops on concrete.

var ctx
var state: Dictionary = {}
var walk_speed_seen: float = 0.0
var walker_stop_frames: int = -1
var skater_speed_at_release: float = 0.0
var skater_speed_2s_later: float = 0.0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	# walker: walk 0..119, let go 120..179 (measure the stop), then run to the end
	if frame == 0:
		ctx.input.press(&"forward")
		ctx.input.press(&"skate")
	if frame == 119:
		walk_speed_seen = float(state["walker_speed"])
	if frame == 120:
		ctx.input.release(&"forward")
		skater_speed_at_release = float(state["skater_speed"])
		ctx.input.release(&"skate")
	if frame > 120 and frame < 180 and walker_stop_frames < 0 and float(state["walker_speed"]) < 0.05:
		walker_stop_frames = frame - 120
	if frame == 180:
		ctx.input.press(&"forward")
		ctx.input.press(&"run")
	if frame == 240:
		skater_speed_2s_later = float(state["skater_speed"])
	done = state["state"] == "over" and frame > 240


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and state["winner"] == "walker" and state["reason"] == "laps" \
		and absf(walk_speed_seen - 2.3) < 0.2 and float(state["walker_top_speed"]) > 5.5 \
		and walker_stop_frames >= 0 and walker_stop_frames < 30 \
		and skater_speed_at_release > 6.0 and skater_speed_2s_later > 0.8 * skater_speed_at_release \
		and int(state["crate_pushes"]) >= 1 and state["skater_surface"] == "ice" and state["walker_surface"] == "concrete"
	return {"ok": ok, "summary": "walker: walked at %.2f m/s, stopped in %d frames on concrete, ran at %.2f m/s, pushed the crate %d times, lap done (%s by %s); skater: %.2f m/s after 2 s of thrust, still %.2f m/s after 2 s of coasting on ice" % [
			walk_speed_seen, walker_stop_frames, float(state["walker_top_speed"]), int(state["crate_pushes"]), str(state["winner"]), str(state["reason"]),
			skater_speed_at_release, skater_speed_2s_later],
		"walk_speed": walk_speed_seen, "run_speed": float(state["walker_top_speed"]), "walker_stop_frames": walker_stop_frames,
		"skater_speed_at_release": skater_speed_at_release, "skater_speed_after_2s_coast": skater_speed_2s_later,
		"crate_pushes": int(state["crate_pushes"]), "total_frames": int(state["total_frames"])}
